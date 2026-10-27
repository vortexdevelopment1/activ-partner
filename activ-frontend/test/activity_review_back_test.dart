import 'dart:convert';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityConfigureScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart';
import 'package:activ_app/Utills/activity_flow_checkpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'jwt_token': 'session'}));
  final timing = {
    'Monday': [
      {'open': '09:00 AM', 'close': '06:00 PM', 'capacity': '4', 'price': '500'}
    ]
  };
  http.Client client() => MockClient((request) async => http.Response(
      jsonEncode({
        'data': request.url.path.endsWith('/questions')
            ? []
            : {'id': 'activity', 'name': 'Pickle Ball', 'imageUrls': []}
      }),
      200));
  void size(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  for (final system in [false, true]) {
    testWidgets(
        '${system ? 'system' : 'button'} Back pops exactly one review route and reuses the same timing editor',
        (tester) async {
      size(tester);
      final api = client();
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => AddVenueTimingScreen(
                                    activityId: 'activity',
                                    initialTiming: timing,
                                    client: api))),
                        child: const Text('Previous step')),
                  ))));
      await tester.tap(find.text('Previous step'));
      await tester.pumpAndSettle();
      final original = tester.state(find.byType(AddVenueTimingScreen));
      for (var visit = 0; visit < 2; visit++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.byType(AddActivityConfigureScreen), findsOneWidget);
        if (system) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text('Back'));
        }
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(AddVenueTimingScreen)), same(original));
        expect(find.byType(AddVenueTimingScreen, skipOffstage: false),
            findsOneWidget);
        final dynamic slots = original;
        expect(slots.timings['Mon'].timeSlots, timing['Monday']);
        expect((await ActivityFlowCheckpoint.read('activity'))!.step, 'timing');
      }
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Previous step'), findsOneWidget);
      expect(
          find.byType(AddVenueTimingScreen, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'system Back from a restored root review opens the previous timing step with saved data',
      (tester) async {
    size(tester);
    await tester.pumpWidget(MaterialApp(
        home: AddActivityConfigureScreen(
      activityId: 'activity',
      activityName: 'Pickle Ball',
      timing: timing,
      client: client(),
    )));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final dynamic slots = tester.state(find.byType(AddVenueTimingScreen));
    expect(slots.timings['Mon'].timeSlots, timing['Monday']);
    expect(find.byType(AddActivityConfigureScreen, skipOffstage: false),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
}
