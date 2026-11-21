
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:no_context_navigation/no_context_navigation.dart';
import 'package:overlay_support/overlay_support.dart';

import 'Screens/splash_screen.dart';
import 'Screens/session_navigation.dart';
import 'Screens/team_session_guard.dart';
import 'Style/app_colors.dart';
import 'api_calling/api_constant.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeApiBaseUrl();

  if (Platform.isIOS) {
    // iOS Firebase configuration:
    // activ-48bbb / com.activ.partnerapp
    // Reads GoogleService-Info.plist from the app bundle.
    await Firebase.initializeApp();
  } else if (Platform.isAndroid) {
    // Preserve the existing Android Firebase configuration.
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyB11VLcJv6FF7iiBH6vJ2hr5_n246Dn6G8",
        appId: "1:626237685353:android:34ebb1a94cb97f274decf8",
        messagingSenderId: "626237685353",
        projectId: "activ-b02f8",
        storageBucket: "activ-b02f8.firebasestorage.app",
      ),
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return OverlaySupport(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,

          scrollBehavior: const MaterialScrollBehavior()
              .copyWith(scrollbars: false),

          theme: ThemeData(
            primarySwatch: Colors.orange,
            fontFamily: 'Satoshi',
          ),

          navigatorKey: NavigationService.navigationKey,

          builder: (context, child) => TeamSessionGuard(
            navigatorKey: NavigationService.navigationKey,
            child: child ?? const SizedBox.shrink(),
          ),

          navigatorObservers: [
            SessionNavigation.instance,
          ],

          home: const SplashScreen(),
        ),
      ),
    );
  }
}
