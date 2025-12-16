// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:best_flutter_ui_templates/main.dart';

void main() {
  testWidgets('App builds and shows Login title', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // wait for initial frames
    await tester.pumpAndSettle();

    // The app's home is LoginPage(title: 'Login') — assert title exists
    expect(find.text('Login'), findsWidgets);
  });
}
