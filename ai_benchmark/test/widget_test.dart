import 'package:flutter_test/flutter_test.dart';
import 'package:ai_benchmark/main.dart';

void main() {
  testWidgets('App should start without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const AiBenchmarkApp());
    
    // タイトルが表示されることを確認
    expect(find.text('AI Benchmark'), findsWidgets);
  });
}
