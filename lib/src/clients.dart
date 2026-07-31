// youtube returns different formats depending on which client asks
class InnerTubeClient {
  final String name;
  final String version;
  final int clientId;
  final String userAgent;

  // ios and android_vr refuse to return streams without these
  final Map<String, dynamic> extraContext;

  // the embedded tv client needs thirdParty beside client, not inside it
  final Map<String, dynamic> rootContext;

  const InnerTubeClient({
    required this.name,
    required this.version,
    required this.clientId,
    required this.userAgent,
    this.extraContext = const {},
    this.rootContext = const {},
  });

  Map<String, String> headers() => {
        'X-Goog-Api-Format-Version': '1',
        'X-YouTube-Client-Name': clientId.toString(),
        'X-YouTube-Client-Version': version,
        'User-Agent': userAgent,
        'Content-Type': 'application/json',
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

// TODO refresh client versions at runtime instead of pinning

// the music web client, primary now that the mobile ones are bot-guarded
const webRemixClient = InnerTubeClient(
  name: 'WEB_REMIX',
  version: '1.20250101.01.00',
  clientId: 67,
  userAgent:
      'com.google.music.web/1.20250101.01.00 (Linux; U; Android 12) gzip',
);

// android_vr still hands back unciphered audio without a potoken
const _androidVr = InnerTubeClient(
  name: 'ANDROID_VR',
  version: '1.60.19',
  clientId: 28,
  userAgent:
      'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; Quest 3) gzip',
  extraContext: {
    'deviceMake': 'Oculus',
    'deviceModel': 'Quest 3',
    'androidSdkVersion': 32,
    'osName': 'Android',
    'osVersion': '12L',
  },
);

const _ios = InnerTubeClient(
  name: 'IOS',
  version: '19.29.1',
  clientId: 5,
  userAgent:
      'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)',
  extraContext: {
    'deviceMake': 'Apple',
    'deviceModel': 'iPhone16,2',
    'osName': 'iPhone',
    'osVersion': '17.5.1.21F90',
  },
);

const _androidMusic = InnerTubeClient(
  name: 'ANDROID_MUSIC',
  version: '6.42.52',
  clientId: 21,
  userAgent:
      'com.google.android.apps.youtube.music/6.42.52 (Linux; U; Android 12) gzip',
  extraContext: {
    'androidSdkVersion': 31,
    'osName': 'Android',
    'osVersion': '12',
  },
);

const _android = InnerTubeClient(
  name: 'ANDROID',
  version: '19.44.38',
  clientId: 3,
  userAgent: 'com.google.android.youtube/19.44.38 (Linux; U; Android 12) gzip',
  extraContext: {
    'androidSdkVersion': 31,
    'osName': 'Android',
    'osVersion': '12',
  },
);

// pulls up videos the normal clients call unavailable
const _tvEmbedded = InnerTubeClient(
  name: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
  version: '2.0',
  clientId: 85,
  userAgent:
      'Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15',
  rootContext: {
    'thirdParty': {'embedUrl': 'https://www.youtube.com/'},
  },
);

// barely worth keeping except when nothing else gets through
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
);

const List<InnerTubeClient> defaultClients = [
  _androidVr,
  _ios,
  _androidMusic,
  _android,
  _tvEmbedded,
  _androidTestsuite,
];

const webClient = InnerTubeClient(
  name: 'WEB',
  version: '2.20240726.00.00',
  clientId: 1,
  userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
);
