import 'package:innertube_dart/innertube_dart.dart';

Future<void> main() async {
  final client = InnerTube();
  final info = await client.player('dQw4w9WgXcQ');

  print('resolved via ${info.client}: ${info.title}');
  print('${info.audioStreams.length} audio, ${info.videoStreams.length} video');
  print('urls expire ${info.expiresAt}');

  for (final audio in info.audioStreams) {
    print('${audio.bitrate}bps ${audio.mimeType}');
  }

  client.close();
}
