import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mornye/controllers/online_stream_settings.dart';
import 'package:mornye/models/track.dart';
import 'package:mornye/services/online_stream_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final track = Track(
    id: '12345',
    name: 'Example track',
    artistName: 'Example artist',
    albumName: 'Example album',
    duration: 225,
    source: 'soundcloud',
  );

  test('source-specific ID and origin travel in every stream request', () {
    final request = onlineStreamRequest(track, 'HI_RES_LOSSLESS');
    expect(request['id'], '12345');
    expect(request['source'], 'soundcloud');
    expect(request['duration_ms'], 225000);
  });

  test('auto prioritizes matching track source and retains all fallbacks', () {
    expect(
      orderedOnlineProviders(
        ['qobuz-web', 'jellyfin', 'soundcloud'],
        preferred: 'auto',
        trackSource: 'soundcloud',
      ),
      ['soundcloud', 'qobuz-web', 'jellyfin'],
    );
  });

  test('manual source preference wins; other providers are still fallback', () {
    expect(
      orderedOnlineProviders(
        ['qobuz-web', 'soundcloud', 'jellyfin'],
        preferred: 'jellyfin',
        trackSource: 'soundcloud',
      ),
      ['jellyfin', 'soundcloud', 'qobuz-web'],
    );
  });

  test('unknown preferred source is ignored and duplicate IDs removed', () {
    expect(
      orderedOnlineProviders(
        ['qobuz-web', 'soundcloud', 'qobuz-web', ''],
        preferred: 'missing',
        trackSource: 'extension:soundcloud',
      ),
      ['soundcloud', 'qobuz-web'],
    );
  });

  test('full direct HTTPS stream accepts providers and codecs beyond FLAC', () {
    expect(
      isFullOnlineStream({
        'success': true,
        'full_track': true,
        'url': 'https://cdn.example.net/complete.m4a',
        'format': 'm4a',
      }),
      isTrue,
    );
    expect(
      receivedStreamFormat({'format': 'aac'}),
      'AAC',
    );
    expect(receivedStreamFormat({}), isNull);
  });

  test('insecure, preview, encrypted, header-dependent sources are rejected', () {
    for (final data in [
      {'url': 'http://example.net/audio.mp3'},
      {'url': 'https://example.net/audio.mp3', 'preview': true},
      {'url': 'https://example.net/audio.mp3', 'encrypted': true},
      {'url': 'https://example.net/audio.mp3', 'requires_headers': true},
      {'url': 'https://example.net/audio.mp3', 'full_track': false},
    ]) {
      final result = {
        'success': true,
        'full_track': true,
        ...data,
      };
      expect(isFullOnlineStream(result), isFalse);
    }
  });

  test('provider preference persists independently of audio quality', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await OnlineStreamSettings.preferredProvider(), 'auto');
    await OnlineStreamSettings.savePreferredProvider('soundcloud');
    expect(await OnlineStreamSettings.preferredProvider(), 'soundcloud');
    expect(await OnlineStreamSettings.current(), 'HI_RES_LOSSLESS');
  });
}
