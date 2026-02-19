import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../l10n/app_localizations.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';

class CreateNoteScreen extends StatefulWidget {
  const CreateNoteScreen({super.key});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final titleController = TextEditingController();
  final tagController = TextEditingController();
  final service = NoteService();

  late quill.QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
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

          // Editor (Paper style)
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
                    autoFocus: true,
                    expands: true, // สำคัญมากสำหรับ Web
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
      id: '',
      title: titleController.text.trim(),
      tags: tags,
      content: _controller.document.toDelta().toJson(),
      createdAt: DateTime.now(),
    );

    await service.createNote(note);
    if (mounted) Navigator.pop(context);
  }
}
