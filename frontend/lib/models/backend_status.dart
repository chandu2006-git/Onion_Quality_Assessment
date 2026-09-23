/// Health/readiness state of the FastAPI inspection service.
///
/// Reported by `GET /api/health`. The backend distinguishes three signals:
/// model files present on disk, weights currently resident in memory, and
/// service readiness (`ready`). Models load lazily one at a time during each
/// analysis, so `detectorLoaded`/`classifierLoaded` are normally false at
/// rest - readiness must not be derived from them. When a model cannot be
/// loaded the backend returns the real failure and the frontend surfaces it as
/// a configuration problem instead of pretending inference is available.
class BackendStatus {
  const BackendStatus({
    required this.reachable,
    required this.status,
    required this.backendReady,
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
  /// Readiness as reported by the backend: model files installed and no
  /// recorded load failure. Independent of the residency flags because
  /// models are loaded on demand for each analysis.
  final bool backendReady;
  /// True only while weights are resident in memory (normally false at rest).
  final bool detectorLoaded;
  final bool classifierLoaded;
  final String? detectorError;
  final String? classifierError;
  final bool detectorFilePresent;
  final bool classifierFilePresent;
  final String version;

  factory BackendStatus.fromJson(Map<String, dynamic> json) {
    final detectorLoaded = json['detector_loaded'] as bool? ?? false;
    final classifierLoaded = json['classifier_loaded'] as bool? ?? false;
    return BackendStatus(
      reachable: true,
      status: json['status'] as String? ?? 'degraded',
      // Older backends without the explicit `ready` flag fall back to the
      // legacy interpretation (both models reported loaded).
      backendReady: json['ready'] as bool? ?? (detectorLoaded && classifierLoaded),
      detectorLoaded: detectorLoaded,
      classifierLoaded: classifierLoaded,
      detectorError: json['detector_error'] as String?,
      classifierError: json['classifier_error'] as String?,
      detectorFilePresent: json['detector_file_present'] as bool? ?? false,
      classifierFilePresent: json['classifier_file_present'] as bool? ?? false,
      version: json['version'] as String? ?? '',
    );
  }

  factory BackendStatus.unreachable({String? message}) => BackendStatus(
        reachable: false,
        status: 'unreachable',
        backendReady: false,
        detectorLoaded: false,
        classifierLoaded: false,
        detectorError: message,
        classifierError: null,
        detectorFilePresent: false,
        classifierFilePresent: false,
        version: '',
      );

  /// True when the service is reachable and the backend reports ready.
  bool get ready => reachable && backendReady;

  bool get configurationIncomplete =>
      reachable && (!detectorFilePresent || !classifierFilePresent);

  /// Inspector-facing explanation of the current state.
  String get summary {
    if (!reachable) {
      return 'Inspection service is currently unavailable. '
          'Please check the FastAPI service and try again.';
    }
    if (ready) {
      return 'Inspection service online. Detection and health classification '
          'models are available and load on demand for each analysis.';
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
