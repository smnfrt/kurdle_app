import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/main.dart';

void main() {
  testWidgets('Kurdle smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
  });
}
