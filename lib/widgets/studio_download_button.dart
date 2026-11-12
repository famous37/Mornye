import 'package:flutter/material.dart';

/// Separate offline import control for the Studio-inspired audio experience.
/// Tap uses the existing downloader; long-press forces its quality selector.
class StudioDownloadButton extends StatelessWidget {
  const StudioDownloadButton({
    super.key,
    required this.onDownload,
    this.onChooseQuality,
    this.isQueued = false,
    this.size = 44,
  });

  final VoidCallback onDownload;
  final VoidCallback? onChooseQuality;
  final bool isQueued;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: !isQueued,
      label: isQueued
          ? 'Download queued'
          : 'Download for offline listening; hold to select quality',
      child: InkWell(
        onTap: isQueued ? null : onDownload,
        onLongPress: isQueued ? null : onChooseQuality,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Icon(
              isQueued
                  ? Icons.downloading_rounded
                  : Icons.download_for_offline_outlined,
              size: 23,
              color: isQueued
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
