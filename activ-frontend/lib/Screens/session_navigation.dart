import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Utills/browser_session.dart';
import '../Utills/session_photo_draft.dart';
import 'ActivityReviewScreen.dart';
import 'CategoryQuestionsScreen.dart';
import 'ContactSupportScreen.dart';
import 'CustomerPlacesOffer.dart';
import 'ForgotPasswordScreen.dart';
import 'GetStartedScreen.dart';
import 'Home/HomeScreen.dart';
import 'LegalInformationScreen.dart';
import 'ListActivityTypeScreen.dart';
import 'LoginScreen.dart';
import 'MobileNumberScreen.dart';
import 'OTPVerificationScreen.dart';
import 'ResetPasswordScreen.dart';
import 'ReviewSignAgreement.dart';
import 'ReviewVenueDetailsScreen.dart';
import 'TellUsAboutScreen.dart';
import 'VenuePhotoUploadScreen.dart';
import 'VenuePhotoListViewScreen.dart';
import 'VenueScreen.dart';
import 'VenueTimingScreen.dart';

/// Page checkpoints live only in this browser tab, just like its login token.
class SessionNavigation extends NavigatorObserver {
  static const storageKey = 'navigation_stack';
  static final instance = SessionNavigation();
  final List<Route<dynamic>> _routes = [];
  Map<String, dynamic>? _root;

  static Map<String, dynamic>? describe(Widget page) {
    if (page is GetStartedScreen) return {'page': 'welcome'};
    if (page is LoginScreen) return {'page': 'login'};
    if (page is MobileNumberScreen)
      return {'page': 'mobile', 'create': page.isCreatingAccount};
    if (page is OTPVerificationScreen)
      return {'page': 'otp', 'create': page.isCreatingAccount};
    if (page is ForgotPasswordScreen)
      return {'page': 'forgot', 'email': page.emailId};
    if (page is ResetPasswordScreen)
      return {'page': 'reset', 'email': page.emailId};
    if (page is TellUsAboutScreen)
      return {'page': 'partner', 'review': page.reviewMode};
    if (page is VenueScreen)
      return {'page': 'venue', 'review': page.reviewMode};
    if (page is CustomerPlacesOffer)
      return {'page': 'amenities', 'review': page.reviewMode};
    if (page is ListActivityTypeScreen)
      return {
        'page': 'sports',
        'review': page.reviewMode,
        'category': page.initialCategoryId
      };
    if (page is CategoryQuestionsScreen)
      return {
        'page': 'questions',
        'venueId': page.venueId,
        'current': page.currentCategory,
        'remaining': page.remainingCategories,
        'index': page.categoryIndex,
        'total': page.totalCategories,
        'timings': page.accumulatedTimings,
        'review': page.reviewMode,
      };
    if (page is VenueTimingScreen)
      return {
        'page': 'timings',
        'activityId': page.activityId,
        'category': page.categoryId,
        'title': page.categoryTitle,
        'remaining': page.remainingCategories,
        'index': page.categoryIndex,
        'total': page.totalCategories,
        'timings': page.accumulatedTimings,
      };
    if (page is VenuePhotoUploadScreen)
      return {
        'page': 'photos',
        'current': page.currentCategory,
        'remaining': page.remainingCategories,
        'index': page.categoryIndex,
        'total': page.totalCategories,
        'timings': page.accumulatedTimings,
        'replace': page.replaceOnlyCurrentCategory,
      };
    if (page is VenuePhotoListViewScreen)
      return {
        'page': 'photoReview',
        'current': page.currentCategory,
        'remaining': page.remainingCategories,
        'index': page.categoryIndex,
        'total': page.totalCategories,
        'timings': page.accumulatedTimings,
        'replace': page.replaceOnlyCurrentCategory,
      };
    if (page is ActivityReviewScreen)
      return {
        'page': 'activityReview',
        'activityId': page.activityId,
        'timingMap': page.venueTimingMap,
        'timings': page.categoryTimings,
        'index': page.initialActivityIndex,
      };
    if (page is LegalInformationScreen) return {'page': 'legal'};
    if (page is ReviewVenueDetailsScreen) return {'page': 'review'};
    if (page is ReviewSignAgreement) return {'page': 'agreement'};
    if (page is ContactSupportScreen) return {'page': 'submitted'};
    if (page is HomeScreen) return {'page': 'home'};
    return null;
  }

  static bool isPublic(Map<String, dynamic> data) =>
      {'welcome', 'login', 'mobile', 'otp', 'forgot', 'reset'}.contains(data['page']);

