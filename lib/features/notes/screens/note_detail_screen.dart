// File: lib/features/notes/screens/note_detail_screen.dart
import 'dart:convert';
// dart:typed_data is not required here (provided via flutter/foundation)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../helpers/note_pdf_helper.dart';
import '../helpers/pdf_download_helper.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import 'edit_note_screen.dart';
import '../../../widgets/tag_chip.dart';
import '../../../widgets/note_content_card.dart';
import '../../../widgets/top_action_card.dart';

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
      if (fresh != null && mounted) {
        setState(() => _note = fresh);
      }
    } catch (_) {
      // ignore errors
    }
  }

  String _buildShareUrl(String noteId) {
    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.authority}/#/share/$noteId';
    }
    return 'https://your-domain.com/#/share/$noteId';
  }

  Future<void> _copyShareLink() async {
    final link = _buildShareUrl(_note.id);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share link copied')));
  }

  Future<void> _setPublicState(bool value) async {
    final updated = _note.copyWith(isPublic: value);
    await service.updateNote(updated);
    if (!mounted) return;
    setState(() => _note = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'Public link enabled' : 'Public link disabled'),
      ),
    );
  }

  Future<void> _previewNotePdf() async {
    final bytes = await buildNotePdf(_note);
    if (!mounted) return;

    // Try web preview helper first (opens new tab on web).
    try {
      final ok = await previewPdf(bytes);
      if (ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF opened in new tab')));
        return;
      }
    } catch (_) {
      // Fall through to in-app preview
    }

    // Fallback: show PdfPreview inside app (mobile)
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('PDF Preview'), elevation: 0),
          body: PdfPreview(
            build: (format) async => bytes,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
          ),
        ),
      ),
    );
  }

  Future<void> _shareOrDownloadNotePdf() async {
    try {
      final bytes = await buildNotePdf(_note);
      final baseName = _note.title.trim().isEmpty
          ? 'note'
          : _note.title.trim().replaceAll(RegExp(r'[^\wก-๙_-]+'), '_');
      final safeBaseName = baseName.replaceAll(RegExp(r'^_+|_+$'), '');
      final filename = '${safeBaseName.isEmpty ? 'note' : safeBaseName}.pdf';

      if (kIsWeb) {
        // Try to download using platform helper (will trigger download)
        final ok = await downloadFile(
          bytes,
          filename,
          mimeType: 'application/pdf',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'PDF downloaded' : 'Unable to download PDF'),
          ),
        );
        return;
      }

      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportTxt() async {
    try {
      final text = buildNoteTextExport(_note);
      final bytes = Uint8List.fromList(utf8.encode(text));
      final baseName = _note.title.trim().isEmpty
          ? 'note'
          : _note.title.trim().replaceAll(RegExp(r'[^\wก-๙_-]+'), '_');
      final safeBaseName = baseName.replaceAll(RegExp(r'^_+|_+$'), '');
      final filename = '${safeBaseName.isEmpty ? 'note' : safeBaseName}.txt';

      if (kIsWeb) {
        final ok = await downloadFile(
          bytes,
          filename,
          mimeType: 'text/plain;charset=utf-8',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'TXT downloaded' : 'Unable to download TXT'),
          ),
        );
        return;
      }

      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: 'text/plain', name: filename),
      ], text: 'Note export');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('TXT export failed: $e')));
    }
  }

  Widget _buildTopActionCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final borderColor = colorScheme.onSurface.withAlpha(18);
    final linkColor = colorScheme.primary;
    final pdfColor = Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      margin: EdgeInsets.zero,
      color: theme.cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Public toggle
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.link_outlined, color: linkColor),
            title: const Text(
              'Public Link',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Allow anyone with link to read this note'),
            trailing: Switch(
              value: _note.isPublic,
              onChanged: (v) async {
                await _setPublicState(v);
              },
              activeThumbColor: linkColor,
            ),
          ),
          const Divider(height: 0),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.link, color: linkColor),
            title: const Text('Copy share link'),
            subtitle: Text(
              _note.isPublic
                  ? _buildShareUrl(_note.id)
                  : 'Enable Public Link first',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            enabled: _note.isPublic,
            onTap: _note.isPublic ? _copyShareLink : null,
          ),
          const Divider(height: 0),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.picture_as_pdf_outlined, color: pdfColor),
            title: const Text('Export PDF'),
            subtitle: const Text('Preview and download/share'),
            onTap: _previewNotePdf,
            trailing: IconButton(
              icon: const Icon(Icons.more_vert_outlined),
              onPressed: _showExportOptions,
              tooltip: 'More',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportOptions() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Preview PDF'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _previewNotePdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(kIsWeb ? 'Download PDF' : 'Share PDF'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _shareOrDownloadNotePdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(kIsWeb ? 'Download TXT' : 'Share TXT'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _exportTxt();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String quillDeltaToPlainText(dynamic content) {
    if (content is String) return content.trim();

    if (content is! List) return '';

    try {
      final doc = quill.Document.fromJson(content);
      return doc.toPlainText().trimRight();
    } catch (_) {
      final buffer = StringBuffer();
      for (final op in content) {
        if (op is Map && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) buffer.write(insert);
        }
      }
      return buffer.toString().trimRight();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    const contentPadding = EdgeInsets.all(16);

    // Build quill controller from stored content (support List, Map, String safely)
    quill.QuillController controller;
    try {
      if (_note.content is List) {
        final doc = quill.Document.fromJson(_note.content as List);
        controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else if (_note.content is Map) {
        final Map contentMap = _note.content as Map;
        List<dynamic>? deltaList;
        if (contentMap['ops'] is List) {
          deltaList = contentMap['ops'] as List<dynamic>;
        }
        if (deltaList == null && contentMap['delta'] is List) {
          deltaList = contentMap['delta'] as List<dynamic>;
        }
        if (deltaList == null && contentMap.containsKey('insert')) {
          deltaList = [contentMap.cast<String, dynamic>()];
        }
        if (deltaList != null) {
          final doc = quill.Document.fromJson(deltaList);
          controller = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
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
    } catch (_) {
      controller = quill.QuillController.basic();
    }

    final isEmpty = controller.document.isEmpty();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          _note.title.isEmpty ? t.untitledNote : _note.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () async {
              final changed = await Navigator.push<bool?>(
                context,
                MaterialPageRoute(builder: (_) => EditNoteScreen(note: _note)),
              );
              if (changed == true) await _reloadNote();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: t.delete,
            onPressed: () async {
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
      body: SingleChildScrollView(
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top card with actions
            TopActionCard(child: _buildTopActionCard(theme)),
            const SizedBox(height: 12),

            // Tags row
            if (_note.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _note.tags.map((tag) => TagChip(tag: tag)).toList(),
              ),
            if (_note.tags.isNotEmpty) const SizedBox(height: 12),

            // Content area
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: isEmpty
                  ? NoteContentCard(
                      plainText: null,
                      isEmpty: true,
                      key: const ValueKey('empty'),
                    )
                  : AbsorbPointer(
                      absorbing: true,
                      child: NoteContentCard(
                        controller: controller,
                        isEmpty: false,
                        key: const ValueKey('content'),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
