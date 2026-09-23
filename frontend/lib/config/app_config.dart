/// Centralised runtime configuration for the ONION DETECT frontend.
///
/// The API base URL is supplied at build/run time, so the exact same source tree
/// can be pointed at a local FastAPI service or a deployed one without editing
/// any Dart file:
///
/// ```bash
/// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
/// flutter build web --release --dart-define=API_BASE_URL=https://inspection.example.org
/// ```
///
/// No other part of the application hard-codes a backend URL.
class AppConfig {
  const AppConfig._();

  static const String _fallbackApiBaseUrl = 'http://127.0.0.1:8081';

  /// FastAPI base URL (no trailing slash).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _fallbackApiBaseUrl,
  );

  static String get normalizedApiBaseUrl =>
      apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;

  /// True when the build still points at a development-only address.
  static bool get usesDevelopmentDefault =>
      normalizedApiBaseUrl.contains('localhost') || normalizedApiBaseUrl.contains('127.0.0.1');

  static const Duration healthTimeout = Duration(seconds: 12);
  static const Duration analysisTimeout = Duration(minutes: 5);
  static const Duration reportTimeout = Duration(minutes: 2);

  /// Mirror of the backend `MAX_UPLOAD_SIZE_MB` setting, used for early feedback
  /// in the browser. The backend remains the authority on the limit.
  static const int maxUploadBytes = 10 * 1024 * 1024;
  static const String maxUploadLabel = '10 MB';

  static const List<String> acceptedExtensions = <String>['jpg', 'jpeg', 'png', 'webp'];
  static const String acceptedFormatsLabel = 'JPG, JPEG, PNG or WEBP';

  static bool isAcceptedFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return acceptedExtensions.any((extension) => lower.endsWith('.$extension'));
  }

  /// Product wording used wherever the workflow is described.
  static const String workflowStatement = 'AI measures  â†’  Human verifies  â†’  Evidence recorded';
  static const String tagline = 'AI-Assisted Onion Quality Inspection';
  static const String assistantDisclaimer =
      'AI-assisted inspection â€” human verification required.';
}
