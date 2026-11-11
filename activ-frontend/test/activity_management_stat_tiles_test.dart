import 'dart:convert';
import 'package:activ_app/Beans/activity_model.dart';
import 'package:activ_app/Screens/Home/Activities/ActivityManagementScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
  });

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    for (final textScale in [1.0, 1.25]) {
      testWidgets(
          'Total Booking, Total Earning and Occupancy counters are proportional at ${width}px with scale $textScale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'activity-1',
                'name': 'Cricket Nets',
                'bookingCount': 0,
                'earnings': 0,
                'occupancy': 0,
                'status': 'approved',
                'isActive': true,
                'bookingAccept': true,
              }
            }),
            200,
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: ActivityManagementScreen(
              activity: ActivityModel.fromJson({
                'activity_id': 'activity-1',
                'operate_value': {'title': 'Cricket Nets'}
              }),
              venueId: 'venue-1',
              client: client,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total Booking'), findsOneWidget);
        expect(find.text('Total Earning'), findsOneWidget);
        expect(find.text('Occupancy'), findsOneWidget);

        // Titles must each have maxLines == 1
        final totalBookingTitle = tester.firstWidget<Text>(find.text('Total Booking'));
        expect(totalBookingTitle.maxLines, equals(1));

        final totalEarningTitle = tester.firstWidget<Text>(find.text('Total Earning'));
        expect(totalEarningTitle.maxLines, equals(1));

        final occupancyTitle = tester.firstWidget<Text>(find.text('Occupancy'));
        expect(occupancyTitle.maxLines, equals(1));

        // Counter values
        expect(find.text('0'), findsOneWidget);
        expect(find.text('₹0'), findsOneWidget);
        expect(find.text('0%'), findsOneWidget);

        final bookingCounterRect = tester.getRect(find.text('0'));
        final earningCounterRect = tester.getRect(find.text('₹0'));
        final occupancyCounterRect = tester.getRect(find.text('0%'));

        // The height of all three counters should be virtually identical (not shrunken)
        expect(bookingCounterRect.height, greaterThan(15.0));
        expect((bookingCounterRect.height - earningCounterRect.height).abs(), lessThanOrEqualTo(4.0));
        expect((bookingCounterRect.height - occupancyCounterRect.height).abs(), lessThanOrEqualTo(4.0));

        expect(tester.takeException(), isNull);
      });
    }
  }
}
