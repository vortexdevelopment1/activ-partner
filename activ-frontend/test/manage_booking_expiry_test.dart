import 'dart:convert';
import 'package:activ_app/Screens/Home/ManageBookingsScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')..addFont(rootBundle.load('fonts/Satoshi-Medium.otf'))).load();
  });
  for (final scenario in ['expired', 'checked-in', 'open-dialog']) {
    testWidgets('$scenario attendance updates without showing expired check-in actions', (tester) async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
      BASE_URL = 'https://backend.test/api/v1';
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final endsAt = DateTime.now().toUtc().add(scenario == 'open-dialog'
          ? const Duration(hours: 1) : const Duration(hours: -1));
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        final Object data = request.url.path.endsWith('/my-approved-venues')
            ? [{'id': 'venue', 'services': [{'id': 'activity'}]}]
            : {'name': 'Billiards', 'bookings': [{
                'id': 'booking', 'customerName': 'Test Customer', 'status': 'Ongoing',
                'startsAt': endsAt.subtract(const Duration(hours: 1)).toIso8601String(),
                'endsAt': endsAt.toIso8601String(), 'checkedIn': scenario == 'checked-in',
                'amount': 900, 'participants': 1, 'paymentMode': 'UPI',
              }]};
        return http.Response(jsonEncode({'data': data}), 200);
      });
      await tester.pumpWidget(MaterialApp(home: ManageBookingsScreen(venueId: 'venue', client: client)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Test Customer'));
      await tester.tap(find.text('Test Customer'));
      await tester.pumpAndSettle();
      expect(find.text('UPI'), findsOneWidget);
      if (scenario == 'open-dialog') {
        expect(find.text('Mark No-show'), findsOneWidget);
        await tester.pump(const Duration(hours: 2));
      }
      if (scenario == 'checked-in') {
        expect(find.text('Mark Completed'), findsOneWidget);
      } else {
        expect(find.text('Mark No-show'), findsNothing);
        expect(find.text('Check-in'), findsNothing);
        expect(find.text('No Show'), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
