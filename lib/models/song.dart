class Song {
  final int id;
  final String title;
  final String file;
  final String cover;
  final String artist;

  Song({
    required this.id,
    required this.title,
    required this.file,
    required this.cover,
    required this.artist,
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] as int,
      title: (map['title'] ?? '').toString(),
      file: (map['file'] ?? '').toString(),
      cover: (map['cover'] ?? '').toString(),
      artist: (map['artist'] ?? '2Block').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'file': file,
      'cover': cover,
      'artist': artist,
    };
  }
}
