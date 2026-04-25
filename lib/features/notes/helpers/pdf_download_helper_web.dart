import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

Future<bool> downloadFile(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();

  html.Url.revokeObjectUrl(url);
  return true;
}

Future<bool> previewPdf(Uint8List bytes) async {
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    // Open in a new tab for preview
    html.window.open(url, '_blank');
    // Note: do not revoke immediately; browsers will revoke when tab is closed
    return true;
  } catch (_) {
    return false;
  }
}
