// ignore_for_file: unused_import
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'ContactSupportScreen.dart';
import 'GetStartedScreen.dart';
import 'Home/HomeScreen.dart' show HomeScreen;
import 'TellUsAboutScreen.dart';
import 'VenueScreen.dart';

/*
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;

        //if (user == null || user.isAnonymous) {
        if (user == null) {
          return GetStartedScreen();
        }

        // User exists (anonymous or logged-in) → Home
        return HomeScreen();
      },
    );
  }
}
*/


/*
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        // ❌ Not logged in
        if (user == null) {
          return GetStartedScreen();
        }

        // ✅ Logged in → now check Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection("activ_user")
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {

            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // No Firestore data → treat as new
              return GetStartedScreen();
            }

            final basicDetails =
            userSnapshot.data!["basic_details"] as Map<String, dynamic>?;

            final bool isProfileCompleted =
                basicDetails?["is_profile_completed"] == true;

            if (isProfileCompleted) {
              return HomeScreen();
            } else {
              return GetStartedScreen(); // or Profile screen
            }
          },
        );
      },
    );
  }
}
*/

/*
class AuthWrapper — old Firestore/phone-based check (replaced by JWT check below)
class _AuthWrapperState — reads userMobileNumber from SharedPrefs,
  queries Firestore users_by_phone → activ_user for is_profile_completed.
  No longer used because login is now email+password with JWT token.
*/

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLoading = true;
  Widget _destination = GetStartedScreen();

  @override
  void initState() {
    super.initState();
    _initAuthCheck();
  }

  Future<void> _initAuthCheck() async {
    try {
      final token = await SharedPreference.readStr("jwt_token");
      final hasToken = token != null && token.isNotEmpty;

      if (!hasToken) {
        _finish(GetStartedScreen());
        return;
      }

      // Check user type saved at login
      final userType = await SharedPreference.readStr("user_type") ?? "";

      // Team members: just validate token is still alive, then go to HomeScreen
      if (userType == "team_member") {
        final response = await http.get(
          Uri.parse(AUTH_PROFILE_URL),
          headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
        );
        CommonUtilities.showLog("AuthWrapper team-member status: ${response.statusCode}");
        if (response.statusCode == 200 || response.statusCode == 201) {
          _finish(HomeScreen());
        } else {
          await SharedPreference.clearSF();
          _finish(GetStartedScreen());
        }
        return;
      }

      // Partner flow — always fetch fresh state from server
      final response = await http.get(
        Uri.parse(AUTH_PROFILE_URL),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );

      CommonUtilities.showLog("AuthWrapper auth-profile status: ${response.statusCode}");
      CommonUtilities.showLog("AuthWrapper auth-profile response: ${response.body}");

      if (response.statusCode != 200 && response.statusCode != 201) {
        await SharedPreference.clearSF();
        _finish(GetStartedScreen());
        return;
      }

      final body = jsonDecode(response.body);
      final bool apiIsProfileComplete = body['data']?['isProfileComplete'] == true;
      final bool apiIsActive = body['data']?['partner']?['isActive'] == true;

      // Update local values with fresh API data
      await SharedPreference.addStringToSF("is_profile_complete", apiIsProfileComplete ? "true" : "false");
      await SharedPreference.addStringToSF("is_active", apiIsActive ? "true" : "false");

      if (!apiIsProfileComplete) {
        _finish(TellUsAboutScreen());
        return;
      }

      if (apiIsActive) {
        _finish(HomeScreen());
        return;
      }

      // Profile complete, not yet active — check venue status
      await _checkVenueStatus(token);
    } catch (e) {
      CommonUtilities.showLog("AuthWrapper init error: $e");
      _finish(GetStartedScreen());
    }
  }

  Future<void> _checkVenueStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse(MY_VENUES_URL),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );

      CommonUtilities.showLog("AuthWrapper my-venues status: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        final int total = (data?['total'] as num?)?.toInt() ?? 0;
        final List items = (data?['items'] ?? data?['venues'] ?? data?['data'] ?? []) as List;
        final String firstStatus = items.isNotEmpty
            ? (items.first['status']?.toString() ?? '')
            : '';
        final String firstVenueId = items.isNotEmpty
            ? (items.first['id']?.toString() ?? '')
            : '';

        if (total == 1 && firstStatus == 'pending') {
          if (firstVenueId.isNotEmpty) {
            await SharedPreference.addStringToSF("venue_id", firstVenueId);
          }
          _finish(const ContactSupportScreen());
        } else if (total == 1 && firstStatus == 'draft') {
          _finish(VenueScreen());
        } else if (total == 0) {
          // Profile complete but no venue yet — continue onboarding
          _finish(VenueScreen());
        } else {
          _finish(GetStartedScreen());
        }
      } else {
        // Token likely expired or server error — go to login
        _finish(GetStartedScreen());
      }
    } catch (e) {
      CommonUtilities.showLog("AuthWrapper venue check error: $e");
      _finish(GetStartedScreen());
    }
  }

  void _finish(Widget destination) {
    if (mounted) {
      setState(() {
        _destination = destination;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _destination;
  }
}
