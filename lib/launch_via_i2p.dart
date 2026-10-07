import 'i2p.dart' show kI2pHttpPort, kI2pSocksPort;
import 'launch_via_tor.dart' show LaunchSpec, splitCommand;

/// I2P split tunneling: start one program with the proxy settings of OnionDesk's private i2pd. Only that program is
/// pointed at I2P; nothing about the machine's network changes. Like the Tor version this cannot force a program
/// that ignores proxy settings, and (by design) clearnet sites do not work through I2P: i2pd has no outproxy here.

const kI2pHost = '127.0.0.1';

String _base(String exe) => exe.split(RegExp(r'[\\/]')).last.toLowerCase().replaceAll(RegExp(r'\.exe$'), '');
const _launchers = {'flatpak', 'snap', 'open', 'gtk-launch', 'xdg-open', 'env', 'sh', 'bash'};
const _chromium = {'chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable', 'chrome', 'brave', 'brave-browser', 'microsoft-edge', 'microsoft-edge-stable', 'msedge', 'vivaldi', 'google chrome', 'brave browser', 'microsoft edge'};
const _firefox = {'firefox', 'firefox-esr', 'librewolf'};

/// Short name for the saved-apps list: `firefox`, `org.mozilla.firefox`, `Spotify` ...
String appLabel(String line) {
  try {
    final w = splitCommand(line);
    if (w.isEmpty) return line;
    if (_base(w.first) == 'flatpak' && w.length > 2 && w[1] == 'run') return w.skip(2).firstWhere((x) => !x.startsWith('-'), orElse: () => w.last);
    return w.first.split(RegExp(r'[\\/]')).last;
  } catch (_) {
    return line;
  }
}

/// proxychains config for the force shim: every TCP connection and name lookup of the app goes to i2pd's SOCKS port
/// (names are sent to i2pd, never resolved locally); loopback is left alone so the app's own local services still work.
String proxychainsConf() => [
      'strict_chain',
      'proxy_dns',
      'remote_dns_subnet 224',
      'tcp_read_time_out 15000',
      'tcp_connect_time_out 8000',
      'localnet 127.0.0.0/255.0.0.0',
      '[ProxyList]',
      'socks5 $kI2pHost $kI2pSocksPort',
    ].map((l) => '$l\n').join();

/// Build the child process for [line] ([profileDir] = private browser profile folder, [base] = the user's environment).
/// With [forceLib] (libproxychains4.so, Linux) and [forceConf] (see [proxychainsConf]) a program that ignores proxy
/// settings is still forced through I2P by preloading the shim; browsers and Flatpak apps use their own mechanism.
LaunchSpec buildI2pLaunch(String line, {required String profileDir, Map<String, String> base = const {}, String? forceLib, String? forceConf}) {
  final words = splitCommand(line);
  if (words.isEmpty) throw const FormatException('Type a program to run');
  final exe = words.first;
  final rest = words.sublist(1);
  final name = _base(exe);
  final http = 'http://$kI2pHost:$kI2pHttpPort';
  final socks = 'socks5h://$kI2pHost:$kI2pSocksPort';
  final env = <String, String>{
    ...base,
    'http_proxy': http, 'HTTP_PROXY': http, 'https_proxy': http, 'HTTPS_PROXY': http,
    'ALL_PROXY': socks, 'all_proxy': socks,
    'no_proxy': '', 'NO_PROXY': '',
  };
  final notes = <String>[];
  if (_chromium.contains(name)) {
    notes.add('Chromium-based browser: I2P proxy flags, remote DNS and a separate private profile.');
    return LaunchSpec(exe, [
      // i2pd's HTTP proxy: host names go to the proxy (no local DNS), unknown .i2p names get i2pd's page with jump
      // services, and clearnet sites are refused. (--host-resolver-rules made Chrome warn about an unsupported flag.)
      '--proxy-server=http=$kI2pHost:$kI2pHttpPort;https=$kI2pHost:$kI2pHttpPort',
      '--user-data-dir=$profileDir',
      '--disable-features=WebRtcHideLocalIpsWithMdns',
      '--force-webrtc-ip-handling-policy=disable_non_proxied_udp',
      ...rest,
    ], env, notes);
  }
  if (_firefox.contains(name)) {
    notes.add('Firefox: a separate profile using the I2P proxy, remote DNS and WebRTC turned off.');
    return LaunchSpec(exe, ['-no-remote', '-profile', profileDir, ...rest], env, notes);
  }
  if (name == 'flatpak' && rest.isNotEmpty && rest.first == 'run') {
    notes.add('Flatpak app: proxy passed with --env. Apps that ignore proxy settings are not covered.');
    return LaunchSpec(exe, ['run', '--env=http_proxy=$http', '--env=https_proxy=$http', '--env=ALL_PROXY=$socks', ...rest.skip(1)], env, notes);
  }
  if (forceLib != null && forceConf != null) {
    final old = base['LD_PRELOAD'];
    env['LD_PRELOAD'] = old == null || old.isEmpty ? forceLib : '$forceLib:$old';
    env['PROXYCHAINS_CONF_FILE'] = forceConf;
    env['PROXYCHAINS_QUIET_MODE'] = '1';
    notes.add('Forced through I2P: connections and name lookups go to I2P even if the app ignores proxy settings. Sandboxed (Flatpak/Snap), statically linked and Go programs are not covered.');
    return LaunchSpec(exe, rest, env, notes);
  }
  notes.add(_launchers.contains(name)
      ? 'Proxy settings were set in the environment. Apps that ignore them are not covered.'
      : 'Proxy settings were set in the environment. Programs that ignore them are not covered.');
  return LaunchSpec(exe, rest, env, notes);
}

/// `user.js` for the Firefox profile: HTTP + SOCKS proxy pointing at i2pd, remote DNS, no WebRTC.
String firefoxI2pUserJs() => [
      'user_pref("network.proxy.type", 1);',
      'user_pref("network.proxy.http", "$kI2pHost");',
      'user_pref("network.proxy.http_port", $kI2pHttpPort);',
      'user_pref("network.proxy.ssl", "$kI2pHost");',
      'user_pref("network.proxy.ssl_port", $kI2pHttpPort);',
      'user_pref("network.proxy.socks", "$kI2pHost");',
      'user_pref("network.proxy.socks_port", $kI2pSocksPort);',
      'user_pref("network.proxy.socks_version", 5);',
      'user_pref("network.proxy.socks_remote_dns", true);',
      'user_pref("network.proxy.no_proxies_on", "");',
      'user_pref("media.peerconnection.enabled", false);',
      'user_pref("network.dns.disableIPv6", true);',
      'user_pref("browser.shell.checkDefaultBrowser", false);',
    ].map((l) => '$l\n').join();
