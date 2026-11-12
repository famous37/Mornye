import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlinePlaybackChoice {
  const OnlinePlaybackChoice({required this.quality, required this.provider});

  final String quality;
  final String provider;
}

/// The selected stream quality is a global preference, not a download option.
/// Highest Qobuz FLAC is the default for fresh installations.
class OnlineStreamSettings {
  static const _key = 'online_stream_quality_v1';
  static const best = 'HI_RES_LOSSLESS';
  static const qualities = <String, String>{
    best: 'Best available · up to 24-bit / 192 kHz',
    'HI_RES': 'Hi-Res FLAC · prefer 24-bit',
    'LOSSLESS': 'Lossless FLAC · 16-bit',
  };

  static Future<String> current() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return qualities.containsKey(value) ? value! : best;
  }

  static Future<void> save(String quality) async {
    if (!qualities.containsKey(quality)) {
      throw ArgumentError.value(
        quality,
        'quality',
        'Unsupported stream quality',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, quality);
  }

  static const _providerKey = 'online_stream_provider_v1';

  /// 'auto' searches all enabled full-track providers in a deterministic order.
  static Future<String> preferredProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_providerKey)?.trim();
    return value == null || value.isEmpty ? 'auto' : value;
  }

  static Future<void> savePreferredProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _providerKey,
      provider.trim().isEmpty ? 'auto' : provider.trim(),
    );
  }

  /// A single screen controls streaming source and quality. This does not
  /// affect which provider the Download button uses.
  static Future<OnlinePlaybackChoice?> choosePlayback(
    BuildContext context,
    Map<String, String> availableProviders,
  ) async {
    final originalQuality = await current();
    final originalProvider = await preferredProvider();
    if (!context.mounted) return null;
    return showModalBottomSheet<OnlinePlaybackChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        var quality = originalQuality;
        var provider = availableProviders.containsKey(originalProvider)
            ? originalProvider
            : 'auto';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.76,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        title: Text('Listen online'),
                        subtitle: Text(
                          'Auto tries the selected track source first, then '
                          'other enabled streaming extensions.',
                        ),
                      ),
                      const ListTile(
                        dense: true,
                        title: Text('Streaming provider'),
                      ),
                      ListTile(
                        title: const Text('Automatic · all available sources'),
                        leading: Icon(provider == 'auto'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                        onTap: () => setSheetState(() => provider = 'auto'),
                      ),
                      for (final entry in availableProviders.entries)
                        ListTile(
                          title: Text(entry.value),
                          leading: Icon(provider == entry.key
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked),
                          onTap: () => setSheetState(
                            () => provider = entry.key,
                          ),
                        ),
                      const Divider(),
                      const ListTile(
                        dense: true,
                        title: Text('Online audio quality'),
                      ),
                      for (final entry in qualities.entries)
                        ListTile(
                          title: Text(entry.value),
                          trailing: quality == entry.key
                              ? const Icon(Icons.check_circle)
                              : null,
                          onTap: () => setSheetState(
                            () => quality = entry.key,
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          OnlinePlaybackChoice(
                            quality: quality,
                            provider: provider,
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Long-press on the inline play control opens the global quality picker.
  static Future<String?> choose(BuildContext context) async {
    final selected = await current();
    if (!context.mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Online audio quality'),
              subtitle: Text(
                'Applied to the next stream. Best available is the default.',
              ),
            ),
            for (final option in qualities.entries)
              ListTile(
                title: Text(option.value),
                trailing: option.key == selected
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.circle_outlined),
                onTap: () => Navigator.pop(sheetContext, option.key),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
