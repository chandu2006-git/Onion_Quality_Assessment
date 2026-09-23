import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../core/api_exception.dart';
import '../core/inspection_id.dart';
import '../models/inspection_session.dart';
import '../models/onion_observation.dart';
import '../services/api_service.dart';
import '../services/file_saver.dart';
import 'api_provider.dart';

/// Stage of the analysis request.
///
/// The upload stage reports genuinely transmitted bytes; the server-side stages
/// are shown as activity, never as invented percentages.
enum AnalysisPhase { idle, uploading, analysing, completed, failed }

class InspectionState {
  const InspectionState({
    this.session,
    this.phase = AnalysisPhase.idle,
    this.uploadProgress = 0,
    this.analysisError,
    this.selectedOnionId,
    this.generatingReport = false,
    this.reportError,
    this.reportNotice,
  });

  final InspectionSession? session;
  final AnalysisPhase phase;

  /// Real upload progress (0..1) of the multipart request.
  final double uploadProgress;

  /// User-safe message when analysis failed.
  final String? analysisError;

  final int? selectedOnionId;

  final bool generatingReport;
  final String? reportError;

  /// Message shown after a report was delivered (download or saved file).
  final String? reportNotice;

  bool get analysisRunning =>
      phase == AnalysisPhase.uploading || phase == AnalysisPhase.analysing;

  InspectionState copyWith({
    InspectionSession? session,
    AnalysisPhase? phase,
    double? uploadProgress,
    String? analysisError,
    bool clearAnalysisError = false,
    int? selectedOnionId,
    bool clearSelection = false,
    bool? generatingReport,
    String? reportError,
    bool clearReportError = false,
    String? reportNotice,
    bool clearReportNotice = false,
  }) {
    return InspectionState(
      session: session ?? this.session,
      phase: phase ?? this.phase,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      analysisError: clearAnalysisError ? null : (analysisError ?? this.analysisError),
      selectedOnionId: clearSelection ? null : (selectedOnionId ?? this.selectedOnionId),
      generatingReport: generatingReport ?? this.generatingReport,
      reportError: clearReportError ? null : (reportError ?? this.reportError),
      reportNotice: clearReportNotice ? null : (reportNotice ?? this.reportNotice),
    );
  }
}

class InspectionNotifier extends StateNotifier<InspectionState> {
  InspectionNotifier(this._api) : super(const InspectionState());

  final ApiService _api;

  InspectionSession? get session => state.session;

  /// Creates the inspection record. The identifier is generated at runtime and
  /// the timestamp uses the current system time.
  void startInspection({
    required String inspector,
    required String location,
    required String batchLot,
    required String notes,
  }) {
    state = InspectionState(
      session: InspectionSession(
        id: generateInspectionId(),
        inspector: inspector,
        location: location,
        batchLot: batchLot,
        notes: notes,
        startedAt: DateTime.now(),
      ),
    );
  }

  /// Registers the uploaded sample. Throws [ApiException] for files the backend
  /// would reject, so the inspector gets the message before uploading.
  void setSample({
    required Uint8List bytes,
    required String fileName,
    required int sizeBytes,
  }) {
    final current = state.session;
    if (current == null) {
      throw const ApiException(
        ApiFailureKind.invalidRequest,
        'Create the inspection record before submitting a sample.',
      );
    }
    if (!AppConfig.isAcceptedFileName(fileName)) {
      throw ApiException(
        ApiFailureKind.invalidImage,
        'The selected file could not be processed. '
        'Please upload a valid JPG, PNG or WEBP image.',
      );
    }
    if (sizeBytes > AppConfig.maxUploadBytes) {
      throw ApiException(
        ApiFailureKind.uploadTooLarge,
        'The selected file is larger than the ${AppConfig.maxUploadLabel} upload limit.',
      );
    }

    current
      ..sampleBytes = bytes
      ..sampleFileName = fileName
      ..sampleSizeBytes = sizeBytes
      ..analysis = null;
    state = state.copyWith(
      phase: AnalysisPhase.idle,
      uploadProgress: 0,
      clearAnalysisError: true,
      clearSelection: true,
      clearReportError: true,
      clearReportNotice: true,
    );
  }

