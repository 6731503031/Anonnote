import 'dart:typed_data';

import 'pdf_download_helper_stub.dart'
    if (dart.library.html) 'pdf_download_helper_web.dart'
    as impl;

Future<bool> downloadFile(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) {
  return impl.downloadFile(bytes, filename, mimeType: mimeType);
}

Future<bool> downloadPdfFile(Uint8List bytes, String filename) {
  return downloadFile(bytes, filename, mimeType: 'application/pdf');
}

/// Attempt to preview PDF bytes. On web this will open a new tab with the
/// PDF preview. On mobile platforms this will return false so callers can
/// fall back to existing share/printing UI.
Future<bool> previewPdf(Uint8List bytes) {
  return impl.previewPdf(bytes);
}
