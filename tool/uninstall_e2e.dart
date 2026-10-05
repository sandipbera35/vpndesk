// Real end-to-end check of the uninstall engine against an INSTALLED package (see docs). Uses sudo -S (password in
// $VPNDESK_TEST_PW) instead of pkexec's GUI prompt; everything else is the production code path.
// Usage: VPNDESK_TEST_PW=... dart tool/uninstall_e2e.dart
import 'dart:convert';
import 'dart:io';

import 'package:vpn_desk/uninstall.dart';

Future<void> main() async {
  final pw = Platform.environment['VPNDESK_TEST_PW'] ?? '';
  final plan = UninstallPlan.detect(exe: '/opt/vpn_desk/vpn_desk', env: Platform.environment, deleteData: false);
  print('kind=${plan.kind.name} script=${plan.rootScript} steps=${plan.steps.map((s) => s.id).join(',')}');
  final u = Uninstaller(
    plan: plan,
    prepare: () async => print('  (prepare: app would disconnect here)'),
    rootRun: (script) async {
      final p = await Process.start('sudo', ['-S', '-p', '', script]);
      p.stdin.writeln(pw);
      await p.stdin.close();
      p.stderr.drain<void>();
      return (lines: p.stdout.transform(utf8.decoder).transform(const LineSplitter()), exit: p.exitCode);
    },
  );
  await for (final e in u.run()) {
    print(e.finished ? 'FINISHED' : '${e.stepId} -> ${e.state!.name}${e.error != null ? '  ERROR: ${e.error}' : ''}');
  }
}
