import 'package:innertube_dart/innertube_dart.dart';
import 'package:test/test.dart';

void main() {
  test('client headers carry the right name and version', () {
    final headers = defaultClients.first.headers();
    expect(headers['X-YouTube-Client-Version'], defaultClients.first.version);
    expect(headers['Content-Type'], 'application/json');
  });

  test('context merges extra fields for android_vr', () {
    final vr = defaultClients.firstWhere((c) => c.name == 'ANDROID_VR');
    final ctx = vr.context()['client'] as Map;
    expect(ctx['clientName'], 'ANDROID_VR');
    expect(ctx['deviceModel'], 'Quest 3');
  });

  test('isExpired flips once the expiry passes', () {
    final past = StreamInfo(
      videoStreams: const [],
      audioStreams: const [],
      hasMultipleLanguages: false,
      availableLanguages: const [],
      expiresAt: DateTime(2000),
    );
    expect(past.isExpired, isTrue);

    final none = StreamInfo(
      videoStreams: const [],
      audioStreams: const [],
      hasMultipleLanguages: false,
      availableLanguages: const [],
    );
    expect(none.isExpired, isFalse);
  });
}
