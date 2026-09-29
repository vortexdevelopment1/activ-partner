import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;

import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../CommonCode.dart';
import '../StringExtensions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isTeamMember = false;

  String _fullName = '';
  String _email = '';
  String _phone = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userType = checkString(await SharedPreference.readStr("user_type"));
    _isTeamMember = userType == "team_member";

    final token = checkString(await SharedPreference.readStr("jwt_token"));

    try {
      final response = await http.get(
        Uri.parse(AUTH_PROFILE_URL),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );

      CommonUtilities.showLog("ProfileScreen status: ${response.statusCode}");
      CommonUtilities.showLog("ProfileScreen body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? {};

        if (_isTeamMember) {
          final member = data['member'] ?? {};
          _fullName = member['fullName']?.toString() ?? member['name']?.toString() ?? '';
          _email = member['email']?.toString() ?? '';
          final permissions = member['permissions'];
          if (permissions is Map) {
            // Build a readable role string from permissions
            final roles = <String>[];
            if (permissions['bookingManagement'] == true) roles.add('Booking Management');
            if (permissions['pricingControl'] == true) roles.add('Pricing Control');
            _role = roles.isNotEmpty ? roles.join(', ') : 'Team Member';
          } else {
            _role = member['role']?.toString() ?? 'Team Member';
          }
        } else {
          final partner = data['partner'] ?? data;
          final firstName = partner['firstName']?.toString() ?? '';
          final lastName = partner['lastName']?.toString() ?? '';
          _fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
          _email = partner['email']?.toString() ?? '';
          _phone = partner['mobile']?.toString() ??
              partner['phone']?.toString() ??
              partner['mobileNumber']?.toString() ?? '';
        }
      } else {
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, 'Failed to load profile.');
      }
    } catch (e) {
      CommonUtilities.showLog("ProfileScreen error: $e");
      if (!mounted) return;
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                    _buildToolbar(context),
                    _isLoading
                        ? Expanded(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.black,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(15, 5, 15, 20),
                              children: [
                                _buildField('Full Name', _fullName.isNotEmpty ? _fullName : '—'),
                                _buildField('Email Address', _email.isNotEmpty ? _email : '—'),
                                if (_isTeamMember)
                                  _buildField('Role', _role.isNotEmpty ? _role : '—')
                                else
                                  _buildField('Phone Number', _phone.isNotEmpty ? _phone : '—'),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      height: AppSize.toolTabSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                child: SvgPicture.asset('assets/ic_back.svg'),
              ),
            ),
          ),
          getTitleText(context, 'Profile Details', 'Profile_Details'),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 20),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
              height: 1,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: AppColors.gray2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gray2, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.darkBlack,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
