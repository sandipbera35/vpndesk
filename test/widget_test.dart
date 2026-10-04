import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_desk/main.dart';

void main() {
  testWidgets('shows disconnected state', (tester) async {
    await tester.pumpWidget(const VpnDeskApp());
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
