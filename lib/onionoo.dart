import 'dart:convert';
import 'dart:io';

/// Disk-cached Onionoo client: a TTL avoids asking at all, and once the TTL has passed a conditional
/// request (`If-Modified-Since`, `Last-Modified`/`ETag` from the previous answer) returns 304 with no
/// body when nothing changed. Payloads are trimmed with Onionoo's own `fields`/`flag`/`country`/`limit`
/// query parameters by the callers.
class OnionooCache {
  final Directory dir;
  final Duration ttl;
  final String base;

  /// Fetches [url] (optionally with extra request headers) and returns (status, body, response headers).
  /// Injected so the app can route it through Tor's SOCKS port and tests can use a local server.
  final Future<({int status, String body, Map<String, String> headers})> Function(String url, Map<String, String> headers) fetch;

  OnionooCache({required this.dir, required this.fetch, this.ttl = const Duration(minutes: 30), this.base = 'https://onionoo.torproject.org'});

  String _name(String path) => path.hashCode.toUnsigned(32).toRadixString(16);
  File _body(String path) => File('${dir.path}/${_name(path)}.json');
  File _meta(String path) => File('${dir.path}/${_name(path)}.meta');

  /// The cached body for [path] without touching the network (null if there is none or it is older than [maxStale]).
  String? peek(String path, {Duration maxStale = const Duration(days: 2)}) {
    try {
      final meta = jsonDecode(_meta(path).readAsStringSync()) as Map<String, dynamic>;
      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch((meta['fetched'] as num).toInt()));
      return age < maxStale ? _body(path).readAsStringSync() : null;
    } catch (_) {
      return null;
    }
  }

  /// Cached or fresh body for [path] (e.g. `details?flag=Exit&fields=...`); null if neither is available.
  /// [maxStale] bounds how old a cached answer may be when the network fails.
  Future<String?> get(String path, {Duration maxStale = const Duration(days: 2), bool forceRefresh = false}) async {
    final now = DateTime.now();
    String? cached;
    Map<String, dynamic> meta = {};
    try {
      cached = _body(path).readAsStringSync();
      meta = jsonDecode(_meta(path).readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      cached = null;
    }
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch((meta['fetched'] as num?)?.toInt() ?? 0);
    if (cached != null && !forceRefresh && now.difference(fetchedAt) < ttl) return cached;
    final headers = <String, String>{
      if (cached != null && meta['lastModified'] is String) 'If-Modified-Since': meta['lastModified'] as String,
      if (cached != null && meta['etag'] is String) 'If-None-Match': meta['etag'] as String,
    };
    try {
      final r = await fetch('$base/$path', headers);
      if (r.status == 304 && cached != null) {
        _save(path, cached, meta, r.headers, now);
        return cached;
      }
      if (r.status == 200 && r.body.isNotEmpty) {
        jsonDecode(r.body); // never cache something that is not JSON
        _save(path, r.body, meta, r.headers, now);
        return r.body;
      }
    } catch (_) {}
    // Network failed: a recent-enough cached answer beats nothing.
    if (cached != null && now.difference(fetchedAt) < maxStale) return cached;
    return null;
  }

  void _save(String path, String body, Map<String, dynamic> old, Map<String, String> h, DateTime now) {
    try {
      dir.createSync(recursive: true);
      _body(path).writeAsStringSync(body);
      _meta(path).writeAsStringSync(jsonEncode({
        'fetched': now.millisecondsSinceEpoch,
        'lastModified': h['last-modified'] ?? old['lastModified'],
        'etag': h['etag'] ?? old['etag'],
      }));
    } catch (_) {}
  }
}
