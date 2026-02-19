class NoteModel {
  final String id;
  final String title;
  final List<String> tags;
  final dynamic content;
  final DateTime createdAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.tags,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'tags': tags,
      'content': content,
      'createdAt': createdAt,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map, String id) {
    return NoteModel(
      id: id,
      title: map['title'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      content: map['content'],
      createdAt: map['createdAt'].toDate(),
    );
  }
}
