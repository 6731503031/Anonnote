import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../l10n/app_localizations.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';

class ShareNoteScreen extends StatelessWidget {
  const ShareNoteScreen({super.key, required this.noteId});

  final String noteId;

  quill.QuillController _buildController(dynamic content) {
    if (content is List) {
      try {
        final doc = quill.Document.fromJson(content);
        return quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        return quill.QuillController.basic();
      }
    }

    if (content is String) {
      final doc = quill.Document()..insert(0, content);
      return quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    return quill.QuillController.basic();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final service = NoteService();

    return Scaffold(
      appBar: AppBar(title: Text('Shared Note')),
      body: FutureBuilder<NoteModel?>(
        future: service.getPublicNoteById(noteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load shared note',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final note = snapshot.data;
          if (note == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'This note is private or no longer available.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final controller = _buildController(note.content);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title.isEmpty ? t.untitledNote : note.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: note.tags
                      .map((tag) => Chip(label: Text(tag)))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(controller.document.toPlainText()),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
