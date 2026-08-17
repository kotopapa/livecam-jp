import 'package:flutter_test/flutter_test.dart';

import 'package:livecam_jp/main.dart';

void main() {
  testWidgets('アプリが起動して仮画面が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const LiveCamApp());
    expect(find.text('実装準備中'), findsOneWidget);
  });
}
