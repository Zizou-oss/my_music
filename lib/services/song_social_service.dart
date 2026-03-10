import 'package:flutter/foundation.dart';

import '../models/song_social.dart';
import 'supabase_service.dart';

class SongSocialService {
  Future<Map<int, SongSocialStats>> getStatsForSongs(List<int> songIds) async {
    if (!SupabaseService.isEnabled || songIds.isEmpty) {
      return <int, SongSocialStats>{};
    }

    try {
      final rows = await SupabaseService.client
          .rpc(
            'get_song_social_counts',
            params: <String, dynamic>{'p_song_ids': songIds},
          )
          .timeout(const Duration(seconds: 5));

      final stats = <int, SongSocialStats>{};
      for (final row in (rows as List<dynamic>)) {
        final item = SongSocialStats.fromMap(row as Map<String, dynamic>);
        stats[item.songId] = item;
      }
      return stats;
    } catch (e) {
      debugPrint('SongSocialService.getStatsForSongs failed: $e');
      return <int, SongSocialStats>{};
    }
  }

  Future<SongSocialStats?> toggleLike(int songId) async {
    if (!SupabaseService.isEnabled || SupabaseService.currentUser == null) {
      return null;
    }

    try {
      final rows = await SupabaseService.client
          .rpc(
            'toggle_song_like',
            params: <String, dynamic>{'p_song_id': songId},
          )
          .timeout(const Duration(seconds: 5));

      final row = (rows as List<dynamic>).cast<Map<String, dynamic>>().first;
      return SongSocialStats(
        songId: (row['song_id'] as num).toInt(),
        likesCount: (row['likes_count'] as num?)?.toInt() ?? 0,
        commentsCount: (row['comments_count'] as num?)?.toInt() ?? 0,
        hasLiked: row['liked'] == true,
      );
    } catch (e) {
      debugPrint('SongSocialService.toggleLike failed: $e');
      return null;
    }
  }

  Future<List<SongComment>> getComments(
    int songId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (!SupabaseService.isEnabled) {
      return const <SongComment>[];
    }

    try {
      final rows = await SupabaseService.client
          .rpc(
            'get_song_comments',
            params: <String, dynamic>{
              'p_song_id': songId,
              'p_limit': limit,
              'p_offset': offset,
            },
          )
          .timeout(const Duration(seconds: 5));

      return (rows as List<dynamic>)
          .map((row) => SongComment.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SongSocialService.getComments failed: $e');
      return const <SongComment>[];
    }
  }

  Future<String?> addComment(int songId, String body) async {
    if (!SupabaseService.isEnabled) {
      return 'Commentaires indisponibles pour le moment.';
    }
    if (SupabaseService.currentUser == null) {
      return 'Connecte-toi pour commenter.';
    }

    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'Ecris un commentaire avant d envoyer.';
    }
    if (trimmed.length > 500) {
      return 'Le commentaire est limite a 500 caracteres.';
    }

    try {
      await SupabaseService.client
          .rpc(
            'add_song_comment',
            params: <String, dynamic>{
              'p_song_id': songId,
              'p_body': trimmed,
            },
          )
          .timeout(const Duration(seconds: 5));
      return null;
    } catch (e) {
      debugPrint('SongSocialService.addComment failed: $e');
      return 'Impossible d envoyer le commentaire.';
    }
  }

  Future<String?> deleteComment(int commentId) async {
    if (!SupabaseService.isEnabled || SupabaseService.currentUser == null) {
      return 'Action impossible.';
    }

    try {
      await SupabaseService.client
          .rpc(
            'delete_song_comment',
            params: <String, dynamic>{'p_comment_id': commentId},
          )
          .timeout(const Duration(seconds: 5));
      return null;
    } catch (e) {
      debugPrint('SongSocialService.deleteComment failed: $e');
      return 'Suppression impossible.';
    }
  }
}
