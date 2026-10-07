import 'dart:io';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/painting.dart' show ColorFilter;

/// Small pure helpers for the home page (kept out of main.dart so they can be unit-tested).

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  const u = ['KB', 'MB', 'GB', 'TB'];
  var v = b / 1024;
  var i = 0;
  while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${u[i]}';
}

/// `h:mm:ss`, or `m:ss` under an hour.
String formatElapsed(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

/// Pull `traffic/read` / `traffic/written` out of a control-port GETINFO reply. Null when absent.
int? parseTraffic(String reply, String key) {
  final m = RegExp('250[- ]traffic/$key=(\\d+)').firstMatch(reply);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Settings that may travel in an export file. Bridge lines (`customBridges`) and the dismissed-update marker are
/// deliberately left out: bridges are private, and the rest is machine-specific (window size, recent apps).
const kExportableSettings = {
  'autoFastest': bool, 'adBlock': bool, 'rotateMin': int, 'excluded': List, 'checkUpdates': bool,
  'connectOnLaunch': bool, 'lang': String, 'country': String, 'favorites': List, 'notifications': bool, 'themeMode': String,
};

Map<String, Object?> exportSettings(Map<dynamic, dynamic> all) => {
      for (final e in kExportableSettings.entries)
        if (all.containsKey(e.key)) e.key: all[e.key],
    };

/// Keep only known keys whose value has the expected type; anything else in an imported file is dropped.
Map<String, Object?> sanitizeImport(Object? decoded) {
  if (decoded is! Map) return {};
  final out = <String, Object?>{};
  for (final e in kExportableSettings.entries) {
    final v = decoded[e.key];
    final ok = switch (e.value) {
      const (bool) => v is bool,
      const (int) => v is int,
      const (String) => v is String && v.length <= 64,
      _ => v is List && v.length <= 300 && v.every((x) => x is String && x.length <= 8),
    };
    if (ok) out[e.key] = v;
  }
  return out;
}

/// Best-effort desktop notification. Never throws, never touches system state.
Future<void> notifyDesktop(String title, String body) async {
  try {
    if (Platform.isLinux) {
      await Process.run('notify-send', ['-a', 'OnionDesk', title, body]);
    } else if (Platform.isMacOS) {
      String q(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      await Process.run('osascript', ['-e', 'display notification "${q(body)}" with title "${q(title)}"']);
    } else if (Platform.isWindows) {
      String q(String s) => s.replaceAll("'", "''");
      await Process.run('powershell', [
        '-NoProfile', '-WindowStyle', 'Hidden', '-Command',
        "Add-Type -AssemblyName System.Windows.Forms; \$n = New-Object System.Windows.Forms.NotifyIcon; "
            "\$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.Visible = \$true; "
            "\$n.ShowBalloonTip(5000, '${q(title)}', '${q(body)}', 'Info'); Start-Sleep -Seconds 6; \$n.Dispose()",
      ]);
    }
  } catch (_) {}
}

/// True while the Light theme is chosen. The app is drawn dark; light mode is that same picture run through
/// [kLightFilter] (invert, then rotate the hue back), so every screen, the map included, follows with no per-widget colors.
final ValueNotifier<bool> lightTheme = ValueNotifier(false);

const kLightFilter = ColorFilter.matrix(<double>[
  0.574, -1.430, -0.144, 0, 255,
  -0.426, -0.430, -0.144, 0, 255,
  -0.426, -1.430, 0.856, 0, 255,
  0, 0, 0, 1, 0,
]);
