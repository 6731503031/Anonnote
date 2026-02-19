import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_model.dart';

class NoteService {
  final _collection = FirebaseFirestore.instance.collection('notes');

  Future<void> createNote(NoteModel note) async {
    await _collection.add(note.toMap());
  }

  Stream<List<NoteModel>> getNotes() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> deleteNote(String id) async {
    await _collection.doc(id).delete();
  }
}
