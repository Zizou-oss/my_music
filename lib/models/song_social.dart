class SongSocialStats {
  final int songId;
  final int likesCount;
  final int commentsCount;
  final bool hasLiked;

  const SongSocialStats({
    required this.songId,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.hasLiked = false,
  });

  factory SongSocialStats.fromMap(Map<String, dynamic> map) {
    return SongSocialStats(
      songId: (map['song_id'] as num).toInt(),
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (map['comments_count'] as num?)?.toInt() ?? 0,
      hasLiked: map['viewer_has_liked'] == true || map['liked'] == true,
    );
  }

  SongSocialStats copyWith({
    int? songId,
    int? likesCount,
    int? commentsCount,
    bool? hasLiked,
  }) {
    return SongSocialStats(
      songId: songId ?? this.songId,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      hasLiked: hasLiked ?? this.hasLiked,
    );
  }
}

class SongComment {
  final int id;
  final int songId;
  final String body;
  final String userName;
  final String userId;
  final DateTime createdAt;
  final bool isMine;

  const SongComment({
    required this.id,
    required this.songId,
    required this.body,
    required this.userName,
    required this.userId,
    required this.createdAt,
    required this.isMine,
  });

  factory SongComment.fromMap(Map<String, dynamic> map) {
    return SongComment(
      id: (map['comment_id'] as num).toInt(),
      songId: (map['song_id'] as num).toInt(),
      body: (map['body'] ?? '').toString(),
      userName: (map['user_name'] ?? 'Utilisateur').toString(),
      userId: (map['user_id'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      isMine: map['is_mine'] == true,
    );
  }
}
