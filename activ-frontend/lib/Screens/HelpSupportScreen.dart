import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:activ_app/Utills/app_time_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../Style/app_colors.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'MobileNumberFormatter.dart';
import 'StringExtensions.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key, this.client});

  final http.Client? client;

  @override
  Widget build(BuildContext context) {
    return _SupportScaffold(
      title: 'Help & Support',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 38, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Need help? We've\ngot your back.",
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.28,
                color: AppColors.darkBlack,
              ),
            ),
            const SizedBox(height: 38),
            _SupportOption(
              icon: Icons.mail_outline_rounded,
              title: 'Email Us',
              subtitle:
                  "Send us an email and we'll get back to you at your preferred time",
              onTap: () => CommonUtilities.NavigateWithPush(
                context,
                EmailUsScreen(client: client),
              ),
            ),
            const SizedBox(height: 14),
            _SupportOption(
              icon: Icons.phone_rounded,
              title: 'Request Call Back',
              subtitle:
                  'Fill In your details and our team will call you at your preferred time',
              onTap: () => CommonUtilities.NavigateWithPush(
                context,
                RequestCallbackScreen(client: client),
              ),
            ),
            const SizedBox(height: 14),
            _SupportOption(
              icon: Icons.contact_support_outlined,
              title: 'Frequently Asked Questions',
              subtitle: 'Find quick answer to common questions',
              onTap: () => CommonUtilities.NavigateWithPush(
                context,
                FaqSupportScreen(client: client),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmailUsScreen extends StatefulWidget {
  const EmailUsScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<EmailUsScreen> createState() => _EmailUsScreenState();
}

class _EmailUsScreenState extends State<EmailUsScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  PlatformFile? _file;
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _file = result.files.first);
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.isEmpty) {
      CommonUtilities.createSnackBar(context, 'Please enter subject');
      return;
    }
    if (message.isEmpty) {
      CommonUtilities.createSnackBar(context, 'Please enter message');
      return;
    }
    setState(() => _sending = true);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final request =
          http.MultipartRequest('POST', Uri.parse(SUPPORT_EMAIL_URL));
      request.headers.addAll({
        'accept': '*/*',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
      request.fields['subject'] = subject;
      request.fields['message'] = message;
      final file = _file;
      if (file?.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'attachment',
            file!.bytes!,
            filename: file.name,
          ),
        );
      }
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_messageFromResponse(response.body) ??
            'Unable to send email. Please try again.');
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const _EmailSentScreen(),
        ),
      );
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      setState(() => _file = null);
    } catch (error) {
      if (mounted) {
        CommonUtilities.createSnackBar(context, _cleanError(error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SupportScaffold(
      title: 'Email Us',
      compactHeader: true,
      footer: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 58,
              child: OutlinedButton(
                onPressed: _sending ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: AppColors.darkBlack,
                  side: const BorderSide(color: AppColors.darkBlack),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _PrimaryButton(
              text: _sending ? 'Sending...' : 'Send Email',
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _sending ? null : _send,
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We’re here to help!',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Send us an email and we’ll get back to\nyou as soon as possible',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      color: AppColors.darkBlack,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _Label('To', compact: true),
                  const _ReadOnlyBox('support@activ.live', compact: true),
                  const SizedBox(height: 4),
                  const Text(
                    'This is our official support email address.',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 13,
                      color: AppColors.black1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Input(
                    label: 'Subject',
                    required: true,
                    controller: _subject,
                    hint: 'Enter subject',
                    compact: true,
                  ),
                  const SizedBox(height: 12),
                  _Input(
                    label: 'Message',
                    required: true,
                    controller: _message,
                    hint: 'Type your message here...',
                    maxLines: 4,
                    compact: true,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Attach ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: '(Optional)'),
                          ],
                        ),
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 14,
                          color: AppColors.darkBlack,
                        ),
                      ),
                      InkWell(
                        onTap: _sending ? null : _pickFile,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file,
                                color: AppColors.purple, size: 20),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                _file == null ? 'Upload File' : _file!.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'You can upload screenshots, invoices,\ndocuments, etc.',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.darkBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Supported formats: JPG, PNG, and PDF (Max 10MB)',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailSentScreen extends StatelessWidget {
  const _EmailSentScreen();

  @override
  Widget build(BuildContext context) {
    return _SupportScaffold(
      title: 'Email Us',
      transparentFooter: true,
      footer: _PrimaryButton(
        text: 'Back to Help & Support',
        onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 72, 28, 32),
              child: Column(
                children: [
                  const _SuccessBadge(),
                  const SizedBox(height: 28),
                  const Text(
                    'Email Sent!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Thank you for reaching out to us.\nWe’ve received your email and our team will\nget back to you soon.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 16,
                      height: 1.35,
                      color: AppColors.darkBlack,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    height: 54,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.purple, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: AppColors.purple,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        const Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                    text: 'Expected response within '),
                                TextSpan(
                                  text: '24-48 hrs',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: SvgPicture.asset('assets/Vector.svg'),
    );
  }
}

class RequestCallbackScreen extends StatefulWidget {
  const RequestCallbackScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<RequestCallbackScreen> createState() => _RequestCallbackScreenState();
}

class _RequestCallbackScreenState extends State<RequestCallbackScreen> {
  final _partner = TextEditingController();
  final _venue = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _query = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  String _phoneCode = 'IND (+91)';
  bool _submitting = false;
  bool _loadingDetails = true;
  bool _detailsUnavailable = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDetails();
  }

  Future<void> _loadSavedDetails() async {
    if (!mounted) return;
    setState(() => _loadingDetails = true);
    final name = checkString(await SharedPreference.readStr('owner_full_name'));
    final email = checkString(await SharedPreference.readStr('owner_email'));
    final phone =
        checkString(await SharedPreference.readStr('userMobileNumber'));
    final code = checkString(await SharedPreference.readStr('phoneCode'));
    final rawVenue =
        checkString(await SharedPreference.readStr('venue_details'));
    final savedVenueName =
        checkString(await SharedPreference.readStr('venue_name'));
    if (!mounted) return;
    try {
      final venue = rawVenue.isEmpty ? {} : jsonDecode(rawVenue);
      if (venue is Map) {
        final venueName = checkString(venue['venue_name']);
        final city = checkString(venue['venue_city']);
        _venue.text = venueName.isEmpty ? savedVenueName : venueName;
        _city.text = city.isEmpty ? checkString(venue['city']) : city;
      }
    } catch (_) {
      CommonUtilities.showLog('Cached callback venue details unavailable.');
    }
    if (_venue.text.trim().isEmpty) _venue.text = savedVenueName;
    _partner.text = name;
    _email.text = email;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    _phone.text = digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits;
    if (code.isNotEmpty) _phoneCode = code;
    setState(() {});
    await _refreshDetails();
  }

  Future<void> _refreshDetails() async {
    if (!mounted) return;
    setState(() => _loadingDetails = true);
    await Future.wait([
      _loadPartnerIdentityFromApi(),
      _loadVenueIdentityFromApi(),
    ]);
    if (mounted) {
      setState(() {
        _loadingDetails = false;
        _detailsUnavailable =
            [_partner, _venue, _city].any((field) => field.text.trim().isEmpty);
      });
    }
  }

  Future<void> _loadPartnerIdentityFromApi() async {
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    if (token.isEmpty || !mounted) return;
    final initialPhone = _phone.text;
    final initialEmail = _email.text;
    try {
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(AUTH_PROFILE_URL),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (!mounted || response.statusCode != 200) return;
      final data = jsonDecode(response.body)['data'];
      if (data is! Map) return;
      final profile = data['member'] ?? data['partner'] ?? data;
      if (profile is! Map) return;
      final name = [profile['firstName'], profile['lastName']]
          .map(checkString)
          .where((part) => part.isNotEmpty)
          .join(' ');
      final fullName = name.isEmpty
          ? checkString(profile['fullName'] ?? profile['name'])
          : name;
      if (fullName.isNotEmpty) _partner.text = fullName;
      final email = checkString(profile['email']);
      if (email.isNotEmpty && _email.text == initialEmail) _email.text = email;
      final digits =
          checkString(profile['phone']).replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty && _phone.text == initialPhone) {
        _phone.text = digits.length == 12 && digits.startsWith('91')
            ? digits.substring(2)
            : digits;
      }
    } catch (_) {
      CommonUtilities.showLog('Callback profile details unavailable.');
    }
  }

  Future<void> _loadVenueIdentityFromApi() async {
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    final selectedId = checkString(await SharedPreference.readStr('venue_id'));
    final isTeamMember =
        await SharedPreference.readStr('user_type') == 'team_member';
    if (token.isEmpty || !mounted) return;

    Future<dynamic> getVenueData(String url) async {
      try {
        final response = await (widget.client?.get ?? http.get)(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body);
          return body is Map ? body['data'] : null;
        }
      } catch (_) {
        CommonUtilities.showLog('Callback venue details unavailable.');
      }
      return null;
    }

    bool fillVenue(Map venue) {
      final primaryName = checkString(venue['name']);
      final primaryCity = checkString(venue['city']);
      final name = primaryName.isEmpty ? checkString(venue['venue_name']) : primaryName;
      final city = primaryCity.isEmpty ? checkString(venue['venue_city']) : primaryCity;
      if (name.isNotEmpty) _venue.text = name;
      if (city.isNotEmpty) _city.text = city;
      return name.isNotEmpty && city.isNotEmpty;
    }

    if (!isTeamMember && selectedId.isNotEmpty) {
      final selected = await getVenueData(
          '$CREATE_VENUE_URL/${Uri.encodeComponent(selectedId)}');
      if (!mounted) return;
      if (selected is Map && fillVenue(selected)) return;
    }

    final data = await getVenueData(
        isTeamMember ? MY_APPROVED_VENUES_URL : MY_VENUES_URL);
    if (!mounted) return;
    final items = data is Map ? data['items'] : data;
    if (items is! List) return;
    final venues = items.whereType<Map>();
    final selected = venues
            .where((venue) => checkString(venue['id']) == selectedId)
            .firstOrNull ??
        venues.firstOrNull;
    if (selected != null) {
      fillVenue(selected);
    }
  }

  @override
  void dispose() {
    _partner.dispose();
    _venue.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    _query.dispose();
    _date.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) {
      _date.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _pickTime() async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      _time.text = MaterialLocalizations.of(context)
          .formatTimeOfDay(picked, alwaysUse24HourFormat: false);
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    for (final field in [
      _partner,
      _venue,
      _city,
      _phone,
      _email,
      _query,
      _date,
      _time,
    ]) {
      if (field.text.trim().isEmpty) {
        CommonUtilities.createSnackBar(
            context, 'Please fill all required fields');
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final response = await (widget.client?.post ?? http.post)(
        Uri.parse(SUPPORT_CALLBACK_URL),
        headers: const {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'partnerName': _partner.text.trim(),
          'venueName': _venue.text.trim(),
          'city': _city.text.trim(),
          'phone': _phone.text.replaceAll(RegExp(r'\D'), ''),
          'email': _email.text.trim(),
          'query': _query.text.trim(),
          'callbackDate': _date.text.trim(),
          'callbackTime': _time.text.trim(),
        }),
      );
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_messageFromResponse(response.body) ??
            'Unable to request callback. Please try again.');
      }
      await _showCallbackDialog(context);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (mounted) CommonUtilities.createSnackBar(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SupportScaffold(
      title: 'Request Callback',
      footer: _PrimaryButton(
        text: _submitting ? 'Requesting...' : 'Request Call Back',
        onPressed: _submitting || _loadingDetails ? null : _submit,
      ),
      child: SingleChildScrollView(
        key: const Key('callback-form-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingDetails) const LinearProgressIndicator(),
            if (_detailsUnavailable && !_loadingDetails)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Enter any missing details, or retry to load them.'),
                  TextButton(
                      onPressed: _refreshDetails, child: const Text('Retry')),
                ],
              ),
            _Input(
              label: 'Venue Partner Name',
              required: true,
              controller: _partner,
              readOnly: !_detailsUnavailable || _loadingDetails,
            ),
            const SizedBox(height: 8),
            _Input(
              label: 'Venue Name',
              required: true,
              controller: _venue,
              readOnly: !_detailsUnavailable || _loadingDetails,
            ),
            const SizedBox(height: 8),
            _Input(
              label: 'City',
              required: true,
              controller: _city,
              readOnly: !_detailsUnavailable || _loadingDetails,
            ),
            const SizedBox(height: 8),
            _PhoneInput(
              label: 'Phone Number',
              controller: _phone,
              phoneCode: _phoneCode,
            ),
            const SizedBox(height: 8),
            _Input(label: 'Email', required: true, controller: _email),
            const SizedBox(height: 8),
            _Input(
              label: 'Please write your Query',
              required: true,
              controller: _query,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            _PickerInput(
              label: 'Preferred Callback Date',
              controller: _date,
              hint: 'Select date',
              icon: Icons.calendar_today_outlined,
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            _PickerInput(
              label: 'Preferred Time Slots',
              controller: _time,
              hint: 'Select time',
              icon: Icons.access_time,
              onTap: _pickTime,
            ),
          ],
        ),
      ),
    );
  }
}

class FaqSupportScreen extends StatefulWidget {
  const FaqSupportScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<FaqSupportScreen> createState() => _FaqSupportScreenState();
}

class _FaqSupportScreenState extends State<FaqSupportScreen> {
  int _open = 0;
  List<_FaqData> _faqs = [];
  bool _loading = true;
  String? _error;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await (widget.client?.get ?? http.get)(Uri.parse(FAQ_PUBLIC_URL))
              .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200)
        throw const FormatException('FAQ request failed');
      final body = jsonDecode(response.body);
      if (body is! Map || body['data'] is! List)
        throw const FormatException('Invalid FAQ response');
      final items = <_FaqData>[];
      for (final entry in body['data']) {
        if (entry is! Map ||
            entry['question'] is! String ||
            entry['answer'] is! String) {
          throw const FormatException('Invalid FAQ entry');
        }
        if (entry['isActive'] != false)
          items.add(_FaqData(entry['question'], entry['answer']));
      }
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _faqs = items;
        _open = items.isEmpty ? -1 : 0;
      });
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = 'Unable to load FAQs.');
      }
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SupportScaffold(
      title: 'FAQs',
      footer: _PrimaryButton(
        text: 'Request Call Back',
        onPressed: () => CommonUtilities.NavigateWithPush(
          context,
          RequestCallbackScreen(client: widget.client),
        ),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  TextButton.icon(
                      onPressed: _loadFaqs,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry loading FAQs')),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadFaqs,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(28, 30, 28, 20),
                    children: [
                      if (_faqs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 30),
                          child: Center(child: Text('No FAQs available yet.')),
                        ),
                      for (var i = 0; i < _faqs.length; i++) ...[
                        _FaqTile(
                          question: _faqs[i].question,
                          answer: _faqs[i].answer,
                          open: _open == i,
                          onTap: () =>
                              setState(() => _open = _open == i ? -1 : i),
                        ),
                        if (i != _faqs.length - 1) const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _FaqData {
  const _FaqData(this.question, this.answer);

  final String question;
  final String answer;
}

class _SupportScaffold extends StatelessWidget {
  const _SupportScaffold({
    required this.title,
    required this.child,
    this.footer,
    this.transparentFooter = false,
    this.compactHeader = false,
  });

  final String title;
  final Widget child;
  final Widget? footer;
  final bool transparentFooter;
  final bool compactHeader;

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
              Padding(
                padding: EdgeInsets.fromLTRB(
                    compactHeader ? 16 : 28,
                    compactHeader ? 12 : 16,
                    compactHeader ? 16 : 28,
                    compactHeader ? 8 : 12),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      shadowColor: Colors.black12,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppColors.darkBlack,
                          size: compactHeader ? 20 : 24,
                        ),
                      ),
                    ),
                    SizedBox(width: compactHeader ? 16 : 24),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: compactHeader ? 22 : 25,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
              if (footer != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 22),
                  decoration: transparentFooter
                      ? null
                      : const BoxDecoration(
                          color: Color(0xFFF0F7D2),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 18,
                              offset: Offset(0, -6),
                            ),
                          ],
                        ),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.black, size: 28),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        color: AppColors.black1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false, this.compact = false});

  final String text;
  final bool required;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(text: '*', style: TextStyle(color: AppColors.red)),
        ],
      ),
      style: TextStyle(
        fontFamily: 'Satoshi',
        fontWeight: FontWeight.w500,
        fontSize: compact ? 14 : 14,
        color: AppColors.darkBlack,
      ),
    );
  }
}

