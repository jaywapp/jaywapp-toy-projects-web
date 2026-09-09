import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:be_my_colleague/common.dart';
import 'package:be_my_colleague/main.dart';

void main() {
  testWidgets('App opens the real signed-out login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text(Common.title), findsOneWidget);
    expect(find.text(Common.copyright), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login with Google'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
