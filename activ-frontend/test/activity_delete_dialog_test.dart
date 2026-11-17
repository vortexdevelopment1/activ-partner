import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:activ_app/Beans/activity_model.dart';
import 'package:activ_app/Screens/Home/Activities/ActivityManagementScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final boundaryKey = GlobalKey();
  var deletes = 0;
  setUpAll(() async {
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() {
    deletes = 0;
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
  });

  Future<void> open(WidgetTester tester,
      {bool failDelete = false,
      Size size = const Size(430, 932),
      double textScale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer session');
      if (request.method == 'DELETE') {
        deletes++;
        return http.Response(
            failDelete
                ? '{"message":"Unable to delete activity"}'
                : '{"data":{}}',
            failDelete ? 500 : 200);
      }
      return http.Response(
          jsonEncode({
            'data': {
              'id': 'activity',
              'name': 'Badminton',
              'status': 'approved',
              'isActive': false,
              'bookingAccept': false,
            }
          }),
          200);
    });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: RepaintBoundary(key: boundaryKey, child: child!),
      ),
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                        builder: (_) => ActivityManagementScreen(
                              activity: ActivityModel.fromJson({
                                'activity_id': 'activity',
                                'operate_value': {'title': 'Badminton'}
                              }),
                              venueId: 'venue',
                              client: client,
                            ))),
                child: const Text('Open activity'),
              ))),
    ));
    await tester.tap(find.text('Open activity'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Delete Activity'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Delete Activity'));
    await tester.pumpAndSettle();
  }

  Finder button(String text) => find.descendant(
      of: find.byType(Dialog), matching: find.widgetWithText(TextButton, text));

  testWidgets('reference popup has concise text and Cancel never deletes',
      (tester) async {
    await open(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
        find.text(
            'Are you sure you want to delete your activity? This action cannot be undone.'),
        findsOneWidget);
    expect(find.text('Delete Activity?'), findsNothing);
    final cancel = tester.widget<TextButton>(button('Cancel'));
    expect(cancel.style!.backgroundColor!.resolve({}), const Color(0xFFFDF6DE));
    final confirm = tester.widget<TextButton>(button('Delete Activity'));
    expect(confirm.style!.backgroundColor!.resolve({}), Colors.black);
    expect(
        confirm.style!.foregroundColor!.resolve({}), const Color(0xFFDAFF50));
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/ui-previews');
      await directory.create(recursive: true);
      await File('${directory.path}/activity-delete-dialog.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(button('Cancel'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(ActivityManagementScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirm deletes once and returns after server success',
      (tester) async {
    await open(tester);
    await tester.tap(button('Delete Activity'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.byType(ActivityManagementScreen), findsNothing);
    expect(find.text('Open activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed deletion keeps the activity screen open', (tester) async {
    await open(tester, failDelete: true);
    await tester.tap(button('Delete Activity'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.byType(ActivityManagementScreen), findsOneWidget);
    expect(find.text('Unable to delete activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup fits a narrow screen with larger text', (tester) async {
    await open(tester, size: const Size(320, 568), textScale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(button('Cancel'));
    await tester.tap(button('Cancel'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    expect(tester.takeException(), isNull);
  });
}
