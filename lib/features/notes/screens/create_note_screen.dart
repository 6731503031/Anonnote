import 'package:flutter/material.dart';
import 'dart:math' show min;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../l10n/app_localizations.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../services/auth_service.dart';

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
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final containerWidth = min(800, screenWidth - 32).toDouble();
    final bottomInset = mq.viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.black),
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
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: t.tagsHint,
                  border: const OutlineInputBorder(),
                  filled: true,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Toolbar — make it horizontally scrollable so tool buttons don't
            // cause RenderFlex overflow on narrow screens.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: quill.QuillSimpleToolbar(controller: _controller),
            ),

            // Editor (Paper style) — give the editor a bounded height by letting
            // it expand within the remaining space (no SingleChildScrollView).
            Expanded(
              child: Center(
                child: Container(
                  width: containerWidth,
                  margin: const EdgeInsets.all(16),
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        color: Colors.black.withAlpha(26),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.black),
                    child: quill.QuillEditor(
                      controller: _controller,
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      config: quill.QuillEditorConfig(
                        autoFocus: true,
                        expands: true,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveNote() async {
    try {
      final tags = tagController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final contentJson = _controller.document.toDelta().toJson();

      final note = NoteModel(
        id: '',
        title: titleController.text.trim(),
        tags: tags,
        content: contentJson,
        createdAt: DateTime.now(),
      );

      // Ensure we have an authenticated user before attempting to write.
      var uid = authService.currentUser?.uid;
      if (uid == null) {
        // Attempt idempotent anonymous sign-in; this will succeed quickly if
        // the user is already signed in, otherwise it will create a session.
        final user = await authService.signInAnonymously();
        uid = user?.uid;
      }

      if (uid == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to sign in. Please check your network or disable browser extensions that block Firebase.',
            ),
          ),
        );
        return;
      }

      // Debug: print whether an auth id token is available. If the token is
      // missing the server will see the request as unauthenticated and the
      // rules will deny it. This helps distinguish blocked webchannel vs
      // rule mismatches.
      // Removed debug logging of idToken for production.

      await service.createNote(note, userId: uid);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save note: $e')));
      }
      // Errors are surfaced to the user via SnackBar; keep logs out of prod.
    }
  }
}
