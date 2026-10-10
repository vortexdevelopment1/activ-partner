import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
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

class ViewDocumentScreen extends StatefulWidget {
  const ViewDocumentScreen({super.key});

  @override
  State<ViewDocumentScreen> createState() => _ViewDocumentScreenState();
}

class _ViewDocumentScreenState extends State<ViewDocumentScreen> {
  bool _isLoading = true;

  String _aadhaarName = '';
  String _aadhaarNumber = '';
  String? _panCardUrl;
  String? _aadhaarCardUrl;
  String? _gstinDocUrl;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final token = checkString(await SharedPreference.readStr("jwt_token"));

    try {
      final response = await http.get(
        Uri.parse(AUTH_PROFILE_URL),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );

      CommonUtilities.showLog("ViewDocumentScreen status: ${response.statusCode}");
      CommonUtilities.showLog("ViewDocumentScreen body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final partner = (body['data'] ?? {})['partner'] ?? {};

        _aadhaarName = partner['aadhaarName']?.toString() ?? '';
        _aadhaarNumber = partner['aadhaarNumber']?.toString() ?? '';
        _panCardUrl = partner['panCardUrl']?.toString();
        _aadhaarCardUrl = partner['aadhaarCardUrl']?.toString();
        _gstinDocUrl = partner['gstinDocUrl']?.toString();
      } else {
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, 'Failed to load documents.');
      }
    } catch (e) {
      CommonUtilities.showLog("ViewDocumentScreen error: $e");
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
                      ? const Expanded(
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
                              _buildField('Aadhaar Name', _aadhaarName.isNotEmpty ? _aadhaarName : '—'),
                              _buildField('Aadhaar Number', _aadhaarNumber.isNotEmpty ? _maskedAadhaar(_aadhaarNumber) : '—'),
                              _buildDocImage('PAN Card', _panCardUrl),
                              _buildDocImage('Aadhaar Card', _aadhaarCardUrl),
                              _buildDocImage('GSTIN Document', _gstinDocUrl),
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

  /// Masks aadhaar like XXXX-XXXX-1234
  String _maskedAadhaar(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12) {
      return 'XXXX-XXXX-${digits.substring(8)}';
    }
    return number;
  }

  Widget _buildToolbar(BuildContext context) {
    return SizedBox(
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
          getTitleText(context, 'View Document', 'View_Document'),
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

  Widget _buildDocImage(String label, String? url) {
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
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.gray2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gray2, width: 1),
          ),
          child: (url == null || url.isEmpty)
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Text(
                    'Not uploaded',
                    style: const TextStyle(
                      fontSize: AppSize.size_14,
                      fontFamily: 'FontRegular',
                      color: AppColors.hintColor,
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.black,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Text(
                        'Failed to load image',
                        style: TextStyle(
                          fontSize: AppSize.size_14,
                          fontFamily: 'FontRegular',
                          color: AppColors.red,
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
