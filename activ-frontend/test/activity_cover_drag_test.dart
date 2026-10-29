import 'dart:convert';
import 'package:activ_app/Beans/activity_model.dart';
import 'package:activ_app/Screens/Home/Activities/ActivityManagementScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const first = 'https://images.test/first.jpg';
  const second = 'https://images.test/second.jpg';
  const third = 'https://images.test/third.jpg';
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
  });
  Future<void> open(WidgetTester tester, http.Client client) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: ActivityManagementScreen(
      activity: ActivityModel.fromJson({'activity_id': 'activity',
        'operate_value': {'title': 'Adventure Sports'}}),
      venueId: 'venue', client: client,
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Manage Images'));
    await tester.tap(find.text('Manage Images'));
    await tester.pumpAndSettle();
  }
  http.Response details(String cover, {List<String> images = const [first, second, third]}) => http.Response(jsonEncode({'data': {
    'id': 'activity', 'name': 'Adventure Sports', 'status': 'approved',
    'imageUrls': images, 'coverImageUrl': cover,
  }}), 200);

  Future<void> drag(WidgetTester tester, String from, String to) async {
    final source = find.byKey(ValueKey('activity-image-$from'));
    final target = find.byKey(ValueKey('activity-image-$to'));
    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('dragging a photo to first sets cover only when saved and survives reopening', (tester) async {
    var cover = first;
    final writes = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        expect(request.url.path, '/api/v1/venues/services/activity/cover');
        expect(request.headers['Authorization'], 'Bearer session');
        cover = jsonDecode(request.body)['imageUrl'] as String;
        writes.add(cover);
        return http.Response('{"data":{}}', 200);
      }
      expect(request.method, 'GET');
      return details(cover);
    });
    await open(tester, client);
    expect(find.byKey(const ValueKey('activity-cover-$first')), findsOneWidget);
    await drag(tester, second, first);
    expect(find.byKey(const ValueKey('activity-cover-$second')), findsOneWidget);
    expect(writes, isEmpty);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(writes, [second]);
    expect(find.text('Update Images'), findsNothing);
    await tester.ensureVisible(find.text('Manage Images'));
    await tester.tap(find.text('Manage Images'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-cover-$second')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('activity-image-$second'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('activity-image-$first'))).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed cover save retains the selected image and can be retried', (tester) async {
    var attempts = 0;
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        expect(jsonDecode(request.body), {'imageUrl': second});
        return ++attempts == 1 ? http.Response('{}', 503) : http.Response('{"data":{}}', 200);
      }
      return details(first);
    });
    await open(tester, client);
    await drag(tester, second, first);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Update Images'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-cover-$second')), findsOneWidget);
    expect(find.text('Unable to save the cover photo. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Update Images'), findsNothing);
  });

  testWidgets('back discards a dragged cover without writing to the backend', (tester) async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return details(first);
    });
    await open(tester, client);
    await drag(tester, second, first);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Manage Images'));
    await tester.tap(find.text('Manage Images'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-cover-$first')), findsOneWidget);
  });

  testWidgets('dragging a lower photo auto-scrolls back to the first cover slot', (tester) async {
    final images = [first, second, third,
      for (var i = 3; i < 12; i++) 'https://images.test/photo-$i.jpg'];
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return details(first, images: images);
    });
    await open(tester, client);
    final source = find.byKey(ValueKey('activity-image-${images.last}'));
    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final before = scroll.position.pixels;
    expect(before, greaterThan(0));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(const Offset(200, 40));
    await tester.pump(const Duration(seconds: 5));
    expect(scroll.position.pixels, lessThan(before));
    final target = find.byKey(const ValueKey('activity-image-$first'));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('activity-cover-${images.last}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the pending cover removes it and retains a valid cover', (tester) async {
    var images = [first, second, third];
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        expect(jsonDecode(request.body), {'imageUrl': second});
        images.remove(second);
        return http.Response('{"data":{}}', 200);
      }
      expect(request.method, 'GET');
      return details(first, images: images);
    });
    await open(tester, client);
    await drag(tester, second, first);
    await tester.tap(find.byTooltip('Remove image').first);
    // The busy indicator keeps animating while confirmation is awaiting input.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-image-$second')), findsNothing);
    expect(find.byKey(const ValueKey('activity-cover-$first')), findsOneWidget);
    await tester.tap(find.text('Save Changes')); // Unchanged cover needs no PATCH.
    await tester.pumpAndSettle();
    expect(find.text('Update Images'), findsNothing);
  });
}