class _ReadOnlyBox extends StatelessWidget {
  const _ReadOnlyBox(this.text, {this.compact = false});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: compact ? 4 : 8),
      height: compact ? 38 : 50,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
      decoration: BoxDecoration(
        color: AppColors.gray2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Satoshi',
          fontSize: compact ? 13 : 16,
          color: AppColors.darkBlack,
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.label,
    required this.controller,
    this.required = false,
    this.hint = '',
    this.maxLines = 1,
    this.readOnly = false,
    this.compact = false,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String hint;
  final int maxLines;
  final bool readOnly;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label, required: required, compact: compact),
        SizedBox(height: compact ? 4 : 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(fontFamily: 'Satoshi', fontSize: compact ? 14 : 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: compact ? 14 : 15,
              color: AppColors.hintColor,
            ),
            filled: true,
            fillColor: readOnly ? AppColors.gray2 : Colors.white,
            contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16, vertical: compact ? 7 : 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.darkBlack),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneInput extends StatelessWidget {
  const _PhoneInput({
    required this.label,
    required this.controller,
    required this.phoneCode,
  });

  final String label;
  final TextEditingController controller;
  final String phoneCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label, required: true),
        const SizedBox(height: 5),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gray),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 118,
                child: Center(
                  child: Text(
                    phoneCode.isEmpty ? 'IND (+91)' : phoneCode,
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 15,
                      color: AppColors.darkBlack,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.gray),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    MobileNumberFormatter(),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 16,
                    color: AppColors.darkBlack,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerInput extends StatelessWidget {
  const _PickerInput({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label, required: true),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          style: const TextStyle(fontFamily: 'Satoshi', fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: Icon(icon, color: AppColors.darkBlack),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray),
            ),
          ),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
    required this.open,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ),
                  Icon(open
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                ],
              ),
              if (open) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.gray),
                const SizedBox(height: 16),
                Text(
                  answer,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.black1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.text, required this.onPressed, this.padding});

  final String text;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: padding,
          backgroundColor: Colors.black,
          foregroundColor: const Color(0xFFD8F34A),
          disabledBackgroundColor: Colors.black54,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Future<void> _showEmailSentDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 44, 34, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFF12E000),
              child: Icon(Icons.check, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 30),
            const Text(
              'Email Sent!',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                fontSize: 26,
                color: AppColors.darkBlack,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Thank you for reaching out to us. We've\nreceived your email and our team will get back\nto you soon.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 17,
                height: 1.35,
                color: AppColors.darkBlack,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.purple),
              ),
              child: const Text(
                'Expected response within 24-48 hrs',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.purple,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 190,
              child: _PrimaryButton(
                text: 'Okay',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showCallbackDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFFF6FBE3),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 552),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 552,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 42, 28, 46),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/callback_calendar.png',
                width: 112,
                height: 112,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              const SizedBox(height: 32),
              const Text(
                'We\u2019ll call you soon!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  height: 1.2,
                  color: AppColors.black1,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thank you for your request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 19,
                  height: 1.4,
                  color: Color(0xFF626262),
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: const Text(
                  'Our team member will call you during your chosen time slot.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 19,
                    height: 1.4,
                    color: Color(0xFF626262),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                height: 72,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: AppColors.yellow,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Okay',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String? _messageFromResponse(String body) {
  try {
    final decoded = jsonDecode(body);
    final message = decoded['message'];
    if (message is List) return message.join('\n');
    return checkString(message).isEmpty ? null : checkString(message);
  } catch (_) {
    return null;
  }
}

String _cleanError(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
