/// Health/readiness state of the FastAPI inspection service.
///
/// Reported by `GET /api/health`. When a model cannot be loaded the backend
/// returns the real failure and the frontend surfaces it as a configuration
/// problem instead of pretending inference is available.
class BackendStatus {
  const BackendStatus({
    required this.reachable,
    required this.status,
    required this.detectorLoaded,
    required this.classifierLoaded,
    required this.detectorError,
    required this.classifierError,
    required this.detectorFilePresent,
    required this.classifierFilePresent,
    required this.version,
  });

  final bool reachable;
  final String status;
  final bool detectorLoaded;
  final bool classifierLoaded;
  final String? detectorError;
  final String? classifierError;
  final bool detectorFilePresent;
  final bool classifierFilePresent;
  final String version;

  factory BackendStatus.fromJson(Map<String, dynamic> json) => BackendStatus(
        reachable: true,
        status: json['status'] as String? ?? 'degraded',
        detectorLoaded: json['detector_loaded'] as bool? ?? false,
        classifierLoaded: json['classifier_loaded'] as bool? ?? false,
        detectorError: json['detector_error'] as String?,
        classifierError: json['classifier_error'] as String?,
        detectorFilePresent: json['detector_file_present'] as bool? ?? false,
        classifierFilePresent: json['classifier_file_present'] as bool? ?? false,
        version: json['version'] as String? ?? '',
      );

  factory BackendStatus.unreachable({String? message}) => BackendStatus(
        reachable: false,
        status: 'unreachable',
        detectorLoaded: false,
        classifierLoaded: false,
        detectorError: message,
        classifierError: null,
        detectorFilePresent: false,
        classifierFilePresent: false,
        version: '',
      );

  /// True only when both trained models report as loaded.
  bool get ready => reachable && detectorLoaded && classifierLoaded;

  bool get configurationIncomplete =>
      reachable && (!detectorFilePresent || !classifierFilePresent);

  /// Inspector-facing explanation of the current state.
  String get summary {
    if (!reachable) {
      return 'Inspection service is currently unavailable. '
          'Please check the FastAPI service and try again.';
    }
    if (ready) {
      return 'Inspection service online. Detection and health classification models loaded.';
    }
    if (configurationIncomplete) {
      final missing = <String>[
        if (!detectorFilePresent) 'onion_detector_v1.pt',
        if (!classifierFilePresent) 'onion_health_mobilenetv2_best.keras',
      ];
      return 'The inspection model is not available. '
          'Missing model file(s): ${missing.join(', ')}. '
          'Place the trained files in the backend models directory and restart the service.';
    }
    final detail = detectorError ?? classifierError;
    return detail == null
        ? 'The inspection model is not available. Please verify the configured model files.'
        : 'The inspection model is not available. $detail';
  }
}
