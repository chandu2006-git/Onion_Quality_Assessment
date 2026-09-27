import 'package:flutter_test/flutter_test.dart';
import 'package:onion_detect/models/backend_status.dart';

/// Readiness contract for the lazy-loading FastAPI backend.
///
/// The backend keeps detector/classifier weights unloaded at rest and loads
/// them inside POST /api/analyze. `detector_loaded: false` / `classifier_loaded:
/// false` is therefore the NORMAL state of a perfectly healthy service and
/// must never be interpreted as "service unavailable".
void main() {
  group('BackendStatus.fromJson', () {
    test('current backend payload: ready=true with loaded=false (production lazy state)', () {
      final status = BackendStatus.fromJson(const {
        'status': 'ok',
        'ready': true,
        'detector_loaded': false,
        'classifier_loaded': false,
        'detector_error': null,
        'classifier_error': null,
        'detector_file_present': true,
        'classifier_file_present': true,
        'version': '1.0.0',
      });

      expect(status.reachable, isTrue);
      expect(status.ready, isTrue,
          reason: 'ready:true from /api/health must allow ANALYZE even when '
              'both models are not resident in memory');
      expect(status.configurationIncomplete, isFalse);
      expect(status.summary, contains('online'));
    });

    test('legacy payload without `ready` key: derives readiness from files + errors, '
        'never from the transient loaded flags', () {
      final notResident = BackendStatus.fromJson(const {
        'status': 'ok',
        'detector_loaded': false,
        'classifier_loaded': false,
        'detector_error': null,
        'classifier_error': null,
        'detector_file_present': true,
        'classifier_file_present': true,
      });

      expect(notResident.ready, isTrue,
          reason: 'loaded:false at rest must not disable analysis');

      // Flipping residency must not change readiness.
      final resident = BackendStatus.fromJson(const {
        'status': 'ok',
        'detector_loaded': true,
        'classifier_loaded': true,
        'detector_error': null,
        'classifier_error': null,
        'detector_file_present': true,
        'classifier_file_present': true,
      });

      expect(resident.ready, notResident.ready);
      expect(resident.ready, isTrue);
    });

    test('legacy payload with a real load failure is not ready and reports the error', () {
      final status = BackendStatus.fromJson(const {
        'status': 'degraded',
        'detector_loaded': false,
        'classifier_loaded': false,
        'detector_error': null,
        'classifier_error': 'weights file rejected by runtime',
        'detector_file_present': true,
        'classifier_file_present': true,
      });

      expect(status.ready, isFalse);
      expect(status.summary, contains('weights file rejected by runtime'));
    });

    test('explicit ready:false from the backend is honoured', () {
      final status = BackendStatus.fromJson(const {
        'status': 'degraded',
        'ready': false,
        'detector_loaded': false,
        'classifier_loaded': false,
        'detector_error': null,
        'classifier_error': null,
        'detector_file_present': true,
        'classifier_file_present': true,
      });

      expect(status.ready, isFalse);
    });

    test('missing model file blocks readiness and names the artefact', () {
      final status = BackendStatus.fromJson(const {
        'status': 'degraded',
        'detector_loaded': false,
        'classifier_loaded': false,
        'detector_error': null,
        'classifier_error': null,
        'detector_file_present': true,
        'classifier_file_present': false,
      });

      expect(status.ready, isFalse);
      expect(status.configurationIncomplete, isTrue);
      expect(status.summary, contains('onion_health_mobilenetv2_best.tflite'));
    });

    test('unreachable service is not ready', () {
      final status =
          BackendStatus.unreachable(message: 'connection refused');

      expect(status.reachable, isFalse);
      expect(status.ready, isFalse);
      expect(status.summary, contains('currently unavailable'));
    });
  });
}
