import 'package:flutter/material.dart';

import '../providers/inspection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'status_widgets.dart';
import 'surfaces.dart';

/// Processing indicator for the analysis request.
///
/// The upload stage shows genuinely transmitted bytes. The server-side stages
/// (detection and classification) run inside a single inference request, so they
/// are presented as activity — never as invented percentages.
class AnalysisActivity extends StatelessWidget {
  const AnalysisActivity({
    super.key,
    required this.phase,
    required this.uploadProgress,
  });

  final AnalysisPhase phase;
  final double uploadProgress;

  bool get _uploadComplete =>
      uploadProgress >= 1 ||
      phase == AnalysisPhase.analysing ||
      phase == AnalysisPhase.completed;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      label: 'Analysing sample',
      borderColour: AppTheme.secondaryGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StageRow(
            title: 'Uploading sample image',
            detail: _uploadComplete
                ? 'Sample received by the inspection service.'
                : 'Transferring the sample image…',
            state: _uploadComplete ? _StageState.done : _StageState.active,
            trailing: _uploadComplete
                ? null
                : SizedBox(
                    width: 120,
                    child: ProgressLine(value: uploadProgress),
                  ),
          ),
          _StageRow(
            title: 'Detecting onion bulbs',
            detail: 'YOLOv8n locates each bulb in the sample image.',
            state: _stageStateForServerWork(),
          ),
          _StageRow(
            title: 'Assessing individual onions',
            detail: 'Every detected bulb is cropped and evaluated independently.',
            state: _stageStateForServerWork(),
          ),
          _StageRow(
            title: 'Preparing inspection results',
            detail: 'Building the annotated evidence image and observation list.',
            state: phase == AnalysisPhase.completed
                ? _StageState.done
                : _StageState.waiting,
            isLast: true,
          ),
          const SizedBox(height: AppTheme.s12),
          Text(
            'Processing runs on the inspection server. Durations depend on the '
            'number of bulbs in the sample and on the available compute.',
            style: AppTypo.meta,
          ),
        ],
      ),
    );
  }

  _StageState _stageStateForServerWork() {
    switch (phase) {
      case AnalysisPhase.analysing:
        return _StageState.active;
      case AnalysisPhase.completed:
        return _StageState.done;
      default:
        return _StageState.waiting;
    }
  }
}

enum _StageState { waiting, active, done }

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.title,
    required this.detail,
    required this.state,
    this.trailing,
    this.isLast = false,
  });

  final String title;
  final String detail;
  final _StageState state;
  final Widget? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Widget marker;
    switch (state) {
      case _StageState.done:
        marker = const Icon(Icons.check_circle, size: 18, color: AppTheme.healthy);
        break;
      case _StageState.active:
        marker = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.amber),
        );
        break;
      case _StageState.waiting:
        marker = Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border, width: 2),
          ),
        );
        break;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: marker),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: state == _StageState.waiting
                        ? AppTheme.secondaryText
                        : AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: AppTypo.meta),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
