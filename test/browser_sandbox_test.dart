import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/browser_sandbox.dart';

void main() {
  bool ok(Map<String, String> files, {bool linux = true}) => sandboxAvailable(linux: linux, read: (p) => files[p]);

  test('a normal Linux system can sandbox', () {
    expect(ok({'/proc/sys/user/max_user_namespaces': '63000'}), isTrue);
    expect(ok({}), isTrue, reason: 'nothing restricts it');
  });

  test('each way of switching user namespaces off is recognised', () {
    expect(ok({'/proc/sys/kernel/unprivileged_userns_clone': '0'}), isFalse);
    expect(ok({'/proc/sys/kernel/apparmor_restrict_unprivileged_userns': '1'}), isFalse);
    expect(ok({'/proc/sys/user/max_user_namespaces': '0'}), isFalse);
    expect(ok({'/proc/sys/kernel/unprivileged_userns_clone': '1', 'kernel/apparmor_restrict_unprivileged_userns': '0'}), isTrue);
  });

  test('other systems have their own sandbox', () {
    expect(ok({'/proc/sys/user/max_user_namespaces': '0'}, linux: false), isTrue);
  });
}
