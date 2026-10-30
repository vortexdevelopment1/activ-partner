import 'dart:convert';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityConfigureScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart'
    as add;
import 'package:activ_app/Screens/VenueTimingScreen.dart' as onboarding;
import 'package:activ_app/Screens/Home/ManageSlotsScreen.dart';
import 'package:activ_app/Screens/Home/ManagePricingScreen.dart';
import 'package:activ_app/Utills/slot_timing_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Map<String, String> slot(String price) => {
        'open': '09:00 AM',
        'close': '06:00 PM',
        'capacity': '4',
        'price': price
      };
  setUp(() async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'test-session'});
  });
  void largeScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(550, 2500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  http.Client client() => MockClient((request) async => http.Response(
      jsonEncode({
        'data': request.url.path.endsWith('/questions')
            ? []
            : {
                'id': 'activity',
                'name': 'Pickle Ball',
                'imageUrls': [],
                'amenities': []
              }
      }),
      200));

  test('draft writes preserve snapshots, order and activity/category isolation',
      () async {
    final data = {
      'days': ['Mon'],
      'timings': {
        'Mon': [slot('100')]
      }
    };
    final first = SlotTimingDraft.save('activity-one', data);
    (data['days'] as List).add('Tue');
    await first;
    expect((await SlotTimingDraft.read('activity-one'))!['days'], ['Mon']);
    await SlotTimingDraft.save('activity-two', {
      'days': ['Wed']
    });
    await SlotTimingDraft.save('activity-one', data);
    expect((await SlotTimingDraft.read('activity-two'))!['days'], ['Wed']);
    expect(
        (await SlotTimingDraft.read('activity-one'))!['days'], ['Mon', 'Tue']);
  });

  testWidgets(
      'review Back restores timings and reopening the editor keeps them on mobile',
      (tester) async {
    largeScreen(tester);
    final api = client();
    await tester.pumpWidget(MaterialApp(
        home: AddActivityConfigureScreen(
      activityId: 'activity',
      activityName: 'Pickle Ball',
      client: api,
      timing: {
        'Monday': [slot('500')]
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(add.AddVenueTimingScreen));
    expect(state.selectedDays, ['Mon']);
    expect(state.timings['Mon'].timeSlots, [slot('500')]);
    await tester.enterText(find.byKey(const Key('slot-Mon-price-0')), '650');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(
        home: add.AddVenueTimingScreen(activityId: 'activity', client: api)));
    await tester.pumpAndSettle();
    expect(find.text('650'), findsOneWidget);
    final dynamic restored =
        tester.state(find.byType(add.AddVenueTimingScreen));
    expect(restored.timings['Mon'].timeSlots.first['price'], '650');
  });

  testWidgets(
      'add activity copies again after editing and can copy from another day',
      (tester) async {
    largeScreen(tester);
    await tester.pumpWidget(MaterialApp(
        home: add.AddVenueTimingScreen(
      activityId: 'copy',
      client: client(),
      initialTiming: {
        'Monday': [slot('100')],
        'Tuesday': [slot('200')]
      },
    )));
    await tester.pumpAndSettle();
    Future<void> copy(int day) async {
      await tester.tap(find.text('Copy to all').at(day));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    await copy(0);
    final dynamic state = tester.state(find.byType(add.AddVenueTimingScreen));
    expect(state.timings['Mon'].timeSlots.first['price'], '100');
    expect(state.timings['Tue'].timeSlots.first['price'], '100');
    await tester.enterText(find.byKey(const Key('slot-Mon-price-0')), '350');
    await copy(0);
    expect(state.timings['Mon'].timeSlots.first['price'], '350');
    expect(state.timings['Tue'].timeSlots.first['price'], '350');
    await tester.enterText(find.byKey(const Key('slot-Tue-price-0')), '475');
    expect(state.timings['Mon'].timeSlots.first['price'], '350');
    await copy(1);
    expect(state.timings['Mon'].timeSlots.first['price'], '475');
    expect(state.timings['Tue'].timeSlots.first['price'], '475');
    expect(state.timings['Mon'].timeSlots.first['capacity'], '4');
  });

  testWidgets(
      'onboarding restores operating days, ranges and capacity on mobile',
      (tester) async {
    largeScreen(tester);
    await SlotTimingDraft.save('timing_draft_venue_category', {
      'days': ['Mon', 'Tue'],
      'capacity': '8',
      'timings': {
        'Mon': [slot('100')],
        'Tue': [slot('200')]
      }
    });
    await tester.pumpWidget(const MaterialApp(
        home: onboarding.VenueTimingScreen(
            activityId: 'venue', categoryId: 'category')));
    await tester.pumpAndSettle();
    final dynamic state =
        tester.state(find.byType(onboarding.VenueTimingScreen));
    expect(state.selectedDays, ['Mon', 'Tue']);
    expect(find.text('8'), findsOneWidget);
    await tester.tap(find.text('Copy to all').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(state.timings['Tue'].timeSlots, [slot('100')]);
    state.setState(
        () => state.timings['Tue'].timeSlots.first['open'] = '10:00 AM');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy to all').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(state.timings['Mon'].timeSlots.first['open'], '10:00 AM');
  });

  http.Client managementClient() => MockClient((request) async => http.Response(
      jsonEncode({
        'data': [
          {
            'id': 'venue',
            'services': [
              {
                'status': 'approved',
                'categoryId': 'category',
                'name': 'Pickle Ball'
              }
            ],
            'availability': {
              'category': [
                for (final day in ['Monday', 'Tuesday'])
                  {
                    'day': day,
                    'slots': [
                      {
                        'openTime': '09:00 AM',
                        'closeTime': '06:00 PM',
                        'capacity': 4,
                        'price': 100
                      }
                    ]
                  }
              ]
            }
          }
        ]
      }),
      200));

  testWidgets(
      'slot management keeps unsaved fields and repeated copy results when reopened',
      (tester) async {
    largeScreen(tester);
    final api = managementClient();
    await tester.pumpWidget(MaterialApp(home: ManageSlotsScreen(client: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('slot-price-Monday-0')), '700');
    await tester.tap(find.text('Copy to all').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('slot-price-Tuesday-0')))
            .controller!
            .text,
        '700');
    await tester.enterText(find.byKey(const Key('slot-price-Monday-0')), '850');
    await tester.tap(find.text('Copy to all').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: ManageSlotsScreen(client: api)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('slot-price-Tuesday-0')))
            .controller!
            .text,
        '850');
  });

  testWidgets(
      'pricing copies capacity and current price and restores unsaved edits',
      (tester) async {
    largeScreen(tester);
    final api = managementClient();
    await tester
        .pumpWidget(MaterialApp(home: ManagePricingScreen(client: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '925');
    await tester.tap(find.byKey(const Key('copy-pricing-Mon')));
    await tester.pumpAndSettle();
    expect(find.text('925'), findsNWidgets(2));
    final draft = await SlotTimingDraft.read('manage_pricing_timing_venue');
    expect(draft!['Tue']['slots'][0]['capacity'], 4);
    await tester.pumpWidget(const SizedBox());
    await tester
        .pumpWidget(MaterialApp(home: ManagePricingScreen(client: api)));
    await tester.pumpAndSettle();
    expect(find.text('925'), findsNWidgets(2));
  });
}
