import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PocketFlowApp());
    expect(find.byType(PocketFlowApp), findsOneWidget);
  });
}