  void clearSample() {
    final current = state.session;
    if (current == null) return;
    current
      ..sampleBytes = null
      ..sampleFileName = null
      ..sampleSizeBytes = null
      ..analysis = null;
    state = state.copyWith(
      phase: AnalysisPhase.idle,
      uploadProgress: 0,
      clearAnalysisError: true,
      clearSelection: true,
      clearReportError: true,
      clearReportNotice: true,
    );
  }

  /// Runs real inference through `POST /api/analyze`.
  Future<void> analyzeSample() async {
    final current = state.session;
    final bytes = current?.sampleBytes;
    if (current == null || bytes == null || bytes.isEmpty) {
      state = state.copyWith(
        phase: AnalysisPhase.failed,
        analysisError: 'Upload an onion sample to begin inspection.',
      );
      return;
    }
    if (state.analysisRunning) return; // duplicate submission guard

    state = state.copyWith(
      phase: AnalysisPhase.uploading,
      uploadProgress: 0,
      clearAnalysisError: true,
      clearReportError: true,
      clearReportNotice: true,
      clearSelection: true,
    );

    try {
      final result = await _api.analyzeSample(
        bytes: bytes,
        fileName: current.sampleFileName ?? 'onion-sample.jpg',
        onUploadProgress: (sent, total) {
          if (!mounted) return;
          final progress = total <= 0 ? 0.0 : sent / total;
          state = state.copyWith(
            phase: progress >= 1 ? AnalysisPhase.analysing : AnalysisPhase.uploading,
            uploadProgress: progress,
          );
        },
      );
      current.analysis = result;
      state = state.copyWith(
        phase: AnalysisPhase.completed,
        uploadProgress: 1,
        clearAnalysisError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        phase: AnalysisPhase.failed,
        uploadProgress: 0,
        analysisError: error.message,
      );
    } catch (error) {
      state = state.copyWith(
        phase: AnalysisPhase.failed,
        uploadProgress: 0,
        analysisError: 'The inspection could not be completed. '
            'Please try again or contact the system administrator.',
      );
    }
  }

  void selectOnion(int? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
      return;
    }
    state = state.copyWith(selectedOnionId: id);
  }

  /// Accept the AI observation for one bulb.
  void confirmAiObservation(int id) {
    final observation = state.session?.observationById(id);
    if (observation == null) return;
    observation.confirmAi();
    _emitVerificationChange();
  }

  /// Record an inspector decision that differs from the AI observation.
  void overrideObservation(int id, String decision) {
    final observation = state.session?.observationById(id);
    if (observation == null) return;
    if (OnionHealth.isHealthy(decision) == observation.isHealthyObservation) {
      observation.confirmAi();
    } else {
      observation.overrideWith(decision);
    }
    _emitVerificationChange();
  }

  void clearReview(int id) {
    final observation = state.session?.observationById(id);
    if (observation == null) return;
    observation.clearReview();
    _emitVerificationChange();
  }

  void setVerificationNote(int id, String note) {
    final observation = state.session?.observationById(id);
    if (observation == null) return;
    observation.verificationNote = note;
    state = state.copyWith();
  }

  void _emitVerificationChange() {
    state = state.copyWith(clearReportError: true, clearReportNotice: true);
  }


  /// Builds and saves the inspection report from the verified inspection data.
  Future<SaveOutcome?> generateReport() async {
    final current = state.session;
    if (current == null || state.generatingReport) return null;

    state = state.copyWith(
      generatingReport: true,
      clearReportError: true,
      clearReportNotice: true,
    );

    try {
      final payload = current.toReportPayload();
      final document = await _api.generateReport(payload);
      final outcome = await saveDocument(
        document.bytes,
        fileName: document.fileName,
        mimeType: 'application/pdf',
      );
      state = state.copyWith(
        generatingReport: false,
        reportNotice: outcome.savedToBrowser
            ? 'Inspection report downloaded: ${document.fileName}'
            : 'Inspection report saved to ${outcome.location}',
      );
      return outcome;
    } on ApiException catch (error) {
      state = state.copyWith(generatingReport: false, reportError: error.message);
    } catch (error) {
      state = state.copyWith(
        generatingReport: false,
        reportError: 'The inspection report could not be generated. '
            'Please try again or contact the system administrator.',
      );
    }
    return null;
  }

  /// Clears the session (used when an inspector starts a new inspection).
  void reset() => state = const InspectionState();
}

final inspectionProvider =
    StateNotifierProvider<InspectionNotifier, InspectionState>((ref) {
  return InspectionNotifier(ref.watch(apiServiceProvider));
});

