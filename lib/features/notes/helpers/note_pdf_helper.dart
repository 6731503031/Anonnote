import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/note_model.dart';

String quillDeltaToPlainText(dynamic content) {
  if (content is String) {
    return content.trim();
  }

  if (content is! List) {
    return '';
  }

  try {
    final doc = quill.Document.fromJson(content);
    return doc.toPlainText().trimRight();
  } catch (_) {
    final buffer = StringBuffer();
    for (final op in content) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is String) {
          buffer.write(insert);
        }
      }
    }
    return buffer.toString().trimRight();
  }
}

Future<pw.Font> _loadThaiFont() async {
  final candidates = <String>[
    'assets/fonts/NotoSansThai-VariableFont.ttf',
    'assets/fonts/NotoSansThai-Regular.ttf',
    'assets/fonts/NotoSansThai-Bold.ttf',
  ];

  for (final path in candidates) {
    try {
      final data = await rootBundle.load(path);
      return pw.Font.ttf(data);
    } catch (_) {
      // Try next candidate.
    }
  }

  throw StateError('Unable to load Thai font assets');
}

String _formatCreatedAt(DateTime dateTime) {
  final local = dateTime.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

String buildNoteTextExport(NoteModel note) {
  final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
  final tags = note.tags.isEmpty ? '-' : note.tags.join(', ');
  final content = quillDeltaToPlainText(note.content);

  return [
    title,
    'Created: ${_formatCreatedAt(note.createdAt)}',
    'Tags: $tags',
    '------------------------------',
    content.isEmpty ? '(No content)' : content,
  ].join('\n');
}

Future<Uint8List> buildNotePdf(NoteModel note) async {
  final contentText = quillDeltaToPlainText(note.content);

  Future<Uint8List> buildWithOptionalFont(pw.Font? font) async {
    final pdf = font == null
        ? pw.Document()
        : pw.Document(
            theme: pw.ThemeData.withFont(base: font, bold: font),
          );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim(),
            style: pw.TextStyle(
              font: font,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Created: ${_formatCreatedAt(note.createdAt)}',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Tags: ${note.tags.isEmpty ? '-' : note.tags.join(', ')}',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Text(
            contentText.isEmpty ? '(No content)' : contentText,
            style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 2),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  try {
    final thaiFont = await _loadThaiFont();
    return await buildWithOptionalFont(thaiFont);
  } catch (_) {
    // Web-safe fallback: still allow export even when custom font parsing fails.
    return await buildWithOptionalFont(null);
  }
}
