import 'dart:async';
import 'dart:convert';
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:http/http.dart' as http;
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'LoginScreen.dart';
import 'MobileNumberFormatter.dart';
import 'VenueScreen.dart';
import 'onboarding_widgets.dart';
import '../Utills/browser_session.dart';

class TellUsAboutScreen extends StatefulWidget {
  const TellUsAboutScreen({super.key, this.reviewMode = false});
  final bool reviewMode;

  @override
  State<TellUsAboutScreen> createState() => _State();
}

class _State extends State<TellUsAboutScreen> {

  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController mobileNumberController = TextEditingController();
  TextEditingController venueOwnerMobileNumberController = TextEditingController();
  bool isButtonEnabled = false;
  bool isChecked = true;
  String phoneCode = "", userMobileNumber = "", jwtToken = "";

  int currentStep = 3;
  final int totalSteps = 10;

  void nextStep() {
    if (currentStep < totalSteps) {
      setState(() {
        currentStep++;
      });
    }
  }

  void prevStep() {
    if (currentStep > 1) {
      setState(() {
        currentStep--;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getData().whenComplete(() {
      if (!mounted || !isBrowserSession || widget.reviewMode) return;
      for (final controller in [firstNameController, lastNameController,
        emailController, venueOwnerMobileNumberController]) {
        controller.addListener(_saveSessionDraft);
      }
    });
  }

  void _saveSessionDraft() {
    if (!isBrowserSession || widget.reviewMode) return;
    writeBrowserSession('owner_full_name', '${firstNameController.text.trim()} ${lastNameController.text.trim()}'.trim());
    writeBrowserSession('owner_email', emailController.text.trim());
    writeBrowserSession('same_as_owner_number_checked', isChecked ? 'true' : 'false');
    writeBrowserSession('same_as_owner_number', isChecked ? 'true' : venueOwnerMobileNumberController.text.trim());
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
    jwtToken = checkString(await SharedPreference.readStr("jwt_token"));

    final fullName = checkString(await SharedPreference.readStr('owner_full_name'));
    final email = checkString(await SharedPreference.readStr('owner_email'));
    final sameNumber = await SharedPreference.readStr('same_as_owner_number_checked');
    final contactNumber = checkString(await SharedPreference.readStr('same_as_owner_number'));
    if (!mounted) return;
    mobileNumberController.text = userMobileNumber;
    final nameParts = fullName.trim().split(RegExp(r'\s+'));
    firstNameController.text = nameParts.first;
    lastNameController.text = nameParts.skip(1).join(' ');
    emailController.text = email;
    isChecked = sameNumber == 'true';
    if (!isChecked) {
      venueOwnerMobileNumberController.text = contactNumber;
    }
    isButtonEnabled = firstNameController.text.isNotEmpty && lastNameController.text.isNotEmpty && emailController.text.isNotEmpty;

    setState(() {});
  }

  void completeProfile() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final contactPhone = isChecked
        ? userMobileNumber.replaceAll('-', '')
        : venueOwnerMobileNumberController.text.trim().replaceAll('-', '');

    // Save locally as before
    await SharedPreference.addStringToSF("owner_full_name", "$firstName $lastName".trim());
    await SharedPreference.addStringToSF("owner_email", email);
    await SharedPreference.addStringToSF("owner_mobile_number", userMobileNumber);
    await SharedPreference.addStringToSF(
      "same_as_owner_number_checked", isChecked ? "true" : "false");
    await SharedPreference.addStringToSF(
      "same_as_owner_number",
      isChecked ? "true" : venueOwnerMobileNumberController.text.trim());

    if (!mounted) return;
    final payload = {
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      "businessName": "",
      "contactPhone": contactPhone,
    };

    // The form data is already persisted locally. Move to the next step
    // immediately and sync the profile without blocking the onboarding UI.
    if (!widget.reviewMode) {
      CommonUtilities.NavigateWithPush(context, VenueScreen());
      unawaited(_persistProfile(payload));
      return;
    }

    await _persistProfile(payload);
  }

  Future<void> _persistProfile(Map<String, dynamic> payload) async {
    try {
      final jwtToken = checkString(await SharedPreference.readStr("jwt_token"));
      if (jwtToken.isEmpty) {
        throw Exception(
            'Session expired. Please verify your phone number again.');
      }
      final response = await http.patch(
        Uri.parse(COMPLETE_PROFILE_URL),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(payload),
      );

      CommonUtilities.showLog("Complete Profile status: ${response.statusCode}");
      CommonUtilities.showLog("Complete Profile response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await SharedPreference.addStringToSF("is_profile_complete", "true");
        if (mounted && widget.reviewMode) Navigator.pop(context, true);
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Failed to save profile. Please try again.';
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          CommonUtilities.createSnackBar(context, msg);
        }
      }
    } catch (e) {
      CommonUtilities.showLog("Complete Profile error: $e");
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        CommonUtilities.createSnackBar(
            context, 'Network error. Please check your connection.');
      }
    }
  }

