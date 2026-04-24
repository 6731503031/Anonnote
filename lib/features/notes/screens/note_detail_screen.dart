import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../helpers/pdf_download_helper.dart';
import '../helpers/note_pdf_helper.dart';
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

  String _buildShareUrl(String noteId) {
    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.authority}/#/share/$noteId';
    }
    return 'https://your-domain.com/#/share/$noteId';
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

  Future<void> _copyShareLink() async {
    final link = _buildShareUrl(_note.id);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share link copied')));
  }

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

  Future<void> _previewNotePdf() async {
    final bytes = await buildNotePdf(_note);
    if (!mounted) return;

    // Try to show an in-app preview on web as well. Some browsers/hosts may
    // not support embedded preview; in that case fall back to download/share.
    if (kIsWeb) {
      try {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('PDF Preview')),
              body: PdfPreview(
                build: (format) async => bytes,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
              ),
            ),
          ),
        );
        return;
      } catch (e) {
        // Preview failed on this platform/context. Fall back to download/share.
        await _shareOrDownloadNotePdf();
        return;
      }
    }

    // Non-web platforms: show native preview.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('PDF Preview')),
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
          : _note.title.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
      final safeBaseName = baseName.replaceAll(RegExp(r'^_+|_+$'), '');
      final filename = '${safeBaseName.isEmpty ? 'note' : safeBaseName}.pdf';

      if (kIsWeb) {
        try {
          await Printing.sharePdf(bytes: bytes, filename: filename);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('PDF ready')));
          return;
        } catch (_) {
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
          : _note.title.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
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

  Future<void> _showExportPdfSheet() async {
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
                leading: const Icon(Icons.share_outlined),
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // Build a controller for the current note content to extract plain text
    quill.QuillController controller;

    // Normalize several possible stored shapes for content: List (delta),
    // Map (e.g. {'ops': [...]}, {'delta': [...]}, or {'insert': ...}),
    // or plain String. If normalization fails, fall back to an empty controller.
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
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Public Link'),
                    subtitle: const Text(
                      'Allow anyone with link to read this note',
                    ),
                    value: _note.isPublic,
                    onChanged: _setPublicState,
                  ),
                  ListTile(
                    leading: const Icon(Icons.link),
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
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Export PDF'),
                    subtitle: const Text('Preview and download/share'),
                    onTap: _showExportPdfSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
