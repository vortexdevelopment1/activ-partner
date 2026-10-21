import 'dart:async';
import 'dart:convert';

import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';

const _background = Color(0xFFF7FBE3);
const _purple = Color(0xFFA536E5);
const _lime = Color(0xFFD8F34A);
TextStyle _text(double size,
        {bool bold = false, Color color = const Color(0xFF202020)}) =>
    TextStyle(
        fontFamily: 'Satoshi',
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color);

Widget _header(BuildContext context, String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(children: [
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
                child: Text(title, style: _text(24, bold: true)))),
      ]),
    );

Widget _button(String label, VoidCallback? onPressed, {bool busy = false}) =>
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: _lime,
            minimumSize: const Size(0, 54),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: _lime, strokeWidth: 2))
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: _text(18, bold: true, color: _lime))),
      ),
    );

Widget _shell(BuildContext context, String title, Widget body,
        {Widget? bottom}) =>
    AnnotatedRegion<SystemUiOverlayStyle>(
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
              _header(context, title),
              Expanded(child: body),
              if (bottom != null)
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: bottom),
            ]),
          )))),
    );

String _message(http.Response response) {
  try {
    final message = jsonDecode(response.body)['message'];
    if (message is List) return message.join('\n');
    if (message != null) return message.toString();
  } catch (_) {}
  return 'Unable to save your bank account. Please try again.';
}

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key, this.client, this.pickCheque});
  final http.Client? client;
  final Future<PlatformFile?> Function()? pickCheque;

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;
  num? _earnings, _credited;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final headers = {
        'Authorization': 'Bearer $token',
        'accept': 'application/json'
      };
      final uri = Uri.parse('$BASE_URL/bank-accounts/my');
      final response =
          await (widget.client?.get ?? http.get)(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint(
            'Bank account load failed: $uri, HTTP ${response.statusCode}');
        if (response.statusCode == 401) {
          throw StateError('Your session has expired. Please sign in again.');
        }
        if (response.statusCode == 403) {
          throw StateError(
              'Bank details are only available to the venue partner.');
        }
        throw StateError(
            'The bank account service is temporarily unavailable. Please try again.');
      }
      final data = jsonDecode(response.body)['data'];
      if (data is! List) throw Exception('Invalid bank account response');
      _accounts = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _earnings = _credited = null;
      try {
        final summary = await (widget.client?.get ?? http.get)(
                Uri.parse('$BASE_URL/bank-accounts/summary'),
                headers: headers)
            .timeout(const Duration(seconds: 20));
        if (summary.statusCode == 200) {
          final totals = jsonDecode(summary.body)['data'];
          _earnings = totals['totalEarnings'] as num?;
          _credited = totals['totalCredited'] as num?;
        }
      } catch (_) {}
    } on StateError catch (error) {
      _error = error.message;
    } on TimeoutException {
      _error = 'The connection timed out. Please try again.';
    } catch (error) {
      debugPrint('Bank account load failed (${error.runtimeType}).');
      _error = 'Unable to load bank accounts. Please try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => AddBankAccountScreen(
                client: widget.client, pickCheque: widget.pickCheque)));
    if (saved == true && mounted) await _load();
  }

  Future<void> _viewCheque(String url) async {
    try {
      final uri = Uri.parse(BASE_URL).resolve(url);
      if (!['https', 'http'].contains(uri.scheme) ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Cannot open cheque');
      }
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to open the cancelled cheque.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _shell(
      context,
      'Bank Account Details',
      _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: _text(14), textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 8),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: _stat(
                                              'Total Earnings',
                                              _earnings,
                                              Icons
                                                  .account_balance_wallet_outlined)),
                                      const SizedBox(width: 16),
                                      Expanded(
                                          child: _stat(
                                              'Total Credited',
                                              _credited,
                                              Icons.currency_exchange))
                                    ]),
                                    const SizedBox(height: 16),
                                    if (_accounts.isEmpty) ...[
                                      Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 28),
                                          decoration: _card(),
                                          child: Column(children: [
                                            const Icon(
                                                Icons.lock_outline_rounded,
                                                size: 48),
                                            const SizedBox(height: 14),
                                            Text('Add Bank Account',
                                                style: _text(24, bold: true),
                                                textAlign: TextAlign.center),
                                            const SizedBox(height: 10),
                                            Text(
                                                'Add your bank account to receive payouts.',
                                                style: _text(16,
                                                    color: const Color(
                                                        0xFF484848)),
                                                textAlign: TextAlign.center),
                                          ])),
                                      const SizedBox(height: 24),
                                      Text('Why do we need bank details?',
                                          style: _text(18, bold: true)),
                                      const SizedBox(height: 8),
                                      Text(
                                          'To initiate automatic payout (T+2) to your',
                                          style: _text(14)),
                                      const SizedBox(height: 8),
                                      Text('registered bank account.',
                                          style: _text(18,
                                              bold: true, color: _purple)),
                                    ] else
                                      ..._accounts.map(_accountCard),
                                  ]),
                            ),
                          ))),
      bottom: _loading || _error != null
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              if (_accounts.isEmpty) ...[
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: _card(outlined: true),
                    child: Row(children: [
                      const Icon(Icons.warning_rounded,
                          color: _purple, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(
                              'Adding bank account is mandatory to receive payouts',
                              style: _text(16, color: const Color(0xFFAC69C6))))
                    ])),
                const SizedBox(height: 12),
              ],
              _button('Add Bank Account', _add),
            ]),
    );
  }

  BoxDecoration _card({bool outlined = false}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(outlined ? 8 : 12),
      border: Border.all(color: outlined ? _purple : const Color(0xFFD5DADA)));

  Widget _stat(String label, num? value, IconData icon) => Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(16),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(label, style: _text(15)))),
            const SizedBox(width: 4),
            Icon(icon, size: 20, color: const Color(0xFF549A68))
          ]),
          const SizedBox(height: 24),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: value == null
                  ? Text('--', style: _text(24, bold: true))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.currency_rupee,
                          size: 24, semanticLabel: 'Rupees'),
                      const SizedBox(width: 4),
                      Text(NumberFormat('#,##0.##', 'en_IN').format(value),
                          style: _text(24, bold: true)),
                    ])),
        ]),
      );

  Widget _accountCard(Map<String, dynamic> account) {
    final status = (account['status'] ?? '').toString().toLowerCase();
    final number = (account['accountNumber'] ?? '').toString();
    final last4 =
        number.length > 4 ? number.substring(number.length - 4) : number;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openAccount(account),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 18),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Bank Details', style: _text(18, bold: true))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: status == 'approved'
                      ? Colors.green
                      : status == 'rejected'
                          ? const Color(0xFFFF5757)
                          : _purple,
                  borderRadius: BorderRadius.circular(20)),
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                  status == 'approved'
                      ? 'Verified'
                      : status == 'rejected'
                          ? 'Rejected'
                          : 'Under Review',
                  style: _text(13, bold: true, color: Colors.white)))),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 24)
        ]),
        const SizedBox(height: 16),
        Text(account['accountHolderName'] ?? '-', style: _text(16)),
        const SizedBox(height: 10),
        Text(account['bankName'] ?? '-', style: _text(16)),
        const SizedBox(height: 10),
        Text('A/C No. XXXX XXXX $last4', style: _text(16)),
        const SizedBox(height: 10),
        Text('IFSC: ${account['ifscCode'] ?? '-'}', style: _text(16)),
        ]),
      ),
    );
  }

  void _openAccount(Map<String, dynamic> account) {
    final status = (account['status'] ?? '').toString().toLowerCase();
    final submittedAt = DateTime.tryParse(
            (account['createdAt'] ?? '').toString()) ??
        DateTime.now();
    final Widget page = status == 'under_review'
        ? BankVerificationProgressScreen(submittedAt: submittedAt)
        : status == 'approved'
            ? BankAccountVerifiedScreen(account: account)
            : BankAccountRejectedScreen(
                account: account,
                client: widget.client,
                pickCheque: widget.pickCheque);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class BankAccountVerifiedScreen extends StatelessWidget {
  const BankAccountVerifiedScreen({super.key, required this.account});

  final Map<String, dynamic> account;

  @override
  Widget build(BuildContext context) => _accountResultScreen(
        context,
        title: 'Bank Account Verified',
        icon: Icons.verified,
        iconColor: Colors.green,
        heading: 'Bank Account Verified',
        message: 'Your account has been verified and\nlinked successfully.',
        account: account,
        bottomLabel: 'Back',
      );
}

class BankAccountRejectedScreen extends StatelessWidget {
  const BankAccountRejectedScreen({
    super.key,
    required this.account,
    this.client,
    this.pickCheque,
  });

  final Map<String, dynamic> account;
  final http.Client? client;
  final Future<PlatformFile?> Function()? pickCheque;

  @override
  Widget build(BuildContext context) => _accountResultScreen(
        context,
        title: 'Bank Account Not Verified',
        icon: Icons.cancel,
        iconColor: const Color(0xFFFF5757),
        heading: 'Bank Account Not Verified',
        message: 'Your bank account could not be verified.',
        account: account,
        client: client,
        pickCheque: pickCheque,
        rejectionReason:
            (account['rejectionReason'] ?? 'Please submit corrected details.')
                .toString(),
        bottomLabel: 'Back',
        showUpdateButton: true,
      );
}

Widget _accountResultScreen(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Color iconColor,
  required String heading,
  required String message,
  required Map<String, dynamic> account,
  required String bottomLabel,
  String? rejectionReason,
  bool showUpdateButton = false,
  http.Client? client,
  Future<PlatformFile?> Function()? pickCheque,
}) {
  final number = (account['accountNumber'] ?? '').toString();
  final last4 = number.length > 4 ? number.substring(number.length - 4) : number;
  return _shell(
    context,
    title,
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(children: [
        const SizedBox(height: 18),
          Icon(icon, size: 88, color: iconColor),
        const SizedBox(height: 18),
        Text(heading, style: _text(24, bold: true), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(message,
            style: _text(16, color: const Color(0xFF484848)),
            textAlign: TextAlign.center),
        const SizedBox(height: 26),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFD5DADA)),
                borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bank Details', style: _text(18, bold: true)),
              const SizedBox(height: 14),
              Text(account['accountHolderName'] ?? '-', style: _text(16)),
              const SizedBox(height: 8),
              Text(account['bankName'] ?? '-', style: _text(16)),
              const SizedBox(height: 8),
              Text('A/C No. XXXX XXXX $last4', style: _text(16)),
              const SizedBox(height: 8),
              Text('IFSC: ${account['ifscCode'] ?? '-'}', style: _text(16)),
            ])),
        if (rejectionReason != null) ...[
          const SizedBox(height: 16),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  border: Border.all(color: const Color(0xFFFF7474)),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rejection Reason',
                    style: _text(18, bold: true, color: Colors.red.shade800)),
                const SizedBox(height: 6),
                Text(rejectionReason!,
                    style: _text(14, color: Colors.red.shade800)),
              ])),
        ],
      ]),
    ),
    bottom: showUpdateButton
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            _button(
                'Update Bank Details',
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AddBankAccountScreen(
                            isUpdate: true,
                            existingAccount: account,
                            client: client,
                            pickCheque: pickCheque)))),
            const SizedBox(height: 10),
            _button(bottomLabel, () => Navigator.of(context).pop()),
          ])
        : _button(bottomLabel, () => Navigator.of(context).pop()),
  );
}

