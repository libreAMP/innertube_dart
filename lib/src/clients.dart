class InnerTubeClient {
  final String name;
  final String version;
  final int clientId;
  final String userAgent;
  final Map<String, dynamic> extraContext;
  final Map<String, dynamic> rootContext;
  final String origin;
  final String referer;
  final bool useMusicPlayerEndpoint;

  const InnerTubeClient({
    required this.name,
    required this.version,
    required this.clientId,
    required this.userAgent,
    this.extraContext = const {},
    this.rootContext = const {},
    this.origin = 'https://music.youtube.com',
    this.referer = 'https://music.youtube.com/',
    this.useMusicPlayerEndpoint = false,
  });

  Map<String, String> headers() => {
        'X-Goog-Api-Format-Version': '1',
        'X-YouTube-Client-Name': clientId.toString(),
        'X-YouTube-Client-Version': version,
        'User-Agent': userAgent,
        'Content-Type': 'application/json',
        'Origin': origin,
        'Referer': referer,
      };

  bool get needsPoToken => switch (name) {
        'TVHTML5_SIMPLY' => true,
        'TVHTML5_SIMPLY_EMBEDDED_PLAYER' => true,
        _ => false,
      };

  Map<String, dynamic> context() => {
        'client': {
          'clientName': name,
          'clientVersion': version,
          ...extraContext,
        },
        ...rootContext,
      };
}

const _webRemix = InnerTubeClient(
  name: 'WEB_REMIX',
  version: '1.20260707.12.00',
  clientId: 67,
  userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
  origin: 'https://music.youtube.com',
  referer: 'https://music.youtube.com/',
);

const _androidVr = InnerTubeClient(
  name: 'ANDROID_VR',
  version: '1.65.10',
  clientId: 28,
  userAgent:
      'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; Quest 3) gzip',
  extraContext: {
    'deviceMake': 'Oculus',
    'deviceModel': 'Quest 3',
    'androidSdkVersion': 32,
    'osName': 'Android',
    'osVersion': '12L',
  },
  origin: 'https://www.youtube.com',
  referer: 'https://www.youtube.com/',
);

const _ios = InnerTubeClient(
  name: 'IOS',
  version: '21.26.4',
  clientId: 5,
  userAgent:
      'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)',
  extraContext: {
    'deviceMake': 'Apple',
    'deviceModel': 'iPhone16,2',
    'osName': 'iPhone',
    'osVersion': '17.5.1.21F90',
  },
  origin: 'https://www.youtube.com',
  referer: 'https://www.youtube.com/',
);

const _androidMusic = InnerTubeClient(
  name: 'ANDROID_MUSIC',
  version: '7.27.52',
  clientId: 21,
  userAgent:
      'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 12) gzip',
  extraContext: {
    'androidSdkVersion': 31,
    'osName': 'Android',
    'osVersion': '12',
  },
  origin: 'https://music.youtube.com',
  referer: 'https://music.youtube.com/',
);

const _android = InnerTubeClient(
  name: 'ANDROID',
  version: '21.26.364',
  clientId: 3,
  userAgent:
      'com.google.android.youtube/21.26.364 (Linux; U; Android 12) gzip',
  extraContext: {
    'androidSdkVersion': 31,
    'osName': 'Android',
    'osVersion': '12',
  },
  origin: 'https://www.youtube.com',
  referer: 'https://www.youtube.com/',
);

const _visionOs = InnerTubeClient(
  name: 'VISIONOS',
  version: '0.1',
  clientId: 101,
  userAgent:
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15',
  extraContext: {
    'deviceMake': 'Apple',
    'deviceModel': 'RealityDevice14,1',
    'osName': 'VISION_OS',
    'osVersion': '1.3',
  },
  origin: 'https://www.youtube.com',
  referer: 'https://www.youtube.com/',
  useMusicPlayerEndpoint: true,
);

const _tvEmbedded = InnerTubeClient(
  name: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
  version: '2.0',
  clientId: 85,
  userAgent:
      'Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15',
  rootContext: {
    'thirdParty': {'embedUrl': 'https://www.youtube.com/'},
  },
  origin: 'https://www.youtube.com',
  referer: 'https://www.youtube.com/',
);

const _tvHtml5Simply = InnerTubeClient(
  name: 'TVHTML5_SIMPLY',
  version: '1.0',
  clientId: 75,
  userAgent:
      'Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15',
  extraContext: {
    'osName': 'PlayStation',
    'osVersion': '12.00',
  },
  origin: 'https://www.youtube.com',
  referer: 'https://www.youtube.com/',
);

const _androidTestsuite = InnerTubeClient(
  name: 'ANDROID_TESTSUITE',
  version: '1.9',
  clientId: 30,
  userAgent: 'com.google.android.youtube/1.9 (Linux; U; Android 12) gzip',
  extraContext: {
    'androidSdkVersion': 31,
    'osName': 'Android',
    'osVersion': '12',
  },
  origin: 'https://www.youtube.com',
  referer: 'https://www.youtube.com/',
);

const List<InnerTubeClient> defaultClients = [
  _visionOs,
  _androidVr,
  _ios,
  _androidMusic,
  _android,
  _tvEmbedded,
  _tvHtml5Simply,
  _androidTestsuite,
];

const webClient = InnerTubeClient(
  name: 'WEB',
  version: '2.20260708.00.00',
  clientId: 1,
  userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  origin: 'https://www.youtube.com',
  referer: 'https://www.youtube.com/',
);

const webRemixClient = _webRemix;