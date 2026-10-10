import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../ContactSupportFormScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _background = Color(0xFFF0F7D2);
  static const _purple = Color(0xFFA536F5);
  bool _loading = true,
      _uploading = false,
      _teamMember = false,
      _verified = false;
  String _name = '', _displayName = '', _email = '', _phone = '';
  String _venuePhone = '', _avatar = '', _role = '';
  String? _error, _venueError;

  Future<http.Response> _get(String url, String token) =>
      (widget.client?.get ?? http.get)(Uri.parse(url), headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));

  List<Map<String, dynamic>> _venuesFromData(dynamic data) {
    final dynamic source = data is List
        ? data
        : data is Map
            ? data['items'] ?? data['venues'] ?? data['data']
            : null;
    if (source is! List) return [];
    return source
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _idOf(Map venue) => (venue['id'] ?? venue['_id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
      _venueError = null;
    });
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      _teamMember =
          await SharedPreference.readStr('user_type') == 'team_member';
      if (token.isEmpty) throw Exception('Please log in again.');
      final response = await _get(AUTH_PROFILE_URL, token);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Could not load your details.');
      }
      final data = jsonDecode(response.body)['data'];
      final profile = _teamMember ? data['member'] : (data['partner'] ?? data);
      final names = [profile['firstName'], profile['lastName']]
          .where((value) => value != null && value.toString().trim().isNotEmpty)
          .join(' ');
      _name = names.isNotEmpty
          ? names
          : (profile['fullName'] ?? profile['name'] ?? '').toString();
      _displayName = (profile['businessName'] ?? _name).toString();
      _email = (profile['email'] ?? '').toString();
      _phone = (profile['phone'] ??
              profile['mobile'] ??
              profile['mobileNumber'] ??
              '')
          .toString();
      _avatar =
          (profile['avatarUrl'] ?? profile['profileImage'] ?? '').toString();
      if (_avatar.startsWith('/')) {
        _avatar = Uri.parse(BASE_URL).resolve(_avatar).toString();
      }
      _role = (profile['role'] ?? 'Team Member').toString();
      final permissions = profile['permissions'];
      if (_teamMember && permissions is Map) {
        final roles = <String>[
          if (permissions['bookingManagement'] == true) 'Booking Management',
          if (permissions['pricingControl'] == true) 'Pricing Control',
        ];
        _role = roles.isEmpty ? 'Team Member' : roles.join(', ');
      }
      _verified = !_teamMember &&
          (profile['isVerified'] ?? profile['isActive']) == true;
      if (!_teamMember) {
        try {
          final selectedId = await SharedPreference.readStr('venue_id');
          final venuesResponse = await _get(MY_APPROVED_VENUES_URL, token);
          if (venuesResponse.statusCode != 200) {
            throw Exception('Venue unavailable');
          }
          final venues =
              _venuesFromData(jsonDecode(venuesResponse.body)['data']);
          final matching =
              venues.where((venue) => _idOf(venue) == selectedId?.toString());
          final venue = matching.isNotEmpty
              ? matching.first
              : (venues.isNotEmpty ? venues.first : null);
          _venuePhone = (venue?['venuePhone'] ?? '').toString();
        } catch (_) {
          _venueError = 'Unable to load venue number';
        }
      }
    } catch (_) {
      _error = 'Unable to load your details. Please try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _changePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85);
      if (photo == null || !mounted) return;
      setState(() => _uploading = true);
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final request =
          http.MultipartRequest('PATCH', Uri.parse('$BASE_URL/partners/avatar'))
            ..headers['Authorization'] = 'Bearer $token'
            ..files.add(http.MultipartFile.fromBytes(
                'avatar', await photo.readAsBytes(),
                filename: photo.name));
      final client = widget.client ?? http.Client();
      late http.Response response;
      try {
        response = await http.Response.fromStream(
            await client.send(request).timeout(const Duration(seconds: 30)));
      } finally {
        if (widget.client == null) client.close();
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Upload failed');
      }
      await _loadProfile();
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to update photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  TextStyle _text(double size,
          {bool bold = false, Color color = const Color(0xFF202020)}) =>
      TextStyle(
          fontFamily: 'Satoshi',
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color);

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: _background),
        child: Scaffold(
          backgroundColor: _background,
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.black))
                      : _error != null
                          ? Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: _text(15)),
                                  TextButton(
                                      onPressed: _loadProfile,
                                      child: const Text('Retry')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.maybePop(context),
                                      child: const Text('Back')),
                                ]))
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 30, 20, 24),
                              children: [
                                  _header(),
                                  const SizedBox(height: 32),
                                  Text('Your Information',
                                      style: _text(18, bold: true)),
                                  const SizedBox(height: 14),
                                  _field('Full Name', _name,
                                      Icons.person_outline_rounded),
                                  _field('Email Address', _email,
                                      Icons.mail_outline_rounded),
                                  _field('Primary Phone Number', _phone,
                                      Icons.phone_outlined),
                                  if (_teamMember)
                                    _field('Role', _role, Icons.badge_outlined)
                                  else
                                    _field(
                                        'Venue Primary Number',
                                        _venueError ?? _venuePhone,
                                        Icons.fax_outlined),
                                  const SizedBox(height: 6),
                                  _supportNotice(),
                                ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const ContactSupportFormScreen())),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: const Color(0xFFD8F34A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Contact Support',
                              style: _text(20,
                                  bold: true, color: const Color(0xFFD8F34A)))),
                    ),
                  )),
            ]),
          ))),
        ),
      );

  Widget _header() => Column(children: [
        Row(children: [
          Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black12,
              child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  style: IconButton.styleFrom(
                      minimumSize: const Size.square(40),
                      maximumSize: const Size.square(40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  icon: const Icon(Icons.arrow_back, size: 25),
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  padding: EdgeInsets.zero)),
          const SizedBox(width: 16),
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                      _teamMember ? 'Team Member Details' : 'Partner Details',
                      style: _text(24, bold: true)))),
        ]),
        const SizedBox(height: 24),
        if (_verified) ...[
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified, color: Color(0xFF19BC45), size: 13),
                const SizedBox(width: 9),
                Text('Verified Partner', style: _text(13)),
              ])),
          const SizedBox(height: 16),
        ],
        SizedBox(
            width: 124,
            height: 124,
            child: Stack(children: [
              ClipOval(
                  child: SizedBox(
                      width: 124,
                      height: 124,
                      child: ColoredBox(
                          color: const Color(0xFFD0D0D0),
                          child: _avatar.isNotEmpty
                              ? Image.network(_avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _defaultAvatar())
                              : _defaultAvatar()))),
              if (!_teamMember)
                Positioned(
                    right: 0,
                    bottom: 3,
                    child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(
                            side: BorderSide(color: _purple, width: .7)),
                        child: IconButton(
                            tooltip: 'Edit profile photo',
                            onPressed: _uploading ? null : _changePhoto,
                            style: IconButton.styleFrom(
                                minimumSize: const Size.square(24),
                                maximumSize: const Size.square(24),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            constraints: const BoxConstraints.tightFor(
                                width: 24, height: 24),
                            padding: EdgeInsets.zero,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.camera_alt,
                                    color: _purple, size: 18)))),
            ])),
        const SizedBox(height: 14),
        Text(_displayName.isNotEmpty ? _displayName : 'Partner',
            style: _text(20, bold: true), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(_email, style: _text(15), textAlign: TextAlign.center),
      ]);

  Widget _defaultAvatar() => const Icon(Icons.person_outline_rounded,
      size: 64, color: Color(0xFF505050), semanticLabel: 'Partner profile');

  Widget _field(String label, String value, IconData icon) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(minHeight: 84),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 30, color: Colors.black)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: _text(14, color: const Color(0xFF484848))),
                const SizedBox(height: 5),
                Text(value.isNotEmpty ? value : 'Not provided',
                    style: _text(16, bold: true)),
              ])),
          const SizedBox(width: 8),
          const Icon(Icons.lock_outline_rounded,
              size: 25, color: Colors.black, semanticLabel: 'Read only'),
        ]),
      );

  Widget _supportNotice() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFA857C8))),
        child: Row(children: [
          const Icon(Icons.headset_mic_outlined, color: _purple, size: 36),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Need to update your details?',
                    style:
                        _text(20, bold: true, color: const Color(0xFFAC69C6))),
                const SizedBox(height: 10),
                Text(
                    'Profile details are locked after verification for security purposes. Contact support and our team will help you.',
                    style: _text(14, color: const Color(0xFFAC69C6))
                        .copyWith(height: 1.45)),
              ])),
        ]),
      );
}
