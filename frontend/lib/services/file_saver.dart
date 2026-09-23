import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart' as implementation;

/// Where a generated document ended up after saving.
class SaveOutcome {
  const SaveOutcome({required this.savedToBrowser, this.location});

  /// True on Flutter Web: the browser download was started.
  final bool savedToBrowser;

  /// Filesystem path when the document was written locally (mobile/desktop).
  final String? location;
}

/// Saves a generated document (the inspection PDF).
///
/// On the web the bytes are handed to the browser as a download; on other
/// platforms the document is written to a temporary directory. The concrete
/// implementation is selected at compile time so no `dart:io` code is ever
/// compiled for the web target.
Future<SaveOutcome> saveDocument(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) =>
    implementation.saveDocument(bytes, fileName: fileName, mimeType: mimeType);

/// True when saving triggers a browser download instead of writing a file.
bool get savesToBrowserDownload => implementation.savesToBrowserDownload;
