import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../l10n/app_localizations.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../services/auth_service.dart';

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
  late bool _isHidden;
  DateTime? _expireAt;

  late quill.QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note.title);
    tagController = TextEditingController(text: widget.note.tags.join(', '));
    _isHidden = widget.note.isHidden;
    _expireAt = widget.note.expireAt;
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
                subtitle: const Text(
                  'Hidden notes are excluded from the normal note list',
                ),
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

            // Toolbar — make it horizontally scrollable on narrow screens.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: quill.QuillSimpleToolbar(controller: _controller),
            ),

            // Editor — put editor in an Expanded container and let it expand
            // to a bounded height so its internal widgets can layout.
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
        id: widget.note.id,
        title: titleController.text.trim(),
        tags: tags,
        content: contentJson,
        createdAt: widget.note.createdAt,
        expireAt: _expireAt,
        isHidden: _isHidden,
        isFavorite: widget.note.isFavorite,
        isPublic: widget.note.isPublic,
      );

      // Ensure we are signed in before attempting an update (rules require auth).
      if (authService.currentUser == null) {
        await authService.signInAnonymously();
      }

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
      // error surfaced to user; no console debug print in production.
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
