import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/note_model.dart';
import '../services/auth_service.dart';
import '../services/note_service.dart';

class NoteImportResult {
  final int importedCount;
  final String message;

  const NoteImportResult({required this.importedCount, required this.message});
}

Future<NoteImportResult> pickAndImportNotes() async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
    );

    if (picked == null || picked.files.isEmpty) {
      return const NoteImportResult(
        importedCount: 0,
        message: 'Import cancelled',
      );
    }

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return const NoteImportResult(
        importedCount: 0,
        message: 'Selected file is empty',
      );
    }

    final uid = await _ensureUserId();
    if (uid == null) {
      return const NoteImportResult(
        importedCount: 0,
        message: 'Unable to sign in. Try again.',
      );
    }

    final extension = (file.extension ?? '').toLowerCase();
    final text = utf8.decode(bytes, allowMalformed: true);

    final notes = switch (extension) {
      'txt' => _parseTxtToNotes(file.name, text),
      'json' => _parseJsonToNotes(text),
      _ => <NoteModel>[],
    };

    if (notes.isEmpty) {
      return const NoteImportResult(
        importedCount: 0,
        message: 'No valid notes found in file',
      );
    }

    final service = NoteService();
    for (final note in notes) {
      await service.createNote(note, userId: uid);
    }

    return NoteImportResult(
      importedCount: notes.length,
      message: 'Imported ${notes.length} note(s)',
    );
  } catch (e, st) {
    // Don't let unexpected runtime errors (including LateInitializationError)
    // bubble up to the caller. Return a friendly result so the UI can show
    // a clear SnackBar message instead of crashing.
    // Log to debug console when available.
    try {
      // ignore: avoid_print
      print('Note import failed: $e\n$st');
    } catch (_) {}
    return NoteImportResult(importedCount: 0, message: 'Import failed: $e');
  }
}

Future<String?> _ensureUserId() async {
  var uid = authService.currentUser?.uid;
  if (uid != null) return uid;

  final user = await authService.signInAnonymously();
  uid = user?.uid;
  return uid;
}

List<NoteModel> _parseTxtToNotes(String filename, String text) {
  final title = _baseNameWithoutExtension(filename);
  return [
    NoteModel(
      id: '',
      title: title.isEmpty ? 'Imported note' : title,
      tags: const <String>[],
      content: _toDeltaContent(text),
      createdAt: DateTime.now(),
      isHidden: false,
      isFavorite: false,
      isPublic: false,
    ),
  ];
}

List<NoteModel> _parseJsonToNotes(String text) {
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return const <NoteModel>[];
  }

  if (decoded is List) {
    return decoded
        .whereType<Map>()
        .map((item) => _mapJsonToNote(item.cast<String, dynamic>()))
        .whereType<NoteModel>()
        .toList();
  }

  if (decoded is Map<String, dynamic>) {
    final note = _mapJsonToNote(decoded);
    return note == null ? const <NoteModel>[] : <NoteModel>[note];
  }

  return const <NoteModel>[];
}

NoteModel? _mapJsonToNote(Map<String, dynamic> map) {
  final rawTitle = (map['title'] ?? '').toString().trim();
  final rawContent = map['content'];

  final title = rawTitle.isEmpty ? 'Imported note' : rawTitle;
  final tags = _parseTags(map['tags']);
  final content = _toDeltaContent(rawContent);

  return NoteModel(
    id: '',
    title: title,
    tags: tags,
    content: content,
    createdAt: DateTime.now(),
    isHidden: false,
    isFavorite: false,
    isPublic: false,
  );
}

List<String> _parseTags(dynamic tagsRaw) {
  if (tagsRaw is List) {
    return tagsRaw
        .map((t) => t.toString().trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
  if (tagsRaw is String) {
    return tagsRaw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

dynamic _toDeltaContent(dynamic rawContent) {
  // If content already looks like a Quill delta list, return as-is.
  if (rawContent is List) {
    return rawContent;
  }

  // Some JSON exports may include a Map with an 'ops' key or delta-like
  // structure. Try to normalize that into the expected List format.
  if (rawContent is Map) {
    // Common shapes: {"ops": [...] } or {"delta": [...] }
    if (rawContent['ops'] is List) {
      return rawContent['ops'];
    }
    if (rawContent['delta'] is List) {
      return rawContent['delta'];
    }
    // If it's already a map representation of a single insert, convert to list
    if (rawContent.containsKey('insert')) {
      return [rawContent.cast<String, dynamic>()];
    }
  }

  final text = (rawContent ?? '').toString();
  return <Map<String, String>>[
    {'insert': text.isEmpty ? '\n' : text},
  ];
}

String _baseNameWithoutExtension(String fileName) {
  final slash = fileName.replaceAll('\\', '/').split('/').last;
  final dotIndex = slash.lastIndexOf('.');
  if (dotIndex <= 0) return slash;
  return slash.substring(0, dotIndex);
}
