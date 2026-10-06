import 'dart:io';

import 'launch_via_tor.dart' show kSocksHost, kSocksPort;

/// Installed programs for the "Run an app through OnionDesk" picker. Pure parsers (tested) plus a scanner per OS.
class AppEntry {
  const AppEntry(this.name, this.command);
  final String name;

  /// What the launcher runs. Windows shortcuts use `lnk:<path>`.
  final String command;
}

const kLinkPrefix = 'lnk:';

/// `Exec=` of a .desktop file without the freedesktop field codes (%f %F %u %U %i %c %k, and `%%` -> `%`).
String stripFieldCodes(String exec) => exec
    .replaceAll('%%', '\u0000')
    .replaceAll(RegExp(r'%[fFuUdDnNickvm]'), '')
    .replaceAll('\u0000', '%')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// One .desktop file -> entry, or null for things that are not a plain GUI app (hidden, terminal, wrong type, no Exec).
AppEntry? parseDesktopEntry(String text) {
  final kv = <String, String>{};
  var inMain = false;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('[')) { inMain = line == '[Desktop Entry]'; continue; }
    if (!inMain || line.isEmpty || line.startsWith('#')) continue;
    final i = line.indexOf('=');
    if (i <= 0) continue;
    final k = line.substring(0, i).trim();
    if (k.contains('[')) continue; // localised keys (Name[de]) - the plain one is used
    kv.putIfAbsent(k, () => line.substring(i + 1).trim());
  }
  if (kv['Type'] != 'Application') return null;
  if (kv['NoDisplay']?.toLowerCase() == 'true' || kv['Hidden']?.toLowerCase() == 'true' || kv['Terminal']?.toLowerCase() == 'true') return null;
  final name = kv['Name'], exec = kv['Exec'];
  if (name == null || name.isEmpty || exec == null) return null;
  final cmd = stripFieldCodes(exec);
  return cmd.isEmpty ? null : AppEntry(name, cmd);
}

/// macOS: launch through `open` so the .app starts normally, with the proxy variables handed to it.
String macOpenCommand(String appPath) =>
    'open -n --env ALL_PROXY=socks5h://$kSocksHost:$kSocksPort --env all_proxy=socks5h://$kSocksHost:$kSocksPort -a "$appPath"';

List<AppEntry> _sorted(Iterable<AppEntry> all) {
  final seen = <String>{};
  final out = [for (final a in all) if (seen.add(a.name.toLowerCase())) a]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

List<AppEntry> scanLinuxApps(Map<String, String> env, {bool includeSystemDirs = true}) {
  final home = env['HOME'] ?? '';
  final dataHome = env['XDG_DATA_HOME'] ?? '$home/.local/share';
  final dirs = <String>{
    '$dataHome/applications',
    for (final d in (env['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share').split(':')) if (d.isNotEmpty) '$d/applications',
    if (includeSystemDirs) ...['/var/lib/flatpak/exports/share/applications', '$dataHome/flatpak/exports/share/applications', '/var/lib/snapd/desktop/applications'],
  };
  final apps = <AppEntry>[];
  for (final d in dirs) {
    try {
      for (final f in Directory(d).listSync().whereType<File>().where((f) => f.path.endsWith('.desktop'))) {
        final e = parseDesktopEntry(f.readAsStringSync());
        if (e != null) apps.add(e);
      }
    } catch (_) {}
  }
  return _sorted(apps);
}

List<AppEntry> scanMacApps(Map<String, String> env) {
  final apps = <AppEntry>[];
  for (final d in ['/Applications', '/System/Applications', '${env['HOME'] ?? ''}/Applications']) {
    try {
      for (final e in Directory(d).listSync().whereType<Directory>().where((e) => e.path.endsWith('.app'))) {
        final name = e.path.split('/').last.replaceAll(RegExp(r'\.app$'), '');
        apps.add(AppEntry(name, macOpenCommand(e.path)));
      }
    } catch (_) {}
  }
  return _sorted(apps);
}

List<AppEntry> scanWindowsApps(Map<String, String> env) {
  final apps = <AppEntry>[];
  for (final base in [env['ProgramData'], env['APPDATA']]) {
    if (base == null) continue;
    try {
      for (final f in Directory('$base\\Microsoft\\Windows\\Start Menu\\Programs').listSync(recursive: true).whereType<File>().where((f) => f.path.toLowerCase().endsWith('.lnk'))) {
        final name = f.path.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.lnk$', caseSensitive: false), '');
        if (RegExp(r'uninstall|readme|help|license', caseSensitive: false).hasMatch(name)) continue;
        apps.add(AppEntry(name, '$kLinkPrefix${f.path}'));
      }
    } catch (_) {}
  }
  return _sorted(apps);
}

/// All installed apps for this OS (runs file listing, so call it off the hot path).
Future<List<AppEntry>> scanInstalledApps() async {
  final env = Platform.environment;
  if (Platform.isLinux) return scanLinuxApps(env);
  if (Platform.isMacOS) return scanMacApps(env);
  if (Platform.isWindows) return scanWindowsApps(env);
  return const [];
}

/// Apps whose name contains every word of [query] (case-insensitive), best prefix matches first.
List<AppEntry> filterApps(List<AppEntry> apps, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return apps;
  final hit = apps.where((a) => words.every((w) => a.name.toLowerCase().contains(w))).toList();
  hit.sort((a, b) {
    final ap = a.name.toLowerCase().startsWith(words.first) ? 0 : 1, bp = b.name.toLowerCase().startsWith(words.first) ? 0 : 1;
    return ap != bp ? ap - bp : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return hit;
}
