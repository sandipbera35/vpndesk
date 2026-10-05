import 'dart:io';

/// A sandbox with a fake `gsettings`, `pkexec` and `notify-send` first on PATH and a private state dir,
/// so tests of the recovery logic never touch the real desktop settings, processes or firewall.
class FakeSystem {
  final Directory root = Directory.systemTemp.createTempSync('vpndesk_test_');
  late final Directory bin = Directory('${root.path}/bin')..createSync();
  late final Directory gs = Directory('${root.path}/gs')..createSync();
  late final Directory state = Directory('${root.path}/state')..createSync();
  late final File netState = File('${root.path}/netstate');
  late final File pkexecLog = File('${root.path}/pkexec.log');
  late final File helper = File('${root.path}/vpndesk-net');
  bool pkexecFails = false;

  FakeSystem() {
    // gsettings: values stored one per file, strings quoted like the real tool prints them.
    _script('gsettings', r'''
d="$FAKE_GS"; cmd=$1; shift
if [ "$cmd" = get ]; then cat "$d/$1.$2" 2>/dev/null || exit 1; exit 0; fi
if [ "$cmd" = set ]; then
  echo "set $1 $2 $3" >> "$d/log"
  case "$3" in ''|*[!0-9]*) printf "'%s'\n" "$3" > "$d/$1.$2" ;; *) printf '%s\n' "$3" > "$d/$1.$2" ;; esac
  exit 0
fi
exit 1
''');
    _script('pkexec', r'''
echo "$@" >> "$FAKE_PKEXEC_LOG"
[ -f "$FAKE_PKEXEC_FAIL" ] && exit 126
echo none > "$VPNDESK_NETSTATE"
exit 0
''');
    _script('notify-send', 'exit 0');
    helper.writeAsStringSync('#!/bin/bash\nexit 0\n');
    Process.runSync('chmod', ['+x', helper.path]);
    netState.writeAsStringSync('none\n');
  }

  void _script(String name, String body) {
    final f = File('${bin.path}/$name')..writeAsStringSync('#!/bin/bash\n$body\n');
    Process.runSync('chmod', ['+x', f.path]);
  }

  void setGs(String schema, String key, String raw) => File('${gs.path}/$schema.$key').writeAsStringSync('$raw\n');
  String? getGs(String schema, String key) {
    final f = File('${gs.path}/$schema.$key');
    return f.existsSync() ? f.readAsStringSync().trim() : null;
  }

  static const proxy = 'org.gnome.system.proxy';

  /// Pretend the machine is stuck with the app's own proxy settings.
  void stuckProxy() {
    setGs(proxy, 'mode', "'manual'");
    setGs('$proxy.socks', 'host', "'127.0.0.1'");
    setGs('$proxy.socks', 'port', '9050');
  }

  void setNetState(String s) => netState.writeAsStringSync('$s\n');
  String get netStateNow => netState.readAsStringSync().trim();
  List<String> get pkexecCalls => pkexecLog.existsSync() ? pkexecLog.readAsLinesSync() : [];

  Map<String, String> get env => {
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'FAKE_GS': gs.path,
        'FAKE_PKEXEC_LOG': pkexecLog.path,
        'FAKE_PKEXEC_FAIL': '${root.path}/pkexec.fail',
        'VPNDESK_STATE_DIR': state.path,
        'VPNDESK_NETSTATE': netState.path,
        'VPNDESK_HELPER': helper.path,
      };

  File get journal => File('${state.path}/session.json');

  /// Write a journal in the format `Session` produces.
  void writeJournal(Map<String, Object?> kv) {
    final body = kv.entries.map((e) => '  "${e.key}": ${e.value is String ? '"${e.value}"' : e.value}').join(',\n');
    journal.writeAsStringSync('{\n$body\n}\n');
  }

  void failPkexec(bool on) {
    final f = File('${root.path}/pkexec.fail');
    if (on) {
      f.writeAsStringSync('1');
    } else if (f.existsSync()) {
      f.deleteSync();
    }
  }

  void dispose() => root.deleteSync(recursive: true);
}
