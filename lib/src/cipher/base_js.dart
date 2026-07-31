import 'package:http/http.dart' as http;

// youtube rotates the player js roughly weekly, hold it a day and keep the stale copy on a failed refresh
class BaseJs {
  final http.Client _http;
  String? _playerId;
  String? _source;
  DateTime? _fetchedAt;

  static const _ttl = Duration(hours: 24);

  BaseJs(this._http);

  bool get _fresh =>
      _source != null &&
      _fetchedAt != null &&
      DateTime.now().difference(_fetchedAt!) < _ttl;

  String? get source => _source;

  Future<String?> get({String? videoId}) async {
    if (_fresh) return _source;
    final previous = _source;
    _playerId ??= await _resolvePlayerId(videoId);
    if (_playerId == null) return previous;
    try {
      final res = await _http.get(
        Uri.parse(
            'https://www.youtube.com/s/player/$_playerId/player_ias.vflset/en_US/base.js'),
        headers: const {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return previous;
      _source = res.body;
      _fetchedAt = DateTime.now();
      return _source;
    } catch (_) {
      return previous;
    }
  }

  // the embed page is lighter than the watch page and always carries the player src
  Future<String?> _resolvePlayerId(String? videoId) async {
    final pages = <String>[
      if (videoId != null) 'https://www.youtube.com/embed/$videoId',
      'https://www.youtube.com/',
    ];
    for (final url in pages) {
      try {
        final res = await _http.get(Uri.parse(url),
            headers: const {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) continue;
        final m = RegExp(r'/s/player/([a-f0-9]{8,})/').firstMatch(res.body);
        if (m != null) return m.group(1);
      } catch (_) {}
    }
    return null;
  }

  // a matching sts tells youtube this client speaks the current player's dialect
  int? extractSts() {
    final src = _source;
    if (src == null) return null;
    final m = RegExp(r'''(?:signatureTimestamp|sts)["']?\s*[:=]\s*["']?(\d{4,6})''')
        .firstMatch(src);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}
