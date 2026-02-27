import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_model.dart';

class NoteService {
  // Make the collection access lazy so constructing the service doesn't
  // immediately touch Firebase; this helps tests that don't initialize
  // Firebase to instantiate the service without throwing.
  CollectionReference get _collection =>
      FirebaseFirestore.instance.collection('notes');

  Future<void> createNote(NoteModel note) async {
    await _collection.add(note.toMap());
  }

  Stream<List<NoteModel>> getNotes() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => NoteModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> deleteNote(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> updateNote(NoteModel note) async {
    if (note.id.isEmpty) return;
    await _collection.doc(note.id).set(note.toMap());
  }
}
