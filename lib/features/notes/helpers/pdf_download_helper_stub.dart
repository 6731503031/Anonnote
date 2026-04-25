import 'dart:typed_data';

Future<bool> downloadFile(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  return false; // mobile ไม่ใช้
}

Future<bool> previewPdf(Uint8List bytes) async {
  // Mobile platforms should not use this web-only preview helper.
  // Return false so callers can fall back to printing/sharing.
  return false;
}
