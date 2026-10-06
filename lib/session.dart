import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Crash journal: `~/.local/state/oniondesk/session.json`.
///
/// Written (atomically) *before* the app changes anything on the system and deleted only after a clean
/// disconnect. If the app is killed, `oniondesk-restore` reads it to undo exactly what was changed.
/// The file is flat JSON with one `"key": value` per line so the bash script can read it without jq.
class Session {
  /// Tests point this at a temp dir; otherwise `$ONIONDESK_STATE_DIR` or the XDG state dir is used.
  static Directory? dirOverride;

  static Directory get dir {
    final env = Platform.environment;
    final path = dirOverride?.path ??
        env['ONIONDESK_STATE_DIR'] ??
        '${env['XDG_STATE_HOME'] ?? '${env['HOME'] ?? Directory.systemTemp.path}/.local/state'}/oniondesk';
    return Directory(path);
  }

  static File get file => File('${dir.path}/session.json');

  static Map<String, Object?> _data = {};

  /// Set while uninstalling: the journal must not be written again after it was deleted.
  static bool frozen = false;

  /// Clock ticks since boot at which [pid] started (`/proc/<pid>/stat` field 22), or null if it is gone.
  /// Together with the pid this identifies a process even if the pid is later reused.
  static int? startTime(int pid) {
    try {
      final s = File('/proc/$pid/stat').readAsStringSync();
      // comm (field 2) may contain spaces/parens: everything after the last ") " is well-formed.
      final rest = s.substring(s.lastIndexOf(') ') + 2).split(' ');
      return int.parse(rest[19]);
    } catch (_) {
      return null;
    }
  }

  static bool get active => _data.isNotEmpty;
  static Object? get(String key) => _data[key];

  /// Start a fresh journal for this run of the app.
  static void begin(String mode) {
    _data = {
      'version': 1,
      'session': List.generate(8, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join(),
      'app_pid': pid,
      'app_start': startTime(pid) ?? 0,
      'mode': mode,
      'tor_pid': 0,
      'tor_start': 0,
      'tor_exe': '',
      'proxy_changed': false,
      'nft_table': mode == 'system-wide' ? 'inet oniondesk' : '',
    };
    _write();
  }

  /// Merge [kv] into the journal and persist it. Starts a journal if none is active.
  static void set(Map<String, Object?> kv) {
    if (!active) begin('default');
    _data.addAll(kv);
    _write();
  }

  /// Record the tor process we spawned (pid + start time + executable) so recovery never kills a different tor.
  static void recordTor(int torPid, String exe) {
    set({'tor_pid': torPid, 'tor_start': startTime(torPid) ?? 0, 'tor_exe': _resolve(exe)});
  }

  /// Absolute, symlink-free path of [exe] (looked up on PATH when it is a bare name like `tor`),
  /// i.e. what `/proc/<pid>/exe` will say for the running process.
  static String _resolve(String exe) {
    final candidates = exe.contains('/')
        ? [exe]
        : [for (final d in (Platform.environment['PATH'] ?? '').split(':')) if (d.isNotEmpty) '$d/$exe'];
    for (final c in candidates) {
      try {
        if (File(c).existsSync()) return File(c).resolveSymbolicLinksSync();
      } catch (_) {}
    }
    return exe;
  }

  /// Clean disconnect: everything was restored, so there is nothing left to recover.
  static void end() {
    _data = {};
    try {
      file.deleteSync();
    } catch (_) {}
  }

  static String _render(Map<String, Object?> d) =>
      '{\n${d.entries.map((e) => '  ${jsonEncode(e.key)}: ${jsonEncode(e.value)}').join(',\n')}\n}\n';

  /// write tmp + fsync + rename, so a crash never leaves a half-written journal.
  static void _write() {
    if (frozen) return;
    try {
      dir.createSync(recursive: true);
      final tmp = File('${file.path}.tmp');
      final raf = tmp.openSync(mode: FileMode.write);
      raf.writeStringSync(_render(_data));
      raf.flushSync();
      raf.closeSync();
      tmp.renameSync(file.path);
    } catch (_) {}
  }
}
