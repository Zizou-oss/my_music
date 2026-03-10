class Song {
  final int id;
  final String title;
  final String file;
  final String cover;
  final String artist;
  final String lyrics;
  final String lyricsLrc;
  final String storagePath;
  final String? localPath;
  final int playsCount;
  final DateTime? createdAt;

  Song({
    required this.id,
    required this.title,
    required this.file,
    required this.cover,
    required this.artist,
    this.lyrics = '',
    this.lyricsLrc = '',
    this.storagePath = '',
    this.localPath,
    this.playsCount = 0,
    this.createdAt,
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['created_at']?.toString();
    if (rawCreatedAt != null && rawCreatedAt.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }
    return Song(
      id: (map['id'] as num).toInt(),
      title: (map['title'] ?? '').toString(),
      file: (map['file'] ?? '').toString(),
      cover: (map['cover'] ?? '').toString(),
      artist: (map['artist'] ?? '2Block').toString(),
      lyrics: (map['lyrics'] ?? '').toString(),
      lyricsLrc: (map['lyrics_lrc'] ?? '').toString(),
      storagePath: (map['storage_path'] ?? '').toString(),
      localPath: map['local_path']?.toString(),
      playsCount: (map['plays_count'] as num?)?.toInt() ?? 0,
      createdAt: parsedCreatedAt,
    );
  }

  bool get isDownloaded => localPath != null && localPath!.isNotEmpty;

  Song copyWith({
    int? id,
    String? title,
    String? file,
    String? cover,
    String? artist,
    String? lyrics,
    String? lyricsLrc,
    String? storagePath,
    String? localPath,
    int? playsCount,
    DateTime? createdAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      file: file ?? this.file,
      cover: cover ?? this.cover,
      artist: artist ?? this.artist,
      lyrics: lyrics ?? this.lyrics,
      lyricsLrc: lyricsLrc ?? this.lyricsLrc,
      storagePath: storagePath ?? this.storagePath,
      localPath: localPath ?? this.localPath,
      playsCount: playsCount ?? this.playsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'file': file,
      'cover': cover,
      'artist': artist,
      'lyrics': lyrics,
      'lyrics_lrc': lyricsLrc,
      'storage_path': storagePath,
      'local_path': localPath,
      'plays_count': playsCount,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
