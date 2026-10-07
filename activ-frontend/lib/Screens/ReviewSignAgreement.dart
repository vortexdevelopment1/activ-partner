import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../Style/app_colors.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'ContactSupportScreen.dart';
import 'onboarding_widgets.dart';

class ReviewSignAgreement extends StatefulWidget {
  const ReviewSignAgreement({super.key, this.client});
  final http.Client? client;

  @override
  State<ReviewSignAgreement> createState() => _State();
}

class _State extends State<ReviewSignAgreement> {
  final _signature = TextEditingController();
  final _documentScroll = ScrollController();
  final _signingDate = DateTime.now();
  String _content = '';
  String? _error;
  bool _loading = true, _accepted = false, _submitting = false;
  bool _downloading = false;
  static const _purple = Color(0xFFA634FF);

  bool get _canFinish =>
      !_loading &&
      _content.isNotEmpty &&
      _accepted &&
      _signature.text.trim().isNotEmpty &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    _loadAgreement();
  }

  @override
  void dispose() {
    _signature.dispose();
    _documentScroll.dispose();
    super.dispose();
  }

  Future<void> _loadAgreement() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await (widget.client
                  ?.get(Uri.parse('$LEGAL_URL/partner_agreement')) ??
              http.get(Uri.parse('$LEGAL_URL/partner_agreement')))
          .timeout(const Duration(seconds: 15));
      _checkResponse(response, 'Unable to load the partnership agreement.');
      final raw = jsonDecode(response.body)['data']['content'] as String;
      final document = html.parse(raw);
      final content = _documentText(document.body!).trim();
      if (content.isEmpty) {
        throw Exception('The partnership agreement is not available yet.');
      }
      if (mounted) setState(() => _content = content);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  String _documentText(dom.Node node) {
    if (node is dom.Text) return node.data;
    if (node is dom.Element && ['script', 'style'].contains(node.localName)) {
      return '';
    }
    if (node is dom.Element && node.localName == 'br') return '\n';
    final text = node.nodes.map(_documentText).join();
    if (node is dom.Element &&
        ['h1', 'h2', 'h3', 'h4', 'p', 'div', 'li', 'tr']
            .contains(node.localName)) {
      return '$text\n\n';
    }
    return text;
  }

  void _checkResponse(http.Response response, String fallback) {
    if (response.statusCode == 200 || response.statusCode == 201) return;
    String message = fallback;
    try {
      final value = jsonDecode(response.body)['message'];
      if (value != null) {
        message = value is List ? value.join(', ') : value.toString();
      }
    } catch (_) {/* Non-JSON errors still show a useful message. */}
    throw Exception(message);
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final uri = Uri.parse('$LEGAL_URL/partner_agreement/download');
      final response = await (widget.client?.get(uri) ?? http.get(uri))
          .timeout(const Duration(seconds: 30));
      _checkResponse(response, 'Unable to download the partnership agreement.');
      final data = jsonDecode(response.body)['data'];
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save partnership agreement',
        fileName: data['filename'] as String? ?? 'activ-partner-agreement.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: base64Decode(data['base64'] as String),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _finish() async {
    if (!_canFinish) return;
    setState(() => _submitting = true);
    try {
      final venueId = await SharedPreference.readStr('venue_id');
      final token = await SharedPreference.readStr('jwt_token');
      if (venueId == null ||
          venueId.isEmpty ||
          token == null ||
          token.isEmpty) {
        throw Exception('Your session is missing. Please sign in again.');
      }
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      };
      final uri = Uri.parse('$BASE_URL/venues/$venueId/terms');
      final body = jsonEncode({
        'electronicSignature': _signature.text.trim(),
        'termsAccepted': true
      });
      final terms =
          await (widget.client?.patch(uri, headers: headers, body: body) ??
                  http.patch(uri, headers: headers, body: body))
              .timeout(const Duration(seconds: 30));
      _checkResponse(terms, 'Failed to accept the agreement.');
      final submitUri = Uri.parse('$BASE_URL/venues/$venueId/submit');
      final submit = await (widget.client?.post(submitUri, headers: headers) ??
              http.post(submitUri, headers: headers))
          .timeout(const Duration(seconds: 30));
      _checkResponse(submit, 'Failed to submit the venue.');
      if (!mounted) return;
      CommonUtilities.firstTimeLoginSignup = 'yes';
      CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
          context, ContactSupportScreen());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
        child: Column(children: [
          Expanded(
              child: SingleChildScrollView(
            key: const Key('agreement-page-scroll'),
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const OnboardingLogo(),
              getStepBarCount(1, 10, 10),
              const SizedBox(height: 25),
              Text('Review & Sign Partnership Agreement',
                  style: OnboardingStyles.heading.copyWith(fontSize: 25)),
              const SizedBox(height: 12),
              Text(
                  'Review your partnership agreement carefully before completing registration',
                  style: OnboardingStyles.body
                      .copyWith(fontSize: 16, height: 1.4)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gray)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('Partnership Agreement',
                                style: OnboardingStyles.heading
                                    .copyWith(fontSize: 18))),
                        IconButton(
                            tooltip: 'Download partnership agreement',
                            onPressed:
                                _loading || _content.isEmpty || _downloading
                                    ? null
                                    : _download,
                            icon: _downloading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.file_download_outlined,
                                    color: Colors.black)),
                      ]),
                      const SizedBox(height: 8),
                      SizedBox(
                          height: 290,
                          child: Container(
                            decoration: BoxDecoration(
                                border: Border.all(color: AppColors.gray),
                                borderRadius: BorderRadius.circular(8)),
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _error != null
                                    ? Center(
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(_error!,
                                                      textAlign:
                                                          TextAlign.center),
                                                  TextButton(
                                                      onPressed: _loadAgreement,
                                                      child:
                                                          const Text('Retry')),
                                                ])))
                                    : Scrollbar(
                                        controller: _documentScroll,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                            controller: _documentScroll,
                                            padding: const EdgeInsets.all(12),
                                            child: SelectableText(_content,
                                                style: OnboardingStyles.body
                                                    .copyWith(
                                                        fontSize: 16,
                                                        height: 1.45)))),
                          )),
                      const SizedBox(height: 12),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                                value: _accepted,
                                activeColor: _purple,
                                side:
                                    const BorderSide(color: _purple, width: 2),
                                onChanged:
                                    _loading || _content.isEmpty || _submitting
                                        ? null
                                        : (value) => setState(
                                            () => _accepted = value ?? false)),
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text.rich(
                                        TextSpan(children: [
                                          const TextSpan(
                                              text: 'I agree to the '),
                                          TextSpan(
                                              text: 'Partnership Agreement',
                                              style: OnboardingStyles.body
                                                  .copyWith(
                                                      color: _purple,
                                                      fontSize: 15)),
                                        ]),
                                        style: OnboardingStyles.body.copyWith(
                                            fontSize: 15, height: 1.4)))),
                          ]),
                    ]),
              ),
              const SizedBox(height: 24),
              Container(
                key: const Key('electronic-signature-panel'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.gray),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Electronic Signature',
                          style:
                              OnboardingStyles.heading.copyWith(fontSize: 18)),
                      const SizedBox(height: 14),
                      Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Full Name'),
                            TextSpan(
                                text: '*',
                                style: OnboardingStyles.body
                                    .copyWith(color: Colors.red)),
                          ]),
                          style: OnboardingStyles.body.copyWith(fontSize: 16)),
                      const SizedBox(height: 10),
                      TextFormField(
                          key: const Key('agreement-signature'),
                          controller: _signature,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          style: OnboardingStyles.body.copyWith(fontSize: 16),
                          decoration: OnboardingStyles.inputDecoration(
                              hintText: 'Enter Full Name'),
                          onChanged: (_) => setState(() {})),
                      const SizedBox(height: 12),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.help_outline,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(
                                    'Type your full name as per govt records',
                                    style: OnboardingStyles.body.copyWith(
                                        color: Colors.grey, fontSize: 14))),
                          ]),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F0FC),
                          border: Border.all(color: AppColors.gray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _signature.text.trim().isEmpty
                                      ? 'Your Sign'
                                      : _signature.text.trim(),
                                  key: const Key('signature-preview'),
                                  style: OnboardingStyles.heading.copyWith(
                                      fontSize: 20,
                                      fontStyle: FontStyle.italic,
                                      color: _signature.text.trim().isEmpty
                                          ? Colors.grey
                                          : AppColors.darkBlack)),
                              const SizedBox(height: 6),
                              Text(
                                  'Signed on  ${DateFormat('MMMM dd, yyyy', 'en_US').format(_signingDate)}',
                                  key: const Key('signature-date')),
                            ]),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: _purple),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            'Note: By signing, you acknowledge that this constitutes a legally binding electronic agreement under applicable Indian laws, equivalent to a handwritten signature.',
                            style: OnboardingStyles.body.copyWith(
                                color: const Color(0xFFA16BC5),
                                fontSize: 15,
                                height: 1.5)),
                      ),
                    ]),
              ),
            ]),
          )),
          Container(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.gray))),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: OnboardingButton(
                        label: 'Back',
                        outlined: true,
                        onPressed:
                            _submitting ? null : () => Navigator.pop(context))),
                const SizedBox(width: 16),
                Expanded(
                    flex: 7,
                    child: OnboardingButton(
                        label: 'Finish',
                        loading: _submitting,
                        disabledBackgroundColor: const Color(0xFF999999),
                        disabledForegroundColor: const Color(0xFFCCCCCC),
                        onPressed: _canFinish ? _finish : null)),
              ])),
        ]),
      );
}
