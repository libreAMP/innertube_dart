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
  int? _signatureTimestamp;
  final Set<String> _deadClients = {};

  InnerTube({List<InnerTubeClient>? clients, http.Client? httpClient})
      : clients = clients ?? defaultClients,
        _http = httpClient ?? http.Client();

  Future<StreamInfo> player(
    String videoId, {
    String? visitorData,
    String? poToken,
    String? gvsPoToken,
  }) async {
    Object? lastError;

    final ts = _signatureTimestamp ?? await _fetchSignatureTimestamp();

    final attempts = <InnerTubeClient>[
      webRemixClient,
      if (poToken != null) webClient,
      ...clients,
    ];

    for (final client in attempts) {
      if (_deadClients.contains(client.name)) continue;
      final isWeb = client.name == webClient.name;
      try {
        final body = <String, dynamic>{
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
          if (ts != null)
            'playbackContext': {
              'contentPlaybackContext': {
                'signatureTimestamp': ts,
              },
            },
          if (isWeb && poToken != null)
            'serviceIntegrityDimensions': {'poToken': poToken},
        };

        final response =
            await _request('player', client, body, visitorData: visitorData);
        final info = _parsePlayerResponse(response, videoId, client.name,
            poToken: isWeb ? poToken : null, gvsPoToken: gvsPoToken);
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

  Future<int?> _fetchSignatureTimestamp() async {
    try {
      final r = await _http.get(
        Uri.parse(
            'https://www.youtube.com/player_api?hl=en'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      if (r.statusCode != 200) return null;
      final match = RegExp(r'signatureTimestamp[:\s]+(\d+)').firstMatch(r.body);
      if (match == null) return null;
      final ts = int.tryParse(match.group(1)!);
      if (ts != null) _signatureTimestamp = ts;
      return ts;
    } catch (_) {
      return null;
    }
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
    final headers = client.headers();
    if (visitorData != null) {
      headers['X-Goog-Visitor-Id'] = visitorData;
    }
    final response = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'context': context,
        ...body,
      }),
    );

    if (response.statusCode >= 400) {
      _deadClients.add(client.name);
      throw InnerTubeException('HTTP ${response.statusCode} from ${client.name}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _withPot(String url, String? poToken) {
    if (poToken == null) return url;
    if (url.contains('pot=')) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}pot=${Uri.encodeQueryComponent(poToken)}';
  }

  // cipher urls sometimes need the sig appended
  String? _urlFromCipher(Map format) {
    final cipher = (format['cipher'] as String?) ??
        (format['signatureCipher'] as String?);
    if (cipher == null) return null;
    var url = '';
    String? sig;
    String? sp;
    for (final part in cipher.split('&')) {
      if (part.startsWith('url=')) {
        url = Uri.decodeQueryComponent(part.substring(4));
      } else if (part.startsWith('s=')) {
        sig = Uri.decodeQueryComponent(part.substring(2));
      } else if (part.startsWith('sp=')) {
        sp = Uri.decodeQueryComponent(part.substring(3));
      }
    }
    if (url.isEmpty) return null;
    if (sig != null && sp != null && !url.contains('$sp=')) {
      final sep = url.contains('?') ? '&' : '?';
      url = '$url$sep$sp=$sig';
    }
    return url;
  }

  StreamInfo _parsePlayerResponse(
    Map<String, dynamic> response,
    String videoId,
    String clientName, {
    String? poToken,
    String? gvsPoToken,
  }) {
    final status = response['playabilityStatus']?['status'];
    if (status != 'OK') {
      final reason = response['playabilityStatus']?['reason'] ?? 'unknown';
      _deadClients.add(clientName);
      throw InnerTubeException('not playable ($status: $reason)');
    }

    final streamingData = response['streamingData'];
    if (streamingData == null) {
      _deadClients.add(clientName);
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
      var url = format['url'] as String?;
      if (url == null) {
        url = _urlFromCipher(format);
        if (url == null) continue;
      }

      final mimeType = format['mimeType'] as String? ?? '';
      final itag = format['itag'] as int;
      final bitrate = format['bitrate'] as int? ?? 0;
      final contentLength = int.tryParse('${format['contentLength'] ?? ''}');

      // gvs potoken goes on every stream url
      url = _withPot(url, gvsPoToken ?? poToken);

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
          audioSampleRate:
              int.tryParse('${format['audioSampleRate'] ?? ''}') ?? 0,
          audioChannels: format['audioChannels'] ?? 2,
          language: lang,
          languageDisplayName: langName,
          isDefaultAudio: isDefault,
          contentLength: contentLength,
        ));
      }
    }

    if (audioStreams.isEmpty && videoStreams.isEmpty) {
      _deadClients.add(clientName);
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
      loudnessDb: (response['playerConfig']?['audioConfig']?['loudnessDb']
              as num?)
          ?.toDouble(),
    );
  }

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

  void resetDeadClients() => _deadClients.clear();
  void close() => _http.close();
}