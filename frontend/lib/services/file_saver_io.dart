import 'dart:io';
import 'dart:typed_data';

import 'file_saver.dart';

/// Non-web implementation: the document is written to the system temporary
/// directory and the path is reported back to the inspector.
const bool savesToBrowserDownload = false;

Future<SaveOutcome> saveDocument(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  final directory = await Directory.systemTemp.createTemp('onion_detect_');
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return SaveOutcome(savedToBrowser: false, location: file.path);
}
