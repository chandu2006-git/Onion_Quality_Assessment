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

  /// Health classification takes a full model load on a cold Render instance,
  /// so the probe waits long enough for the service to answer instead of
  /// reporting a healthy service as unavailable.
  static const Duration healthTimeout = Duration(seconds: 90);
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

  // --------------------------------------------------------------------- //
  // Inspection metadata (illustrative pilot context)
  // --------------------------------------------------------------------- //

  /// Illustrative inspection locations offered in the dropdown.
  ///
  /// These are demo/pilot-context options ONLY. They do not represent live
  /// deployments, actual transactions or any real-time government system.
  static const List<String> illustrativeLocations = <String>[
    'NAFED Procurement Center \u2013 Nashik',
    'NAFED Buffer Godown \u2013 Lasalgaon',
    'APMC Yard \u2013 Pimpalgaon',
    'Pack House \u2013 Pimpri',
    'Sample Inspection Point \u2013 Guntur',
  ];

  /// True for every location in [illustrativeLocations]; drives the
  /// `PILOT DEMO` indicator so illustrative context is never mistaken for a
  /// live deployment.
  static bool isIllustrativeLocation(String location) =>
      illustrativeLocations.contains(location);

  /// Placeholder examples shown in the new-inspection form (never submitted
  /// as values — the inspector types or selects their own).
  static const String inspectorHint = 'Inspector / Demo User';
  static const String batchHint = 'OD-DEMO-001';

  /// Product wording used wherever the workflow is described.
  /// (Unicode escapes keep this source file pure ASCII.)
  static const String workflowStatement =
      'AI measures  \u2192  Human verifies  \u2192  Evidence recorded';
  static const String tagline = 'AI-Assisted Onion Quality Inspection';
  static const String assistantDisclaimer =
      'AI-assisted inspection \u2014 human verification required.';
}
