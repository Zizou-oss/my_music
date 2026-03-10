param(
  [string]$DeviceId = "",
  [string]$RedirectTo = ""
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$adminEnv = Join-Path (Split-Path -Parent $root) "music-admin\.env"

if (-not (Test-Path $adminEnv)) {
  throw "Fichier introuvable: $adminEnv"
}

$envLines = Get-Content -Path $adminEnv
$supabaseUrl = ""
$supabaseAnonKey = ""

foreach ($line in $envLines) {
  if ($line -match "^\s*VITE_SUPABASE_URL\s*=\s*(.+)\s*$") {
    $supabaseUrl = $Matches[1].Trim()
  } elseif ($line -match "^\s*VITE_SUPABASE_ANON_KEY\s*=\s*(.+)\s*$") {
    $supabaseAnonKey = $Matches[1].Trim()
  }
}

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  throw "VITE_SUPABASE_URL ou VITE_SUPABASE_ANON_KEY manquant dans $adminEnv"
}

$args = @(
  "run",
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"
)

if (-not [string]::IsNullOrWhiteSpace($RedirectTo)) {
  $args += "--dart-define=SUPABASE_EMAIL_REDIRECT_TO=$RedirectTo"
}

if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
  $args += @("-d", $DeviceId)
}

Push-Location $root
try {
  & flutter @args
} finally {
  Pop-Location
}
