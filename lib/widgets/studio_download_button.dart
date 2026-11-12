import 'package:flutter/material.dart';

/// Compact download control for the Studio-inspired listening experience.
///
/// Playing and downloading are intentionally independent operations:
/// tapping this button invokes Mornye's existing downloader and quality
/// selection without altering the current playback queue.
class StudioDownloadButton extends StatelessWidget {
  const StudioDownloadButton({
    super.key,
    required this.onDownload,
    this.isQueued = false,
    this.size = 42,
  });

  final VoidCallback onDownload;
  final bool isQueued;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: isQueued ? 'Download queued' : 'Download for offline playback',
      child: IconButton(
        onPressed: isQueued ? null : onDownload,
        tooltip: isQueued ? 'Download queued' : 'Download',
        icon: Icon(
          isQueued
              ? Icons.downloading_rounded
              : Icons.download_for_offline_outlined,
          size: 23,
        ),
        color: scheme.onSurfaceVariant,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
