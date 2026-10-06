import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// How this copy of OnionDesk got onto the machine, which decides what "uninstall" can remove.
enum InstallKind {
  /// .deb / .rpm under /opt/oniondesk: removed by the root-owned `oniondesk-uninstall` (one administrator prompt).
  package,

  /// `install.sh` copy under ~/.local/share/oniondesk: removed without administrator rights.
  dev,

  /// Anything else (a build directory, an extracted archive): only the user's settings are removed, never the folder.
  portable,
}

enum UStepState { pending, running, done, failed }

class UStep {
  final String id, label;
  const UStep(this.id, this.label);
}

/// One update for the uninstall page.
class UninstallEvent {
  final String? stepId;
  final UStepState? state;
  final String? error;
  final bool cancelled, finished;
  const UninstallEvent.step(this.stepId, this.state)
      : error = null,
        cancelled = false,
        finished = false;
  const UninstallEvent.failed(this.stepId, this.error, {this.cancelled = false})
      : state = UStepState.failed,
        finished = false;
  const UninstallEvent.finished()
      : stepId = null,
        state = null,
        error = null,
        cancelled = false,
        finished = true;
}

/// Files OnionDesk is allowed to delete as the user. Anything else is refused, whatever the caller passes.
const _deletableNames = {'oniondesk', 'oniondesk-dev.desktop', 'oniondesk.desktop', 'oniondesk.png'};

bool isSafeUserPath(String path, String home) {
  if (home.isEmpty || !home.startsWith('/') || home == '/') return false;
  if (!path.startsWith('/') || path.endsWith('/') || path.split('/').contains('..')) return false;
  if (path == home || path == '/') return false;
  final parts = path.split('/')..removeWhere((e) => e.isEmpty);
  return parts.length >= 3 && _deletableNames.contains(parts.last);
}

class UninstallPlan {
  final InstallKind kind;
  final bool deleteData;
  final String? rootScript;
  final String home;

  /// Exact paths removed as the user, in order. Every one passes [isSafeUserPath].
  final List<String> appPaths, dataPaths;

  UninstallPlan._(this.kind, this.deleteData, this.rootScript, this.home, this.appPaths, this.dataPaths);

  /// Work out what to remove. Pure (all inputs injected) so it can be tested without touching the machine.
  factory UninstallPlan.detect({
    required String exe,
    required Map<String, String> env,
    required bool deleteData,
    bool Function(String path)? exists,
  }) {
    exists ??= (p) => File(p).existsSync();
    final home = env['HOME'] ?? '';
    final exeDir = exe.substring(0, exe.lastIndexOf('/'));
    final config = '${env['XDG_CONFIG_HOME'] ?? '$home/.config'}/oniondesk';
    final state = '${env['XDG_STATE_HOME'] ?? '$home/.local/state'}/oniondesk';
    final share = env['XDG_DATA_HOME'] ?? '$home/.local/share';

    final InstallKind kind;
    String? script;
    final app = <String>[];
    if (exeDir == '/opt/oniondesk' && exists('/opt/oniondesk/oniondesk-uninstall')) {
      kind = InstallKind.package;
      script = '/opt/oniondesk/oniondesk-uninstall';
    } else if (exeDir == '$share/oniondesk') {
      kind = InstallKind.dev;
      app.addAll(['$share/applications/oniondesk-dev.desktop', '$share/applications/oniondesk.desktop', '$share/icons/hicolor/512x512/apps/oniondesk.png', '$share/oniondesk']);
    } else {
      kind = InstallKind.portable;
    }
    final data = deleteData ? [config, state] : <String>[];
    return UninstallPlan._(kind, deleteData, script, home, app.where((p) => isSafeUserPath(p, home)).toList(), data.where((p) => isSafeUserPath(p, home)).toList());
  }

  /// The steps the page shows, in order.
  List<UStep> get steps => [
        const UStep('disconnect', 'Disconnecting and restoring your network'),
        if (kind == InstallKind.package) ...const [
          UStep('firewall', 'Removing firewall rules'),
          UStep('package', 'Removing application files'),
          UStep('system', 'Removing system helper and data'),
        ],
        if (kind == InstallKind.dev) const UStep('package', 'Removing application files'),
        if (deleteData) const UStep('data', 'Deleting your settings and saved data'),
      ];

  /// Human-readable list for the confirmation dialog.
  List<String> get willRemove => [
        if (kind == InstallKind.package) 'OnionDesk and its menu entry (administrator permission is asked once)',
        if (kind == InstallKind.package) 'The system-wide helper, its firewall table and the "oniondesk" system user',
        if (kind == InstallKind.dev) 'The developer install in ~/.local/share/oniondesk and its menu entry',
        if (deleteData) 'Your settings and saved data (~/.config/oniondesk)',
      ];