class AddBankAccountScreen extends StatefulWidget {
  const AddBankAccountScreen({
    super.key,
    this.client,
    this.pickCheque,
    this.existingAccount,
    this.isUpdate = false,
  });
  final http.Client? client;
  final Future<PlatformFile?> Function()? pickCheque;
  final Map<String, dynamic>? existingAccount;
  final bool isUpdate;
  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _holder = TextEditingController(),
      _bank = TextEditingController(),
      _number = TextEditingController(),
      _confirm = TextEditingController(),
      _ifsc = TextEditingController(),
      _branch = TextEditingController();
  String? _type;
  PlatformFile? _cheque;
  bool _saving = false, _lookingUp = false, _showValidation = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _restoreChequeDraft();
    final account = widget.existingAccount;
    if (account != null) {
      _holder.text = (account['accountHolderName'] ?? '').toString();
      _bank.text = (account['bankName'] ?? '').toString();
      _number.text = (account['accountNumber'] ?? '').toString();
      _confirm.text = _number.text;
      _ifsc.text = (account['ifscCode'] ?? '').toString();
      final type = (account['accountType'] ?? '').toString();
      _type = ['Saving Account', 'Current Account'].contains(type) ? type : null;
      _branch.text = (account['branchName'] ?? '').toString();
    }
  }

  String get _chequeDraftKey =>
      'bank_account_cheque_draft_${widget.existingAccount?['id'] ?? 'new'}';

  Future<void> _restoreChequeDraft() async {
    final encoded = await SharedPreference.readStr('${_chequeDraftKey}_bytes');
    final name = await SharedPreference.readStr('${_chequeDraftKey}_name');
    final sizeValue = await SharedPreference.readStr('${_chequeDraftKey}_size');
    if (encoded == null || name == null || !mounted) return;
    try {
      final bytes = base64Decode(encoded);
      final size = int.tryParse(sizeValue ?? '') ?? bytes.length;
      setState(() => _cheque = PlatformFile(name: name, size: size, bytes: bytes));
    } catch (_) {
      await _clearChequeDraft();
    }
  }

  Future<void> _persistChequeDraft(PlatformFile file) async {
    if (file.bytes == null) return;
    await SharedPreference.addStringToSF(
        '${_chequeDraftKey}_bytes', base64Encode(file.bytes!));
    await SharedPreference.addStringToSF('${_chequeDraftKey}_name', file.name);
    await SharedPreference.addStringToSF(
        '${_chequeDraftKey}_size', file.size.toString());
  }

  Future<void> _clearChequeDraft() async {
    await SharedPreference.remove('${_chequeDraftKey}_bytes');
    await SharedPreference.remove('${_chequeDraftKey}_name');
    await SharedPreference.remove('${_chequeDraftKey}_size');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final controller in [
      _holder,
      _bank,
      _number,
      _confirm,
      _ifsc,
      _branch
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _ifscChanged(String code) {
    _validateLive();
    _debounce?.cancel();
    setState(() => _lookingUp = false);
    if (RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(code.toUpperCase())) {
      _debounce = Timer(
          const Duration(milliseconds: 400), () => _lookup(code.toUpperCase()));
    }
  }

  void _validateLive() {
    if (!_showValidation) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _form.currentState?.validate();
    });
  }

  Future<void> _lookup(String code) async {
    if (!mounted || _saving) return;
    setState(() => _lookingUp = true);
    try {
      final response = await (widget.client?.get ??
              http.get)(Uri.parse('https://ifsc.razorpay.com/$code'))
          .timeout(const Duration(seconds: 10));
      if (!mounted || _saving || _ifsc.text.toUpperCase() != code) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _bank.text = (data['BANK'] ?? '').toString();
        _branch.text = (data['BRANCH'] ?? '').toString();
        _validateLive();
      }
    } catch (_) {
      /* Bank and branch remain editable if lookup is unavailable. */
    } finally {
      if (mounted && _ifsc.text.toUpperCase() == code) {
        setState(() => _lookingUp = false);
      }
    }
  }

  Future<void> _browse() async {
    try {
      final file = widget.pickCheque != null
          ? await widget.pickCheque!()
          : (await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                  withData: true))
              ?.files
              .single;
      if (!mounted || file == null) return;
      if (file.size > 5 * 1024 * 1024 ||
          file.bytes == null ||
          !['jpg', 'jpeg', 'png', 'pdf']
              .contains(file.extension?.toLowerCase())) {
        CommonUtilities.createSnackBar(
            context, 'Choose a JPG, JPEG, PNG or PDF up to 5 MB.');
        return;
      }
      setState(() => _cheque = file);
      await _persistChequeDraft(file);
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to open the file picker.');
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _showValidation = true);
    if (!_form.currentState!.validate()) return;
    if (_cheque == null) {
      CommonUtilities.createSnackBar(
          context, 'Please upload a cancelled cheque.');
      return;
    }
    setState(() => _saving = true);
    _debounce?.cancel();
    final client = widget.client ?? http.Client();
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final endpoint = widget.isUpdate
          ? '$BASE_URL/bank-accounts/${widget.existingAccount!['id']}'
          : '$BASE_URL/bank-accounts';
      final request = http.MultipartRequest(
          widget.isUpdate ? 'PATCH' : 'POST', Uri.parse(endpoint))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields.addAll({
          'accountHolderName': _holder.text.trim(),
          'bankName': _bank.text.trim(),
          'accountNumber': _number.text.trim(),
          'ifscCode': _ifsc.text.trim().toUpperCase(),
          'accountType': _type!,
          if (_branch.text.trim().isNotEmpty) 'branchName': _branch.text.trim()
        })
        ..files.add(http.MultipartFile.fromBytes(
            'cancelledCheque', _cheque!.bytes!,
            filename: _cheque!.name));
      final response = await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 30)));
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        CommonUtilities.createSnackBar(context, _message(response));
        return;
      }
      if (widget.isUpdate) {
        await _clearChequeDraft();
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) => BankAccountScreen(
                    client: widget.client, pickCheque: widget.pickCheque)),
            (route) => route.isFirst);
      } else {
        await _clearChequeDraft();
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => BankVerificationProgressScreen(
                    submittedAt: DateTime.now())));
      }
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to save your bank account. Please try again.');
      }
    } finally {
      if (widget.client == null) client.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _input(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: _text(14, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5DADA))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _purple)));

  Widget _label(String label, {bool required = true}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(text: label, style: _text(16), children: [
        if (required)
          const TextSpan(text: '*', style: TextStyle(color: Color(0xFFDB8181))),
      ])));

  Widget _browseButton() => SizedBox(
      width: 180,
      child: OutlinedButton(
          onPressed: _saving ? null : _browse,
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _purple),
              foregroundColor: _purple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: Text('Browse',
              style: _text(18, bold: true, color: _purple))));

  Widget _chequeUploadBox() {
    final content = _cheque == null
        ? Column(children: [
            const Icon(Icons.photo_library_outlined, size: 64),
            const SizedBox(height: 16),
            Text('Upload Cancelled Cheque',
                style: _text(18, bold: true), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('JPG, JPEG, PNG or PDF (Max 5MB)',
                style: _text(14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _browseButton(),
          ])
        : Padding(
            padding: const EdgeInsets.all(12), child: _selectedCheque());

    if (_cheque != null) {
      return Container(
          width: double.infinity,
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _purple),
              borderRadius: BorderRadius.circular(12)),
          child: content);
    }
    return DottedBorder(
        color: _purple,
        dashPattern: const [8, 5],
        borderType: BorderType.RRect,
        radius: const Radius.circular(12),
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: content));
  }

  Widget _selectedCheque() {
    final file = _cheque!;
    final extension = file.extension?.toLowerCase();
    final isImage = file.bytes != null &&
        ['jpg', 'jpeg', 'png'].contains(extension);
    final size = file.size >= 1024 * 1024
        ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(file.size / 1024).toStringAsFixed(0)} KB';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isImage)
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(file.bytes!,
                width: double.infinity, height: 130, fit: BoxFit.cover))
      else
        Container(
            height: 90,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.picture_as_pdf_outlined, size: 48)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: Text(file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(14, bold: true))),
        IconButton(
            tooltip: 'Remove file',
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _cheque = null);
                    await _clearChequeDraft();
                  },
            icon: const Icon(Icons.close, size: 22)),
      ]),
      Text(size, style: _text(12, color: Colors.grey.shade700)),
    ]);
  }

  Widget _field(String label, String hint, TextEditingController controller,
          {bool required = true,
          bool numeric = false,
          String? Function(String?)? validator,
          bool ifsc = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label(label, required: required),
            TextFormField(
                key: ValueKey(label),
                controller: controller,
                enabled: !_saving,
                style: _text(14),
                decoration: _input(hint),
                keyboardType:
                    numeric ? TextInputType.number : TextInputType.text,
                textCapitalization: ifsc
                    ? TextCapitalization.characters
                    : TextCapitalization.words,
                inputFormatters:
                    numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
                onChanged: ifsc ? _ifscChanged : (_) => _validateLive(),
                validator: validator ??
                    (value) => required && (value ?? '').trim().isEmpty
                        ? 'Enter $label.'
                        : null),
          ]));

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: _shell(
        context,
      widget.isUpdate ? 'Update Bank Details' : 'Add Bank Account',
        SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Form(
              key: _form,
              autovalidateMode: _showValidation
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bank Details', style: _text(18, bold: true)),
                    const SizedBox(height: 20),
                    _field('Account Holder Name', 'Rahul sharma', _holder),
                    _field('Bank Name', 'HDFC Bank', _bank),
                    _field('Account Number', '1234567890', _number,
                        numeric: true,
                        validator: (value) =>
                            RegExp(r'^[0-9]{6,20}$')
                                    .hasMatch((value ?? '').trim())
                                ? null
                                : 'Enter a valid account number.'),
                    _field('Confirm Account Number', '1234567890', _confirm,
                        numeric: true,
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ||
                                    value?.trim() != _number.text.trim()
                                ? 'Account numbers do not match.'
                                : null),
                    _field('IFSC Code', 'HDFC0001234', _ifsc,
                        ifsc: true,
                        validator: (value) => RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                                .hasMatch((value ?? '').trim().toUpperCase())
                            ? null
                            : 'Enter a valid IFSC code.'),
                    _label('Account Type'),
                    DropdownButtonFormField<String>(
                        key: const ValueKey('Account Type'),
                        initialValue: _type,
                        isExpanded: true,
                        style: _text(14),
                        decoration: _input('Select account type'),
                        hint: Text('Select account type',
                            style: _text(14, color: Colors.grey)),
                        items: ['Saving Account', 'Current Account']
                            .map((type) => DropdownMenuItem(
                                value: type, child: Text(type)))
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() => _type = value);
                                _validateLive();
                              },
                        validator: (value) =>
                            value == null ? 'Select an account type.' : null),
                    const SizedBox(height: 14),
                    _field('Branch Name', 'Kormangala, Bengaluru', _branch,
                        required: false),
                    Text(
                        _lookingUp
                            ? 'Looking up IFSC...'
                            : 'Auto-filled based on IFSC',
                        style: _text(11)),
                    const SizedBox(height: 24),
                    _chequeUploadBox(),
                    const SizedBox(height: 18),
                    Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: _purple),
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.info_outline,
                                    color: _purple, size: 20),
                                const SizedBox(width: 8),
                                Text('Important',
                                    style: _text(16,
                                        bold: true,
                                        color: const Color(0xFFAC69C6)))
                              ]),
                              const SizedBox(height: 12),
                              for (final note in [
                                'Please Upload a Clear image of cancelled Cheque.',
                                'Ensure account number and IFSC are Visible.',
                                'Account holder name should match.'
                              ])
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.check_circle_outline,
                                              size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child:
                                                  Text(note, style: _text(14))),
                                        ])),
                            ])),
                    const SizedBox(height: 24),
                    _button('Submit for Verification', _saving ? null : _submit,
                        busy: _saving),
                  ]),
            )),
      ));
}

