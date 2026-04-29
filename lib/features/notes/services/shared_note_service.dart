import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../config/app_config.dart';

import '../models/note_model.dart';
import '../models/shared_note_model.dart';
import 'auth_service.dart';

class SharedNoteService {
  CollectionReference get _collection =>
      FirebaseFirestore.instance.collection('shared_notes');

  String buildShareUrl(String sharedId) {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.hasAuthority) {
        return '${uri.scheme}://${uri.authority}/#/share/$sharedId';
      }
    }
    return '${AppConfig.webBaseUrl}/#/share/$sharedId';
  }

  Future<String> createSharedNote(NoteModel note, {DateTime? expiresAt}) async {
    final ownerId = authService.currentUser?.uid ?? '';
    final docRef = _collection.doc();
    await docRef.set({
      'noteId': note.id,
      'ownerId': ownerId,
      'title': note.title,
      'tags': note.tags,
      'content': note.content,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'isPublic': true,
    });
    return docRef.id;
  }

  Future<void> updateSharedNote(
    String sharedId,
    NoteModel note, {
    DateTime? expiresAt,
  }) async {
    await _collection.doc(sharedId).update({
      'title': note.title,
      'tags': note.tags,
      'content': note.content,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'isPublic': true,
    });
  }

  Future<void> deleteSharedNote(String sharedId) async {
    await _collection.doc(sharedId).delete();
  }

  Future<SharedNoteModel?> getSharedNoteById(String sharedId) async {
    final doc = await _collection.doc(sharedId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    if (data['isPublic'] != true) return null;
    final shared = SharedNoteModel.fromMap(data, doc.id);
    if (shared.isExpired) return null;
    return shared;
  }
}
