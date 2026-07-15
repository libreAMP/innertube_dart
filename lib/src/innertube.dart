import 'dart:convert';

import 'package:http/http.dart' as http;

import 'clients.dart';
import 'models.dart';

class InnerTubeException implements Exception {
  final String message;
  InnerTubeException(this.message);
  @override
  String toString() => 'InnerTubeException: $message';
}

class InnerTube {
  static const _baseUrl = 'https://youtubei.googleapis.com/youtubei/v1/';

  final List<InnerTubeClient> clients;
  final http.Client _http;

  InnerTube({List<InnerTubeClient>? clients, http.Client? httpClient})
      : clients = clients ?? defaultClients,
        _http = httpClient ?? http.Client();

  Future<StreamInfo> player(
    String videoId, {
    String? visitorData,
    String? poToken,
  }) async {
    Object? lastError;

    // the web client gets first shot when a potoken is around
    final attempts = <InnerTubeClient>[
      if (poToken != null) webClient,
      ...clients,
    ];

    for (final client in attempts) {
      final isWeb = client.name == webClient.name;
      try {
        final body = <String, dynamic>{
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
          if (isWeb && poToken != null)
            'serviceIntegrityDimensions': {'poToken': poToken},
        };
        final response =
            await _request('player', client, body, visitorData: visitorData);
        final info = _parsePlayerResponse(response, videoId, client.name,
            poToken: isWeb ? poToken : null);
        if (info.audioStreams.isNotEmpty || info.videoStreams.isNotEmpty) {
          return info;
        }
        lastError = 'no streams from ${client.name}';
      } catch (e) {
        lastError = e;
      }
    }

    throw InnerTubeException(
      'all clients failed for "$videoId" (last: $lastError)',
    );
  }

  Future<Map<String, dynamic>> _request(
    String endpoint,
    InnerTubeClient client,
    Map<String, dynamic> body, {
    String? visitorData,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final context = client.context();
    if (visitorData != null) {
      (context['client'] as Map)['visitorData'] = visitorData;
    }
    final response = await _http.post(
      uri,
      headers: client.headers(),
      body: jsonEncode({
        'context': context,
        ...body,
      }),
    );

    if (response.statusCode >= 400) {
      throw InnerTubeException('HTTP ${response.statusCode} from ${client.name}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // youtube binds the potoken to the stream url via a pot query param
  String _withPot(String url, String? poToken) {
    if (poToken == null) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}pot=${Uri.encodeQueryComponent(poToken)}';
  }

  StreamInfo _parsePlayerResponse(
    Map<String, dynamic> response,
    String videoId,
    String clientName, {
    String? poToken,
  }) {
    final status = response['playabilityStatus']?['status'];
    if (status != 'OK') {
      final reason = response['playabilityStatus']?['reason'] ?? 'unknown';
      throw InnerTubeException('not playable ($status: $reason)');
    }

    final streamingData = response['streamingData'];
    if (streamingData == null) {
      throw InnerTubeException('no streamingData');
    }

    final formats = <dynamic>[
      ...?(streamingData['formats'] as List<dynamic>?),
      ...?(streamingData['adaptiveFormats'] as List<dynamic>?),
    ];

    final videoStreams = <VideoStream>[];
    final audioStreams = <AudioStream>[];
    final languages = <String>{};

    for (final format in formats) {
      if (format is! Map) continue;
      // ciphered formats have no direct url, skip them
      if (format['url'] == null) continue;

      final mimeType = format['mimeType'] as String? ?? '';
      final url = _withPot(format['url'] as String, poToken);
      final itag = format['itag'] as int;
      final bitrate = format['bitrate'] as int? ?? 0;
      final contentLength = int.tryParse('${format['contentLength'] ?? ''}');

      if (mimeType.startsWith('video/')) {
        if (format['width'] != null && format['height'] != null) {
          videoStreams.add(VideoStream(
            url: url,
            itag: itag,
            mimeType: mimeType,
            bitrate: bitrate,
            width: format['width'],
            height: format['height'],
            fps: format['fps'] ?? 30,
            contentLength: contentLength,
          ));
        }
      } else if (mimeType.startsWith('audio/')) {
        String? lang;
        String? langName;
        var isDefault = false;
        final track = format['audioTrack'];
        if (track is Map) {
          lang = track['id'] as String?;
          langName = track['displayName'] as String?;
          isDefault = track['audioIsDefault'] as bool? ?? false;
          if (langName != null) languages.add(langName);
        }

        audioStreams.add(AudioStream(
          url: url,
          itag: itag,
          mimeType: mimeType,
          bitrate: bitrate,
          audioSampleRate: int.tryParse('${format['audioSampleRate'] ?? ''}') ?? 0,
          audioChannels: format['audioChannels'] ?? 2,
          language: lang,
          languageDisplayName: langName,
          isDefaultAudio: isDefault,
          contentLength: contentLength,
        ));
      }
    }

    return StreamInfo(
      videoId: videoId,
      client: clientName,
      title: response['videoDetails']?['title'] as String?,
      videoStreams: videoStreams,
      audioStreams: audioStreams,
      hasMultipleLanguages: languages.length > 1,
      availableLanguages: languages.toList(),
      expiresAt: _expiryOf(audioStreams, videoStreams),
    );
  }

  // urls carry an expire param in unix seconds
  DateTime? _expiryOf(List<AudioStream> audio, List<VideoStream> video) {
    final url = audio.isNotEmpty
        ? audio.first.url
        : (video.isNotEmpty ? video.first.url : null);
    if (url == null) return null;
    final expire = Uri.tryParse(url)?.queryParameters['expire'];
    final seconds = int.tryParse(expire ?? '');
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  void close() => _http.close();
}
