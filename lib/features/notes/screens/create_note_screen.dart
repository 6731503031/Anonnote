import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../l10n/app_localizations.dart';
import '../../../widgets/color_picker.dart';
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
  String? _selectedColorHex;

  late quill.QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  late ScrollController _editorScrollController;
  late FocusNode _titleFocusNode;
  late FocusNode _tagFocusNode;
  final _titleKey = GlobalKey();
  final _tagKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _editorScrollController = ScrollController();
    _titleFocusNode = FocusNode();
    _tagFocusNode = FocusNode();

    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus) _scrollIntoView(_titleKey);
    });
    _tagFocusNode.addListener(() {
      if (_tagFocusNode.hasFocus) _scrollIntoView(_tagKey);
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    tagController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _editorScrollController.dispose();
    _titleFocusNode.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t =
        AppLocalizations.of(context) ?? AppLocalizations(const Locale('en'));
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(t.createNote),
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens_outlined),
            tooltip: 'Pick color',
            onPressed: _showColorPicker,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
            tooltip: t.save,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final editorHeight = constraints.maxHeight.clamp(200.0, 600.0);
            return SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      key: _titleKey,
                      focusNode: _titleFocusNode,
                      controller: titleController,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                      key: _tagKey,
                      focusNode: _tagFocusNode,
                      controller: tagController,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                        'Require PIN to open from the note list',
                      ),
                      value: _isHidden,
                      onChanged: (value) => setState(() => _isHidden = value),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: quill.QuillSimpleToolbar(controller: _controller),
                  ),

                  SizedBox(
                    height: editorHeight,
                    child: Builder(
                      builder: (ctx) {
                        final theme = Theme.of(ctx);
                        final isDark = theme.brightness == Brightness.dark;
                        final bg = isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white;
                        final textColor = isDark
                            ? Colors.white
                            : Colors.black87;

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: bg,
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      blurRadius: 8,
                                      color: Colors.black.withAlpha(26),
                                    ),
                                  ],
                            borderRadius: BorderRadius.circular(8),
                            border: isDark
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.04),
                                  )
                                : null,
                          ),
                          child: DefaultTextStyle(
                            style: TextStyle(color: textColor, height: 1.5),
                            child: quill.QuillEditor(
                              controller: _controller,
                              focusNode: _focusNode,
                              scrollController: _editorScrollController,
                              config: quill.QuillEditorConfig(
                                autoFocus: false,
                                expands: true,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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
        colorHex: _selectedColorHex,
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

  Future<void> _showColorPicker() async {
    final colors = const [
      Color(0xFFFBF8FF),
      Color(0xFFFFFBF0),
      Color(0xFFF0FFF4),
      Color(0xFFF0F7FF),
      Color(0xFFFFF0F6),
      Color(0xFFF7FFF9),
      Color(0xFFF6F6F9),
    ];

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pick a color'),
              const SizedBox(height: 12),
              ColorPickerWidget(
                colors: colors,
                selected: _selectedColorHex != null
                    ? Color(
                        int.parse(_selectedColorHex!.replaceFirst('#', '0xff')),
                      )
                    : null,
                onSelected: (c) {
                  setState(
                    () => _selectedColorHex =
                        '#${c.toARGB32().toRadixString(16).substring(2)}',
                  );
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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

  void _scrollIntoView(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      alignment: 0.1,
      curve: Curves.easeInOut,
    );
  }
}
