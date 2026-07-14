# innertube_dart

Pulls YouTube stream urls straight from the InnerTube `player` endpoint by
impersonating a native client. It skips the watch page and the
signature-decipher step, so it's quicker than the HTML route.

Used by the Kashou player.

## Why not youtube_explode_dart

It's more complete but goes the slow HTML and cipher way. This does one POST and
gets direct urls back. The catch is it breaks more often when YouTube changes a
client, so there's an ordered list in `lib/src/clients.dart` that it falls
through until one works. A version bump usually fixes it.

Kashou tries this first and falls back to youtube_explode_dart when it comes
back empty.

## Usage

```dart
import 'package:innertube_dart/innertube_dart.dart';

final client = InnerTube();
final info = await client.player('dQw4w9WgXcQ');

for (final audio in info.audioStreams) {
  print('${audio.bitrate}bps ${audio.mimeType} -> ${audio.url}');
}
```

`player()` throws when the video won't play or nothing in the client list works.

## Multi-language audio

Dubbed videos come back with several audio streams tagged with a `language` and
`languageDisplayName`. Check `hasMultipleLanguages` and `availableLanguages` to
show a picker.

Stream extraction only for now, no search or playlists.

## License

GPL-3.0, see LICENSE. Anything built on this must stay GPL and must keep
attribution to innertube_dart by libreAMP (GPL-3.0 section 7b), see NOTICE.
Some parts come from muzoapi (MIT), also credited in NOTICE.
