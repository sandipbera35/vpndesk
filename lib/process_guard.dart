import 'dart:io';

/// Keeps a child program from outliving this app. A normal quit stops it, but if OnionDesk is killed or crashes, nothing
/// would: so a tiny separate watcher process (it does not die with us) waits for the app to vanish and then stops the
/// child, but only if that process is still the program we started (a recycled pid is never touched).
///
/// Linux and macOS: a shell loop. Windows: a hidden PowerShell loop (never run on real Windows by me).
Future<void> guardProcess({required int owner, required int target, required String exe}) async {
  try {
    if (Platform.isWindows) {
      final name = exe.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.exe$', caseSensitive: false), '');
      final script = "while (Get-Process -Id $owner -ErrorAction SilentlyContinue) { if (-not (Get-Process -Id $target -ErrorAction SilentlyContinue)) { exit }; Start-Sleep -Seconds 1 }; "
          "\$p = Get-Process -Id $target -ErrorAction SilentlyContinue; if (\$p -and \$p.ProcessName -eq '$name') { Stop-Process -Id $target -Force }";
      await Process.start('powershell', ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', script], mode: ProcessStartMode.detached);
      return;
    }
    await Process.start('sh', ['-c', kGuardScript, 'oniondesk-guard', '$owner', '$target', exe], mode: ProcessStartMode.detached);
  } catch (_) {
    // best effort: the next start of the app also reaps a leftover (see I2pRouter.killStale)
  }
}

/// `$1` owner pid, `$2` target pid, `$3` the target's program path.
const kGuardScript = r'''
owner="$1"; target="$2"; exe="$3"
while kill -0 "$owner" 2>/dev/null; do
  kill -0 "$target" 2>/dev/null || exit 0
  sleep 1
done
if ps -o args= -p "$target" 2>/dev/null | grep -qF -- "$exe"; then
  kill -TERM "$target" 2>/dev/null
  i=0
  while kill -0 "$target" 2>/dev/null && [ "$i" -lt 8 ]; do sleep 1; i=$((i+1)); done
  kill -KILL "$target" 2>/dev/null
fi
exit 0
''';

/// Processes of [exeName] whose command line carries `--datadir <dataDir>`: left over from an earlier run of this app
/// (Linux and macOS). Used to reap an orphan even when its pid file is gone.
Future<List<int>> findOrphansByDatadir(String exeName, String dataDir) async {
  if (Platform.isWindows) return const [];
  try {
    final r = await Process.run('ps', ['-eo', 'pid=,args=']);
    final out = <int>[];
    for (final l in '${r.stdout}'.split('\n')) {
      final m = RegExp(r'^\s*(\d+)\s+(.*)$').firstMatch(l);
      if (m == null) continue;
      final args = m.group(2)!;
      final first = args.split(' ').first.split('/').last;
      if (first == exeName && args.contains('--datadir $dataDir')) out.add(int.parse(m.group(1)!));
    }
    return out;
  } catch (_) {
    return const [];
  }
}
