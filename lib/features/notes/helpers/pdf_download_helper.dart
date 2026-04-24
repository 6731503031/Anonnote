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
