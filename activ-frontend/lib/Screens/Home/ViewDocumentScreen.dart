import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../ContactSupportFormScreen.dart';

class ViewDocumentScreen extends StatefulWidget {
  const ViewDocumentScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<ViewDocumentScreen> createState() => _ViewDocumentScreenState();
}

class _ViewDocumentScreenState extends State<ViewDocumentScreen> {
  static const _background = Color(0xFFF0F7D2);
  static const _purple = Color(0xFFA536E5);
  static const _mutedPurple = Color(0xFFAC69C6);
  final _formKey = GlobalKey<FormState>();
  final _gstNumber = TextEditingController();
  final _gstName = TextEditingController();
  Map<String, dynamic> _partner = {};
  Map<String, dynamic>? _gstRequest;
  PlatformFile? _certificate;
  bool _loading = true, _submitting = false;
  String? _error, _gstError;

  bool get _verified => _partner['isVerified'] == true;
  bool get _gstVerified =>
      _partner['gstVerifiedAt'] != null || _partner['gstIsVerified'] == true;
  bool get _gstPending => _gstRequest?['status'] == 'pending';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _gstNumber.dispose();
    _gstName.dispose();
    super.dispose();
  }

  Future<http.Response> _get(String url, String token) =>
      (widget.client?.get ?? http.get)(Uri.parse(url), headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
      _gstError = null;
    });
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final response = await _get(AUTH_PROFILE_URL, token);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Unable to load documents');
      }
      final data = jsonDecode(response.body)['data'];
      _partner = Map<String, dynamic>.from(data['partner'] ?? data);
      final selectedVenueId = await SharedPreference.readStr('venue_id');
      final documents = _partner['legalDocuments'];
      if (documents is List) {
        final records = documents.whereType<Map>().toList();
        final matching = records.where(
            (record) => record['venueId']?.toString() == selectedVenueId);
        final available = records.where((record) => [
              'aadhaarCardUrl',
              'panCardUrl',
              'gstinDocUrl'
            ].any((key) => (record[key] ?? '').toString().trim().isNotEmpty));
        final selected = matching.isNotEmpty
            ? matching.first
            : (selectedVenueId == null || selectedVenueId.isEmpty) &&
                    available.isNotEmpty
                ? available.first
                : null;
        if (selected != null) {
          _partner.addAll(Map<String, dynamic>.from(selected));
        }
      }
      try {
        final gst = await _get('$BASE_URL/partners/gst-verification/my', token);
        if (gst.statusCode != 200) throw Exception('GST status unavailable');
        final request = jsonDecode(gst.body)['data'];
        _gstRequest =
            request is Map ? Map<String, dynamic>.from(request) : null;
        if (!mounted) return;
        _gstNumber.text =
            (_gstRequest?['gstNumber'] ?? _partner['gstNumber'] ?? '')
                .toString();
        _gstName.text =
            (_gstRequest?['gstName'] ?? _partner['gstName'] ?? '').toString();
      } catch (_) {
        _gstError =
            'Unable to load GST status. Please retry before submitting.';
      }
    } catch (_) {
      _error = 'Unable to load your documents. Please try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _browse() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024 || file.bytes == null) {
        CommonUtilities.createSnackBar(
            context, 'Choose a PDF, PNG or JPG file up to 5 MB.');
        return;
      }
      setState(() => _certificate = file);
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to open the file picker.');
      }
    }
  }

  Future<void> _submitGst() async {
    if (!_formKey.currentState!.validate()) return;
    if (_certificate == null) {
      CommonUtilities.createSnackBar(
          context, 'Please upload your GST certificate.');
      return;
    }
    setState(() => _submitting = true);
    final client = widget.client ?? http.Client();
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final request = http.MultipartRequest(
          'POST', Uri.parse('$BASE_URL/partners/gst-verification'))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['gstNumber'] = _gstNumber.text.trim().toUpperCase()
        ..fields['gstName'] = _gstName.text.trim()
        ..files.add(http.MultipartFile.fromBytes('gstDoc', _certificate!.bytes!,
            filename: _certificate!.name));
      final response = await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 30)));
      if (response.statusCode != 200 && response.statusCode != 201) {
        final message = jsonDecode(response.body)['message'];
        throw Exception(message is List
            ? message.join('\n')
            : message ?? 'Submission failed.');
      }
      if (!mounted) return;
      CommonUtilities.createSnackBar(
          context, 'GST certificate submitted for verification.');
      await _loadDocuments();
    } catch (error) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (widget.client == null) client.close();
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _viewDocument(String url) async {
    try {
      final uri = Uri.parse(BASE_URL).resolve(url);
      if (!['http', 'https'].contains(uri.scheme) ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Cannot open document');
      }
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to open this document.');
      }
    }
  }

  TextStyle _text(double size,
          {bool bold = false, Color color = const Color(0xFF202020)}) =>
      TextStyle(
          fontFamily: 'Satoshi',
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color);

  BoxDecoration _panel({bool outlined = false}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(outlined ? 8 : 12),
      border: outlined ? Border.all(color: _purple) : null);

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
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: _header()),
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
                                      style: _text(15),
                                      textAlign: TextAlign.center),
                                  TextButton(
                                      onPressed: _loadDocuments,
                                      child: const Text('Retry')),
                                ]))
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              children: [
                                  _businessBanner(),
                                  const SizedBox(height: 24),
                                  Text(
                                      _verified
                                          ? 'Verified Documents'
                                          : 'Identity Documents',
                                      style: _text(18, bold: true)),
                                  const SizedBox(height: 6),
                                  Text(
                                      _verified
                                          ? 'Your identity documents are verified and locked for security.'
                                          : 'Your identity documents will be locked once verified.',
                                      style: _text(14)),
                                  const SizedBox(height: 18),
                                  _documentCard('Aadhaar Card',
                                      'aadhaarCardUrl', 'aadhaarVerifiedAt'),
                                  _documentCard('PAN Card', 'panCardUrl',
                                      'panVerifiedAt'),
                                  const SizedBox(height: 8),
                                  Text('GST Details',
                                      style: _text(18, bold: true)),
                                  const SizedBox(height: 6),
                                  Text(
                                      'Add your GST details for invoicing and tax compliance.',
                                      style: _text(14)),
                                  const SizedBox(height: 18),
                                  if ((_partner['gstinDocUrl'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    _documentCard('GST Certificate',
                                        'gstinDocUrl', 'gstVerifiedAt'),
                                  if (!_gstVerified) _gstForm(),
                                  const SizedBox(height: 20),
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

  Widget _header() => Row(children: [
        Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: Colors.black12,
            child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back, size: 26))),
        const SizedBox(width: 16),
        Expanded(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Business & Verification',
                    style: _text(24, bold: true)))),
      ]);

  Widget _businessBanner() => Container(
        decoration: _panel(outlined: true),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.verified_user_outlined, color: _purple, size: 34),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_verified ? 'Verified Business' : 'Verification Pending',
                    style: _text(16, bold: true, color: _mutedPurple)),
                const SizedBox(height: 6),
                Text(
                    _verified
                        ? 'Your identity documents have been verified by ACTIV.'
                        : 'Your identity documents are awaiting verification by ACTIV.',
                    style: _text(12, color: _mutedPurple)),
              ])),
        ]),
      );

  Widget _documentCard(String label, String urlKey, String dateKey) {
    final url = (_partner[urlKey] ?? '').toString();
    final verified = url.isNotEmpty &&
        (_partner[dateKey] != null ||
            (dateKey == 'gstVerifiedAt' ? _gstVerified : _verified));
    // The API exposes verification timestamps; do not invent upload dates.
    final uploaded = DateTime.tryParse(
        (_partner['${urlKey.replaceFirst('Url', '')}UploadedAt'] ?? '')
            .toString());
    final verifiedAt = DateTime.tryParse((_partner[dateKey] ?? '').toString());
    final updated =
        DateTime.tryParse((_partner['documentsUpdatedAt'] ?? '').toString());
    final date = uploaded ?? verifiedAt ?? updated;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: _panel(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: _text(18, bold: true))),
          if (verified)
            Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                    color: Color(0xFFF3F3F3), shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline_rounded, size: 20)),
        ]),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(verified ? Icons.verified_user : Icons.hourglass_top,
                  size: 16,
                  color: verified
                      ? const Color(0xFF19BC45)
                      : Colors.amber.shade800),
              const SizedBox(width: 6),
              Text(
                  verified
                      ? 'Verified'
                      : url.isEmpty
                          ? 'Not uploaded'
                          : 'Pending',
                  style: _text(12)),
            ])),
        const SizedBox(height: 28),
        LayoutBuilder(builder: (context, constraints) {
          final details =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                uploaded != null
                    ? 'Uploaded On'
                    : verifiedAt != null
                        ? 'Verified On'
                        : updated != null
                            ? 'Updated On'
                            : 'Uploaded On',
                style: _text(13)),
            const SizedBox(height: 8),
            Text(
                date == null
                    ? 'Not available'
                    : DateFormat('d MMM yyyy').format(date.toLocal()),
                style: _text(14)),
          ]);
          final button = OutlinedButton(
              onPressed: url.isEmpty ? null : () => _viewDocument(url),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _purple,
                  side: BorderSide(color: url.isEmpty ? Colors.grey : _purple),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('View Document',
                  style: _text(16,
                      bold: true, color: url.isEmpty ? Colors.grey : _purple)));
          return constraints.maxWidth < 280
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 10), button])
              : Row(children: [
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  button
                ]);
        }),
        if (verified) ...[
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE0E0E0)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_outline_rounded,
                size: 30, color: Color(0xFF484848)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    'This document is locked after verification. Contact ACTIV support to request changes.',
                    style: _text(12, color: const Color(0xFF484848)))),
          ]),
        ],
      ]),
    );
  }

  Widget _gstForm() => Container(
        decoration: _panel(outlined: true),
        padding: const EdgeInsets.all(18),
        child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.post_add_outlined, color: _purple, size: 76),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          _gstPending
                              ? 'GST Verification Pending'
                              : 'Add GSTIN',
                          style: _text(18, bold: true)),
                      const SizedBox(height: 6),
                      Text(
                          'Add GST details to enable business invoicing and tax compliance',
                          style: _text(14)),
                    ])),
              ]),
              const SizedBox(height: 22),
              if (_gstError != null) ...[
                Text(_gstError!, style: _text(14, color: Colors.red.shade700)),
                TextButton(
                    onPressed: _loadDocuments, child: const Text('Retry')),
              ],
              if (_gstRequest?['status'] == 'rejected') ...[
                Text(
                    'GST verification was rejected. ${_gstRequest?['adminNotes'] ?? ''}',
                    style: _text(14, color: Colors.red.shade700)),
                const SizedBox(height: 12),
              ],
              Text('GSTIN Number', style: _text(14)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _gstNumber,
                  readOnly: _gstPending || _submitting,
                  textCapitalization: TextCapitalization.characters,
                  style: _text(14),
                  decoration: _input('e.g. 27AAPFU0939F1ZV'),
                  validator: (value) =>
                      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
                              .hasMatch((value ?? '').trim().toUpperCase())
                          ? null
                          : 'Enter a valid GSTIN number.'),
              const SizedBox(height: 22),
              Text('Business Name (As per GST)', style: _text(14)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _gstName,
                  readOnly: _gstPending || _submitting,
                  style: _text(14),
                  decoration: _input('Enter business name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter the business name.'
                      : null),
              const SizedBox(height: 24),
              if (!_gstPending)
                Center(
                    child: SizedBox(
                        width: 180,
                        child: OutlinedButton(
                            onPressed: _submitting ? null : _browse,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: _purple,
                                side: const BorderSide(color: _purple),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: Text('Browse',
                                style:
                                    _text(16, bold: true, color: _purple))))),
              if (_certificate != null)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_certificate!.name,
                        style: _text(14), textAlign: TextAlign.center)),
              if (_gstPending &&
                  (_gstRequest?['gstDocUrl'] ?? '').toString().isNotEmpty)
                Center(
                    child: TextButton(
                        onPressed: () =>
                            _viewDocument(_gstRequest!['gstDocUrl'].toString()),
                        child: const Text('View Certificate'))),
              const SizedBox(height: 18),
              Center(
                  child: Text(
                      _gstPending
                          ? 'Your GST certificate is under review'
                          : 'Upload your GST Certificate',
                      style: _text(16, bold: true),
                      textAlign: TextAlign.center)),
              const SizedBox(height: 6),
              Center(
                  child: Text(
                      'Please upload clear wide-angle photos in PDF, PNG or JPG formats up-to 5 MB',
                      style: _text(14, color: const Color(0xFF484848)),
                      textAlign: TextAlign.center)),
              const SizedBox(height: 22),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _gstPending || _submitting || _gstError != null
                          ? null
                          : _submitGst,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: const Color(0xFFD8F34A),
                          minimumSize: const Size(0, 58),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFFD8F34A)))
                          : Text(
                              _gstPending
                                  ? 'Verification Pending'
                                  : 'Submit for Verification',
                              textAlign: TextAlign.center,
                              style: _text(18,
                                  bold: true,
                                  color: const Color(0xFFD8F34A))))),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.info_outline, color: Color(0xFF646464)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Verification may take up to 24-48 hours.',
                        style: _text(14, color: const Color(0xFF484848)))),
              ]),
            ])),
      );

  InputDecoration _input(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: _text(14, color: Colors.grey),
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5DADA))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _purple)));

  Widget _supportNotice() => Container(
        decoration: _panel(outlined: true),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          const Icon(Icons.headset_mic_outlined, color: _purple, size: 36),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Need to make changes?',
                    style: _text(20, bold: true, color: _mutedPurple)),
                const SizedBox(height: 10),
                Text(
                    'Document changes are not allowed once verified. Contact ACTIV Support for any updates.',
                    style:
                        _text(14, color: _mutedPurple).copyWith(height: 1.45)),
              ])),
        ]),
      );
}
