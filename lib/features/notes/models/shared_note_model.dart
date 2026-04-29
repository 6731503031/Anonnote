import 'package:cloud_firestore/cloud_firestore.dart';

class SharedNoteModel {
  final String id;
  final String noteId;
  final String ownerId;
  final String title;
  final List<String> tags;
  final dynamic content;
  final DateTime createdAt;
  final DateTime? expiresAt;

  SharedNoteModel({
    required this.id,
    required this.noteId,
    required this.ownerId,
    required this.title,
    required this.tags,
    required this.content,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return !expiry.isAfter(DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {
      'noteId': noteId,
      'ownerId': ownerId,
      'title': title,
      'tags': tags,
      'content': content,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'isPublic': true,
    };
  }

  factory SharedNoteModel.fromMap(Map<String, dynamic> map, String id) {
    final dynamic createdAtRaw = map['createdAt'];
    final createdAt = createdAtRaw is DateTime
        ? createdAtRaw
        : createdAtRaw != null
        ? (createdAtRaw as Timestamp).toDate()
        : DateTime.now();

    final dynamic expiresAtRaw = map['expiresAt'];
    final DateTime? expiresAt = expiresAtRaw == null
        ? null
        : expiresAtRaw is DateTime
        ? expiresAtRaw
        : (expiresAtRaw as Timestamp).toDate();

    return SharedNoteModel(
      id: id,
      noteId: map['noteId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      content: map['content'],
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}