  void _validateNumber(String input) {
    String digits = input.replaceAll('-', '');
    if (digits.length == 10) {
      setState(() {
        isButtonEnabled = true;
      });
    } else {
      setState(() {
        isButtonEnabled = false;
      });
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    mobileNumberController.dispose();
    venueOwnerMobileNumberController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (widget.reviewMode) {
      Navigator.maybePop(context);
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    double progress = currentStep / totalSteps;

    return PopScope(
      canPop: widget.reviewMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !widget.reviewMode) _goBack();
      },
      child: OnboardingScaffold(
        child: LayoutBuilder(builder: (context, constraints) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    getStepBar(progress),
                    getText(),
                    getSubText(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    getNameFields(context),
                    getEmailLabel(),
                    getEmailField(context),
                    getPhoneNumberText(),
                    getMobileNumberField(context),
                    getPhoneVerifiedText(),
                    const SizedBox(height: 4),
                    getPrimaryContactNumberText(),
                    getPrimaryContactNumberSubText(),
                    getOwnerPhoneNumberText(),
                    getOwnerMobileNumberField(context),
                    getCheckBoxSamesOwner(),
                    const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.gray)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Row(children: [
                  Expanded(flex: 3, child: OnboardingButton(
                    label: 'Back', outlined: true, borderRadius: 12,
                    onPressed: _goBack,
                  )),
                  const SizedBox(width: 16),
                  Expanded(flex: 7, child: OnboardingButton(
                  label: 'Next',
                  borderRadius: 12,
                  onPressed: () {
                    if (validation(context)) completeProfile();
                  },
                )),
                ]),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget getStepBar(double progress)
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }


  Widget getText()
  {
    return Container(
      margin: const EdgeInsets.only(top: 25),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Tell us about you, partner!",
        style: TextStyle(
            fontSize: AppSize.size_25,
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlack,
            height: 1.2
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getSubText()
  {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: const Text(
        "We will use these details for all business communications & updates",
        style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'Satoshi',
            color: AppColors.black1,
            height: 1.4
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _nameField(TextEditingController controller, String label, String hint, TextInputAction action) {
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
            child: Row(
              children: [
                Text(label, style: const TextStyle(fontSize: AppSize.size_14, fontFamily: 'Satoshi', color: AppColors.black1, height: 1)),
                const Text("*", style: TextStyle(fontSize: AppSize.size_14, fontFamily: 'Satoshi', color: AppColors.red, height: 1)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextFormField(
                controller: controller,
                textInputAction: action,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.text,
                cursorColor: AppColors.cursorBlack,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp("[a-zA-Z ]")),
                  LengthLimitingTextInputFormatter(100),
                ],
                style: const TextStyle(fontSize: AppSize.size_14, fontFamily: 'Satoshi', color: AppColors.darkBlack),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: AppSize.size_14, fontFamily: 'Satoshi', color: AppColors.hintColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget getNameFields(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _nameField(firstNameController, 'First Name', 'First Name', TextInputAction.next)),
        const SizedBox(width: 12),
        Expanded(child: _nameField(lastNameController, 'Last Name', 'Last Name', TextInputAction.next)),
      ],
    );
  }

  Widget getEmailLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Email Address",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'Satoshi',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),

        Container(
          margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'Satoshi',
                color: AppColors.red,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        )
      ],
    );
  }

  Widget getEmailField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          border: Border.all(color: AppColors.gray, width: 1)),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: emailController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.emailAddress,
            cursorColor: AppColors.cursorBlack,
            inputFormatters: [
              LengthLimitingTextInputFormatter(100),
            ],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'Satoshi',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Email Address', // Set the hint label text
              hintStyle: TextStyle(
                fontSize:  AppSize.size_14,
                fontFamily: 'Satoshi',
                color: AppColors.hintColor, // Text color of the hint label
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget getPhoneNumberText()
  {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Phone Number",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'Satoshi',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),

        Container(
          margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'Satoshi',
                color: AppColors.red,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        )
      ],
    );
  }

  Widget getMobileNumberField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
          color: AppColors.gray2,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          border: Border.all(color: AppColors.gray2, width: 1)),
      child: Padding(
        padding: const EdgeInsets.only(left: 0, right: 0),
        child: Row(
          children: [
            // Country Code Layout
            Container(
              padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
              margin: const EdgeInsets.fromLTRB(5, 0, 0, 0),
              child: Row(
                children: [
                  Container(
                    child: Text(
                        phoneCode,
                      style: TextStyle(
                        fontSize:  AppSize.size_14,
                        fontFamily: 'Satoshi',
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider Line.
            Container(
              height: 50,
              margin: EdgeInsets.fromLTRB(0, 0, 5, 0),
              child: VerticalDivider(
                color: AppColors.gray,
                thickness: 1,
              ),
            ),

            Expanded(
              //flex: 4,
              child: Container(
                child: TextFormField(
                  enabled: false,
                  controller: mobileNumberController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.number,
                  cursorColor: AppColors.cursorBlack,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    MobileNumberFormatter(),
                  ],
                  onChanged: _validateNumber,
                  validator: (value) {
                    String digits = value?.replaceAll('-', '') ?? '';
                    if (digits.length != 10) {
                      return "Enter valid 10-digit mobile number";
                    }
                    return null;
                  },
                  style: TextStyle(
                    fontSize:  AppSize.size_14,
                    fontFamily: 'Satoshi',
                    color: AppColors.darkBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XX-XXXX-XXXX', // Set the hint label text
                    hintStyle: TextStyle(
                      fontSize:  AppSize.size_14,
                      fontFamily: 'Satoshi',
                      color: AppColors.hintColor, // Text color of the hint label
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),

            Container(
              width: 15,
              height: 15,
              margin: EdgeInsets.only(right: 10),
              child: Image.asset('assets/ic_right_green.png'),
            ),
          ],
        ),
      ),
    );
  }

  Widget getPhoneVerifiedText() {

    return Container(
      margin: EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: Image.asset('assets/ic_right_green.png'),
          ),
          Container(
            margin: EdgeInsets.fromLTRB(5, 0, 0, 0),
            child: const Text(
              "Phone number is verified",
              style: TextStyle(
                  fontSize: AppSize.size_12,
                  fontFamily: 'Satoshi',
                  color: AppColors.green,
                  height: 1.25,
                  leadingDistribution: TextLeadingDistribution.even,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget getPrimaryContactNumberText()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: const Text(
        "Venue’s primary contact number",
        style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'Satoshi',
            color: AppColors.black1,
            height: 1
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getPrimaryContactNumberSubText()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: const Text(
        "Members, ACTIV team, and other partners may call on this number for booking support",
        style: TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'Satoshi',
            color: AppColors.black1,
            height: 1.4
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getOwnerPhoneNumberText()
  {
    return Visibility(
      visible: !isChecked ? true : false,
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
            child: const Text(
              "Phone Number",
              style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'Satoshi',
                  color: AppColors.black1,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          ),

          Container(
            margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
            child: const Text(
              "*",
              style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'Satoshi',
                  color: AppColors.red,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          )
        ],
      ),
    );
  }

  Widget getOwnerMobileNumberField(BuildContext context) {
    return Visibility(
      visible: !isChecked ? true : false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            border: Border.all(color: AppColors.gray, width: 1)),
        child: Padding(
          padding: const EdgeInsets.only(left: 0, right: 0),
          child: Row(
            children: [
              // Country Code Layout
              Container(
                padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                margin: const EdgeInsets.fromLTRB(5, 0, 0, 0),
                child: Row(
                  children: [
                    Container(
                      child: Text(
                        phoneCode,
                        style: TextStyle(
                          fontSize:  AppSize.size_14,
                          fontFamily: 'Satoshi',
                          color: AppColors.darkBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Divider Line.
              Container(
                height: 50,
                margin: EdgeInsets.fromLTRB(0, 0, 5, 0),
                child: VerticalDivider(
                  color: AppColors.gray,
                  thickness: 1,
                ),
              ),

              Expanded(
                //flex: 4,
                child: Container(
                  child: TextFormField(
                    controller: venueOwnerMobileNumberController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.number,
                    cursorColor: AppColors.cursorBlack,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      MobileNumberFormatter(),
                    ],
                    onChanged: _validateNumber,
                    validator: (value) {
                      String digits = value?.replaceAll('-', '') ?? '';
                      if (digits.length != 10) {
                        return "Enter valid 10-digit mobile number";
                      }
                      return null;
                    },
                    style: TextStyle(
                      fontSize:  AppSize.size_14,
                      fontFamily: 'Satoshi',
                      color: AppColors.darkBlack,
                    ),
                    decoration: InputDecoration(
                      hintText: 'XX-XXXX-XXXX', // Set the hint label text
                      hintStyle: TextStyle(
                        fontSize:  AppSize.size_14,
                        fontFamily: 'Satoshi',
                        color: AppColors.hintColor, // Text color of the hint label
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget getCheckBoxSamesOwner()
  {
    return Container(
      alignment: Alignment.centerLeft,
      margin: EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            child: Checkbox(
              value: isChecked,
              onChanged: (value) {
                setState(() {
                  isChecked = value!;
                });
                  _saveSessionDraft();
              },
              activeColor: AppColors.black, // Tick color
              checkColor: AppColors.white,  // Tick icon color
              side: BorderSide(color: AppColors.black, width: 2), // Border style
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
          ),

          Flexible(child: Container(
            margin: EdgeInsets.only(left: 5),
            child: const Text(
              'Same as owner number',
              style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'Satoshi',
                  color: AppColors.black1,
                  height: 1.25,
                  leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ))
        ],
      ),
    );
  }

  bool validation(BuildContext context)
  {
    String input = venueOwnerMobileNumberController.text.trim();

    if (firstNameController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, "Please enter your first name.");
      return false;
    }
    else if (lastNameController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, "Please enter your last name.");
      return false;
    }
    else if (emailController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationEmailEnter);
      return false;
    }
    else if (!CommonUtilities.emailVaidatation(emailController.text.trim())) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationValidEmailEnter);
      return false;
    }
    else if (!isChecked && input.isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.venueOwnerMobileNumberEnter);
      return false;
    }
    else if (!isChecked && !RegExp(r'^\d{2}-\d{4}-\d{4}$').hasMatch(input)) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.venueOwnerMobileNumberValid);
      return false;
    }
    return true;
  }
}
