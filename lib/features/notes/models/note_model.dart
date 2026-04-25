class NoteModel {
  final String id;
  final String title;
  final List<String> tags;
  final dynamic content;
  final DateTime createdAt;
  final DateTime? expireAt;
  final bool isHidden;
  final bool isFavorite;
  final bool isPublic;
  // Optional color stored as hex string (e.g. '#F6F8FF') for note color tint
  final String? colorHex;

  NoteModel({
    required this.id,
    required this.title,
    required this.tags,
    required this.content,
    required this.createdAt,
    this.expireAt,
    this.isHidden = false,
    this.isFavorite = false,
    this.isPublic = false,
    this.colorHex,
  });

  NoteModel copyWith({
    String? id,
    String? title,
    List<String>? tags,
    dynamic content,
    DateTime? createdAt,
    DateTime? expireAt,
    bool? isHidden,
    bool? isFavorite,
    bool? isPublic,
    String? colorHex,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      expireAt: expireAt ?? this.expireAt,
      isHidden: isHidden ?? this.isHidden,
      isFavorite: isFavorite ?? this.isFavorite,
      isPublic: isPublic ?? this.isPublic,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  bool get isExpired {
    final expiry = expireAt;
    if (expiry == null) return false;
    return !expiry.isAfter(DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'tags': tags,
      'content': content,
      'createdAt': createdAt,
      'expireAt': expireAt,
      'isHidden': isHidden,
      'isFavorite': isFavorite,
      'isPublic': isPublic,
      'colorHex': colorHex,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map, String id) {
    final dynamic createdAtRaw = map['createdAt'];
    final DateTime createdAt = createdAtRaw is DateTime
        ? createdAtRaw
        : createdAtRaw != null
        ? createdAtRaw.toDate()
        : DateTime.now();

    final dynamic expireAtRaw = map['expireAt'];
    final DateTime? expireAt = expireAtRaw == null
        ? null
        : expireAtRaw is DateTime
        ? expireAtRaw
        : expireAtRaw.toDate();

    return NoteModel(
      id: id,
      title: map['title'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      content: map['content'],
      createdAt: createdAt,
      expireAt: expireAt,
      isHidden: map['isHidden'] == true,
      isFavorite: map['isFavorite'] == true,
      isPublic: map['isPublic'] == true,
      colorHex: map['colorHex'] as String?,
    );
  }
}
