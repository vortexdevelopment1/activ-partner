import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'LoginScreen.dart';
import 'onboarding_widgets.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key, this.emailWarning});
  final String? emailWarning;

  @override
  State<ContactSupportScreen> createState() => _State();
}

class _State extends State<ContactSupportScreen> {
  String _venueId = '';
  String _venueName = '';
  String? _emailWarning;
  bool _retryingEmail = false;

  @override
  void initState() {
    super.initState();
    _emailWarning = widget.emailWarning;
    _loadVenueInfo();
  }

  Future<void> _retryAgreementEmail() async {
    if (_retryingEmail || _venueId.isEmpty) return;
    setState(() => _retryingEmail = true);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final response = await http.post(
        Uri.parse('$BASE_URL/venues/$_venueId/partner-agreement/email'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            'Unable to retry the agreement email. Please try again.');
      }
      final data = jsonDecode(response.body)['data'];
      if (data is Map && data['sent'] == true) {
        if (mounted) setState(() => _emailWarning = null);
      } else {
        throw Exception(data is Map && data['error'] != null
            ? data['error'].toString()
            : 'The agreement email was not sent. Please try again.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _retryingEmail = false);
    }
  }

  Future<void> _loadVenueInfo() async {
    final id = checkString(await SharedPreference.readStr("venue_id"));
    var name = checkString(await SharedPreference.readStr("venue_name"));
    if (name.isEmpty) {
      name = _venueNameFromDraft(
        checkString(await SharedPreference.readStr("venue_details")),
      );
    }
    if (mounted) {
      setState(() {
        _venueId = id;
        _venueName = name;
      });
    }
    if (name.isEmpty) await _loadVenueNameFromApi(id);
  }

  String _venueNameFromDraft(String value) {
    if (value.isEmpty) return '';
    try {
      final data = jsonDecode(value);
      if (data is Map) {
        return checkString(data['venue_name']?.toString());
      }
    } catch (_) {}
    return '';
  }

  Future<void> _loadVenueNameFromApi(String selectedId) async {
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      if (token.isEmpty) return;
      final response = await http.get(
        Uri.parse(MY_VENUES_URL),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 && response.statusCode != 201) return;
      final data = jsonDecode(response.body)['data'];
      final items = data is Map
          ? (data['items'] ?? data['venues'] ?? data['data'] ?? [])
          : [];
      if (items is! List || items.isEmpty) return;
      final venue = selectedId.isNotEmpty
          ? items.cast<dynamic>().firstWhere(
                (item) => item is Map && item['id']?.toString() == selectedId,
                orElse: () => items.first,
              )
          : items.first;
      if (venue is! Map) return;
      final name = checkString(venue['name']?.toString());
      if (name.isNotEmpty) {
        await SharedPreference.addStringToSF('venue_name', name);
        if (mounted) setState(() => _venueName = name);
      }
    } catch (e) {
      CommonUtilities.showLog('_loadVenueNameFromApi error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        children: [
          /*To Set Top Header Color*/
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 100,
              color: AppColors.yellowTop,
            ),
          ),
          /*To Set Bottom Header Color*/
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 100,
              color: AppColors.white,
            ),
          ),
          SafeArea(
            top: true,
            bottom: true,
            left: false,
            right: false,
            child: Scaffold(
              body: Container(
                decoration: context.getYellowGradient,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;

                    bool isMobile = width < 600;
                    bool isTablet = width >= 600 && width < 1100;

                    double containerWidth =
                        isMobile ? width * 1 : (isTablet ? 500 : 600);

                    return Container(
                      //width: containerWidth,
                      //margin: const EdgeInsets.only(right: 20),
                      //padding: EdgeInsets.all(isMobile ? 20 : 30),
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const OnboardingHeader(),
                            Expanded(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (_emailWarning != null)
                                              _emailFailureNotice(),
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(top: 8),
                                              width: 224,
                                              height: 300,
                                              child: Image.asset(
                                                  'assets/reviewing.png'),
                                            ),
                                            getText(),
                                            getSubText(_venueName, _venueId),
                                            const SizedBox(height: 16),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              child: Column(
                                children: [
                                  bottomBarShadow(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: InkWell(
                                      onTap: () async {
                                        await CommonUtilities
                                            .updateSharedPreference();
                                        CommonUtilities.firstTimeLoginSignup =
                                            '';
                                        if (!context.mounted) return;
                                        CommonUtilities
                                            .NavigateWithPushAndKillAllPriviousScreens(
                                                context, const LoginScreen());
                                      },
                                      child: getButtonBlack(context,
                                          "Back to Login", "contactSupport"),
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _emailFailureNotice() => Container(
        margin: const EdgeInsets.fromLTRB(10, 15, 10, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF2B56B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registration succeeded',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 6),
            Text(_emailWarning!,
                style: const TextStyle(fontSize: 14, height: 1.35)),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _retryingEmail ? null : _retryAgreementEmail,
              icon: _retryingEmail
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.email_outlined),
              label: Text(_retryingEmail ? 'Retrying…' : 'Retry email'),
            ),
          ],
        ),
      );

  Widget getDividerLine() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 15, 0, 15),
      color: AppColors.gray,
      height: 1,
    );
  }

  Widget getText() {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      alignment: Alignment.center,
      child: const Text(
        "🎉 You’re all set, we’re reviewing your venue!",
        style: TextStyle(
          fontSize: AppSize.size_28,
          fontFamily: 'Satoshi',
          color: AppColors.darkBlack,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget getSubText(String venueName, String venueId) {
    final venueLabel = venueName.isNotEmpty
        ? '#$venueName'
        : (venueId.isNotEmpty ? '#$venueId' : 'your venue');
    return Container(
        alignment: Alignment.center,
        margin: EdgeInsets.fromLTRB(0, 15, 0, 10),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
                color: AppColors.darkBlack, // different color
                fontFamily: 'Satoshi',
                fontSize: AppSize.size_16,
                fontWeight: FontWeight.w600,
                height: 1.4),
            children: [
              TextSpan(text: "Your venue registration "),
              TextSpan(
                text: venueLabel,
                style: TextStyle(
                  color: AppColors.black, // different color
                  fontFamily: 'Satoshi',
                  fontSize: AppSize.size_16,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
              TextSpan(
                text:
                    " is complete and under review. Come back in sometime to see your venue live and start receiving bookings from customers.",
                style: TextStyle(
                    color: AppColors.darkBlack, // different color
                    fontFamily: 'Satoshi',
                    fontSize: AppSize.size_16,
                    fontWeight: FontWeight.w600,
                    height: 1.4),
              ),
            ],
          ),
        ));
  }
}
