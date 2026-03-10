import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9.15.1";

type PushPayload = {
  topic?: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown>;
};

const allowedTopics = new Set(["song_updates", "app_updates"]);
const appDownloadUrl = "https://2block-web-ctth.vercel.app/";
const defaultAllowedOrigins = [
  "http://localhost:5173",
  "http://localhost:5174",
  "https://2block-web-ctth.vercel.app",
];
const allowedOrigins = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ?? defaultAllowedOrigins.join(","))
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
);

function buildCorsHeaders(origin: string | null) {
  const allowOrigin = origin && allowedOrigins.has(origin) ? origin : "null";
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

function jsonResponse(payload: unknown, status = 200, corsHeaders?: Record<string, string>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...(corsHeaders ?? {}),
      "Content-Type": "application/json",
    },
  });
}

function normalizeData(rawData?: Record<string, unknown>) {
  const entries = Object.entries(rawData ?? {});
  if (entries.length > 20) {
    throw new Error("Too many data fields");
  }

  const data: Record<string, string> = {};
  for (const [rawKey, rawValue] of entries) {
    const key = rawKey.trim();
    if (!/^[a-zA-Z0-9_.-]{1,40}$/.test(key)) {
      throw new Error(`Invalid data key: ${rawKey}`);
    }

    const value = String(rawValue ?? "").trim();
    if (value.length > 300) {
      throw new Error(`Value too long for key: ${key}`);
    }

    data[key] = value;
  }

  return data;
}

async function getGoogleAccessToken() {
  const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL") ?? "";
  const privateKeyRaw = Deno.env.get("FCM_PRIVATE_KEY") ?? "";
  const privateKeyBase64 = Deno.env.get("FCM_PRIVATE_KEY_BASE64") ?? "";

  let privateKey = privateKeyRaw.trim();
  if (!privateKey && privateKeyBase64.trim()) {
    privateKey = atob(privateKeyBase64.trim());
  }

  // Support common secret formats: quoted string and escaped newlines.
  privateKey = privateKey.replace(/^"(.*)"$/s, "$1").replace(/\\n/g, "\n").replace(/\r\n/g, "\n");

  if (!clientEmail || !privateKey) {
    throw new Error("Missing FCM_CLIENT_EMAIL or FCM_PRIVATE_KEY secret");
  }

  if (!privateKey.includes("BEGIN PRIVATE KEY")) {
    throw new Error("Invalid PEM private key format");
  }

  const client = new JWT({
    email: clientEmail,
    key: privateKey,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  // google-auth-library may return different token shapes depending on runtime.
  const credentials = await client.authorize();
  let accessToken = credentials?.access_token ?? "";

  if (!accessToken) {
    const tokenResponse = await client.getAccessToken();
    if (typeof tokenResponse === "string") {
      accessToken = tokenResponse;
    } else if (tokenResponse && typeof tokenResponse === "object" && "token" in tokenResponse) {
      accessToken = String((tokenResponse as { token?: string | null }).token ?? "");
    }
  }

  if (!accessToken) {
    throw new Error("Unable to obtain Google access token");
  }
  return accessToken;
}

serve(async (req) => {
  const origin = req.headers.get("Origin");
  const corsHeaders = buildCorsHeaders(origin);
  if (origin && !allowedOrigins.has(origin)) {
    return jsonResponse({ error: "Origin not allowed" }, 403, corsHeaders);
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, corsHeaders);
  }

  try {
    const contentType = (req.headers.get("content-type") ?? "").toLowerCase();
    if (!contentType.includes("application/json")) {
      return jsonResponse({ error: "Content-Type must be application/json" }, 415, corsHeaders);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const fcmProjectId = Deno.env.get("FCM_PROJECT_ID") ?? "";

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: "Missing Supabase secrets" }, 500, corsHeaders);
    }
    if (!fcmProjectId) {
      return jsonResponse({ error: "Missing FCM_PROJECT_ID secret" }, 500, corsHeaders);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "Missing Bearer token" }, 401, corsHeaders);
    }
    const jwt = authHeader.slice("Bearer ".length);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const {
      data: { user },
      error: userError,
    } = await adminClient.auth.getUser(jwt);
    if (userError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401, corsHeaders);
    }

    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (profileError || !profile || profile.role !== "admin") {
      return jsonResponse({ error: "Forbidden" }, 403, corsHeaders);
    }

    const rawBody = await req.text();
    if (rawBody.length > 10_000) {
      return jsonResponse({ error: "Payload too large" }, 413, corsHeaders);
    }

    let payload: PushPayload;
    try {
      payload = (JSON.parse(rawBody) ?? {}) as PushPayload;
    } catch (_) {
      return jsonResponse({ error: "Invalid JSON payload" }, 400, corsHeaders);
    }

    const topic = payload.topic?.trim();
    const title = payload.title?.trim();
    const body = payload.body?.trim();

    if (!topic || !allowedTopics.has(topic)) {
      return jsonResponse({ error: "Invalid topic" }, 400, corsHeaders);
    }
    if (!title || !body) {
      return jsonResponse({ error: "title and body are required" }, 400, corsHeaders);
    }
    if (title.length > 120) {
      return jsonResponse({ error: "title is too long (max 120)" }, 400, corsHeaders);
    }
    if (body.length > 300) {
      return jsonResponse({ error: "body is too long (max 300)" }, 400, corsHeaders);
    }

    const data = normalizeData(payload.data);
    data.topic = topic;
    data.title = title;
    data.body = body;
    if (topic === "app_updates") {
      data.notification_type = data.notification_type ?? "app_update";
      // Never allow arbitrary external URL override from payload.
      data.target_url = appDownloadUrl;
    } else if (topic === "song_updates") {
      data.notification_type = data.notification_type ?? "song_update";
    }

    const accessToken = await getGoogleAccessToken();
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`;

    const fcmResponse = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({
        message: {
          topic,
          notification: {
            title,
            body,
          },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id: "2block_push_channel",
              sound: "default",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                alert: {
                  title,
                  body,
                },
                "content-available": 1,
                sound: "default",
              },
            },
          },
        },
      }),
    });

    const responseText = await fcmResponse.text();
    if (!fcmResponse.ok) {
      return jsonResponse(
        {
          error: "FCM send failed",
          status: fcmResponse.status,
          details: responseText,
        },
        502,
        corsHeaders,
      );
    }

    try {
      await adminClient.from("admin_audit_logs").insert({
        admin_user_id: user.id,
        action: "push_broadcast",
        target_type: "push_topic",
        target_id: topic,
        payload: {
          title,
          body,
          data,
        },
      });
    } catch (_) {
      // Keep push flow non-blocking if audit insert fails.
    }

    return jsonResponse({
      ok: true,
      topic,
      fcm: responseText,
    }, 200, corsHeaders);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return jsonResponse({ error: message }, 500, corsHeaders);
  }
});
