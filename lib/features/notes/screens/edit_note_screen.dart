import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../l10n/app_localizations.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';

class EditNoteScreen extends StatefulWidget {
  final NoteModel note;
  const EditNoteScreen({super.key, required this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  late final TextEditingController titleController;
  late final TextEditingController tagController;
  final service = NoteService();

  late quill.QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note.title);
    tagController = TextEditingController(text: widget.note.tags.join(', '));
    _focusNode = FocusNode();
    _scrollController = ScrollController();

    // Restore document if content is a Delta-like JSON, otherwise create basic doc
    if (widget.note.content is List) {
      try {
        final doc = quill.Document.fromJson(widget.note.content as List);
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _controller = quill.QuillController.basic();
      }
    } else if (widget.note.content is String) {
      final doc = quill.Document()..insert(0, widget.note.content as String);
      _controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _controller = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    tagController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(t.createNote),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
            tooltip: t.save,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: t.titleHint,
                border: const OutlineInputBorder(),
                filled: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: tagController,
              decoration: InputDecoration(
                hintText: t.tagsHint,
                border: const OutlineInputBorder(),
                filled: true,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Toolbar
          quill.QuillSimpleToolbar(controller: _controller),

          // Editor
          Expanded(
            child: Center(
              child: Container(
                width: 800,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(blurRadius: 8, color: Colors.black.withAlpha(26)),
                  ],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: quill.QuillEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: const quill.QuillEditorConfig(
                    autoFocus: false,
                    expands: true,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveNote() async {
    final tags = tagController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final note = NoteModel(
      id: widget.note.id,
      title: titleController.text.trim(),
      tags: tags,
      content: _controller.document.toDelta().toJson(),
      createdAt: widget.note.createdAt,
    );

    try {
      await service.updateNote(note);
      if (mounted) {
        // Inform user of success then close editor.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Note saved')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save note: $e')));
      }
    }
  }
}
