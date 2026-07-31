import 'base_js.dart';

// youtube ciphered formats carry an s param that must be deciphered and rebound as sig before the url plays
class SigDecipher {
  final List<List<String> Function(List<String>, int)> ops;
  SigDecipher(this.ops);

  String? call(String s) {
    var chars = s.split('');
    for (final op in ops) {
      chars = op(chars, 0);
    }
    return chars.join();
  }

  String? decipher(String s, int arg) {
    var chars = s.split('');
    for (final op in ops) {
      chars = op(chars, arg);
    }
    return chars.join();
  }
}

// a helper method takes (a) or (a, b). b is the call-site arg. returns null when the body matches nothing we know
List<String> Function(List<String>, int)? _parseHelperBody(String body) {
  if (body.contains('.reverse()')) {
    return (a, _) => a.reversed.toList();
  }
  // splice(0, b): drop the first b chars
  if (RegExp(r'\.splice\(\s*0\s*,\s*\w').hasMatch(body)) {
    return (a, b) => a.length > b ? a.sublist(b) : <String>[];
  }
  // swap: var c=a[0];a[0]=a[b%a.length];a[b%a.length]=c
  if (RegExp(r'\w+\[0\]\s*=\s*\w+\[\s*\w+\s*%\s*\w+\.length\s*\]').hasMatch(body)) {
    return (a, b) {
      if (a.isEmpty) return a;
      final i = b % a.length;
      final tmp = a[0];
      a[0] = a[i];
      a[i] = tmp;
      return a;
    };
  }
  return null;
}

class _Helper {
  final String name;
  final Map<String, List<String> Function(List<String>, int)?> methods;
  _Helper(this.name, this.methods);
}

// returns null when the shapes dont match, caller falls back to raw urls
SigDecipher? extractSigDecipherer(String baseJs) {
  final fnName = _findDecipherFnName(baseJs);
  if (fnName == null) return null;
  final fnBody = _extractFnBody(baseJs, fnName);
  if (fnBody == null) return null;
  final helperName = _findHelperName(fnBody);
  if (helperName == null) return null;
  final helper = _extractHelper(baseJs, helperName);
  if (helper == null) return null;

  final ops = <List<String> Function(List<String>, int)>[];
  final callRe = RegExp('${RegExp.escape(helperName)}\\.(\\w+)\\((\\w+),(\\d+)\\)');
  for (final m in callRe.allMatches(fnBody)) {
    final methodName = m.group(1)!;
    final arg = int.tryParse(m.group(3) ?? '') ?? 0;
    final op = helper.methods[methodName];
    if (op != null) {
      ops.add((a, _) => op(a, arg));
    }
  }
  if (ops.isEmpty) return null;
  return SigDecipher(ops);
}

// the decipher fn is referenced where the signature gets set, several shapes across builds
String? _findDecipherFnName(String src) {
  final patterns = <RegExp>[
    RegExp(r'\bc\s*&&\s*\w+\.set\([^,]*,\s*\([a-z],\s*(\w+)\('),
    RegExp(r'\b\w+\s*&&\s*\w+\.set\([^,]*,\s*\([a-z],\s*(\w+)\('),
    RegExp(r'\.set\([^,]+,\s*\(\w+\.split\(""\),\s*(\w+)\('),
    RegExp(r'\bc\s*&&\s*\w+\.set\([^,]*,\s*(\w+)\(\w+\.split'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(src);
    if (m != null) return m.group(1);
  }
  return null;
}

// pull a function body by name, matching the three declarations youtube uses
String? _extractFnBody(String src, String name) {
  final patterns = [
    RegExp('function\\s+$name\\s*\\([^)]*\\)\\s*\\{'),
    RegExp('$name\\s*=\\s*function\\s*\\([^)]*\\)\\s*\\{'),
    RegExp('$name\\s*:\\s*function\\s*\\([^)]*\\)\\s*\\{'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(src);
    if (m == null) continue;
    return _balancedBrace(src, m.end - 1);
  }
  return null;
}

// the helper object is a bag of numbered methods, harvest each body and parse it
_Helper? _extractHelper(String src, String name) {
  final defRe = RegExp('(?:var\\s+)?$name\\s*=\\s*\\{');
  final m = defRe.firstMatch(src);
  if (m == null) return null;
  final body = _balancedBrace(src, m.end - 1);
  if (body == null) return null;
  final methods = <String, List<String> Function(List<String>, int)?>{};
  final methodRe = RegExp(r'(\w+)\s*:\s*function\s*\([^)]*\)\s*\{');
  for (final mm in methodRe.allMatches(body)) {
    final key = mm.group(1)!;
    final mBody = _balancedBrace(body, mm.end - 1);
    if (mBody == null) continue;
    methods[key] = _parseHelperBody(mBody);
  }
  return _Helper(name, methods);
}

String? _findHelperName(String fnBody) {
  // calls look like helperName.123(a, N)
  final m = RegExp(r'(\w+)\.\d+\(\w+,').firstMatch(fnBody);
  return m?.group(1);
}

// text inside the braces starting at the { at openIdx, balanced
String? _balancedBrace(String src, int openIdx) {
  if (openIdx >= src.length || src[openIdx] != '{') return null;
  var depth = 0;
  var inStr = false;
  String? quote;
  for (var i = openIdx; i < src.length; i++) {
    final c = src[i];
    if (inStr) {
      if (c == '\\') {
        i++;
        continue;
      }
      if (c == quote) inStr = false;
      continue;
    }
    if (c == '"' || c == "'" || c == '`') {
      inStr = true;
      quote = c;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return src.substring(openIdx + 1, i);
    }
  }
  return null;
}

// a ciphered format comes as s=...&sp=sig&url=...; decipher s, rebind as sig
String? decipherUrl(String? signatureCipher, String? directUrl, SigDecipher? dec) {
  if (dec == null) return directUrl;
  final raw = signatureCipher ?? directUrl;
  if (raw == null) return null;
  final params = Uri.splitQueryString(raw);
  final s = params['s'];
  final sp = params['sp'] ?? 'sig';
  var url = params['url'] ?? directUrl;
  if (s == null || url == null) return directUrl;
  final deciphered = dec(s);
  if (deciphered == null) return directUrl;
  return '$url&$sp=${Uri.encodeQueryComponent(deciphered)}';
}

// tied to a base.js source, re-extracted when it rotates
class SigCipherCache {
  final BaseJs _baseJs;
  String? _source;
  SigDecipher? _decipher;

  SigCipherCache(this._baseJs);

  SigDecipher? get() {
    final src = _baseJs.source;
    if (src == null) return null;
    if (src == _source && _decipher != null) return _decipher;
    _source = src;
    _decipher = extractSigDecipherer(src);
    return _decipher;
  }
}
