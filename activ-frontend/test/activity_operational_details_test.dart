import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityConfigureScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
  });

  Map<String, dynamic> sampleTiming() => {
        'Monday': [
          {
            'open': '09:00 AM',
            'close': '07:00 PM',
            'capacity': '5',
            'price': '500',
            'discountedPrice': '350',
          }
        ],
        'Tuesday': [
          {
            'open': '06:00 AM',
            'close': '12:00 PM',
            'capacity': '5',
            'price': '500',
            'discountedPrice': '350',
          },
          {
            'open': '04:00 PM',
            'close': '10:00 PM',
            'capacity': '5',
            'price': '400',
            'discountedPrice': '300',
          }
        ],
        'Wednesday': [
          {
            'open': '09:00 AM',
            'close': '07:00 PM',
            'capacity': '5',
            'price': '250',
            'discountedPrice': '200',
          }
        ],
        'Thursday': [
          {
            'open': '09:00 AM',
            'close': '07:00 PM',
            'capacity': '5',
            'price': '100',
            'discountedPrice': '80',
          }
        ],
        'Friday': [
          {
            'open': '09:00 AM',
            'close': '07:00 PM',
            'capacity': '5',
            'price': '600',
            'discountedPrice': '500',
          }
        ],
        'Saturday': [
          {'open': '-', 'close': '-'}
        ],
        'Sunday': [
          {'open': '-', 'close': '-'}
        ],
      };

  http.Client mockClient() => MockClient((request) async {
        if (request.url.path.endsWith('/questions')) {
          return http.Response(jsonEncode({'data': []}), 200);
        }
        if (request.url.path.contains('/venues/activities/')) {
          return http.Response(
              jsonEncode({
                'data': {
                  'id': 'activity-1',
                  'name': 'Gym',
                  'imageUrls': [],
                  'amenities': ['Lockers', 'Showers'],
                }
              }),
              200);
        }
        return http.Response(jsonEncode({'data': {}}), 200);
      });

  testWidgets(
      'Operational Details matches reference layout with Operating Days and Day Wise Timings without discount badge',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AddActivityConfigureScreen(
          activityId: 'activity-1',
          activityName: 'Gym',
          timing: sampleTiming(),
          client: mockClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Section Headers
    expect(find.text('Operational Details'), findsOneWidget);
    expect(find.text('Operating Days'), findsOneWidget);
    expect(find.text('Day Wise Timings'), findsOneWidget);

    // Verify all 7 days in Operating Days row
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Wed'), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);
    expect(find.text('Sat'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);

    // Verify table headers and values
    expect(find.text('Open Time'), findsWidgets);
    expect(find.text('Close Time'), findsWidgets);
    expect(find.text('Slot Price'), findsWidgets);

    // Verify days are listed
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Thursday'), findsOneWidget);
    expect(find.text('Friday'), findsOneWidget);

    // Inactive days should NOT be in Day Wise Timings
    expect(find.text('Saturday'), findsNothing);
    expect(find.text('Sunday'), findsNothing);

    // Verify prices displayed
    expect(find.text('500'), findsNWidgets(2)); // Monday + Tuesday 1st slot
    expect(find.text('400'), findsOneWidget); // Tuesday 2nd slot
    expect(find.text('250'), findsOneWidget); // Wednesday
    expect(find.text('100'), findsOneWidget); // Thursday
    expect(find.text('600'), findsOneWidget); // Friday

    // Ensure NO "% OFF" badge is displayed
    expect(find.textContaining('% OFF'), findsNothing);
    expect(find.textContaining('30% OFF'), findsNothing);
  });

  testWidgets(
      'Editing slot price in AddVenueTimingScreen updates AddActivityConfigureScreen dynamically',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AddActivityConfigureScreen(
          activityId: 'activity-1',
          activityName: 'Gym',
          timing: sampleTiming(),
          client: mockClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial Monday slot price is 500
    expect(find.text('500'), findsWidgets);

    // Tap Edit on Operational Details
    await tester.tap(find.byKey(const Key('edit-operational-details')));
    await tester.pumpAndSettle();

    // Should now be on AddVenueTimingScreen
    expect(find.byType(AddVenueTimingScreen), findsOneWidget);

    // Edit Monday's price to 750
    final priceField = find.byKey(const Key('slot-Mon-price-0'));
    expect(priceField, findsOneWidget);
    await tester.enterText(priceField, '750');
    await tester.pumpAndSettle();

    // Tap Next to submit updated timing
    final nextButton = find.widgetWithText(InkWell, 'Next');
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Back on AddActivityConfigureScreen
    expect(find.byType(AddActivityConfigureScreen), findsOneWidget);

    // The price must now dynamically display 750!
    expect(find.text('750'), findsOneWidget);

    // Tap Edit again to verify the new price (750) is retained and not reverted
    await tester.tap(find.byKey(const Key('edit-operational-details')));
    await tester.pumpAndSettle();

    expect(find.byType(AddVenueTimingScreen), findsOneWidget);
    expect(find.text('750'), findsOneWidget);
  });
}
