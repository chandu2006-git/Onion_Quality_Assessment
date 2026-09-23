/// User-facing failure categories.
///
/// Every failure the inspection service can produce is mapped to a professional
/// message. Raw exception text, stack traces and internal paths are never shown
/// to the inspector; they stay in the browser/service logs.
enum ApiFailureKind {
  /// The FastAPI service could not be reached at all.
  network,

  /// The models are not loaded (HTTP 503 from the backend).
  modelUnavailable,

  /// The uploaded file could not be processed (HTTP 400).
  invalidImage,

  /// The submitted inspection payload is incomplete (HTTP 422).
  invalidRequest,

  /// The submitted file exceeded the configured upload limit (HTTP 413).
  uploadTooLarge,

  /// The report could not be generated.
  report,

  /// Anything else (HTTP 5xx / unexpected).
  server,
}

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode, this.cause});

  final ApiFailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  factory ApiException.network({Object? cause}) => ApiException(
        ApiFailureKind.network,
        'Inspection service is currently unavailable. '
        'Please check the FastAPI service and try again.',
        cause: cause,
      );

  factory ApiException.timeout() => const ApiException(
        ApiFailureKind.network,
        'The inspection service did not respond in time. Please try again.',
      );

  /// Maps an HTTP status code and optional backend detail to a safe message.
  factory ApiException.fromStatus(int statusCode, String? detail) {
    final trimmed = (detail ?? '').trim();
    switch (statusCode) {
      case 400:
        return ApiException(
          ApiFailureKind.invalidImage,
          trimmed.isNotEmpty
              ? trimmed
              : 'The selected file could not be processed. '
                  'Please upload a valid JPG, PNG or WEBP image.',
          statusCode: statusCode,
        );
      case 404:
      case 405:
        return ApiException(
          ApiFailureKind.server,
          'The inspection service did not recognise the request. '
          'Please verify the configured API address.',
          statusCode: statusCode,
        );
      case 413:
        return const ApiException(
          ApiFailureKind.uploadTooLarge,
          'The selected file is larger than the configured upload limit. '
          'Please submit a smaller image.',
          statusCode: 413,
        );
      case 422:
        return ApiException(
          ApiFailureKind.invalidRequest,
          trimmed.isNotEmpty
              ? trimmed
              : 'The submitted inspection data is incomplete or invalid.',
          statusCode: statusCode,
        );
      case 503:
        return ApiException(
          ApiFailureKind.modelUnavailable,
          trimmed.isNotEmpty
              ? trimmed
              : 'The inspection model is not available. '
                  'Please verify the configured model files.',
          statusCode: statusCode,
        );
      default:
        return ApiException(
          ApiFailureKind.server,
          trimmed.isNotEmpty && statusCode < 500
              ? trimmed
              : 'The inspection could not be completed. '
                  'Please try again or contact the system administrator.',
          statusCode: statusCode,
        );
    }
  }

  /// True when the message came from the backend and is already user-safe.
  bool get isBackendMessage => kind == ApiFailureKind.modelUnavailable ||
      kind == ApiFailureKind.invalidImage ||
      kind == ApiFailureKind.invalidRequest;

  @override
  String toString() => message;
}
