/// Shared rules for provider-neutral, full-length streaming.
///
/// Keep this file Flutter-free so that both the queue controller and the
/// native media-session resolver can apply exactly the same safety checks.
library;

import 'package:mornye/models/track.dart';

Map<String, dynamic> onlineStreamRequest(Track track, String quality) => {
  'id': track.id,
  'title': track.name,
  'artist': track.artistName,
  'album': track.albumName,
  'isrc': track.isrc ?? '',
  'source': track.source ?? '',
  'deezer_id': track.deezerId ?? '',
  'duration_ms': track.duration * 1000,
  'quality': quality,
};

/// The preferred source is explicit. Otherwise, prefer the source whose
/// catalogue supplied the track. Other enabled streaming providers follow,
/// allowing the player to look for the same verified recording elsewhere.
List<String> orderedOnlineProviders(
  Iterable<String> enabledIds, {
  String? preferred,
  String? trackSource,
}) {
  final ids = <String>[];
  for (final raw in enabledIds) {
    final id = raw.trim();
    if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
  }
  if (ids.isEmpty) return const [];
  final chosen = (preferred ?? '').trim();
  final source = (trackSource ?? '').trim().toLowerCase();
  String? matchingSource;
  for (final id in ids) {
    final normalized = id.toLowerCase();
    if (source == normalized ||
        source == 'extension:$normalized' ||
        source == 'provider:$normalized' ||
        source.startsWith('$normalized:')) {
      matchingSource = id;
      break;
    }
  }
  final sorted = <String>[];
  if (chosen != 'auto' && ids.contains(chosen)) sorted.add(chosen);
  if (matchingSource != null && !sorted.contains(matchingSource)) {
    sorted.add(matchingSource);
  }
  for (final id in ids) {
    if (!sorted.contains(id)) sorted.add(id);
  }
  return sorted;
}

/// A metadata preview, encrypted media, insecure HTTP URL, or stream requiring
/// HTTP headers is not a directly playable full song for this audio pipeline.
bool isFullOnlineStream(Map<String, dynamic> result) {
  final url = result['url']?.toString().trim() ?? '';
  final uri = Uri.tryParse(url);
  return result['success'] == true &&
      result['full_track'] == true &&
      result['preview'] != true &&
      result['encrypted'] != true &&
      result['requires_headers'] != true &&
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty;
}

/// Do not present the requested quality as the received codec.
String? receivedStreamFormat(Map<String, dynamic>? result) {
  final value = result?['format']?.toString().trim();
  return value == null || value.isEmpty ? null : value.toUpperCase();
}
