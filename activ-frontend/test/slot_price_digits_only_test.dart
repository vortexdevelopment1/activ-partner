import 'package:activ_app/Screens/Home/ManageSlotsScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'test-session'});
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
                {
                  'day': 'Monday',
                  'slots': [
                    {
                      'openTime': '09:00 AM',
                      'closeTime': '06:00 PM',
                      'capacity': 4,
                      'price': 100,
                      'discount': ''
                    }
                  ]
                }
              ]
            }
          }
        ]
      }),
      200));

  testWidgets('slot price and discounted price fields reject decimal points and accept digits only', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(550, 2500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final api = managementClient();
    await tester.pumpWidget(MaterialApp(home: ManageSlotsScreen(client: api)));
    await tester.pumpAndSettle();

    final discountField = find.byKey(const Key('slot-discount-Monday-0'));
    expect(discountField, findsOneWidget);

    // Attempt to enter a decimal value like .94
    await tester.enterText(discountField, '.94');
    await tester.pumpAndSettle();

    // Since digitsOnly is enforced, decimal point is rejected and cannot be typed
    final controller = tester.widget<TextField>(discountField).controller!;
    expect(controller.text.contains('.'), isFalse);
    expect(controller.text, '94');

    // Attempt to enter a decimal value into the main slot price
    final priceField = find.byKey(const Key('slot-price-Monday-0'));
    await tester.enterText(priceField, '1000.50');
    await tester.pumpAndSettle();

    final priceController = tester.widget<TextField>(priceField).controller!;
    expect(priceController.text.contains('.'), isFalse);
    expect(priceController.text, '100050');
  });
}
