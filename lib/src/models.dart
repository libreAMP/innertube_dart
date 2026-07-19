class StreamInfo {
  final List<VideoStream> videoStreams;
  final List<AudioStream> audioStreams;
  final bool hasMultipleLanguages;
  final List<String> availableLanguages;
  final String? title;
  final String? videoId;

  // for logging
  final String? client;

  // parsed from the url's expire param, roughly 6h out
  final DateTime? expiresAt;

  // how far off youtube's reference loudness this track sits
  final double? loudnessDb;

  StreamInfo({
    required this.videoStreams,
    required this.audioStreams,
    required this.hasMultipleLanguages,
    required this.availableLanguages,
    this.title,
    this.videoId,
    this.client,
    this.expiresAt,
    this.loudnessDb,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class BaseStream {
  final String url;
  final int itag;
  final String mimeType;
  final int bitrate;
  final int? contentLength;

  BaseStream({
    required this.url,
    required this.itag,
    required this.mimeType,
    required this.bitrate,
    this.contentLength,
  });
}

class VideoStream extends BaseStream {
  final int width;
  final int height;
  final int fps;

  VideoStream({
    required super.url,
    required super.itag,
    required super.mimeType,
    required super.bitrate,
    required this.width,
    required this.height,
    required this.fps,
    super.contentLength,
  });
}

class AudioStream extends BaseStream {
  final int audioSampleRate;
  final int audioChannels;
  final String? language;
  final String? languageDisplayName;
  final bool isDefaultAudio;

  AudioStream({
    required super.url,
    required super.itag,
    required super.mimeType,
    required super.bitrate,
    required this.audioSampleRate,
    required this.audioChannels,
    this.language,
    this.languageDisplayName,
    this.isDefaultAudio = false,
    super.contentLength,
  });
}
