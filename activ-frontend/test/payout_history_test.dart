import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:activ_app/Screens/Home/PayoutHistoryScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Satoshi': 'fonts/Satoshi-Medium.otf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf'
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
          .load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({'jwt_token': 'token'}));
  final range =
      DateTimeRange(start: DateTime(2026, 9, 10), end: DateTime(2026, 10, 10));
  final record = {
    'reference': 'ACTIV-PAYOUT-1',
    'amount': 125.5,
    'status': 'success',
    'payoutDate': '2026-10-10T09:00:00Z',
    'bankName': 'Test Bank',
    'accountLast4': '7890'
  };
  http.Response history(List<Map<String, dynamic>> items, {int pages = 1}) =>
      http.Response(
          jsonEncode({
            'data': {'items': items, 'totalPages': pages}
          }),
          200);

  Future<void> show(WidgetTester tester, Widget screen,
      {Size size = const Size(360, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/payout-history-screenshots')
        ..createSync(recursive: true);
      File('${dir.path}/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('reference empty layout and authenticated status filtering',
      (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer token');
      expect(request.url.queryParameters['startDate'], '2026-09-10');
      expect(request.url.queryParameters['endDate'], '2026-10-10');
      return history([]);
    });
    final key = GlobalKey();
    await show(
        tester,
        RepaintBoundary(
            key: key,
            child: PayoutHistoryScreen(client: client, initialRange: range)));
    expect(find.text('No payout records found'), findsOneWidget);
    await capture(tester, key, 'empty');
    for (final entry in {
      'Successful': 'success',
      'Pending': 'pending',
      'Failed': 'failed',
      'All': 'all'
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['status'], entry.value);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('database records show masked accounts and load the next page',
      (tester) async {
    final client = MockClient((request) async => history([
          {
            ...record,
            'reference': 'ACTIV-PAYOUT-${request.url.queryParameters['page']}'
          }
        ], pages: 2));
    await show(
        tester, PayoutHistoryScreen(client: client, initialRange: range));
    expect(find.text('ACTIV-PAYOUT-1'), findsOneWidget);
    expect(find.text('Test Bank | XXXX 7890'), findsOneWidget);
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();
    expect(find.text('ACTIV-PAYOUT-2'), findsOneWidget);
    expect(find.text('Load More'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('range Save reloads and cancellation preserves filters',
      (tester) async {
    var requests = 0;
    await show(
        tester,
        PayoutHistoryScreen(
            initialRange: range,
            client: MockClient((_) async {
              requests++;
              return history([]);
            })));
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Select range'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(requests, 2);
  });

  testWidgets('PDF and CSV downloads keep selected range and status',
      (tester) async {
    final exports = <String>[];
    final saved = <String>[];
    final client = MockClient((request) async {
      if (!request.url.path.endsWith('/download')) return history([]);
      expect(request.url.queryParameters['status'], 'pending');
      expect(request.url.queryParameters['startDate'], '2026-09-10');
      expect(request.headers['Authorization'], 'Bearer token');
      final format = request.url.queryParameters['format']!;
      exports.add(format);
      return http.Response(
          jsonEncode({
            'data': {
              'filename': 'payouts.$format',
              'base64': base64Encode(utf8.encode('report-$format'))
            }
          }),
          200);
    });
    await show(
        tester,
        PayoutHistoryScreen(
            client: client,
            initialRange: range,
            saveReport: (name, bytes) async {
              saved.add(name);
              expect(utf8.decode(bytes), 'report-${exports.last}');
              return true;
            }));
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Export report'));
    await tester.pumpAndSettle();
    expect(find.text('Export Report'), findsOneWidget);
    await tester.tap(find.text('Download Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download Report'));
    await tester.pumpAndSettle();
    expect(exports, ['pdf', 'csv']);
    expect(saved, ['payouts.pdf', 'payouts.csv']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server failure shows Retry and never claims an empty database',
      (tester) async {
    var fail = true;
    await show(
        tester,
        PayoutHistoryScreen(
            initialRange: range,
            client: MockClient((_) async =>
                fail ? http.Response('{}', 500) : history([record]))));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No payout records found'), findsNothing);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('ACTIV-PAYOUT-1'), findsOneWidget);
  });

  testWidgets('history and export fit narrow mobile and desktop viewports',
      (tester) async {
    final client = MockClient((_) async => history([]));
    for (final size in [const Size(320, 720), const Size(900, 900)]) {
      for (final export in [false, true]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final key = GlobalKey();
        await show(
            tester,
            RepaintBoundary(
                key: key,
                child: export
                    ? ExportPayoutReportScreen(
                        client: client, initialRange: range)
                    : PayoutHistoryScreen(client: client, initialRange: range)),
            size: size);
        expect(tester.takeException(), isNull);
        await capture(tester, key,
            '${export ? 'export' : 'history'}-${size.width.toInt()}');
      }
    }
  });
}
