import 'dart:io';

import 'blocklist.dart';

/// Larger, regularly updated ad/tracker list: StevenBlack/hosts (MIT, see THIRD_PARTY_NOTICES.md).
const kRemoteListUrl = 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts';
const kRemoteListFile = 'blocklist-remote.txt';

/// A downloaded list can never be allowed to break the app itself or Tor, so it is rejected if it would block any of these.
const _mustStayReachable = [
  'torproject.org', 'check.torproject.org', 'onionoo.torproject.org', 'github.com', 'api.github.com',
  'raw.githubusercontent.com', 'ipwho.is', 'api.country.is', 'api.ipify.org', 'speed.cloudflare.com', 'cloudflare.com',
];

/// Returns a reason the text is not an acceptable list, or null if it is fine.
String? rejectList(String text) {
  final b = Blocklist()..addAll(text);
  if (b.length < 1000) return 'the list looks too small or is not in hosts format (${b.length} domains)';
  if (b.length > 2000000) return 'the list is unreasonably large (${b.length} domains)';
  for (final h in _mustStayReachable) {
    if (b.isBlocked(h)) return 'the list would block $h';
  }
  return null;
}

/// Download with [get], validate, and replace [dest] atomically. Returns the number of domains, or throws a readable message.
Future<int> updateRemoteList(Future<String> Function(String url) get, File dest) async {
  final text = await get(kRemoteListUrl);
  final bad = rejectList(text);
  if (bad != null) throw 'Ad list not updated: $bad.';
  final tmp = File('${dest.path}.tmp');
  dest.parent.createSync(recursive: true);
  tmp.writeAsStringSync(text);
  tmp.renameSync(dest.path);
  return (Blocklist()..addAll(text)).length;
}

/// True when [f] is missing or older than [maxAge].
bool listIsStale(File f, {Duration maxAge = const Duration(days: 7)}) {
  try {
    return !f.existsSync() || DateTime.now().difference(f.lastModifiedSync()) > maxAge;
  } catch (_) {
    return true;
  }
}
