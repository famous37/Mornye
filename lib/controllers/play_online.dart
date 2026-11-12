import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/controllers/extension_auth_launcher.dart';
import 'package:mornye/controllers/online_stream_settings.dart';
import 'package:mornye/models/track.dart';
import 'package:mornye/providers/extension_provider.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/services/music_player_service.dart';
import 'package:mornye/services/online_stream_support.dart' as online;
import 'package:mornye/services/platform_bridge.dart';

const onlineStreamScheme = 'mornye-online';

/// The signed-session verification flow is shared across providers. It does
/// not bypass authentication: it opens the actual grant URL and retries once.
class OnlineStreamVerificationRequired implements Exception {
  const OnlineStreamVerificationRequired();

  @override
  String toString() => 'VERIFY_REQUIRED';
}

// Preserve the public helpers referenced by the existing stream unit tests.
Map<String, dynamic> onlineStreamRequest(Track track, String quality) =>
    online.onlineStreamRequest(track, quality);

bool isFullOnlineStream(Map<String, dynamic> result) =>
    online.isFullOnlineStream(result);

PlayableMedia _item(
  Track track,
  String initialProvider,
  String quality,
  int index, {
  required List<String> availableProviders,
  required String preferredProvider,
  Map<String, dynamic>? resolved,
}) {
  final source = resolved == null
      ? Uri(
          scheme: onlineStreamScheme,
          host: 'auto',
          pathSegments: [track.id],
          queryParameters: {
            'providers': availableProviders.join(','),
            'preferred': preferredProvider,
            'source': track.source ?? '',
            'title': track.name,
            'artist': track.artistName,
            'album': track.albumName,
            'isrc': track.isrc ?? '',
            'deezer_id': track.deezerId ?? '',
            'duration_ms': '${track.duration * 1000}',
            'quality': quality,
          },
        ).toString()
      : resolved['url'].toString();

  int? positive(Object? value) {
    final number = value is num ? value.toInt() : int.tryParse('$value');
    return number != null && number > 0 ? number : null;
  }

  return PlayableMedia(
    id: 'online:$index:${track.id}',
    source: source,
    title: track.name,
    artist: track.artistName,
    album: track.albumName,
    artUri: normalizeArtUri(track.coverUrl ?? ''),
    duration: track.duration > 0 ? Duration(seconds: track.duration) : null,
    explicit: track.isExplicit,
    // Different sources do not all provide FLAC: show the actual response.
    format: online.receivedStreamFormat(resolved),
    bitDepth: positive(resolved?['bit_depth']),
    sampleRate: positive(resolved?['sample_rate']),
    bitrate: positive(resolved?['bitrate']),
    displayMetadata: {
      'online_stream': true,
      'online_provider': initialProvider,
      'online_source_preference': preferredProvider,
      'online_quality': quality,
      'online_request': onlineStreamRequest(track, quality),
    },
  );
}

/// Start playback from any enabled, full-track capable extension.
/// Track provenance or the user's explicit preference determines the priority.
/// All other compatible providers remain fallback choices.
Future<void> playOnlineQueue(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks, {
  int startIndex = 0,
  String? qualityOverride,
}) async {
  if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) return;
  final container = ProviderScope.containerOf(context, listen: false);

  void notify(String message) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 7)),
    );
  }

  try {
    await container.read(extensionProvider.notifier).ensureInitialized();
  } catch (error) {
    notify('Streaming extensions could not be initialized: $error');
    return;
  }

  final enabled = container
      .read(extensionProvider)
      .extensions
      .where(
        (extension) =>
            extension.enabled &&
            extension.capabilities['fullTrackStreaming'] == true,
      )
      .toList();

  if (enabled.isEmpty) {
    notify(
      'No full-track streaming extension enabled. Install and enable a '
      'compatible online source (Qobuz Online, SoundCloud Online, Jellyfin).',
    );
    return;
  }

  final quality = qualityOverride ?? await OnlineStreamSettings.current();
  final preferred = await OnlineStreamSettings.preferredProvider();
  final track = tracks[startIndex];
  final enabledIds = [for (final extension in enabled) extension.id];
  final candidates = online.orderedOnlineProviders(
    enabledIds,
    preferred: preferred,
    trackSource: track.source,
  );
  final names = {
    for (final extension in enabled) extension.id: extension.displayName,
  };
  final failures = <String>[];

  for (final provider in candidates) {
    try {
      final result = await runExtensionOperationWithVerificationRetry<
        Map<String, dynamic>
      >(
        extensionId: provider,
        browserMode: 'external_first',
        operation: () async {
          final response = await PlatformBridge.invokeExtensionAction(
            provider,
            'resolvePlaybackStream',
            input: onlineStreamRequest(track, quality),
          );
          if (isExtensionVerificationRequired(
            response['error']?.toString() ?? '',
          )) {
            throw const OnlineStreamVerificationRequired();
          }
          return response;
        },
      );
      if (!isFullOnlineStream(result)) {
        failures.add(
          '${names[provider] ?? provider}: '
          "${result['error'] ?? 'No directly playable full HTTPS stream'}",
        );
        continue;
      }

      final queue = [
        for (var i = 0; i < tracks.length; i++)
          _item(
            tracks[i],
            provider,
            quality,
            i,
            preferredProvider: preferred,
            availableProviders: enabledIds,
            resolved: i == startIndex ? result : null,
          ),
      ];
      final player = container.read(musicPlayerControllerProvider);
      if (await player.ensureInitialized() == null) {
        notify('Internal audio player unavailable.');
        return;
      }
      await player.playAll(queue, initialIndex: startIndex);
      return;
    } catch (error) {
      failures.add(
        '${names[provider] ?? provider}: '
        '${isExtensionVerificationRequired(error) ? 'verification required' : error}',
      );
    }
  }
  notify('No provider could play this track: ${failures.take(3).join('; ')}');
}

Future<void> playOnline(BuildContext context, WidgetRef ref, Track track) =>
    playOnlineQueue(context, ref, [track]);

Future<void> chooseOnlineQuality(
  BuildContext context,
  WidgetRef ref,
  List<Track> queue, {
  int startIndex = 0,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  await container.read(extensionProvider.notifier).ensureInitialized();
  if (!context.mounted) return;
  final providers = {
    for (final e in container.read(extensionProvider).extensions)
      if (e.enabled && e.capabilities['fullTrackStreaming'] == true)
        e.id: e.displayName,
  };
  final selection = await OnlineStreamSettings.choosePlayback(
    context,
    providers,
  );
  if (selection == null) return;
  await OnlineStreamSettings.save(selection.quality);
  await OnlineStreamSettings.savePreferredProvider(selection.provider);
  if (!context.mounted) return;
  await playOnlineQueue(
    context,
    ref,
    queue,
    startIndex: startIndex,
    qualityOverride: selection.quality,
  );
}
