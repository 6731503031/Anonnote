import 'dart:typed_data';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;

Future<bool> downloadFile(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  try {
    final base64 = base64Encode(bytes);
    final dataUrl = 'data:$mimeType;base64,$base64';

    final anchor = html.AnchorElement(href: dataUrl)
      ..download = filename
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}
