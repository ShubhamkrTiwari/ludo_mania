import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mania/main.dart';

void main() {
  testWidgets('Ludo Mania app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AvatarLudoApp());
    expect(find.text('LUDO MANIA'), findsOneWidget);
  });
}
