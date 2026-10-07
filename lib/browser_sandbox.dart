import 'dart:io';

/// Chromium's sandbox needs unprivileged user namespaces on Linux. Some systems switch them off (Debian's
/// `unprivileged_userns_clone=0`, Ubuntu 24.04's AppArmor restriction, `max_user_namespaces=0`). Without them the
/// engine cannot start at all, so the browser falls back to running without the sandbox and WARNS the user.
/// Pure: [read] returns the content of a /proc file or null if it does not exist.
bool sandboxAvailable({required bool linux, String? Function(String path)? read}) {
  if (!linux) return true; // Windows and macOS have their own sandbox
  read ??= (p) {
    try { return File(p).readAsStringSync().trim(); } catch (_) { return null; }
  };
  if (read('/proc/sys/kernel/unprivileged_userns_clone') == '0') return false;
  if (read('/proc/sys/kernel/apparmor_restrict_unprivileged_userns') == '1') return false;
  final max = int.tryParse(read('/proc/sys/user/max_user_namespaces') ?? '');
  if (max != null && max == 0) return false;
  return true;
}