  static Widget? restore(Map<String, dynamic> data) {
    final current = Map<String, dynamic>.from(data['current'] ?? {});
    List<Map<String, dynamic>> list(String key) => (data[key] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final index = data['index'] as int? ?? 1;
    final total = data['total'] as int? ?? 1;
    final review = data['review'] == true;
    if (data['page'] == 'photoReview') {
      final draft = SessionPhotoDraft.read(current);
      if (draft == null) return restore({...data, 'page': 'photos'});
      return VenuePhotoListViewScreen(
        images: [
          for (var i = 0; i < draft.bytes.length; i++)
            XFile.fromData(draft.bytes[i],
                name: 'venue_photo_$i.jpg', mimeType: 'image/jpeg')
        ],
        imageBytes: draft.bytes,
        initialCoverIndex: draft.cover,
        currentCategory: current,
        remainingCategories: list('remaining'),
        categoryIndex: index,
        totalCategories: total,
        accumulatedTimings: list('timings'),
        replaceOnlyCurrentCategory: data['replace'] == true,
      );
    }
    return switch (data['page']) {
      'welcome' => const GetStartedScreen(),
      'login' => const LoginScreen(),
      'mobile' => MobileNumberScreen(isCreatingAccount: data['create'] == true),
      'otp' => OTPVerificationScreen(isCreatingAccount: data['create'] == true),
      'forgot' => ForgotPasswordScreen(emailId: data['email'] ?? ''),
      'reset' => ResetPasswordScreen(emailId: data['email'] ?? ''),
      'partner' => TellUsAboutScreen(reviewMode: review),
      'venue' => VenueScreen(reviewMode: review),
      'amenities' => CustomerPlacesOffer(reviewMode: review),
      'sports' => ListActivityTypeScreen(
          reviewMode: review, initialCategoryId: data['category']),
      'questions' => CategoryQuestionsScreen(
          venueId: data['venueId'],
          currentCategory: current,
          remainingCategories: list('remaining'),
          categoryIndex: index,
          totalCategories: total,
          accumulatedTimings: list('timings'),
          reviewMode: review),
      'timings' => VenueTimingScreen(
          activityId: data['activityId'],
          categoryId: data['category'] ?? '',
          categoryTitle: data['title'] ?? '',
          remainingCategories: list('remaining'),
          categoryIndex: index,
          totalCategories: total,
          accumulatedTimings: list('timings')),
      'photos' => VenuePhotoUploadScreen(
          currentCategory: current,
          remainingCategories: list('remaining'),
          categoryIndex: index,
          totalCategories: total,
          accumulatedTimings: list('timings'),
          replaceOnlyCurrentCategory: data['replace'] == true),
      'activityReview' => ActivityReviewScreen(
          activityId: data['activityId'],
          venueTimingMap: Map<String, dynamic>.from(data['timingMap'] ?? {}),
          categoryTimings: list('timings'),
          initialActivityIndex: data['index'] ?? 0),
      'legal' => const LegalInformationScreen(),
      'review' => const ReviewVenueDetailsScreen(),
      'agreement' => const ReviewSignAgreement(),
      'submitted' => const ContactSupportScreen(),
      'home' => HomeScreen(),
      _ => null,
    };
  }

  static List<Map<String, dynamic>> savedStack() {
    try {
      final raw = readBrowserSession(storageKey);
      if (raw == null) return [];
      final data = jsonDecode(raw) as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  void setRoot(Widget page) {
    if (!isBrowserSession) return;
    _root = describe(page);
    _save();
  }

  void _save() {
    if (!isBrowserSession || navigator == null) return;
    final stack = <Map<String, dynamic>>[if (_root != null) _root!];
    for (final route in _routes) {
      // Building the route widget does not mount its state or execute requests.
      final Widget? page = switch (route) {
        MaterialPageRoute r => r.builder(navigator!.context),
        PageRouteBuilder r => r.pageBuilder(
            navigator!.context,
            const AlwaysStoppedAnimation(1.0),
            const AlwaysStoppedAnimation(0.0)),
        _ => null,
      };
      final data = page == null ? null : describe(page);
      if (data == null) continue; // Dialogs do not change the current page.
      if (data['page'] == 'welcome' ||
          data['page'] == 'login' ||
          data['page'] == 'submitted' ||
          data['page'] == 'home') {
        stack.clear();
      }
      stack.add(data);
    }
    if (stack.isNotEmpty) writeBrowserSession(storageKey, jsonEncode(stack));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _save();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _save();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _save();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) _routes.removeAt(index);
    if (newRoute != null)
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
    _save();
  }
}
