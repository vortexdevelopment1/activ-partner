import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../Style/app_colors.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../ContactSupportFormScreen.dart';

class PartnerAgreementScreen extends StatefulWidget {
  const PartnerAgreementScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<PartnerAgreementScreen> createState() => _PartnerAgreementScreenState();
}

class _PartnerAgreementScreenState extends State<PartnerAgreementScreen> {
  final _documentScroll = ScrollController();
  bool _downloading = false;

  static const _purple = AppColors.purple;
  static const _agreementTitle = 'ACTIV Partnership Agreement';
  static const _effectiveDate = '16 Aug 2026';
  static const _agreementText = '''
ACTIVPULSE BOOKING PRIVATE LIMITED
D10 CENTURY GARDEN 18/19A, PADMANABHA STREET, Nemilichery, Tambaram, Kanchipuram- 600044, Tamil Nadu
GSTIN: 33ABCCA3430E1ZD
Email: support@activ.live

Between ACTIVPULSE BOOKING PRIVATE LIMITED and the Venue Partner. This agreement becomes legally binding upon electronic acceptance through the ACTIV Venue Partner App.



1. Introduction
This Venue Partner Agreement governs the Partner's access to and use of the ACTIV Platform. By selecting 'I Agree', entering the Partner's legal name as an electronic signature, and completing registration, the Partner confirms they have read, understood, and accepted this Agreement.

2. Definitions
ACTIV Platform means the mobile application, website, and partner portal. Booking means a confirmed reservation. Partner means the venue/business registering on the platform. Customer means any user making a booking.

3. Appointment
ACTIV appoints the Partner on a non-exclusive basis to list eligible sports, fitness and wellness services.

4. Eligibility
The Partner confirms they are at least 18 years old, legally authorised to operate the venue, possess required licences, and provide accurate information.

5. Venue Listing
The Partner shall maintain accurate venue details, pricing, availability, amenities, operating hours, images and policies.

6. Booking Management
The Partner shall honour confirmed bookings, maintain availability, avoid overbooking, and promptly notify ACTIV of disruptions.

7. Service Standards
The Partner shall maintain safe, clean facilities, functional equipment, professional staff behaviour and comply with applicable laws.

8. Pricing
The Partner may set prices subject to ACTIV policies. ACTIV may introduce promotional campaigns and revise commercial policies with notice where required.

9. Payments & Commission
Bookings are processed through ACTIV. ACTIV deducts applicable commission, taxes and agreed deductions before settlement.

10. Payouts
Payouts follow ACTIV's payout policy. ACTIV may withhold payouts for fraud, disputes, chargebacks, policy violations, or legal requirements.

11. Cancellations
Customer cancellations follow ACTIV policy. Partner cancellations may result in warnings, penalties, suspension, or termination.

12. Taxes
The Partner is solely responsible for GST and all statutory tax obligations.

13. Customer Data
Customer data shall be used only to fulfil bookings and shall not be misused, sold, or shared without lawful authority.

14. Intellectual Property
The Partner grants ACTIV a non-exclusive licence to use venue content for platform operations and marketing while retaining ownership.

15. Prohibited Activities
Offline payments, fake bookings, fraud, misleading information, pricing manipulation and unsafe conduct are prohibited.

16. Liability
ACTIV is a technology platform and is not responsible for venue operations, injuries, theft, property damage or service delivery.

17. Indemnity
The Partner agrees to indemnify ACTIV against claims arising from breach, negligence, misconduct or legal non-compliance.

18. Suspension & Termination
ACTIV may suspend or terminate accounts for fraud, safety issues, false information, or serious policy violations.

19. Confidentiality
The Partner shall keep non-public platform information confidential.

20. Force Majeure
Neither party is liable for failures caused by events beyond reasonable control.

21. Governing Law
This Agreement is governed by Indian law. Arbitration shall take place in Chennai, Tamil Nadu.

22. Amendments
ACTIV may update this Agreement. Continued use of the platform constitutes acceptance of the revised terms.

23. Electronic Acceptance & Signature
Typing the Partner's full legal name and accepting this Agreement constitutes a legally binding electronic signature under applicable Indian law.
''';

  @override
  void dispose() {
    _documentScroll.dispose();
    super.dispose();
  }

  Future<void> _downloadAgreement() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final uri = Uri.parse('$LEGAL_URL/partner_agreement/download');
      final response = await (widget.client?.get(uri) ?? http.get(uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Unable to download the partnership agreement.');
      }
      final data = jsonDecode(response.body)['data'];
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save partnership agreement',
        fileName: data['filename'] as String? ?? 'activ-partner-agreement.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: base64Decode(data['base64'] as String),
      );
    } catch (error) {
      if (!mounted) return;
      CommonUtilities.createSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFF0F7D2),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F7D2),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                downloading: _downloading,
                onDownload: _downloadAgreement,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You signed this agreement during onboarding.\nYou can review or download a copy anytime.',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          height: 1.28,
                          color: AppColors.darkBlack,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _AgreementCard(documentScroll: _documentScroll),
                      const SizedBox(height: 16),
                      const _SupportCard(),
                      const Spacer(),
                      _PrimaryButton(
                        text: 'Contact Support',
                        onPressed: () => CommonUtilities.NavigateWithPush(
                          context,
                          const ContactSupportFormScreen(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.downloading, required this.onDownload});

  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: Colors.black12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: AppColors.darkBlack),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
              'Partner Agreement',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: AppColors.darkBlack,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Download agreement',
            onPressed: downloading ? null : onDownload,
            icon: downloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined,
                    color: AppColors.darkBlack, size: 30),
          ),
        ],
      ),
    );
  }
}

class _AgreementCard extends StatelessWidget {
  const _AgreementCard({required this.documentScroll});

  final ScrollController documentScroll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  color: _PartnerAgreementScreenState._purple, size: 38),
              const SizedBox(width: 16),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            _PartnerAgreementScreenState._agreementTitle + '\n',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBlack,
                        ),
                      ),
                      const TextSpan(text: 'Effective Date: '),
                      TextSpan(
                        text: _PartnerAgreementScreenState._effectiveDate,
                        style: const TextStyle(
                          color: _PartnerAgreementScreenState._purple,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 16,
                    height: 1.28,
                    color: AppColors.darkBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray),
            ),
            child: Scrollbar(
              controller: documentScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: documentScroll,
                padding: const EdgeInsets.all(14),
                child: const SelectableText(
                  _PartnerAgreementScreenState._agreementText,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    height: 1.32,
                    color: AppColors.darkBlack,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.purple, width: 1.2),
      ),
      child: const Row(
        children: [
          Icon(Icons.support_agent_rounded, color: AppColors.purple, size: 38),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Have questions or need to\ndiscuss?',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.25,
                    color: AppColors.purple,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'If you have any doubts or need clarification about this agreement, our support team is here to help.',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.28,
                    color: AppColors.purple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: const Color(0xFFD8F34A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
