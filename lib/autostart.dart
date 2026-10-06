import 'dart:io';

/// Start OnionDesk when the user logs in. Pure builders (tested) plus a small writer per OS.
/// The entry only starts the app (with `--autostart`); connecting is a separate setting, so nothing changes the
/// network until the user allowed that.
const kAutostartArg = '--autostart';
const kAppId = 'io.github.sandipbera35.OnionDesk';

String _q(String s) => '"${s.replaceAll('"', r'\"')}"';

String linuxAutostartEntry(String exe) => '[Desktop Entry]\n'
    'Type=Application\n'
    'Name=OnionDesk\n'
    'Comment=Browse through Tor from a country you choose\n'
    'Exec=${_q(exe)} $kAutostartArg\n'
    'Icon=oniondesk\n'
    'Terminal=false\n'
    'X-GNOME-Autostart-enabled=true\n';

String macLaunchAgent(String exe) => '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    '<plist version="1.0"><dict>\n'
    '<key>Label</key><string>$kAppId</string>\n'
    '<key>ProgramArguments</key><array><string>${_xml(exe)}</string><string>$kAutostartArg</string></array>\n'
    '<key>RunAtLoad</key><true/>\n'
    '</dict></plist>\n';

String _xml(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Value of the Windows `Run` registry entry.
String windowsRunValue(String exe) => '${_q(exe)} $kAutostartArg';

class Autostart {
  Autostart({Map<String, String>? env, String? exe}) : _env = env ?? Platform.environment, _exe = exe ?? Platform.resolvedExecutable;
  final Map<String, String> _env;
  final String _exe;

  File? _file() {
    final home = _env['HOME'] ?? '';
    if (Platform.isLinux) {
      final base = _env['XDG_CONFIG_HOME'] ?? '$home/.config';
      return File('$base/autostart/$kAppId.desktop');
    }
    if (Platform.isMacOS) return File('$home/Library/LaunchAgents/$kAppId.plist');
    return null;
  }

  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  Future<bool> isEnabled() async {
    if (Platform.isWindows) {
      final r = await Process.run('reg', ['query', _runKey, '/v', 'OnionDesk']);
      return r.exitCode == 0;
    }
    return _file()?.existsSync() ?? false;
  }

  /// Returns true when the setting now matches [on].
  Future<bool> set(bool on) async {
    try {
      if (Platform.isWindows) {
        final r = on
            ? await Process.run('reg', ['add', _runKey, '/v', 'OnionDesk', '/t', 'REG_SZ', '/d', windowsRunValue(_exe), '/f'])
            : await Process.run('reg', ['delete', _runKey, '/v', 'OnionDesk', '/f']);
        return on ? r.exitCode == 0 : true;
      }
      final f = _file();
      if (f == null) return false;
      if (on) {
        f.parent.createSync(recursive: true);
        f.writeAsStringSync(Platform.isMacOS ? macLaunchAgent(_exe) : linuxAutostartEntry(_exe));
      } else if (f.existsSync()) {
        f.deleteSync();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
