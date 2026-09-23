import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/inspection_id.dart';
import '../providers/inspection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../widgets/app_shell.dart';
import '../widgets/feedback.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/surfaces.dart';

/// Page 2 — create the inspection record before a sample is submitted.
class StartInspectionScreen extends ConsumerStatefulWidget {
  const StartInspectionScreen({super.key});

  @override
  ConsumerState<StartInspectionScreen> createState() => _StartInspectionScreenState();
}

class _StartInspectionScreenState extends ConsumerState<StartInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inspector = TextEditingController();
  final _location = TextEditingController();
  final _batchLot = TextEditingController();
  final _notes = TextEditingController();

  List<TextEditingController> get _controllers =>
      [_inspector, _location, _batchLot, _notes];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_refresh)
        ..dispose();
    }
    super.dispose();
  }

  bool get _canContinue =>
      _inspector.text.trim().isNotEmpty &&
      _location.text.trim().isNotEmpty &&
      _batchLot.text.trim().isNotEmpty;

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false) || !_canContinue) return;
    ref.read(inspectionProvider.notifier).startInspection(
          inspector: _inspector.text.trim(),
          location: _location.text.trim(),
          batchLot: _batchLot.text.trim(),
          notes: _notes.text.trim(),
        );
    context.go('/capture');
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(inspectionProvider).session;

    return AppShell(
      child: SingleChildScrollView(
        child: ContentContainer(
          maxWidth: 880,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageHeader(),
              if (existing != null) ...[
                InfoBanner(
                  title: 'Inspection in progress',
                  severity: BannerSeverity.attention,
                  message: 'An inspection record already exists for ${existing.id} '
                      '(${existing.inspector}). Creating a new record replaces the '
                      'current session.',
                  details: const [
                    'Continue the existing inspection to keep its analysis and '
                        'verification state.',
                  ],
                  action: Wrap(
                    spacing: AppTheme.s12,
                    runSpacing: AppTheme.s8,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/capture'),
                        child: const Text('CONTINUE EXISTING INSPECTION'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(inspectionProvider.notifier).reset(),
                        child: const Text('DISCARD AND START NEW'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.lg),
              ],
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PanelCard(
                      label: 'Inspection record',
                      child: Column(
                        children: [
                          _Field(
                            controller: _inspector,
                            label: 'Inspector Name *',
                            hint: 'Name of the person performing the inspection',
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Inspector name is required'
                                    : null,
                          ),
                          const SizedBox(height: AppTheme.md),
                          _Field(
                            controller: _location,
                            label: 'Location *',
                            hint: 'Pack-house, mandi, storage facility or site',
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Location is required'
                                    : null,
                          ),
                          const SizedBox(height: AppTheme.md),
                          _Field(
                            controller: _batchLot,
                            label: 'Batch / Lot Number *',
                            hint: 'Batch, lot or consignment reference',
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Batch/Lot number is required'
                                    : null,
                          ),
                          const SizedBox(height: AppTheme.md),
                          TextFormField(
                            controller: _notes,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Inspection Notes',
                              hintText: 'Optional remarks about sampling or conditions',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.lg),
                    const RecordIdentifierPanel(),
                    const SizedBox(height: AppTheme.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _canContinue ? _submit : null,
                        child: const Text('CONTINUE TO SAMPLE →'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.s12),
                    Text(
                      _canContinue
                          ? 'The inspection ID and timestamp are created with the record.'
                          : 'Complete the required fields to continue.',
                      style: AppTypo.meta,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppTheme.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: 'New inspection'),
          SizedBox(height: AppTheme.s12),
          Text(
            'Create an inspection record before submitting a sample.',
            style: AppTypo.body,
          ),
        ],
      ),
    );
  }
}

/// Explains how the record identifiers are produced (no hard-coded values).
class RecordIdentifierPanel extends StatelessWidget {
  const RecordIdentifierPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      label: 'Record identifiers',
      background: AppTheme.lightGreen,
      borderColour: AppTheme.secondaryGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KeyValueRow(
            label: 'Inspection ID',
            value: 'Assigned automatically on creation',
            hint: 'Format INS-YYYY-XXXXXX — generated once per inspection record.',
          ),
          KeyValueRow(
            label: 'Date & time',
            value: '${formatInspectionTimestamp(DateTime.now())} (system time)',
            hint: 'Captured from the system clock when the record is created.',
          ),
          const KeyValueRow(
            label: 'Final decision authority',
            value: 'Human inspector',
            hint: 'AI observations are verified by a human before the report is issued.',
          ),
        ],
      ),
    );
  }
}

