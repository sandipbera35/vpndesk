// Split-tunnel launcher check against a running OnionDesk proxy (127.0.0.1:9050): builds the same LaunchSpec the app
// uses and runs it. Also lists the installed apps the picker would show.
import 'dart:io';
import 'package:oniondesk/installed_apps.dart';
import 'package:oniondesk/launch_via_tor.dart';

Future<String> run(String line) async {
  final spec = buildLaunch(line, profileDir: '/tmp/oniondesk-split-profile', hasTorsocks: onPath('torsocks'));
  final r = await Process.run(spec.executable, spec.args, environment: spec.env).timeout(const Duration(seconds: 40));
  return '${r.stdout}'.trim();
}

Future<void> main() async {
  final apps = scanLinuxApps(Platform.environment);
  print(apps.length > 5 ? 'PASS  split: installed-apps picker lists ${apps.length} apps (e.g. ${apps.take(3).map((a) => a.name).join(', ')})' : 'FAIL  split: only ${apps.length} apps found');
  const url = 'https://check.torproject.org/api/ip';
  // a program that honours ALL_PROXY (socks5h = remote DNS)
  final a = await run('curl -s $url');
  print(a.contains('"IsTor":true') ? 'PASS  split: curl started through the launcher exits via Tor' : 'FAIL  split: curl via launcher not on Tor: $a');
  // the same program started WITHOUT the launcher is not on Tor (proves the launcher is what makes the difference)
  final direct = (await Process.run('curl', ['-s', '--noproxy', '*', url], environment: {'ALL_PROXY': '', 'all_proxy': ''})).stdout.toString();
  print(direct.contains('"IsTor":false') ? 'PASS  split: the same program without the launcher is NOT on Tor (control)' : 'FAIL  split: control unexpected: $direct');
  // a program that ignores proxy variables: only torsocks can force it
  final py = "python3 -c \"import urllib.request,sys;print(urllib.request.urlopen('$url',timeout=30).read().decode())\"";
  if (onPath('torsocks')) {
    final b = await run(py);
    print(b.contains('"IsTor":true') ? 'PASS  split: a program that ignores proxy settings is forced through Tor by torsocks' : 'FAIL  split: torsocks did not force it: $b');
  } else {
    print('SKIP  split: torsocks not installed');
  }
  print('SPLIT DONE');
}
