@TestOn('linux')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/uninstall.dart';

Future<List<UninstallEvent>> collect(Uninstaller u) => u.run().toList();

String summary(List<UninstallEvent> ev) => ev.map((e) => e.finished ? 'FINISHED' : '${e.stepId}:${e.state!.name}${e.cancelled ? '(cancelled)' : ''}').join(' ');

RootRun fakeRoot(List<String> lines, int code, {List<String>? calls}) => (script) async {
      calls?.add(script);
      return (lines: Stream.fromIterable(lines), exit: Future.value(code));
    };

void main() {
  late Directory home;
  setUp(() => home = Directory.systemTemp.createTempSync('oniondesk_home_'));
  tearDown(() => home.deleteSync(recursive: true));

  Map<String, String> env() => {'HOME': home.path};
  UninstallPlan plan(String exe, {bool data = true, bool Function(String)? exists}) =>
      UninstallPlan.detect(exe: exe, env: env(), deleteData: data, exists: exists);

  void makeDevInstall() {
    for (final f in [
      '.local/share/oniondesk/oniondesk',
      '.local/share/oniondesk/data/x',
      '.local/share/applications/oniondesk-dev.desktop',
      '.local/share/applications/other.desktop',
      '.local/share/icons/hicolor/512x512/apps/oniondesk.png',
      '.config/oniondesk/settings.json',
      '.config/oniondesk/data/state',
      '.local/state/oniondesk/session.json',
      '.config/keepme/important.txt',
      'Documents/keep.txt',
    ]) {
      File('${home.path}/$f').createSync(recursive: true);
    }
  }

  group('isSafeUserPath', () {
    const h = '/home/u';
    test('accepts exactly the known OnionDesk locations', () {
      for (final p in ['/home/u/.config/oniondesk', '/home/u/.local/state/oniondesk', '/home/u/.local/share/oniondesk', '/home/u/.local/share/applications/oniondesk-dev.desktop']) {
        expect(isSafeUserPath(p, h), isTrue, reason: p);
      }
    });
    test('refuses home, root, other names, traversal, relative and trailing-slash paths', () {
      for (final p in ['/home/u', '/', '/home', '/home/u/.config', '/home/u/Documents', '/home/u/.config/oniondesk/../..', '/home/u/.config/oniondesk/', 'relative/oniondesk', '/oniondesk', '/home/u/.config/oniondesk/data']) {
        expect(isSafeUserPath(p, h), isFalse, reason: p);
      }
    });
    test('refuses everything when HOME is empty or root', () {
      expect(isSafeUserPath('/x/y/oniondesk', ''), isFalse);
      expect(isSafeUserPath('/x/y/oniondesk', '/'), isFalse);
    });
  });

  group('detect', () {
    test('package install is recognised only when the root-owned script exists', () {
      expect(plan('/opt/oniondesk/oniondesk', exists: (p) => p == '/opt/oniondesk/oniondesk-uninstall').kind, InstallKind.package);
      expect(plan('/opt/oniondesk/oniondesk', exists: (_) => false).kind, InstallKind.portable);
    });
    test('developer install under ~/.local/share/oniondesk', () {
      expect(plan('${home.path}/.local/share/oniondesk/oniondesk').kind, InstallKind.dev);
    });
    test('a build directory is portable: the folder itself is never scheduled for deletion', () {
      final p = plan('/home/someone/src/vpn/app/build/linux/x64/release/bundle/oniondesk');
      expect(p.kind, InstallKind.portable);
      expect(p.appPaths, isEmpty);
    });
    test('steps depend on the install kind and the data choice', () {
      expect(plan('/opt/oniondesk/oniondesk', exists: (_) => true).steps.map((s) => s.id), ['disconnect', 'firewall', 'package', 'system', 'data']);
      expect(plan('/opt/oniondesk/oniondesk', data: false, exists: (_) => true).steps.map((s) => s.id), ['disconnect', 'firewall', 'package', 'system']);
      expect(plan('${home.path}/.local/share/oniondesk/oniondesk').steps.map((s) => s.id), ['disconnect', 'package', 'data']);
      expect(plan('/tmp/x/oniondesk').steps.map((s) => s.id), ['disconnect', 'data']);
    });
    test('every path in the plan passes the safety guard', () {
      final p = plan('${home.path}/.local/share/oniondesk/oniondesk');
      for (final x in [...p.appPaths, ...p.dataPaths]) {
        expect(isSafeUserPath(x, home.path), isTrue, reason: x);
      }
    });
  });

  group('package uninstall (administrator step)', () {
    UninstallPlan pkg({bool data = true}) => plan('/opt/oniondesk/oniondesk', data: data, exists: (_) => true);

    test('success: steps stream in order, then the user data is deleted', () async {
      makeDevInstall();
      final calls = <String>[];
      var prepared = 0;
      final u = Uninstaller(
          plan: pkg(),
          prepare: () async => prepared++,
          rootRun: fakeRoot(['STEP:firewall:Removing firewall rules', 'STEP:package:Removing application files', 'STEP:system:Removing system helper and data', 'DONE'], 0, calls: calls));
      final ev = await collect(u);
      expect(summary(ev), 'disconnect:running disconnect:done firewall:running firewall:done package:running package:done system:running system:done data:running data:done FINISHED');
      expect(calls, ['/opt/oniondesk/oniondesk-uninstall']);
      expect(prepared, 1);
      expect(Directory('${home.path}/.config/oniondesk').existsSync(), isFalse);
      expect(Directory('${home.path}/.local/state/oniondesk').existsSync(), isFalse);
      expect(File('${home.path}/.config/keepme/important.txt').existsSync(), isTrue, reason: 'unrelated config untouched');
      expect(File('${home.path}/Documents/keep.txt').existsSync(), isTrue);
    });

    test('permission denied (pkexec 126): nothing of the user is deleted', () async {
      makeDevInstall();
      final ev = await collect(Uninstaller(plan: pkg(), rootRun: fakeRoot([], 126)));
      expect(ev.last.cancelled, isTrue);
      expect(ev.last.state, UStepState.failed);
      expect(Directory('${home.path}/.config/oniondesk').existsSync(), isTrue);
      expect(Directory('${home.path}/.local/state/oniondesk').existsSync(), isTrue);
    });

    test('a failing script reports its error and keeps the user data', () async {
      makeDevInstall();
      final ev = await collect(Uninstaller(plan: pkg(), rootRun: fakeRoot(['STEP:firewall:x', 'STEP:package:y', 'ERROR:dpkg could not remove oniondesk: locked'], 1)));
      expect(ev.last.state, UStepState.failed);
      expect(ev.last.stepId, 'package');
      expect(ev.last.error, contains('locked'));
      expect(Directory('${home.path}/.config/oniondesk').existsSync(), isTrue);
    });

    test('a script that ends without DONE is a failure, not a success', () async {
      final ev = await collect(Uninstaller(plan: pkg(data: false), rootRun: fakeRoot(['STEP:firewall:x'], 0)));
      expect(ev.last.state, UStepState.failed);
      expect(ev.any((e) => e.finished), isFalse);
    });

    test('cannot start pkexec: reported as cancelled, nothing deleted', () async {
      makeDevInstall();
      final ev = await collect(Uninstaller(plan: pkg(), rootRun: (_) async => throw const ProcessException('pkexec', [], 'not found')));
      expect(ev.last.cancelled, isTrue);
      expect(Directory('${home.path}/.config/oniondesk').existsSync(), isTrue);
    });

    test('keep my data: settings survive', () async {
      makeDevInstall();
      final ev = await collect(Uninstaller(plan: pkg(data: false), rootRun: fakeRoot(['STEP:firewall:a', 'STEP:package:b', 'STEP:system:c', 'DONE'], 0)));
      expect(ev.last.finished, isTrue);
      expect(Directory('${home.path}/.config/oniondesk').existsSync(), isTrue);
    });
  });

  group('developer / portable installs (no administrator step)', () {
    test('dev install: app files, menu entry and data go; neighbours stay', () async {
      makeDevInstall();
      var asked = false;
      final u = Uninstaller(plan: plan('${home.path}/.local/share/oniondesk/oniondesk'), rootRun: (_) async {
        asked = true;
        throw StateError('must not ask for root');
      });
      final ev = await collect(u);
      expect(summary(ev), 'disconnect:running disconnect:done package:running package:done data:running data:done FINISHED');
      expect(asked, isFalse);
      expect(Directory('${home.path}/.local/share/oniondesk').existsSync(), isFalse);
      expect(File('${home.path}/.local/share/applications/oniondesk-dev.desktop').existsSync(), isFalse);
      expect(File('${home.path}/.local/share/icons/hicolor/512x512/apps/oniondesk.png').existsSync(), isFalse);
      expect(File('${home.path}/.local/share/applications/other.desktop').existsSync(), isTrue);
      expect(File('${home.path}/Documents/keep.txt').existsSync(), isTrue);
    });

    test('portable: only settings are removed', () async {
      makeDevInstall();
      final ev = await collect(Uninstaller(plan: plan('${home.path}/some/dir/oniondesk')));
      expect(ev.last.finished, isTrue);
      expect(Directory('${home.path}/.config/oniondesk').existsSync(), isFalse);
      expect(Directory('${home.path}/.local/share/oniondesk').existsSync(), isTrue);
    });

    test('a symlink named oniondesk is removed as a link, its target is kept', () async {
      final target = Directory('${home.path}/precious')..createSync();
      File('${target.path}/a.txt').createSync();
      Directory('${home.path}/.config').createSync(recursive: true);
      Link('${home.path}/.config/oniondesk').createSync(target.path);
      final ev = await collect(Uninstaller(plan: plan('${home.path}/some/dir/oniondesk')));
      expect(ev.last.finished, isTrue);
      expect(Link('${home.path}/.config/oniondesk').existsSync(), isFalse);
      expect(File('${target.path}/a.txt').existsSync(), isTrue);
    });
  });

  test('dry run walks through every step and removes nothing', () async {
    makeDevInstall();
    final ev = await collect(Uninstaller(plan: plan('${home.path}/.local/share/oniondesk/oniondesk'), dryRun: true, dryStep: Duration.zero));
    expect(summary(ev), 'disconnect:running disconnect:done package:running package:done data:running data:done FINISHED');
    expect(Directory('${home.path}/.local/share/oniondesk').existsSync(), isTrue);
    expect(Directory('${home.path}/.config/oniondesk').existsSync(), isTrue);
  });

  test('a path outside the allow-list is refused even if it gets into the plan', () async {
    // Simulates a bug elsewhere: the runner re-checks every path before deleting.
    final bad = UninstallPlan.detect(exe: '/x/oniondesk', env: {'HOME': home.path}, deleteData: true);
    final doc = Directory('${home.path}/Documents')..createSync();
    expect(isSafeUserPath(doc.path, home.path), isFalse);
    expect(bad.dataPaths.every((p) => isSafeUserPath(p, home.path)), isTrue);
  });
}
