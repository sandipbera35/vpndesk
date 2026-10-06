import 'dart:io';

/// "Run an app through OnionDesk" (proxy mode, per app): start a program that talks to OnionDesk's local SOCKS5
/// proxy. Nothing about the machine's network is changed; only the child process gets the proxy settings.
/// Apps that ignore proxy settings are NOT covered unless `torsocks` is installed, or System-wide mode is on.

const kSocksHost = '127.0.0.1';
const kSocksPort = 9050;

class LaunchSpec {
  const LaunchSpec(this.executable, this.args, this.env, this.notes);
  final String executable;
  final List<String> args;
  final Map<String, String> env;
  final List<String> notes; // shown to the user so nothing is a surprise
}

/// Shell-like split: whitespace separates words, single/double quotes group, backslash escapes the next char.
List<String> splitCommand(String line) {
  final out = <String>[];
  final cur = StringBuffer();
  var inWord = false;
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote != null) {
      if (c == quote) {
        quote = null;
      } else if (c == r'\' && quote == '"' && i + 1 < line.length && (line[i + 1] == '"' || line[i + 1] == r'\')) {
        cur.write(line[++i]);
      } else {
        cur.write(c);
      }
    } else if (c == '"' || c == "'") {
      quote = c;
      inWord = true;
    } else if (c == r'\' && i + 1 < line.length) {
      cur.write(line[++i]);
      inWord = true;
    } else if (c == ' ' || c == '\t') {
      if (inWord) { out.add(cur.toString()); cur.clear(); inWord = false; }
    } else {
      cur.write(c);
      inWord = true;
    }
  }
  if (quote != null) throw const FormatException('Unclosed quote');
  if (inWord) out.add(cur.toString());
  return out;
}

String _base(String exe) => exe.split('/').last.toLowerCase();

/// Programs that only start another program: wrapping them in torsocks would not cover the app they launch.
const _launchers = {'flatpak', 'snap', 'open', 'gtk-launch', 'xdg-open', 'env', 'sh', 'bash'};

const _chromium = {'chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable', 'chrome', 'brave', 'brave-browser', 'microsoft-edge', 'vivaldi'};
const _firefox = {'firefox', 'firefox-esr', 'librewolf'};

/// Build the child process for [line]. [profileDir] is a private, throw-away-able profile folder for browsers;
/// [hasTorsocks] says whether `torsocks` is on PATH; [base] is the user's environment.
LaunchSpec buildLaunch(String line, {required String profileDir, required bool hasTorsocks, Map<String, String> base = const {}}) {
  final words = splitCommand(line);
  if (words.isEmpty) throw const FormatException('Type a program to run');
  final exe = words.first;
  final rest = words.sublist(1);
  final name = _base(exe);
  final proxy = 'socks5h://$kSocksHost:$kSocksPort'; // socks5h: the name is resolved by tor, not locally
  final env = <String, String>{
    ...base,
    'ALL_PROXY': proxy, 'all_proxy': proxy,
    'SOCKS_PROXY': proxy, 'socks_proxy': proxy,
  };
  final notes = <String>[];

  if (_chromium.contains(name)) {
    notes.add('Chromium-based browser: proxy flags, remote DNS and a separate private profile.');
    return LaunchSpec(exe, [
      '--proxy-server=socks5://$kSocksHost:$kSocksPort',
      '--host-resolver-rules=MAP * ~NOTFOUND , EXCLUDE $kSocksHost',
      '--user-data-dir=$profileDir',
      '--disable-features=WebRtcHideLocalIpsWithMdns',
      '--force-webrtc-ip-handling-policy=disable_non_proxied_udp',
      ...rest,
    ], env, notes);
  }
  if (_firefox.contains(name)) {
    notes.add('Firefox: a separate profile with SOCKS5 proxy, remote DNS and WebRTC turned off.');
    return LaunchSpec(exe, ['-no-remote', '-profile', profileDir, ...rest], env, notes);
  }
  if (name == 'flatpak' && rest.isNotEmpty && rest.first == 'run') {
    // The sandbox does not see the host's environment, so hand the proxy to the app explicitly (loopback is shared).
    notes.add('Flatpak app: proxy passed with --env. Apps that ignore proxy settings are not covered.');
    return LaunchSpec(exe, ['run', '--env=ALL_PROXY=$proxy', '--env=all_proxy=$proxy', ...rest.skip(1)], env, notes);
  }
  if (_launchers.contains(name)) {
    notes.add('Proxy settings were set in the environment. Apps that ignore them are not covered; use System-wide mode for those.');
    return LaunchSpec(exe, rest, env, notes);
  }
  if (hasTorsocks) {
    // torsocks refuses connections to localhost, so a program that also honours ALL_PROXY (which points at
    // 127.0.0.1:9050) would fail: with torsocks the proxy variables are left out and torsocks does the routing.
    notes.add('Using torsocks so programs that ignore proxy settings are forced through Tor.');
    return LaunchSpec('torsocks', [exe, ...rest], {...base}, notes);
  }
  notes.add('Proxy settings were set in the environment. Programs that ignore them are not covered; install torsocks or use System-wide mode.');
  return LaunchSpec(exe, rest, env, notes);
}

/// `user.js` for the Firefox profile (written before launching).
String firefoxUserJs() => [
      'user_pref("network.proxy.type", 1);',
      'user_pref("network.proxy.socks", "$kSocksHost");',
      'user_pref("network.proxy.socks_port", $kSocksPort);',
      'user_pref("network.proxy.socks_version", 5);',
      'user_pref("network.proxy.socks_remote_dns", true);',
      'user_pref("network.proxy.no_proxies_on", "");',
      'user_pref("media.peerconnection.enabled", false);',
      'user_pref("network.dns.disableIPv6", true);',
      'user_pref("browser.shell.checkDefaultBrowser", false);',
    ].map((l) => '$l\n').join();

bool onPath(String bin, {Map<String, String>? env}) {
  final dirs = (env ?? Platform.environment)['PATH']?.split(':') ?? const <String>[];
  return dirs.any((d) => d.isNotEmpty && File('$d/$bin').existsSync());
}
