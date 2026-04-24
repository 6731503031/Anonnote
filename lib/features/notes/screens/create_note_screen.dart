import 'package:flutter/material.dart';
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
  DateTime? _expireAt;
  bool _isHidden = false;

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SwitchListTile(
                title: const Text('Hidden Note'),
                subtitle: const Text('Require PIN to open from the note list'),
                value: _isHidden,
                onChanged: (value) => setState(() => _isHidden = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Self-destruct'),
                subtitle: Text(
                  _expireAt == null
                      ? 'No expiry set'
                      : 'Expires: ${_expireAt!.toLocal()}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (_expireAt != null)
                      IconButton(
                        tooltip: 'Clear expiry',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _expireAt = null),
                      ),
                    IconButton(
                      tooltip: 'Pick expiry date/time',
                      icon: const Icon(Icons.edit_calendar_outlined),
                      onPressed: _pickExpiry,
                    ),
                  ],
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
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(blurRadius: 8, color: Colors.black.withAlpha(26)),
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
        expireAt: _expireAt,
        isHidden: _isHidden,
        isFavorite: false,
        isPublic: false,
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

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final base = _expireAt ?? now.add(const Duration(hours: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (pickedTime == null || !mounted) return;

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!selected.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiry must be in the future')),
      );
      return;
    }

    setState(() => _expireAt = selected);
  }
}
