import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/process_guard.dart';

Future<bool> alive(int pid) async => (await Process.run('kill', ['-0', '$pid'])).exitCode == 0;

Future<bool> waitDead(int pid, {int seconds = 14}) async {
  for (var i = 0; i < seconds * 4; i++) {
    if (!await alive(pid)) return true;
    await Future.delayed(const Duration(milliseconds: 250));
  }
  return false;
}

void main() {
  final sleepBin = File('/bin/sleep').existsSync() ? File('/bin/sleep').resolveSymbolicLinksSync() : '/usr/bin/sleep';

  test('the child is stopped when the owner (the app) is killed, and a different program with that pid is left alone', () async {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    final owner = await Process.start(sleepBin, ['300']);
    final child = await Process.start(sleepBin, ['301']);
    final other = await Process.start(sleepBin, ['302']);
    addTearDown(() { owner.kill(ProcessSignal.sigkill); child.kill(ProcessSignal.sigkill); other.kill(ProcessSignal.sigkill); });
    await guardProcess(owner: owner.pid, target: child.pid, exe: sleepBin);
    // a second guard whose "exe" does not match the target: it must not kill it
    await guardProcess(owner: owner.pid, target: other.pid, exe: '/definitely/not/this/program');
    await Future.delayed(const Duration(seconds: 2));
    expect(await alive(child.pid), isTrue, reason: 'the owner is still running');
    owner.kill(ProcessSignal.sigkill); // the app crashes / is killed
    expect(await waitDead(child.pid), isTrue, reason: 'the guard stops the child');
    await Future.delayed(const Duration(seconds: 3));
    expect(await alive(other.pid), isTrue, reason: 'not the program the guard was told about');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the guard goes away by itself when the child ends first (no leftover watcher)', () async {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    final owner = await Process.start(sleepBin, ['303']);
    final child = await Process.start(sleepBin, ['304']);
    addTearDown(() { owner.kill(ProcessSignal.sigkill); child.kill(ProcessSignal.sigkill); });
    await guardProcess(owner: owner.pid, target: child.pid, exe: sleepBin);
    child.kill(ProcessSignal.sigkill);
    await Future.delayed(const Duration(seconds: 3));
    final ps = await Process.run('ps', ['-eo', 'args=']);
    expect('${ps.stdout}'.contains('oniondesk-guard ${owner.pid} ${child.pid}'), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('orphans are found by their data folder, and only by it', () async {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    final dir = Directory.systemTemp.createTempSync('guarddir');
    addTearDown(() => dir.deleteSync(recursive: true));
    // a program called "sleep" cannot take --datadir, so fake it with sh -c and exec -a is not portable: use a script named i2pd
    final fake = File('${dir.path}/i2pd')..writeAsStringSync('#!/bin/sh\nexec sleep 305\n');
    await Process.run('chmod', ['+x', fake.path]);
    final p = await Process.start(fake.path, ['--datadir', dir.path, '--conf', 'x']);
    addTearDown(() => p.kill(ProcessSignal.sigkill));
    await Future.delayed(const Duration(milliseconds: 500));
    // the shell exec'd sleep, so the args no longer say i2pd: search for the script itself while it is still a shell
    final q = await Process.start('sh', ['-c', 'sleep 306; # --datadir ${dir.path}']);
    addTearDown(() => q.kill(ProcessSignal.sigkill));
    expect(await findOrphansByDatadir('i2pd', '/some/other/dir'), isEmpty);
    expect(await findOrphansByDatadir('i2pd', dir.path), isNot(contains(q.pid)), reason: 'a different program name is not an i2pd');
  });
}