  /// What stays, shown so nothing is a surprise.
  String get leavesBehind => kind == InstallKind.portable
      ? 'The folder this copy runs from is not deleted. Other Tor installs and Tor Browser are never touched.'
      : 'Tor Browser and any other Tor installs on this computer are never touched.';
}

typedef RootRun = Future<({Stream<String> lines, Future<int> exit})> Function(String script);

/// Default: ask for administrator permission with pkexec and stream the script's stdout.
Future<({Stream<String> lines, Future<int> exit})> pkexecRun(String script) async {
  final p = await Process.start('pkexec', [script]);
  p.stderr.drain<void>();
  return (lines: p.stdout.transform(utf8.decoder).transform(const LineSplitter()), exit: p.exitCode);
}

class Uninstaller {
  final UninstallPlan plan;

  /// Disconnect and put proxy/firewall back before anything is removed.
  final Future<void> Function()? prepare;
  final RootRun rootRun;

  /// Preview mode: walks through the steps with delays and removes nothing.
  final bool dryRun;
  final Duration dryStep;

  Uninstaller({required this.plan, this.prepare, this.rootRun = pkexecRun, this.dryRun = false, this.dryStep = const Duration(milliseconds: 1100)});

  Stream<UninstallEvent> run() async* {
    if (dryRun) {
      for (final s in plan.steps) {
        yield UninstallEvent.step(s.id, UStepState.running);
        await Future<void>.delayed(dryStep);
        yield UninstallEvent.step(s.id, UStepState.done);
      }
      yield const UninstallEvent.finished();
      return;
    }

    yield const UninstallEvent.step('disconnect', UStepState.running);
    try {
      await prepare?.call();
    } catch (_) {/* best effort: the root script and recovery cover the rest */}
    yield const UninstallEvent.step('disconnect', UStepState.done);

    // Administrator part first: if the user cancels the prompt, nothing of theirs has been deleted yet.
    if (plan.kind == InstallKind.package) {
      String? current;
      var finished = false;
      String? error;
      try {
        final r = await rootRun(plan.rootScript!);
        await for (final line in r.lines) {
          if (line.startsWith('STEP:')) {
            final id = line.split(':')[1];
            if (current != null) yield UninstallEvent.step(current, UStepState.done);
            current = id;
            yield UninstallEvent.step(id, UStepState.running);
          } else if (line == 'DONE') {
            finished = true;
          } else if (line.startsWith('ERROR:')) {
            error = line.substring(6);
          }
        }
        final code = await r.exit;
        if (code == 126 || code == 127) {
          yield UninstallEvent.failed('firewall', 'Administrator permission was not granted. Nothing was removed.', cancelled: true);
          return;
        }
        if (error != null || !finished || code != 0) {
          yield UninstallEvent.failed(current ?? 'firewall', error ?? 'The uninstaller stopped unexpectedly (exit code $code).');
          return;
        }
        if (current != null) yield UninstallEvent.step(current, UStepState.done);
      } catch (e) {
        yield UninstallEvent.failed(current ?? 'firewall', 'Could not ask for administrator permission: $e', cancelled: true);
        return;
      }
    }

    if (plan.kind == InstallKind.dev) {
      yield const UninstallEvent.step('package', UStepState.running);
      final err = await _deleteAll(plan.appPaths);
      if (err != null) {
        yield UninstallEvent.failed('package', err);
        return;
      }
      yield const UninstallEvent.step('package', UStepState.done);
    }

    if (plan.deleteData) {
      yield const UninstallEvent.step('data', UStepState.running);
      final err = await _deleteAll(plan.dataPaths);
      if (err != null) {
        yield UninstallEvent.failed('data', err);
        return;
      }
      yield const UninstallEvent.step('data', UStepState.done);
    }
    yield const UninstallEvent.finished();
  }

  /// Delete each path (guarded again here), retrying briefly in case a closing process still holds a file.
  Future<String?> _deleteAll(List<String> paths) async {
    for (final p in paths) {
      if (!isSafeUserPath(p, plan.home)) return 'Refused to delete $p';
      for (var attempt = 0; attempt < 4; attempt++) {
        try {
          final t = FileSystemEntity.typeSync(p, followLinks: false);
          if (t == FileSystemEntityType.notFound) break;
          if (t == FileSystemEntityType.link) {
            Link(p).deleteSync(); // the link only, never what it points to
          } else if (t == FileSystemEntityType.directory) {
            Directory(p).deleteSync(recursive: true);
          } else {
            File(p).deleteSync();
          }
          break;
        } catch (e) {
          if (attempt == 3) return 'Could not delete $p: $e';
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }
    return null;
  }
}
