import 'dart:async';

import 'package:activ_app/Screens/AuthWrapper.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 1600);
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Timer _minimumSplashTimer;
  bool _minimumSplashElapsed = false;
  bool _authResolved = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _splashDuration,
    )..forward();
    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _minimumSplashTimer = Timer(_splashDuration, () {
      _minimumSplashElapsed = true;
      _revealDestinationIfReady();
    });
  }

  void _onAuthResolved() {
    _authResolved = true;
    _revealDestinationIfReady();
  }

  void _revealDestinationIfReady() {
    if (!mounted || !_minimumSplashElapsed || !_authResolved) return;
    setState(() => _showSplash = false);
  }

  @override
  void dispose() {
    _minimumSplashTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AuthWrapper(client: widget.client, onResolved: _onAuthResolved),
        if (_showSplash)
          Positioned.fill(
            key: const ValueKey('startup-splash-overlay'),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: AppColors.yellowBottom,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
              child: Scaffold(
                body: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.yellowTop,
                        AppColors.yellowBottom,
                      ],
                    ),
                  ),
                  child: Center(
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/logo.png',
                        width: MediaQuery.of(context).size.width * 0.45,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
