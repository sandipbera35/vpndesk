// Address-bar logic of the OnionDesk Browser (pure, so it can be tested without the browser engine).


/// What to load for what the user typed into the address bar.
///   * a full address (`http://`, `https://`) is used as it is; other schemes (`file:`, `chrome:`, `javascript:`...) are refused
///   * `name.i2p` and other dotted names are opened (http for .i2p, https otherwise): this is what the stock
///     Chromium address bar got wrong for .i2p
///   * anything else is a search: on I2P only, the I2P search engine; otherwise DuckDuckGo (never Google)
/// Returns null for input that must not be loaded.
String? resolveAddress(String input, {required bool useTor, required bool useI2p}) {
  final t = input.trim();
  if (t.isEmpty) return null;
  final scheme = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):').firstMatch(t)?.group(1)?.toLowerCase();
  if (scheme != null && RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(t)) {
    return scheme == 'http' || scheme == 'https' ? t : null;
  }
  if (t == 'about:blank') return t;
  // "host:port" has a colon but no scheme: treat as host below; real schemes without // (javascript:, data:, mailto:) are refused
  if (scheme != null && !RegExp(r'^[^/\s]+:\d+(/|$)').hasMatch(t)) return null;
  final looksLikeHost = !t.contains(RegExp(r'\s')) && (t.contains('.') || t.startsWith('localhost')) && !t.startsWith('.') && !t.endsWith('.');
  if (looksLikeHost) {
    final host = t.split(RegExp(r'[/?#:]')).first.toLowerCase();
    return '${host.endsWith('.i2p') ? 'http' : 'https'}://$t';
  }
  final q = Uri.encodeQueryComponent(t);
  if (useI2p && !useTor) return 'http://legwork.i2p/yacysearch.html?query=$q';
  return 'https://duckduckgo.com/?q=$q';
}

/// How an address is SHOWN in the address bar: the way the user would type it, without the `http://` / `https://`
/// the browser adds by itself, and without a lone trailing slash. (The real URL is still what gets loaded.)
String displayAddress(String url) {
  var t = url.trim();
  final m = RegExp(r'^https?://', caseSensitive: false).firstMatch(t);
  if (m != null) t = t.substring(m.end);
  if (t.endsWith('/') && t.indexOf('/') == t.length - 1) t = t.substring(0, t.length - 1);
  return t;
}

/// A suggestion card on the start screen.
class QuickLink {
  const QuickLink(this.title, this.url, this.blurb);
  final String title, url, blurb;
}

/// Popular I2P search engines and directories (their availability on I2P varies from day to day; a name the router does
/// not know yet fails until its address book has downloaded).
const kI2pQuickLinks = [
  QuickLink('Legwork', 'http://legwork.i2p/', 'Full-text search engine for eepsites'),
  QuickLink('Ransack', 'http://ransack.i2p/', 'Independent I2P search engine'),
  QuickLink('Eepsites', 'http://eepsites.i2p/', 'Directory of eepsites'),
  QuickLink('NotBob', 'http://notbob.i2p/', 'Directory and up/down status of eepsites'),
  QuickLink('identiguy', 'http://identiguy.i2p/', 'Address book and directory'),
  QuickLink('stats.i2p', 'http://stats.i2p/', 'Network statistics and site list'),
  QuickLink('I2P forum', 'http://i2pforum.i2p/', 'The I2P community forum'),
  QuickLink('I2P Project', 'http://i2p-projekt.i2p/', 'The official I2P website'),
];

/// Starting points for the normal web through Tor.
const kTorQuickLinks = [
  QuickLink('DuckDuckGo', 'https://duckduckgo.com/', 'Search without tracking'),
  QuickLink('Tor Project', 'https://www.torproject.org/', 'About Tor'),
  QuickLink('Check Tor', 'https://check.torproject.org/', 'Are you using Tor?'),
  QuickLink('Wikipedia', 'https://www.wikipedia.org/', 'The free encyclopedia'),
];
