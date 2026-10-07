import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:activ_app/Screens/ContactSupportFormScreen.dart';
import 'package:activ_app/Screens/ActivityReviewScreen.dart';
import 'package:activ_app/Screens/LegalInformationScreen.dart';
import 'package:activ_app/Screens/VenuePhotoListViewScreen.dart';
import 'package:activ_app/Screens/CategoryQuestionsScreen.dart';
import 'package:activ_app/Screens/CommonCode.dart';
import 'package:activ_app/Screens/ForgotPasswordScreen.dart';
import 'package:activ_app/Screens/GetStartedScreen.dart';
import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:activ_app/Screens/MobileNumberScreen.dart';
import 'package:activ_app/Screens/Menu/MenuScreen.dart';
import 'package:activ_app/Screens/Home/VenueInfoScreen.dart';
import 'package:activ_app/Screens/onboarding_widgets.dart';
import 'package:activ_app/Screens/OTPVerificationScreen.dart';
import 'package:activ_app/Screens/ReviewVenueDetailsScreen.dart';
import 'package:activ_app/Screens/ReviewSignAgreement.dart';
import 'package:activ_app/Screens/TellUsAboutScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Routes extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundaryKey = GlobalKey();

  setUpAll(() async {
    for (final entry in {
      'OnboardingRegular': 'fonts/Metropolis-Regular.ttf',
      'OnboardingMedium': 'fonts/Metropolis-Medium.otf',
      'OnboardingSemibold': 'fonts/Metropolis-SemiBold.otf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'FontRegular': 'fonts/Acumin-RPro.otf',
      'FontMedium': 'fonts/AcuminPro-Medium.otf',
      'FontSemiBold': 'fonts/AcuminPro-Semibold.otf',
      'packages/font_awesome_flutter/FontAwesomeBrands':
          'packages/font_awesome_flutter/lib/fonts/fa-brands-400.ttf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
          .load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'phoneCode': '+91',
      'userMobileNumber': '987-654-4567',
    });
  });

  Future<void> showScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(430, 932),
    double textScale = 1,
    double keyboardHeight = 0,
    _Routes? routes,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      navigatorObservers: [if (routes != null) routes],
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
        ),
        child: RepaintBoundary(key: boundaryKey, child: child!),
      ),
      home: screen,
    ));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/logo.png'),
          tester.element(find.byType(RepaintBoundary).first));
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    debugDisableShadows = false;
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(boundary);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/onboarding-previews');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    debugDisableShadows = true;
  }

  Future<void> fillLogin(WidgetTester tester) async {
    await tester.enterText(
        find.byKey(const Key('login-identifier')), 'partner@example.com');
    await tester.enterText(
        find.byKey(const Key('login-password')), 'secret123');
  }

  Finder digit(int index) => find.byKey(Key('otp-digit-$index'));

  final liveVenue = {
    'id': 'venue-1',
    'name': 'Sports Arena Complex',
    'description': 'Premium multi-sports facility with professional coaching.',
    'locationUrl': 'https://maps.app.goo.gl/B9zJmCugWfHug5a36',
    'flatBuilding': '202, 2nd floor',
    'venuePhone': '+919876543210',
    'city': 'Indore',
    'state': 'Madhya Pradesh',
    'zipCode': '452010',
  };
  final pendingUpdate = {
    'id': 'request-1',
    'venueId': 'venue-1',
    'status': 'pending',
    'createdAt': '2026-10-06T10:30:00Z',
    'requestedChanges': {
      'name': 'Updated Sports Arena',
      'description': 'Updated professional coaching facilities'
    },
  };

  void seedVenueInfo({bool teamMember = false}) =>
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'token',
        'venue_id': 'venue-1',
        'user_type': teamMember ? 'team_member' : 'partner',
      });

  http.Client updateClient(
          {List<Map<String, dynamic>> requests = const [],
          Future<http.Response> Function(http.Request)? submit}) =>
      MockClient((request) async {
        if (request.method == 'POST') {
          return submit?.call(request) ?? http.Response('{}', 500);
        }
        return http.Response(
            jsonEncode({
              'data': request.url.path.contains('update-requests/my')
                  ? requests
                  : [liveVenue]
            }),
            200);
      });

  Finder venueField(String key) => find.byKey(Key('venue-update-$key'));

  testWidgets(
      'venue update matches editable reference and starts from saved values',
      (tester) async {
    seedVenueInfo();
    await showScreen(tester, VenueInfoScreen(client: updateClient()),
        size: const Size(430, 1276));
    expect(find.text('Update Venue Details'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(8));
    expect(tester.widget<TextFormField>(venueField('name')).controller?.text,
        'Sports Arena Complex');
    expect(
        tester.widget<TextFormField>(venueField('venuePhone')).controller?.text,
        '+919876543210');
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: venueField('description'),
                matching: find.byType(TextField)))
            .maxLength,
        200);
    expect(tester.widget<TextFormField>(venueField('name')).enabled, isTrue);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, 'venue-update-editable-430x1276');
  });

  testWidgets(
      'venue submission locks fields, prevents duplicate requests and restores pending state',
      (tester) async {
    seedVenueInfo();
    var posts = 0;
    final response = Completer<http.Response>();
    final client = updateClient(submit: (request) {
      posts++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['name'], 'Updated Sports Arena');
      expect(body['venuePhone'], '+919876543210');
      expect(request.url.path.endsWith('/venue-1/update-request'), isTrue);
      return response.future;
    });
    await showScreen(tester, VenueInfoScreen(client: client));
    await tester.enterText(venueField('name'), 'Updated Sports Arena');
    await tester.tap(find.text('Submit for Review'));
    await tester.pump();
    await tester.tap(find.byType(OnboardingButton));
    await tester.pump();
    expect(posts, 1);
    response.complete(http.Response(jsonEncode({'data': pendingUpdate}), 201));
    await tester.pumpAndSettle();
    expect(find.text('Status: Under Review'), findsOneWidget);
    expect(find.text('Under Review'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(8));
    expect(tester.widget<TextFormField>(venueField('name')).enabled, isFalse);
    expect(liveVenue['name'], 'Sports Arena Complex');
    await showScreen(tester,
        VenueInfoScreen(client: updateClient(requests: [pendingUpdate])),
        size: const Size(430, 1562));
    expect(tester.widget<TextFormField>(venueField('name')).controller?.text,
        'Updated Sports Arena');
    expect(
        tester
            .widget<TextFormField>(venueField('description'))
            .controller
            ?.text,
        'Updated professional coaching facilities');
    expect(find.text('Submitted on'), findsOneWidget);
    expect(find.text('Review ETA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'venue-update-pending-430x1562');
  });

  testWidgets(
      'venue updates validate hidden fields and keep drafts after server failures',
      (tester) async {
    seedVenueInfo();
    var posts = 0;
    await showScreen(tester,
        VenueInfoScreen(client: updateClient(submit: (_) async {
      posts++;
      return http.Response('{"message":"Internal server error"}', 500);
    })));
    await tester.enterText(venueField('name'), 'Changed Arena');
    await tester.ensureVisible(venueField('locationUrl'));
    await tester.enterText(venueField('locationUrl'), 'not a map link');
    await tester.tap(find.text('Submit for Review'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid Google Maps link.'), findsOneWidget);
    expect(posts, 0);
    await tester.enterText(
        venueField('locationUrl'), liveVenue['locationUrl']!);
    await tester.ensureVisible(venueField('venuePhone'));
    await tester.enterText(venueField('venuePhone'), 'Vijay Nagar');
    await tester.tap(find.text('Submit for Review'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    expect(find.text('Enter a valid phone number.'), findsOneWidget);
    await tester.enterText(venueField('venuePhone'), '+919876543210');
    await tester.tap(find.text('Submit for Review'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('Could not submit changes. Please try again.'),
        findsOneWidget);
    expect(tester.widget<TextFormField>(venueField('name')).controller?.text,
        'Changed Arena');
    expect(tester.widget<TextFormField>(venueField('name')).enabled, isTrue);
  });

  testWidgets(
      'rejected updates can be corrected and team members remain read only',
      (tester) async {
    seedVenueInfo();
    await showScreen(
        tester,
        VenueInfoScreen(
            client: updateClient(requests: [
          {
            ...pendingUpdate,
            'status': 'rejected',
            'adminNotes': 'Please correct the location'
          },
        ])));
    expect(find.text('Please correct the location'), findsOneWidget);
    expect(tester.widget<TextFormField>(venueField('name')).enabled, isTrue);
    seedVenueInfo(teamMember: true);
    var statusCalls = 0;
    await showScreen(tester,
        VenueInfoScreen(client: MockClient((request) async {
      if (request.url.path.contains('update-requests')) statusCalls++;
      return http.Response(
          jsonEncode({
            'data': [liveVenue]
          }),
          200);
    })));
    expect(statusCalls, 0);
    expect(tester.widget<TextFormField>(venueField('name')).enabled, isFalse);
    expect(find.text('View Only'), findsOneWidget);
  });

  testWidgets(
      'unchanged venues do not submit and approved requests unlock live details',
      (tester) async {
    seedVenueInfo();
    var posts = 0;
    await showScreen(
        tester,
        VenueInfoScreen(
            client: updateClient(
                requests: [
              {...pendingUpdate, 'status': 'approved'}
            ],
                submit: (_) async {
                  posts++;
                  return http.Response('{}', 500);
                })));
    expect(tester.widget<TextFormField>(venueField('name')).enabled, isTrue);
    expect(tester.widget<TextFormField>(venueField('name')).controller?.text,
        liveVenue['name']);
    await tester.tap(find.text('Submit for Review'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    expect(find.text('Make a change before submitting for review.'),
        findsOneWidget);
  });

  testWidgets('conflicting submissions restore the persisted pending request',
      (tester) async {
    seedVenueInfo();
    var submitted = false;
    await showScreen(tester,
        VenueInfoScreen(client: MockClient((request) async {
      if (request.method == 'POST') {
        submitted = true;
        return http.Response('{"message":"Already pending"}', 409);
      }
      return http.Response(
          jsonEncode({
            'data': request.url.path.contains('update-requests/my')
                ? (submitted ? [pendingUpdate] : [])
                : [liveVenue]
          }),
          200);
    })));
    await tester.enterText(venueField('name'), 'Another draft');
    await tester.tap(find.text('Submit for Review'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Under Review'), findsOneWidget);
    expect(tester.widget<TextFormField>(venueField('name')).enabled, isFalse);
    expect(tester.widget<TextFormField>(venueField('name')).controller?.text,
        'Updated Sports Arena');
  });

  testWidgets('failed review status lookup requires retry before editing',
      (tester) async {
    seedVenueInfo();
    var failStatus = true;
    await showScreen(tester,
        VenueInfoScreen(client: MockClient((request) async {
      if (request.url.path.contains('update-requests/my')) {
        return failStatus
            ? http.Response('{}', 500)
            : http.Response('{"data":[]}', 200);
      }
      return http.Response(
          jsonEncode({
            'data': [liveVenue]
          }),
          200);
    })));
    expect(find.text('Could not load the review status. Please try again.'),
        findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    failStatus = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(venueField('name')).enabled, isTrue);
  });

  testWidgets(
      'venue update layouts fit smaller phones, keyboard and enlarged text',
      (tester) async {
    seedVenueInfo();
    for (final size in [
      const Size(320, 640),
      const Size(430, 932),
      const Size(800, 932)
    ]) {
      await showScreen(tester,
          VenueInfoScreen(client: updateClient(requests: [pendingUpdate])),
          size: size,
          textScale: 1.5,
          keyboardHeight: size.width == 320 ? 200 : 0);
      await tester.ensureVisible(find.text('Review ETA'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(
          tester, 'venue-update-pending-${size.width.toInt()}-large-text');
    }
  });

  testWidgets(
      'partner menu uses personal photo or person icon, never application logo',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'jwt_token': 'token', 'user_type': 'partner'});
    for (final photo in ['', 'https://example.com/partner-photo.png']) {
      await showScreen(
          tester,
          MenuScreen(
              client: MockClient((_) async => http.Response(
                  jsonEncode({
                    'data': {
                      'partner': {
                        'firstName': 'Virat',
                        'lastName': 'Kohli',
                        'businessName': 'Company',
                        'email': 'partner@example.com',
                        'avatarUrl': photo,
                        'logoUrl': 'https://example.com/company-logo.png'
                      }
                    },
                  }),
                  200))));
      expect(find.text('Virat Kohli'), findsOneWidget);
      expect(find.text('Company'), findsNothing);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/logo.png'),
          findsNothing);
      if (photo.isEmpty) {
        expect(find.byIcon(Icons.person_outline_rounded), findsNWidgets(2));
      } else {
        expect(
            find.byWidgetPredicate((widget) =>
                widget is Image &&
                widget.image is NetworkImage &&
                (widget.image as NetworkImage).url == photo),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'venue information opens from partner menu and shows approved data',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'jwt_token': 'token', 'user_type': 'partner'});
    final client = MockClient((request) async {
      if (request.url.path.contains('my-approved-venues')) {
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'venue',
                  'name': 'Sports Arena',
                  'status': 'approved',
                  'bookingAccept': true,
                  'amenities': ['WiFi'],
                  'categories': [
                    {'id': 'badminton', 'name': 'Badminton'}
                  ]
                },
              ]
            }),
            200);
      }
      if (request.url.path.contains('update-requests/my'))
        return http.Response('{"data":[]}', 200);
      return http.Response(
          jsonEncode({
            'data': {
              'partner': {'firstName': 'Partner'}
            }
          }),
          200);
    });
    await showScreen(tester, MenuScreen(client: client));
    await tester.tap(find.text('Venue Information'));
    await tester.pumpAndSettle();
    expect(find.byType(VenueInfoScreen), findsOneWidget);
    expect(find.text('Sports Arena'), findsOneWidget);
    expect(find.text('No venue data found.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'venue information handles server errors with retry and true empty state',
      (tester) async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'token'});
    var calls = 0;
    await showScreen(tester, VenueInfoScreen(client: MockClient((_) async {
      calls++;
      return calls == 1
          ? http.Response('{"message":"Internal server error"}', 500)
          : http.Response('{"data":[]}', 200);
    })));
    expect(find.text('Could not load venue details. Please try again.'),
        findsOneWidget);
    expect(find.text('No venue data found.'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No venue data found.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  void seedVenueReview({String? commission}) {
    SharedPreferences.setMockInitialValues({
      'is_profile_complete': 'true',
      'owner_full_name': 'Virat Kohli',
      'owner_email': 'virat.kohli@gmail.com',
      'owner_mobile_number': '98-0123-4567',
      'userMobileNumber': '98-0123-4567',
      'phoneCode': '+91',
      'same_as_owner_number_checked': 'false',
      'same_as_owner_number': '98-7654-3210',
      'jwt_token': 'test-token',
      'venue_id': 'venue-1',
      if (commission != null) 'venue_commission': commission,
      'venue_details': jsonEncode({
        'venue_name': 'Sports Arena Complex',
        'venue_description':
            'Premium multi-sports facility with state-of-the-art equipment and professional coaching.',
        'venue_address': '202, 2nd floor, Vijay Nagar',
        'venue_city': 'Indore',
        'venue_state': 'Madhya Pradesh',
        'venue_pin_code': '900000',
        'venue_latitude': '22.75',
        'venue_longitude': '75.89',
      }),
      'place_offer': jsonEncode({
        'place_offer': [
          for (final title in [
            'Free Parking',
            'WiFi',
            'Locker Room',
            'Personal Training',
            'Proper Lighting',
            'Sound System',
            'Shower Room'
          ])
            {'id': title, 'title': title},
        ]
      }),
      'operate_value': jsonEncode([
        {
          'id': 'badminton',
          'title': 'Badminton',
          'description': 'Indoor shuttle play arena'
        },
        {
          'id': 'tennis',
          'title': 'Tennis',
          'description': 'Outdoor or indoor court space'
        },
        {
          'id': 'cricket',
          'title': 'Box Cricket',
          'description': 'Enclosed mini cricket arena'
        },
      ]),
    });
  }

  Widget testVenueReview(http.Client client) => ReviewVenueDetailsScreen(
      client: client,
      mapBuilder: (position) => ColoredBox(
          color: const Color(0xFFE7EEF0),
          child: Center(
              child: Text(
                  'Venue location: ${position.latitude}, ${position.longitude}'))));

  testWidgets(
      'venue review always shows partner and distinct venue contact details',
      (tester) async {
    seedVenueReview();
    await showScreen(
        tester,
        testVenueReview(MockClient((_) async => http.Response(
            jsonEncode({
              'data': {'commissionPercentage': 12}
            }),
            200))),
        size: const Size(430, 2342));
    await tester.runAsync(() async {
      for (final asset in ['assets/ic_cock.png', 'assets/ic_other.png']) {
        await precacheImage(AssetImage(asset),
            tester.element(find.byType(ReviewVenueDetailsScreen)));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Venue Partner Details'), findsOneWidget);
    expect(find.text('Virat Kohli'), findsOneWidget);
    expect(find.text('virat.kohli@gmail.com'), findsOneWidget);
    expect(find.text('+91 98-0123-4567'), findsOneWidget);
    expect(find.text('+91 98-7654-3210'), findsOneWidget);
    expect(find.text('Sports Arena Complex'), findsOneWidget);
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('Free Parking'), findsOneWidget);
    expect(find.text('Badminton'), findsOneWidget);
    expect(find.text('Tennis'), findsOneWidget);
    expect(find.text('Box Cricket'), findsOneWidget);
    expect(find.text('7/7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'venue-review-430x2342');
    await tester.tap(find.text('Learn more about how commissions work'));
    await tester.pumpAndSettle();
    expect(find.text('Commission Structure'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewSignAgreement), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'partner edit is prefilled and returned changes are saved to venue',
      (tester) async {
    seedVenueReview();
    Map<String, dynamic>? update;
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        update = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      return http.Response(
          jsonEncode({
            'data': {'commissionPercentage': 12}
          }),
          200);
    });
    await showScreen(tester, testVenueReview(client));
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.byType(TellUsAboutScreen), findsOneWidget);
    final values = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();
    expect(values, contains('Virat'));
    expect(values, contains('Kohli'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_full_name', 'Updated Partner');
    tester.state<NavigatorState>(find.byType(Navigator)).pop(true);
    await tester.pumpAndSettle();
    expect(find.text('Updated Partner'), findsOneWidget);
    expect(update?['venuePhone'], '9876543210');
    expect(update?['name'], 'Sports Arena Complex');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'commission request failure does not invent a rate and supports retry',
      (tester) async {
    seedVenueReview();
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return calls == 1
          ? http.Response('{}', 500)
          : http.Response(
              jsonEncode({
                'data': {'commissionPercentage': 12}
              }),
              200);
    });
    await showScreen(tester, testVenueReview(client),
        size: const Size(430, 2342));
    expect(find.text('10%'), findsNothing);
    expect(find.text('Unable to refresh the rate.'), findsOneWidget);
    await tester.tap(find.text('Unable to refresh the rate.'));
    await tester.pumpAndSettle();
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('venue review fits small and wide layouts with large text',
      (tester) async {
    seedVenueReview(commission: '12');
    for (final size in [
      const Size(320, 640),
      const Size(430, 932),
      const Size(800, 932)
    ]) {
      await showScreen(tester,
          testVenueReview(MockClient((_) async => http.Response('{}', 500))),
          size: size, textScale: 1.5);
      await tester.scrollUntilVisible(find.text('Box Cricket'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await capture(tester, 'venue-review-${size.width.toInt()}-large-text');
    }
  });

  testWidgets('activity edit restores answers and preserves other activities',
      (tester) async {
    seedVenueReview();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'activity_questions_display',
        jsonEncode([
          {
            'categoryId': 'badminton',
            'categoryTitle': 'Badminton',
            'questionId': 'description',
            'questionText': 'Activity Description',
            'answer': 'Existing badminton description'
          },
          {
            'categoryId': 'badminton',
            'categoryTitle': 'Badminton',
            'questionId': 'environment',
            'questionText': 'Playing Environment',
            'answer': ['Indoor']
          },
          {
            'categoryId': 'tennis',
            'categoryTitle': 'Tennis',
            'questionId': 'tennis-description',
            'questionText': 'Activity Description',
            'answer': 'Existing tennis description'
          },
        ]));
    final client = MockClient((request) async {
      if (request.method == 'POST') return http.Response('{}', 200);
      if (request.url.path.contains('commission')) {
        return http.Response(
            jsonEncode({
              'data': {'commissionPercentage': 12}
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'description',
                'questionText': 'Activity Description',
                'questionType': 'textarea',
                'isRequired': true,
                'isActive': true
              },
              {
                'id': 'environment',
                'questionText': 'Playing Environment',
                'questionType': 'checkbox',
                'options': ['Indoor', 'Outdoor'],
                'isActive': true
              },
            ]
          }),
          200);
    });
    await showScreen(tester, testVenueReview(client),
        size: const Size(430, 2342));
    final row = find
        .ancestor(of: find.text('Badminton'), matching: find.byType(Row))
        .first;
    await tester
        .tap(find.descendant(of: row, matching: find.byType(TextButton)));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryQuestionsScreen), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'Existing badminton description');
    expect(
        tester.widgetList<Checkbox>(find.byType(Checkbox)).first.value, isTrue);
    await tester.enterText(
        find.byType(TextField).first, 'Updated badminton description');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewVenueDetailsScreen), findsOneWidget);
    expect(find.text('Updated badminton description'), findsOneWidget);
    expect(find.text('Existing tennis description'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Get Started logo stays small across viewport widths',
      (tester) async {
    for (final width in [320.0, 430.0, 800.0]) {
      await showScreen(tester, const GetStartedScreen(),
          size: Size(width, 932));
      final logo = find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/logo.png');
      expect(tester.getSize(logo), const Size(105, 60));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('step five reviews each activity with saved photos and timings',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'activity_questions_display': jsonEncode([
        {
          'categoryTitle': 'Badminton',
          'questionText': 'Total Courts',
          'answer': '6'
        },
        {
          'categoryTitle': 'Badminton',
          'questionText': 'Flooring Type',
          'answer': 'Synthetic'
        },
        {
          'categoryTitle': 'Badminton',
          'questionText': 'Maximum Capacity',
          'answer': '24'
        },
        {
          'categoryTitle': 'Badminton',
          'questionText': 'Activity Description',
          'answer': 'A premium facility with professional coaching.'
        },
        {
          'categoryTitle': 'Squash',
          'questionText': 'Total Courts',
          'answer': '2'
        },
      ]),
    });
    final photo =
        (await rootBundle.load('assets/ic_pool.png')).buffer.asUint8List();
    VenuePhotoListViewScreen.cachedImagesByCategory['badminton'] =
        List.filled(5, photo);
    addTearDown(VenuePhotoListViewScreen.cachedImagesByCategory.clear);
    final screen = ActivityReviewScreen(activityId: 'venue', categoryTimings: [
      {
        'id': 'badminton',
        'title': 'Badminton',
        'timing': {
          'Monday': [
            {'open': '09:00 AM', 'close': '07:00 PM', 'capacity': '4'}
          ],
          'Tuesday': [
            {'open': '06:00 AM', 'close': '12:00 PM', 'capacity': '4'},
            {'open': '04:00 PM', 'close': '10:00 PM', 'capacity': '4'},
          ],
          'Saturday': [
            {'open': '-', 'close': '-'}
          ],
        }
      },
      {'id': 'squash', 'title': 'Squash', 'timing': <String, dynamic>{}},
    ]);
    await showScreen(tester, screen, size: const Size(430, 2490));
    await tester.runAsync(() async {
      await precacheImage(MemoryImage(photo),
          tester.element(find.byType(ActivityReviewScreen)));
    });
    await tester.pumpAndSettle();
    expect(find.text('5/7'), findsOneWidget);
    expect(find.text('Configuring Activity 1 of 2 \u2014 Step 4/4'),
        findsOneWidget);
    expect(find.text('Badminton'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Number of Courts'), findsOneWidget);
    expect(find.text('Synthetic'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Operational Details'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('06:00 AM'), findsOneWidget);
    expect(find.text('04:00 PM'), findsOneWidget);
    expect(find.text('4'), findsNWidgets(3));
    expect(find.text('Edit'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await capture(tester, 'activity-review-430x2490');
    await tester.tap(find.text('Configure Next Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Squash'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('No photos uploaded.'), findsOneWidget);
    expect(find.text('Synthetic'), findsNothing);
    expect(find.text('Operational timings have not been added yet.'),
        findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Badminton'), findsOneWidget);
    await tester.tap(find.text('Configure Next Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalInformationScreen), findsOneWidget);
  });

  testWidgets('activity review fits small and wide layouts with enlarged text',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'activity_questions_display': jsonEncode([
        {
          'categoryTitle': 'Badminton',
          'questionText': 'Total Courts',
          'answer': '6'
        },
      ]),
    });
    const screen = ActivityReviewScreen(activityId: 'venue', categoryTimings: [
      {
        'id': 'a',
        'title': 'Badminton',
        'timing': {
          'Monday': [
            {'open': '09:00 AM', 'close': '07:00 PM'}
          ],
        }
      },
      {'id': 'b', 'title': 'Squash', 'timing': <String, dynamic>{}},
    ]);
    for (final size in [
      const Size(320, 640),
      const Size(430, 932),
      const Size(800, 932)
    ]) {
      await showScreen(tester, screen, size: size, textScale: 1.5);
      await tester.scrollUntilVisible(find.text('Capacity'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await capture(tester, 'activity-review-${size.width.toInt()}-large-text');
    }
  });

  testWidgets('invalid review draft still shows skipped activity',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'activity_questions_display': '{broken'});
    await showScreen(
        tester,
        const ActivityReviewScreen(activityId: 'venue', categoryTimings: [
          {'id': 'a', 'title': 'Badminton', 'timing': <String, dynamic>{}},
        ]));
    expect(find.text('Badminton'), findsOneWidget);
    expect(find.text('No details available.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review edit links return to the selected activity screens',
      (tester) async {
    const steps = [
      'upload1',
      'photos1',
      'questions1',
      'timings1',
      'upload2',
      'photos2',
      'questions2',
      'timings2'
    ];
    const review = ActivityReviewScreen(activityId: 'venue', categoryTimings: [
      {'id': 'a', 'title': 'Badminton', 'timing': <String, dynamic>{}},
      {'id': 'b', 'title': 'Squash', 'timing': <String, dynamic>{}},
    ]);
    for (final section in [
      'Photos',
      'Activity Specific Details',
      'Operational Details'
    ]) {
      await showScreen(tester, const Scaffold(body: Text('upload1')));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      for (final step in steps.skip(1)) {
        navigator.push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: Text(step))));
        await tester.pumpAndSettle();
      }
      navigator.push(MaterialPageRoute<void>(builder: (_) => review));
      await tester.pumpAndSettle();
      final header = find
          .ancestor(of: find.text(section), matching: find.byType(Row))
          .first;
      final edit =
          find.descendant(of: header, matching: find.byType(TextButton));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final expected = section == 'Photos'
          ? 'photos1'
          : section == 'Activity Specific Details'
              ? 'questions1'
              : 'timings1';
      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reference layouts render with empty fields and masked phone',
      (tester) async {
    await showScreen(tester, const LoginScreen());
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('login-password')))
            .initialValue,
        isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue);
    await capture(tester, 'login-430x932');
    await showScreen(tester, const OTPVerificationScreen());
    expect(find.text('We sent a code to +91-xx-xxxx-4567'), findsOneWidget);
    expect(find.text('Edit Number'), findsNothing);
    for (var i = 0; i < 4; i++) {
      expect(tester.getSize(digit(i)), const Size(44, 44));
      expect(tester.widget<TextField>(digit(i)).controller!.text, isEmpty);
    }
    expect(tester.getTopLeft(find.byKey(const Key('otp-submit'))).dy,
        closeTo(856, 1));
    await capture(tester, 'otp-430x932');
  });

  testWidgets('mobile screen matches reference and only enables valid numbers',
      (tester) async {
    await showScreen(tester, const MobileNumberScreen());
    expect(find.text('IND (+91)'), findsOneWidget);
    expect(find.text('Already have an account? '), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    final button = find.descendant(
        of: find.byKey(const Key('mobile-submit')),
        matching: find.byType(TextButton));
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    expect(tester.getTopLeft(find.byKey(const Key('mobile-submit'))).dy,
        closeTo(856, 1));
    await capture(tester, 'mobile-430x932');
    await tester.enterText(find.byKey(const Key('mobile-number')), 'abc123');
    await tester.pump();
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    await tester.enterText(
        find.byKey(const Key('mobile-number')), '9876544567');
    await tester.pump();
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
  });

  testWidgets('mobile OTP request preserves payload, number and destination',
      (tester) async {
    await showScreen(tester,
        MobileNumberScreen(client: MockClient((request) async {
      expect(jsonDecode(request.body), {'phone': '9876544567'});
      return http.Response('{}', 200);
    })));
    await tester.enterText(
        find.byKey(const Key('mobile-number')), '9876544567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(OTPVerificationScreen), findsOneWidget);
    expect(find.text('We sent a code to +91-xx-xxxx-4567'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance()).getString('userMobileNumber'),
        '98-7654-4567');
  });

  testWidgets('mobile request prevents repeats and keeps screen on failure',
      (tester) async {
    var calls = 0;
    final response = Completer<http.Response>();
    await showScreen(tester, MobileNumberScreen(client: MockClient((_) {
      calls++;
      return response.future;
    })));
    await tester.enterText(
        find.byKey(const Key('mobile-number')), '9876544567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-submit')));
    expect(calls, 1);
    response.complete(http.Response('{"message":"Please try again"}', 400));
    await tester.pumpAndSettle();
    expect(find.byType(MobileNumberScreen), findsOneWidget);
    expect(find.text('Please try again'), findsOneWidget);
    await showScreen(
        tester,
        MobileNumberScreen(
            client: MockClient(
                (_) async => throw const SocketException('offline'))));
    await tester.enterText(
        find.byKey(const Key('mobile-number')), '9876544567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(MobileNumberScreen), findsOneWidget);
    expect(find.text('Network error. Please check your connection.'),
        findsOneWidget);
  });

  testWidgets(
      'mobile login link returns to existing login and support opens form',
      (tester) async {
    await showScreen(tester, const LoginScreen());
    await tester.tap(find.text('Login using OTP'));
    await tester.pumpAndSettle();
    expect(find.byType(MobileNumberScreen), findsOneWidget);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    final routes = _Routes();
    await showScreen(tester, const MobileNumberScreen(), routes: routes);
    await tester.tap(find.byKey(const Key('mobile-support')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat with support'));
    final route = routes.pushed.last as PageRouteBuilder;
    expect(
        route.pageBuilder(tester.element(find.byType(MobileNumberScreen)),
            const AlwaysStoppedAnimation(1), const AlwaysStoppedAnimation(1)),
        isA<ContactSupportFormScreen>());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('support panel toggles, preserves phone and closes outside',
      (tester) async {
    await showScreen(tester, const MobileNumberScreen());
    await tester.enterText(
        find.byKey(const Key('mobile-number')), '9801234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-support')));
    await tester.pumpAndSettle();
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Chat with support'), findsOneWidget);
    expect(find.text('Call support'), findsOneWidget);
    expect(find.text('FAQs'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await capture(tester, 'mobile-support-open-430x932');
    await tester.tap(find.byKey(const Key('mobile-support')));
    await tester.pumpAndSettle();
    expect(find.text('Help & Support'), findsNothing);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('mobile-number')))
            .controller!
            .text,
        '98-0123-4567');
    await tester.tap(find.byKey(const Key('mobile-support')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter your mobile number'));
    await tester.pumpAndSettle();
    expect(find.text('Help & Support'), findsNothing);
    await showScreen(tester, const LoginScreen());
    await tester.tap(find.byKey(const Key('login-support')));
    await tester.pumpAndSettle();
    expect(find.text('Help & Support'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Help & Support'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('FAQ panel fetches public questions and supports retry',
      (tester) async {
    var calls = 0;
    await showScreen(tester,
        MobileNumberScreen(client: MockClient((request) async {
      expect(request.url.path, endsWith('/faqs/public'));
      calls++;
      if (calls == 1) return http.Response('{}', 500);
      return http.Response(
          jsonEncode({
            'data': [
              {
                'question': 'How can I register?',
                'answer': 'Enter your mobile number.'
              },
            ]
          }),
          200);
    })));
    await tester.tap(find.byKey(const Key('mobile-support')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FAQs'));
    await tester.pumpAndSettle();
    expect(find.text('Retry loading FAQs'), findsOneWidget);
    await tester.tap(find.text('Retry loading FAQs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How can I register?'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your mobile number.'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('activity questions hide Court Surface and show third sub-step',
      (tester) async {
    Map<String, dynamic>? submitted;
    final routes = _Routes();
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'description',
                  'questionText': 'Activity Description',
                  'questionType': 'textarea',
                  'isRequired': true
                },
                {
                  'id': 'surface',
                  'questionText': 'Court Surface',
                  'questionType': 'select',
                  'isRequired': true,
                  'options': []
                },
                {
                  'id': 'court-type',
                  'questionText': 'Court Type',
                  'questionType': 'select',
                  'isRequired': false,
                  'options': ['Standard', 'Premium']
                },
              ]
            }),
            200);
      }
      submitted = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });
    await showScreen(
        tester,
        CategoryQuestionsScreen(
          venueId: 'venue-id',
          currentCategory: const {'id': 'squash', 'title': 'Squash'},
          categoryIndex: 2,
          totalCategories: 3,
          client: client,
        ),
        routes: routes);
    expect(find.text('Court Surface'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('4/7'), findsOneWidget);
    expect(find.text('Configuring Activity 2 of 3 \u2014 Step 3/4'),
        findsOneWidget);
    await capture(tester, 'activity-questions-step3-430x932');
    await tester.enterText(
        find.byType(TextFormField), 'A spacious squash court.');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    final answers = submitted!['answers'] as List<dynamic>;
    expect(answers.any((item) => item['questionId'] == 'surface'), isFalse);
    expect(answers.any((item) => item['questionId'] == 'description'), isTrue);
  });

  testWidgets('activity sub-step labels include single and multiple activities',
      (tester) async {
    for (var step = 1; step <= 4; step++) {
      await showScreen(
          tester, Scaffold(body: getActivityStepLabel(1, 1, step)));
      expect(find.text('Configuring Activity 1 of 1 \u2014 Step $step/4'),
          findsOneWidget);
    }
  });

  testWidgets('small, wide, keyboard and enlarged-text layouts do not overflow',
      (tester) async {
    for (final size in [
      const Size(237, 512),
      const Size(320, 568),
      const Size(800, 1000),
    ]) {
      for (final screen in [
        const LoginScreen(),
        const OTPVerificationScreen(),
        const MobileNumberScreen(),
      ]) {
        await showScreen(tester, screen, size: size);
        expect(tester.takeException(), isNull);
        await capture(
            tester,
            '${screen is LoginScreen ? 'login' : screen is MobileNumberScreen ? 'mobile' : 'otp'}-${size.width.toInt()}x${size.height.toInt()}');
      }
    }
    for (final screen in [
      const LoginScreen(),
      const OTPVerificationScreen(),
      const MobileNumberScreen()
    ]) {
      await showScreen(tester, screen,
          size: const Size(320, 568), textScale: 1.5, keyboardHeight: 240);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(screen is LoginScreen
          ? find.byKey(const Key('login-password'))
          : screen is MobileNumberScreen
              ? find.byKey(const Key('mobile-number'))
              : digit(3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(
          tester,
          '${screen is LoginScreen ? 'login' : screen is MobileNumberScreen ? 'mobile' : 'otp'}-keyboard-large-text');
    }
  });

  testWidgets('OTP accepts digits, advances, pastes and deletes backwards',
      (tester) async {
    await showScreen(tester, const OTPVerificationScreen());
    await tester.enterText(digit(0), 'a1');
    await tester.pump();
    expect(tester.widget<TextField>(digit(0)).controller!.text, '1');
    expect(tester.widget<TextField>(digit(1)).focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(tester.widget<TextField>(digit(0)).controller!.text, isEmpty);
    expect(tester.widget<TextField>(digit(0)).focusNode!.hasFocus, isTrue);
    await tester.enterText(digit(2), '0512');
    await tester.pump();
    expect(
        List.generate(
            4, (i) => tester.widget<TextField>(digit(i)).controller!.text),
        ['0', '5', '1', '2']);
    await tester.enterText(digit(3), '');
    await tester.pump();
    expect(tester.widget<TextField>(digit(2)).focusNode!.hasFocus, isTrue);
  });

  testWidgets('incomplete OTP does not call verification API', (tester) async {
    var calls = 0;
    await showScreen(tester,
        OTPVerificationScreen(client: MockClient((_) async {
      calls++;
      return http.Response('{}', 400);
    })));
    await tester.tap(find.byKey(const Key('otp-submit')));
    await tester.pump();
    expect(calls, 0);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('OTP errors preserve screen and requests cannot repeat',
      (tester) async {
    var calls = 0;
    final response = Completer<http.Response>();
    await showScreen(tester,
        OTPVerificationScreen(client: MockClient((request) {
      calls++;
      expect(jsonDecode(request.body), {'phone': '9876544567', 'otp': '1234'});
      return response.future;
    })));
    await tester.enterText(digit(0), '1234');
    await tester.tap(find.byKey(const Key('otp-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('otp-submit')));
    expect(calls, 1);
    response.complete(http.Response('{"message":"Invalid code"}', 400));
    await tester.pumpAndSettle();
    expect(find.text('Invalid code'), findsOneWidget);
    expect(find.byType(OTPVerificationScreen), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets('network errors do not pop login or verification',
      (tester) async {
    final client =
        MockClient((_) async => throw const SocketException('offline'));
    await showScreen(tester, LoginScreen(client: client));
    await fillLogin(tester);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Network error. Please check your connection.'),
        findsOneWidget);
    await showScreen(tester, OTPVerificationScreen(client: client));
    await tester.enterText(digit(0), '1234');
    await tester.tap(find.byKey(const Key('otp-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(OTPVerificationScreen), findsOneWidget);
    expect(find.text('Network error. Please check your connection.'),
        findsOneWidget);
  });

  testWidgets('successful OTP stores token and opens profile onboarding',
      (tester) async {
    await showScreen(
        tester,
        OTPVerificationScreen(
            client: MockClient((_) async => http.Response(
                jsonEncode({
                  'data': {
                    'accessToken': 'test-token',
                    'isProfileComplete': false,
                    'partner': {'isActive': false},
                  }
                }),
                200))));
    await tester.enterText(digit(0), '1234');
    await tester.tap(find.byKey(const Key('otp-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(TellUsAboutScreen), findsOneWidget);
    expect(find.text('1/7'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(1 / 7, 0.0001));
    expect((await SharedPreferences.getInstance()).getString('jwt_token'),
        'test-token');
  });

  testWidgets('login validates and sends existing payload once',
      (tester) async {
    var calls = 0;
    final response = Completer<http.Response>();
    await showScreen(tester, LoginScreen(client: MockClient((request) {
      calls++;
      expect(jsonDecode(request.body),
          {'email': 'partner@example.com', 'password': 'secret123'});
      return response.future;
    })));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(calls, 0);
    await fillLogin(tester);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-submit')));
    expect(calls, 1);
    response.complete(http.Response('{"message":"Wrong password"}', 401));
    await tester.pumpAndSettle();
    expect(find.text('Wrong password'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('login navigation links keep their destinations', (tester) async {
    for (final entry in {
      'Login using OTP': MobileNumberScreen,
      'Create Account': MobileNumberScreen,
      'Forgot Password?': ForgotPasswordScreen,
    }.entries) {
      final routes = _Routes();
      await showScreen(tester, const LoginScreen(), routes: routes);
      await tester.tap(find.text(entry.key));
      final route = routes.pushed.last as PageRouteBuilder;
      final destination = route.pageBuilder(
          tester.element(find.byType(LoginScreen)),
          const AlwaysStoppedAnimation(1),
          const AlwaysStoppedAnimation(1));
      expect(destination.runtimeType, entry.value);
      await tester.pumpWidget(const SizedBox());
    }
    final routes = _Routes();
    await showScreen(tester, const LoginScreen(), routes: routes);
    await tester.tap(find.byKey(const Key('login-support')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat with support'));
    final route = routes.pushed.last as PageRouteBuilder;
    expect(
        route.pageBuilder(tester.element(find.byType(LoginScreen)),
            const AlwaysStoppedAnimation(1), const AlwaysStoppedAnimation(1)),
        isA<ContactSupportFormScreen>());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('legal links fetch and open their matching dialogs',
      (tester) async {
    await showScreen(
        tester,
        LoginScreen(
            client: MockClient((_) async => http.Response(
                jsonEncode({
                  'data': [
                    {
                      'type': 'terms_and_conditions',
                      'title': 'Terms & Conditions',
                      'content': 'Test terms content'
                    },
                    {
                      'type': 'privacy_policy',
                      'title': 'Privacy Policy',
                      'content': 'Test privacy content'
                    },
                  ]
                }),
                200))));
    final footer = tester.widget<Text>(find.byWidgetPredicate((widget) =>
        widget is Text &&
        widget.textSpan != null &&
        widget.textSpan!.toPlainText().startsWith('By clicking on Login')));
    final spans = (footer.textSpan! as TextSpan).children!;
    for (final index in [1, 3]) {
      final recognizer = (spans[index] as TextSpan).recognizer;
      (recognizer as dynamic).onTap();
      await tester.pumpAndSettle();
      expect(
          find.text(index == 1 ? 'Test terms content' : 'Test privacy content'),
          findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
  });
}
