import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/api_calling/progress_bar/progress_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'ForgotPasswordScreen.dart';
import 'Home/HomeScreen.dart';
import 'MobileNumberScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _loginScreenState();
}

class _loginScreenState extends State<LoginScreen> {

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    initLogin();
  }

  Future<void> initLogin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    CommonUtilities.showLog("UID: $uid");
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(height: 100, color: AppColors.yellowTop),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 100, color: AppColors.white),
          ),
          SafeArea(
            top: true,
            bottom: true,
            left: false,
            right: false,
            child: Scaffold(
              body: Container(
                decoration: context.getYellowGradient,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [

                          getActivIcon('assets/activ_tm.svg'),

                          Container(
                            margin: EdgeInsets.only(left: 15, right: 15),
                            child: getText('Login to your account'),
                          ),

                          getEmailLabel(),
                          getEmailField(context),

                          getPasswordLabel(),
                          getPasswordField(context),

                          getForgotPasswordRow(context),

                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: InkWell(
                              onTap: () {
                                if (validation(context)) {
                                  handleLogin();
                                }
                              },
                              child: getButtonBlack(context, "Login", "login"),
                            ),
                          ),

                          // "or" divider
                          Container(
                            alignment: Alignment.center,
                            margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                getHorizontalLine(),
                                getOrText(),
                                getHorizontalLine(),
                              ],
                            ),
                          ),

                          // Login using OTP button
                          InkWell(
                            onTap: () {
                              CommonUtilities.NavigateWithPush(context, MobileNumberScreen());
                            },
                            child: Container(
                              margin: EdgeInsets.only(top: 5),
                              child: getLoginWithOTP(context, 'Login using OTP', 'login'),
                            ),
                          ),

                          // New to ACTIV? Create Account
                          Container(
                            margin: EdgeInsets.only(top: 15, bottom: 10),
                            alignment: Alignment.center,
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'New to ACTIV? ',
                                    style: TextStyle(
                                      fontSize: AppSize.size_14,
                                      fontFamily: 'FontMedium',
                                      color: AppColors.darkBlack,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Create Account',
                                    style: TextStyle(
                                      fontSize: AppSize.size_14,
                                      fontFamily: 'FontMedium',
                                      color: AppColors.purple,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        CommonUtilities.NavigateWithPush(context, MobileNumberScreen());
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),

                    // Terms & Privacy Policy footer
                    Container(
                      margin: EdgeInsets.only(top: 10, bottom: 10, left: 10, right: 10),
                      child: getTermsConditionText(),
                    ),

                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget getEmailLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(15, 20, 0, 0),
          child: const Text(
            "Email Address or Phone Number",
            style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
              height: 1,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.red,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget getEmailField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 8, 15, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: TextFormField(
          controller: emailController,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
          cursorColor: AppColors.cursorBlack,
          style: TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'FontRegular',
            color: AppColors.darkBlack,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your email address.',
            hintStyle: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.hintColor,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget getPasswordLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(15, 20, 0, 0),
          child: const Text(
            "Password",
            style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
              height: 1,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.red,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget getPasswordField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 8, 15, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 5),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: passwordController,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.visiblePassword,
                obscureText: !isPasswordVisible,
                cursorColor: AppColors.cursorBlack,
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.darkBlack,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter Password',
                  hintStyle: TextStyle(
                    fontSize: AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.hintColor,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.darkGray,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  isPasswordVisible = !isPasswordVisible;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget getForgotPasswordRow(BuildContext context) {
    return InkWell(
      onTap: () {
        CommonUtilities.NavigateWithPush(
          context,
          ForgotPasswordScreen(emailId: emailController.text.trim()),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 10, 15, 0),
            child: const Text(
              "Forgot Password?",
              style: TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontMedium',
                color: AppColors.purple,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget getHorizontalLine() {
    return Container(
      color: AppColors.gray,
      height: 1,
      width: 145,
    );
  }

  Widget getOrText() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: Text(
        'or',
        style: TextStyle(
          color: AppColors.darkBlack,
          fontSize: AppSize.size_14,
          fontFamily: 'FontMedium',
        ),
      ),
    );
  }

  Widget getTermsConditionText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.black,
          fontFamily: 'FontMedium',
          fontSize: AppSize.size_14,
          height: 1.5,
        ),
        children: [
          const TextSpan(
            text: 'By clicking on Login, I accept the ',
            style: TextStyle(
              color: AppColors.black,
              fontFamily: 'FontMedium',
              fontSize: AppSize.size_14,
            ),
          ),
          TextSpan(
            text: 'Terms & Conditions',
            style: const TextStyle(
              color: AppColors.purple,
              fontFamily: 'FontMedium',
              fontSize: AppSize.size_14,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showLegalPopup('terms_and_conditions'),
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
              color: AppColors.purple,
              fontFamily: 'FontMedium',
              fontSize: AppSize.size_14,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showLegalPopup('privacy_policy'),
          ),
        ],
      ),
    );
  }

  void handleLogin() async {
    await SharedPreference.remove("jwt_token");
    await SharedPreference.remove("is_active");
    await SharedPreference.remove("user_type");
    await SharedPreference.remove("permissions");

    ProgressBar().showLoader(context);

    try {
      final response = await http.post(
        Uri.parse(PARTNER_LOGIN_URL),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      CommonUtilities.showLog("Partner Login status: ${response.statusCode}");
      CommonUtilities.showLog("Partner Login response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? {};
        final String token = _extractToken(body);

        // Detect login type: partner vs team member
        final bool isTeamMember = data['member'] != null;
        final bool isPartnerActive = data['partner']?['isActive'] == true;

        if (token.isEmpty) {
          CommonUtilities.showLog("Partner Login missing token. Response: ${response.body}");
          CommonUtilities.createSnackBar(
              context, 'Login succeeded, but token was missing. Please try again.');
          return;
        }

        await SharedPreference.addStringToSF("jwt_token", token);

        if (!mounted) return;

        if (isTeamMember) {
          final bool isMemberActive = data['member']?['isActive'] == true;
          final Map perms = data['member']?['permissions'] ?? {};
          await SharedPreference.addStringToSF("is_active", isMemberActive ? "true" : "false");
          await SharedPreference.addStringToSF("user_type", "team_member");
          await SharedPreference.addStringToSF("permissions", jsonEncode(perms));
          if (!mounted) return;
          if (isMemberActive) {
            CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, HomeScreen());
          } else {
            CommonUtilities.createSnackBar(context, 'Your account is not active yet. Please wait for approval.');
          }
        } else if (isPartnerActive) {
          await SharedPreference.addStringToSF("is_active", "true");
          await SharedPreference.addStringToSF("user_type", "partner");
          await SharedPreference.addStringToSF("permissions", "{}");
          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, HomeScreen());
        } else {
          await SharedPreference.addStringToSF("is_active", "false");
          CommonUtilities.createSnackBar(context, 'Your account is not active yet. Please wait for approval.');
        }
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Login failed. Please try again.';
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      CommonUtilities.showLog("Partner Login error: $e");
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }
  }

  String _extractToken(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final directToken = data['accessToken'] ??
          data['token'] ??
          data['access_token'] ??
          data['jwtToken'] ??
          data['jwt_token'];
      if (directToken != null && directToken.toString().isNotEmpty) {
        return directToken.toString();
      }

      final auth = data['auth'];
      if (auth is Map<String, dynamic>) {
        final authToken =
            auth['accessToken'] ?? auth['token'] ?? auth['access_token'];
        if (authToken != null && authToken.toString().isNotEmpty) {
          return authToken.toString();
        }
      }
    }

    final rootToken = body['accessToken'] ??
        body['token'] ??
        body['access_token'] ??
        body['jwtToken'] ??
        body['jwt_token'];
    return rootToken?.toString() ?? '';
  }

  Future<void> _showLegalPopup(String type) async {
    try {
      final response = await http.get(Uri.parse(LEGAL_URL));
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> list = jsonDecode(response.body) is List
            ? jsonDecode(response.body)
            : (jsonDecode(response.body)['data'] ?? []);

        Map<String, dynamic>? item;
        for (final entry in list) {
          if (entry is Map<String, dynamic> && entry['type'] == type) {
            item = entry;
            break;
          }
        }

        if (!mounted) return;

        final String title = item?['title']?.toString() ?? (type == 'terms_and_conditions' ? 'Terms & Conditions' : 'Privacy Policy');
        final String raw = item?['content']?.toString() ?? 'Content not available.';
        final String content = raw.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => Dialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row with close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: AppSize.size_18,
                          fontFamily: 'FontSemiBold',
                          color: AppColors.darkBlack,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppColors.darkBlack, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.gray),
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontRegular',
                        color: AppColors.darkBlack,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        CommonUtilities.createSnackBar(context, 'Failed to load content. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }
  }

  bool validation(BuildContext context) {
    final identifier = emailController.text.trim();
    final password = passwordController.text;
    final phoneDigits = identifier.replaceAll(RegExp(r'\D'), '');
    final isEmail = CommonUtilities.emailVaidatation(identifier);
    final isPhone = phoneDigits.length == 10 || phoneDigits.length == 12;

    if (identifier.isEmpty) {
      CommonUtilities.createSnackBar(context, 'Please enter email address or phone number.');
      return false;
    } else if (!isEmail && !isPhone) {
      CommonUtilities.createSnackBar(context, 'Please enter a valid email address or phone number.');
      return false;
    } else if (password.isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.passwordEnter);
      return false;
    }
    return true;
  }
}
