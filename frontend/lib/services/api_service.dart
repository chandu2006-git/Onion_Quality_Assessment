import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../core/api_exception.dart';
import '../models/analysis_result.dart';
import '../models/backend_status.dart';

/// Result of a PDF request: the document bytes and the file name reported by the
/// backend through `Content-Disposition`.
class ReportDocument {
  const ReportDocument({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// The single HTTP client used by the application.
///
/// The base URL comes from [AppConfig] (build-time `API_BASE_URL`), so no screen
/// contains a hard-coded backend address. Model inference always happens on the
/// server; this class only transports images, JSON and the generated PDF.
class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.normalizedApiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  void dispose() => _client.close();

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// `GET /api/health`
  Future<BackendStatus> health() async {
    try {
      final response =
          await _client.get(_uri('/api/health')).timeout(AppConfig.healthTimeout);
      if (response.statusCode != 200) {
        return BackendStatus.unreachable(
          message: 'The service responded with status ${response.statusCode}.',
        );
      }
      return BackendStatus.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on TimeoutException {
      return BackendStatus.unreachable(message: 'The health check timed out.');
    } catch (error) {
      return BackendStatus.unreachable(message: error.toString());
    }
  }

  /// `POST /api/analyze` — real detection + per-bulb health classification.
  ///
  /// [onUploadProgress] receives the genuinely transmitted byte count of the
  /// multipart upload; no progress value is invented anywhere.
  Future<AnalysisResult> analyzeSample({
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/analyze'))
      ..files.add(
        http.MultipartFile(
          'image',
          _progressStream(bytes, onUploadProgress),
          bytes.length,
          filename: fileName,
          contentType: MediaType('image', _subtypeFor(fileName)),
        ),
      );

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(
            AppConfig.analysisTimeout,
            onTimeout: () => throw ApiException.timeout(),
          );
      response = await http.Response.fromStream(streamed);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (error) {
      throw ApiException.network(cause: error);
    }

    if (response.statusCode != 200) {
      throw ApiException.fromStatus(response.statusCode, _detailOf(response.body));
    }
    try {
      return AnalysisResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (error) {
      throw ApiException(
        ApiFailureKind.server,
        'The inspection response could not be read. Please try again.',
        cause: error,
      );
    }
  }

  /// `POST /api/report` — builds the inspection PDF from verified data.
  Future<ReportDocument> generateReport(Map<String, dynamic> payload) async {
    http.Response response;
    try {
      response = await _client
          .post(
            _uri('/api/report'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(AppConfig.reportTimeout);
    } on TimeoutException {
      throw const ApiException(
        ApiFailureKind.report,
        'The inspection report took too long to generate. Please try again.',
      );
    } catch (error) {
      throw ApiException.network(cause: error);
    }

    if (response.statusCode != 200) {
      throw ApiException.fromStatus(response.statusCode, _detailOf(response.body));
    }
    return ReportDocument(
      bytes: response.bodyBytes,
      fileName: _fileNameFromHeaders(response.headers) ??
          'ONION-DETECT-${payload['inspection_id'] ?? 'inspection-report'}.pdf',
    );
  }

  // ------------------------------------------------------------------ //
  // Internals
  // ------------------------------------------------------------------ //
  static String _subtypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }

  static String? _detailOf(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? _fileNameFromHeaders(Map<String, String> headers) {
    final disposition = headers['content-disposition'];
    if (disposition == null) return null;
    final match = RegExp('filename="?([^";]+)"?').firstMatch(disposition);
    return match?.group(1);
  }

  /// Streams the sample in chunks while reporting the transmitted byte count.
  static Stream<List<int>> _progressStream(
    Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  ) async* {
    const chunkSize = 64 * 1024;
    var sent = 0;
    while (sent < bytes.length) {
      final end = (sent + chunkSize < bytes.length) ? sent + chunkSize : bytes.length;
      yield Uint8List.sublistView(bytes, sent, end);
      sent = end;
      onProgress?.call(sent, bytes.length);
    }
  }
}

