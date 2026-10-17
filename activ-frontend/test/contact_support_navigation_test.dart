import 'package:activ_app/Screens/ContactSupportFormScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('OK after contact submission returns to the previous page',
      (tester) async {
    SharedPreferences.setMockInitialValues({'phoneCode': '+91'});
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ContactSupportFormScreen(),
          )),
          child: const Text('Previous page'),
        ),
      )),
    ));
    await tester.tap(find.text('Previous page'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Partner');
    await tester.enterText(find.byType(TextFormField).at(1), '9764946494');
    await tester.enterText(find.byType(TextFormField).at(2), 'Please contact me');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);
    expect(find.byType(ContactSupportFormScreen), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactSupportFormScreen), findsNothing);
    expect(find.text('Previous page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
