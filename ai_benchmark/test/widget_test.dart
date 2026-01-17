import 'package:flutter_test/flutter_test.dart';
import 'package:similarity_quiz/main.dart';

void main() {
  testWidgets('App should start without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const SimilarityQuizApp());
    
    // ホーム画面のタイトルが表示されることを確認
    expect(find.text('判別クイズ'), findsOneWidget);
  });
}
