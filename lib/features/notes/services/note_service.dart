import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_model.dart';
import 'auth_service.dart';

class NoteService {
  // Make the collection access lazy so constructing the service doesn't
  // immediately touch Firebase; this helps tests that don't initialize
  // Firebase to instantiate the service without throwing.
  CollectionReference get _collection =>
      FirebaseFirestore.instance.collection('notes');

  /// Create a note. If [userId] is provided it will be saved on the document.
  /// The service will set `createdAt` to Firestore `Timestamp.now()` to keep
  /// server/storage consistent.
  Future<void> createNote(NoteModel note, {String? userId}) async {
    final map = Map<String, dynamic>.from(note.toMap());
    map['createdAt'] = Timestamp.now();
    if (userId != null) map['userId'] = userId;
    await _collection.add(map);
  }

  // Removed global getNotes() to enforce per-user access. Use
  // getNotesForCurrentUser() instead which filters by the signed-in uid.

  /// Returns a raw Firestore QuerySnapshot stream containing notes for the
  /// currently signed-in anonymous user, ordered by `createdAt` descending.
  /// If there is no signed-in user this returns an empty stream.
  Stream<QuerySnapshot<Map<String, dynamic>>> getNotesSnapshotForCurrentUser() {
    final uid = authService.currentUser?.uid;
    if (uid == null) return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();

    return FirebaseFirestore.instance
        .collection('notes')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .cast<QuerySnapshot<Map<String, dynamic>>>();
  }

  /// Typed stream of [NoteModel] for the current user. Returns an empty
  /// stream when there is no signed-in user.
  Stream<List<NoteModel>> getNotesForCurrentUser() {
    final uid = authService.currentUser?.uid;
    if (uid == null) return Stream.value(<NoteModel>[]);

    return FirebaseFirestore.instance
        .collection('notes')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> deleteNote(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> updateNote(NoteModel note) async {
    if (note.id.isEmpty) return;

    // Use update() to modify only the editable fields so we don't overwrite
    // server-managed or security-critical fields like `userId` or the
    // original `createdAt` timestamp. This prevents losing the owner UID
    // when saving edits.
    await _collection.doc(note.id).update({
      'title': note.title,
      'tags': note.tags,
      'content': note.content,
    });
  }
}