class BankVerificationProgressScreen extends StatelessWidget {
  const BankVerificationProgressScreen({
    super.key,
    required this.submittedAt,
  });

  final DateTime submittedAt;

  @override
  Widget build(BuildContext context) {
    final completion = submittedAt.add(const Duration(hours: 3));
    final format = DateFormat('d MMM yyyy, hh:mm a');
    return _shell(
      context,
      'Bank Account Verification',
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(children: [
          const SizedBox(height: 12),
          SvgPicture.asset('assets/bank_verification_icon.svg', width: 120, height: 120),
          const SizedBox(height: 16),
          Text('Verification in Progress',
              style: _text(24, bold: true), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('We are verifying your bank details.\nThis usually takes a few hours.',
              style: _text(17, color: const Color(0xFF484848)),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _purple, width: 1.5),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Text('Status', style: _text(18, bold: true, color: _purple)),
                const Spacer(),
                const Icon(Icons.circle, size: 18, color: Color(0xFFFFB943)),
                const SizedBox(width: 8),
                Text('Under Review', style: _text(16))
              ])),
          const SizedBox(height: 20),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD5DADA)),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _dateRow(Icons.access_time, 'Submitted On', format.format(submittedAt)),
                const SizedBox(height: 12),
                _dateRow(Icons.access_time, 'Estimated Completion', format.format(completion)),
              ])),
        ]),
      ),
      bottom: _button('Back', () => Navigator.of(context).pop()),
    );
  }

  Widget _dateRow(IconData icon, String label, String value) => Row(children: [
        Icon(icon, size: 24),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(14))),
        const SizedBox(width: 12),
        Flexible(
            child: Text(value,
                maxLines: 1,
                textAlign: TextAlign.right,
                style: _text(14))),
      ]);
}
