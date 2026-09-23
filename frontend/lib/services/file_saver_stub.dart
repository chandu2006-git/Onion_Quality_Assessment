import 'dart:typed_data';

import 'file_saver.dart';

/// Fallback implementation used when neither `dart:io` nor browser APIs exist.
const bool savesToBrowserDownload = false;

Future<SaveOutcome> saveDocument(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async =>
    throw UnsupportedError(
      'Saving documents is not supported on this platform.',
    );
