import 'package:activ_app/Screens/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const buttonKey = Key('support-drag-button');
  Future<void> showSupport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Stack(children: [
        Positioned.fill(child: ColoredBox(color: Colors.white)),
        DraggableOnboardingSupportMenu(buttonKey: buttonKey),
      ])),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('support button moves with a drag and remains tappable', (tester) async {
    await showSupport(tester);
    final button = find.byKey(buttonKey);
    final before = tester.getCenter(button);
    await tester.drag(button, const Offset(-240, -180));
    await tester.pumpAndSettle();
    final after = tester.getCenter(button);
    expect(after.dx, lessThan(before.dx - 150));
    expect(after.dy, lessThan(before.dy - 100));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-support-panel')), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-support-panel')), findsNothing);
  });

  testWidgets('open support button can be dragged and panel follows it', (tester) async {
    await showSupport(tester);
    final button = find.byKey(buttonKey);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final before = tester.getCenter(button);
    final panel = find.byKey(const Key('onboarding-support-panel'));
    final panelBefore = tester.getRect(panel);
    await tester.drag(button, const Offset(-240, -120));
    await tester.pumpAndSettle();
    expect(tester.getCenter(button).dx, lessThan(before.dx - 150));
    expect(tester.getCenter(button).dy, lessThan(before.dy - 80));
    expect(tester.getRect(panel).top, lessThan(panelBefore.top - 80));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
