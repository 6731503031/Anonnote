import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../l10n/app_localizations.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import 'edit_note_screen.dart';

class NoteDetailScreen extends StatefulWidget {
  final NoteModel note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late NoteModel _note;
  final service = NoteService();

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  Future<void> _reloadNote() async {
    try {
      final fresh = await service.getNoteById(_note.id);
      if (fresh != null) {
        setState(() => _note = fresh);
      }
    } catch (_) {
      // ignore errors; keep showing existing note
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // Build a controller for the current note content to extract plain text
    quill.QuillController controller;
    if (_note.content is List) {
      try {
        final doc = quill.Document.fromJson(_note.content as List);
        controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        controller = quill.QuillController.basic();
      }
    } else if (_note.content is String) {
      final doc = quill.Document()..insert(0, _note.content as String);
      controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      controller = quill.QuillController.basic();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_note.title.isEmpty ? t.untitledNote : _note.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () async {
              // Await the edit screen and then refresh the note from server.
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditNoteScreen(note: _note)),
              );
              await _reloadNote();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: t.delete,
            onPressed: () async {
              // capture NavigatorState/info before showing the dialog to avoid
              // using BuildContext after an await (use_build_context_synchronously lint)
              final navigator = Navigator.of(context);
              final canPopBeforeDialog = navigator.canPop();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(t.delete),
                  content: Text('${t.delete}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                await service.deleteNote(_note.id);
                if (canPopBeforeDialog) navigator.pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: _note.tags.map((t) => Chip(label: Text(t))).toList(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    controller.document.toPlainText(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
