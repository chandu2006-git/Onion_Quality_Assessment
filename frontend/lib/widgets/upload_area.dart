import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

/// Sample submission surface: drag & drop, browser file picker and device camera.
///
/// Upload is the mandatory path; the camera option uses the device camera when
/// the platform exposes one and falls back to the file picker otherwise.
class UploadArea extends StatefulWidget {
  const UploadArea({
    super.key,
    required this.enabled,
    required this.onFileSelected,
    this.onError,
  });

  final bool enabled;
  final ValueChanged<XFile> onFileSelected;
  final ValueChanged<String>? onError;

  @override
  State<UploadArea> createState() => _UploadAreaState();
}

class _UploadAreaState extends State<UploadArea> {
  final ImagePicker _picker = ImagePicker();
  bool _dragging = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;
      widget.onFileSelected(picked);
    } catch (error) {
      widget.onError?.call(
        'The selected file could not be processed. '
        'Please upload a valid JPG, PNG or WEBP image.',
      );
    }
  }

  Future<void> _handleDropped(List<XFile> files) async {
    if (files.isEmpty) return;
    final file = files.first;
    if (!AppConfig.isAcceptedFileName(file.name)) {
      widget.onError?.call(
        'Unsupported file type. Please upload a ${AppConfig.acceptedFormatsLabel} image.',
      );
      return;
    }
    widget.onFileSelected(file);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropTarget(
          enable: widget.enabled,
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (details) {
            setState(() => _dragging = false);
            _handleDropped(details.files);
          },
          child: _DropZone(
            dragging: _dragging,
            enabled: widget.enabled,
            onBrowse: () => _pick(ImageSource.gallery),
          ),
        ),
        const SizedBox(height: AppTheme.md),
        Row(
          children: [
            Expanded(
              child: _SourceButton(
                icon: Icons.photo_camera_outlined,
                title: 'TAKE PHOTO',
                subtitle: 'Use the device camera where available',
                onTap: widget.enabled ? () => _pick(ImageSource.camera) : null,
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: _SourceButton(
                icon: Icons.upload_file_outlined,
                title: 'UPLOAD IMAGE',
                subtitle:
                    '${AppConfig.acceptedFormatsLabel} · up to ${AppConfig.maxUploadLabel}',
                onTap: widget.enabled ? () => _pick(ImageSource.gallery) : null,
              ),
            ),
          ],
        ),
      ],
    );

  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.dragging,
    required this.enabled,
    required this.onBrowse,
  });

  final bool dragging;
  final bool enabled;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: dragging ? AppTheme.lightGreen : AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        border: Border.all(
          color: dragging ? AppTheme.secondaryGreen : AppTheme.border,
          width: dragging ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onBrowse : null,
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.s24,
            vertical: AppTheme.s48,
          ),
          child: Column(
            children: [
              Icon(
                dragging ? Icons.download_outlined : Icons.add_photo_alternate_outlined,
                size: 34,
                color: AppTheme.secondaryGreen,
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                dragging ? 'Drop the sample image' : 'Drag & drop an onion sample',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: AppTheme.s8),
              Text(
                'or click to browse · ${AppConfig.acceptedFormatsLabel} · '
                'up to ${AppConfig.maxUploadLabel}',
                textAlign: TextAlign.center,
                style: AppTypo.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.primary),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypo.meta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
