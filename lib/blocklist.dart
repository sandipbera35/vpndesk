import 'dart:io';

/// Domain blocklist for the ad/tracker blocker. Hosts-file or plain one-domain-per-line format; a listed
/// domain also blocks all its subdomains.
class Blocklist {
  final Set<String> _domains = {};

  int get length => _domains.length;

  /// Parses `0.0.0.0 ads.example.com`, `127.0.0.1 x.y`, or bare `domain` lines; `#` starts a comment.
  void addAll(String text) {
    for (var line in text.split('\n')) {
      final hash = line.indexOf('#');
      if (hash >= 0) line = line.substring(0, hash);
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) continue;
      final host = (parts.length > 1 ? parts[1] : parts[0]).toLowerCase();
      if (host == 'localhost' || !host.contains('.')) continue;
      _domains.add(host);
    }
  }

  bool isBlocked(String host) {
    var h = host.toLowerCase();
    if (h.endsWith('.')) h = h.substring(0, h.length - 1);
    while (true) {
      if (_domains.contains(h)) return true;
      final dot = h.indexOf('.');
      if (dot < 0) return false;
      h = h.substring(dot + 1);
      if (!h.contains('.')) return false; // never match a bare TLD
    }
  }

  /// Loads the bundled list text, the downloaded list (if any) and an optional user list (`blocklist.txt` in the config dir).
  static Blocklist load(String bundled, File? userFile, {File? remoteFile}) {
    final b = Blocklist()..addAll(bundled);
    for (final f in [remoteFile, userFile]) {
      try {
        if (f != null && f.existsSync()) b.addAll(f.readAsStringSync());
      } catch (_) {}
    }
    return b;
  }
}
