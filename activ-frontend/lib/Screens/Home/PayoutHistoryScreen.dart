import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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

DateTimeRange _defaultRange() {
  final today = DateUtils.dateOnly(DateTime.now());
  return DateTimeRange(
      start: today.subtract(const Duration(days: 30)), end: today);
}

Future<DateTimeRange?> _pickRange(BuildContext context, DateTimeRange range) =>
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: range,
      helpText: 'Select range',
      confirmText: 'Save',
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: _purple)
                .copyWith(primary: _purple, secondary: const Color(0xFF08C9BB)),
            datePickerTheme: const DatePickerThemeData(
                rangePickerBackgroundColor: Color(0xFFFFF7FF),
                rangePickerHeaderBackgroundColor: Color(0xFFFFF7FF),
                rangePickerHeaderForegroundColor: Colors.black,
                rangeSelectionBackgroundColor: Color(0xFF08C9BB)),
          ),
          child: child!),
    );

Widget _dateField(DateTimeRange range, VoidCallback? onTap) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFD5DADA))),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(children: [
              Expanded(
                  child: Text(
                      '${DateFormat('d MMM yyyy').format(range.start)} - ${DateFormat('d MMM yyyy').format(range.end)}',
                      style: _text(16))),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_outlined, size: 24),
            ])),
      ),
    );

Widget _shell(BuildContext context, String title, Widget body,
        {Widget? action, Widget? bottom}) =>
    AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: _background),
      child: Scaffold(
          backgroundColor: _background,
          bottomNavigationBar: bottom == null
              ? null
              : SafeArea(
                  top: false,
                  child: Align(
                      heightFactor: 1,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 20),
                              child: bottom)))),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              Padding(
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
                    if (action != null) action,
                  ])),
              Expanded(child: body),
            ]),
          )))),
    );

Map<String, String> _filters(DateTimeRange range, String status) => {
      'startDate': DateFormat('yyyy-MM-dd').format(range.start),
      'endDate': DateFormat('yyyy-MM-dd').format(range.end),
      'status': status,
    };

void _check(http.Response response) {
  if (response.statusCode == 401) {
    throw StateError('Your session has expired. Please sign in again.');
  }
  if (response.statusCode != 200) {
    if (response.statusCode == 400) {
      try {
        final message = jsonDecode(response.body)['message'];
        throw StateError(
            message is List ? message.join('\n') : message.toString());
      } on FormatException {
        /* Fall back to the service error for non-JSON responses. */
      }
    }
    throw StateError(
        'The payout service is temporarily unavailable. Please try again.');
  }
}

typedef SavePayoutReport = Future<bool> Function(
    String filename, Uint8List bytes);

class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen(
      {super.key, this.client, this.initialRange, this.saveReport});
  final http.Client? client;
  final DateTimeRange? initialRange;
  final SavePayoutReport? saveReport;
  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  late DateTimeRange _range;
  String _status = 'all';
  bool _loading = true, _loadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  int _page = 1, _totalPages = 1, _request = 0;
  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ?? _defaultRange();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request, page = more ? _page + 1 : 1;
    setState(() {
      _loading = !more;
      _loadingMore = more;
      _error = null;
    });
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final uri = Uri.parse('$BASE_URL/bookings/payout-history').replace(queryParameters: {
        ..._filters(_range, _status),
        'page': '$page',
        'limit': '20'
      });
      final response = await (widget.client?.get ?? http.get)(uri,
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      _check(response);
      final data = jsonDecode(response.body)['data'];
      final records = (data['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted || request != _request) return;
      setState(() {
        _records = more ? [..._records, ...records] : records;
        _page = page;
        _totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error is StateError
          ? error.message
          : 'Unable to load payout history. Please try again.');
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _chooseDates() async {
    final range = await _pickRange(context, _range);
    if (range == null || !mounted) return;
    setState(() => _range = range);
    await _load();
  }

  @override
  Widget build(BuildContext context) => _shell(
        context,
        'Payout History',
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              _dateField(_range, _chooseDates),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                const options = {
                  'all': 'All',
                  'success': 'Successful',
                  'pending': 'Pending',
                  'failed': 'Failed'
                };
                final controls = options.entries
                    .map((option) => OutlinedButton(
                          onPressed: () {
                            if (_status == option.key) return;
                            setState(() => _status = option.key);
                            _load();
                          },
                          style: OutlinedButton.styleFrom(
                              backgroundColor: _status == option.key
                                  ? _purple
                                  : Colors.transparent,
                              foregroundColor: _status == option.key
                                  ? Colors.white
                                  : const Color(0xFF484848),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 34),
                              side: BorderSide(
                                  color: _status == option.key
                                      ? _purple
                                      : const Color(0xFF484848)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(option.value,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: _text(15,
                                      color: _status == option.key
                                          ? Colors.white
                                          : const Color(0xFF484848)))),
                        ))
                    .toList();
                return constraints.maxWidth < 290 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2
                    ? Wrap(spacing: 10, runSpacing: 8, children: controls)
                    : Row(children: [
                        for (var i = 0; i < controls.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: controls[i]),
                        ]
                      ]);
              }),
              const SizedBox(height: 12),
              Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _purple))
                      : _error != null
                          ? Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Text(_error!,
                                      style: _text(14),
                                      textAlign: TextAlign.center),
                                  TextButton(
                                      onPressed: () => _load(),
                                      child: const Text('Retry')),
                                ]))
                          : _records.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) =>
                                      RefreshIndicator(
                                          onRefresh: () => _load(),
                                          child: ListView(
                                              physics:
                                                  const AlwaysScrollableScrollPhysics(),
                                              children: [
                                                SizedBox(
                                                    height:
                                                        constraints.maxHeight,
                                                    child: Align(
                                                        alignment:
                                                            const Alignment(
                                                                0, 0.3),
                                                        child: Text(
                                                            'No payout records found',
                                                            style: _text(16))))
                                              ])))
                              : RefreshIndicator(
                                  onRefresh: () => _load(),
                                  child: ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 20),
                                      itemCount: _records.length +
                                          (_page < _totalPages ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index == _records.length) {
                                          return Center(
                                              child: TextButton(
                                                  onPressed: _loadingMore
                                                      ? null
                                                      : () => _load(more: true),
                                                  child: _loadingMore
                                                      ? const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2))
                                                      : const Text(
                                                          'Load More')));
                                        }
                                        return _record(_records[index]);
                                      }))),
            ])),
        action: IconButton(
            tooltip: 'Export report',
            icon: const Icon(Icons.file_download_outlined, size: 30),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ExportPayoutReportScreen(
                        client: widget.client,
                        initialRange: _range,
                        status: _status,
                        saveReport: widget.saveReport)))),
      );

  Widget _record(Map<String, dynamic> record) {
    final reference = record['reference'] ?? record['payoutReference'];
    final bankName = record['bankName'] ?? record['bank']?['name'];
    final accountLast4 = record['accountLast4'] ?? record['bank']?['accountLast4'];
    final status = record['status'].toString(),
        date = DateTime.tryParse((record['payoutDate'] ?? '').toString());
    final statusLabel = status == 'success'
        ? 'Success'
        : status == 'failed'
            ? 'Failed'
            : 'Pending';
    final statusColor = status == 'success'
        ? const Color(0xFF12D000)
        : status == 'failed'
            ? const Color(0xFFFF5757)
            : const Color(0xFFE39700);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PayoutTransactionDetailsScreen(
                  bookingId: record['id'].toString(), client: widget.client))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD5DADA))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(
                    date == null
                        ? '-'
                        : DateFormat('d MMM yyyy').format(date.toLocal()),
                    style: _text(18, bold: true))),
            const Icon(Icons.chevron_right, size: 28),
          ]),
          const SizedBox(height: 10),
          if (reference != null || bankName != null)
            Text(
              [
                if (reference != null) reference.toString(),
                if (bankName != null)
                  '$bankName | XXXX ${accountLast4 ?? '-'}',
              ].join(' • '),
              style: _text(14),
            ),
          if (reference != null || bankName != null)
            const SizedBox(height: 8),
          Row(children: [
            Text('₹ ', style: _text(16)),
            Text(
                NumberFormat('#,##0.00', 'en_IN')
                    .format((record['amount'] as num?)?.toDouble() ?? 0),
                style: _text(20, bold: true)),
            const Spacer(),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(22)),
                child: Text(statusLabel,
                    style: _text(14, color: Colors.white, bold: true))),
          ]),
        ]),
      ),
    );
  }
}

class PayoutTransactionDetailsScreen extends StatefulWidget {
  const PayoutTransactionDetailsScreen(
      {super.key, required this.bookingId, this.client});
  final String bookingId;
  final http.Client? client;

  @override
  State<PayoutTransactionDetailsScreen> createState() =>
      _PayoutTransactionDetailsScreenState();
}

class _PayoutTransactionDetailsScreenState
    extends State<PayoutTransactionDetailsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true, _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse('$BASE_URL/bookings/${widget.bookingId}/payout-statement'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));
      _check(response);
      final data = jsonDecode(response.body)['data'];
      if (mounted) setState(() => _data = Map<String, dynamic>.from(data));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message
            : 'Unable to load transaction details. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(dynamic value) => NumberFormat('#,##0.00', 'en_IN')
      .format((value as num?)?.toDouble() ?? 0);

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? '-'
        : DateFormat('d MMM yyyy, hh:mm a').format(date.toLocal());
  }

  Future<void> _downloadStatement() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(
            '$BASE_URL/bookings/${widget.bookingId}/payout-statement/download'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 45));
      _check(response);
      final data = Map<String, dynamic>.from(jsonDecode(response.body)['data']);
      final filename = data['filename'] as String? ??
          'ACTIV_Transaction_${widget.bookingId}.pdf';
      final bytes = base64Decode(data['base64'] as String);
      final saved = await FilePicker.platform.saveFile(
            dialogTitle: 'Save transaction statement',
            fileName: filename,
            type: FileType.custom,
            allowedExtensions: const ['pdf'],
            bytes: bytes,
          ) !=
          null;
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction statement downloaded.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message
                : 'Unable to download the transaction statement.')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD5DADA))),
        child: child,
      );

  Widget _line(String label, dynamic value,
          {bool bold = false, Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 6,
              child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      maxLines: 1, style: _text(14, bold: bold)))),
          const SizedBox(width: 8),
          Expanded(
              flex: 4,
              child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text(value?.toString() ?? '-',
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: _text(14, bold: bold, color: valueColor ??
                          const Color(0xFF202020)))))
        ]),
      );

  Widget _gstLine({required bool gstRegistered, required dynamic value}) {
    final message = gstRegistered
        ? 'GST on Commission (18%): GST is charged on the ACTIV Platform '
            'Service Fee (Commission). GST-registered venues may claim this '
            'amount as Input Tax Credit (ITC), subject to applicable GST laws.'
        : 'GST on Commission (18%): GST is charged on the ACTIV Platform '
            'Service Fee (Commission). Since this venue is not registered '
            'under GST, this amount is not eligible for Input Tax Credit (ITC).';
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 7,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('GST on Commission (18%)', style: _text(14)),
                const SizedBox(width: 4),
                Tooltip(
                    message: message,
                    child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showGstInfo(gstRegistered, message),
                        child: const Icon(Icons.info_outline,
                            color: _purple, size: 21)))
              ])),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text(value?.toString() ?? '-',
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: _text(14, color: const Color(0xFF9C35E8)))))
        ]));
  }

  Future<void> _showGstInfo(bool gstRegistered, String message) async {
    await showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1ECF6),
                    borderRadius: BorderRadius.circular(30)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          gstRegistered
                              ? 'GST Registered Venue'
                              : 'Non-GST Registered Venue',
                          style: _text(22, bold: true))),
                  const SizedBox(height: 24),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(message,
                          style: _text(16).copyWith(height: 1.45))),
                  const SizedBox(height: 22),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF6D4CB3),
                              backgroundColor: const Color(0xFFE7DDF2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 9),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              textStyle: _text(16)),
                          child: const Text('Close')))
                ]))));
  }

  Widget _bankDetailsCard(Map<String, dynamic> bank) => _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_balance_outlined,
                color: Color(0xFF8A8A8A), size: 28),
            const SizedBox(width: 8),
            Expanded(
                child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text('Credited Bank Account Details',
                        maxLines: 1, style: _text(16, bold: true)))),
            const SizedBox(width: 12),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: bank['verified'] == true
                        ? Colors.green
                        : const Color(0xFFFFB52E),
                    borderRadius: BorderRadius.circular(22)),
                child: Text(bank['verified'] == true ? 'Verified' : 'Pending',
                    style: _text(11, bold: true, color: Colors.white))),
          ]),
          const SizedBox(height: 12),
          Text(bank['accountHolderName']?.toString() ?? '-', style: _text(16)),
          const SizedBox(height: 10),
          Text(bank['bankName']?.toString() ?? '-', style: _text(16)),
          const SizedBox(height: 10),
          Text('A/C No. ${bank['accountNumber'] ?? '-'}', style: _text(16)),
          const SizedBox(height: 10),
          Text('IFSC: ${bank['ifscCode'] ?? '-'}', style: _text(16)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return _shell(
      context,
      'Transaction Details',
      _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _error != null
              ? Center(child: Text(_error!, style: _text(15)))
              : data == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        _card(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                _statusChip(data['status']),
                                const SizedBox(width: 64),
                                Flexible(
                                    child: _statusChip(
                                        data['isGstRegistered'] == true
                                            ? 'GST Registered Venue'
                                            : 'Non-GST Registered Venue',
                                        color: data['isGstRegistered'] == true
                                            ? _purple
                                            : const Color(0xFFFF5757)))
                              ]),
                              const SizedBox(height: 16),
                              Text('Amount Received', style: _text(14)),
                              const SizedBox(height: 4),
                              Text('₹${_money(data['amountReceived'])}',
                                  style: _text(26, bold: true)),
                              const SizedBox(height: 16),
                              Text('Payout Date', style: _text(14, bold: true)),
                              const SizedBox(height: 4),
                              Text(_date(data['payoutDate']), style: _text(14))
                            ])),
                        _card(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payout Breakdown',
                                  style: _text(16, bold: true)),
                              const SizedBox(height: 8),
                              _line('Total Booking Amount',
                                  '+  ₹${_money(data['grossBookingAmount'])}',
                                  valueColor: const Color(0xFF12C900)),
                              _line(
                                  'ACTIV Commission (${data['commissionPercent']}%)',
                                  '-  ₹${_money(data['activCommission'])}',
                                  valueColor: const Color(0xFFFF5757)),
                              _gstLine(
                                  gstRegistered:
                                      data['isGstRegistered'] == true,
                                  value:
                                      '-  ₹${_money(data['gstOnCommission'])}'),
                              const Divider(color: Color(0xFF8BC48B)),
                              _line('Net Received',
                                  '₹${_money(data['netReceived'])}',
                                  bold: true)
                            ])),
                        _card(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Transaction & Slot Details',
                                  style: _text(16, bold: true)),
                              const SizedBox(height: 8),
                              _line('Activity Name', data['activityName']),
                              _line('Date', data['slotDate']),
                              _line('Slot Time', data['slotTime']),
                              _line('Slot Base Price',
                                  '₹ ${_money(data['slotBasePrice'])}'),
                              _line('Booking ID', data['bookingId']),
                              _line('Transaction ID', data['transactionId'])
                            ])),
                        if (data['bank'] is Map)
                          _bankDetailsCard(
                              Map<String, dynamic>.from(data['bank'] as Map)),
                      ],
                    ),
      action: IconButton(
          tooltip: 'Download statement',
          onPressed: _downloading ? null : _downloadStatement,
          icon: _downloading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.file_download_outlined, size: 30)),
    );
  }

  Widget _statusChip(dynamic value, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
          color: color ??
              (value == 'success' ? Colors.green : const Color(0xFFE19400)),
          borderRadius: BorderRadius.circular(22)),
      child: Text(value == 'success' ? 'Success' : value.toString(),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: _text(12, bold: true, color: Colors.white)));
}

class ExportPayoutReportScreen extends StatefulWidget {
  const ExportPayoutReportScreen(
      {super.key,
      this.client,
      required this.initialRange,
      this.status = 'all',
      this.saveReport});
  final http.Client? client;
  final DateTimeRange initialRange;
  final String status;
  final SavePayoutReport? saveReport;
  @override
  State<ExportPayoutReportScreen> createState() =>
      _ExportPayoutReportScreenState();
}

class _ExportPayoutReportScreenState extends State<ExportPayoutReportScreen> {
  late DateTimeRange _range;
  String _format = 'pdf';
  bool _downloading = false;
  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
  }

  Future<void> _dates() async {
    final range = await _pickRange(context, _range);
    if (range != null && mounted) setState(() => _range = range);
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final uri = Uri.parse('$BASE_URL/payouts/download').replace(
          queryParameters: {
            ..._filters(_range, widget.status),
            'format': _format
          });
      final response = await (widget.client?.get ?? http.get)(uri,
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 45));
      _check(response);
      final data = jsonDecode(response.body)['data'];
      final filename = data['filename'] as String,
          bytes = base64Decode(data['base64'] as String);
      if (!mounted) return;
      final saved = widget.saveReport != null
          ? await widget.saveReport!(filename, bytes)
          : await FilePicker.platform.saveFile(
                  dialogTitle: 'Save payout report',
                  fileName: filename,
                  type: FileType.custom,
                  allowedExtensions: [_format],
                  bytes: bytes) !=
              null;
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payout report downloaded.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is StateError
                ? error.message
                : 'Unable to download the report. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _shell(
        context,
        'Export Report',
        ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _dateField(_range, _downloading ? null : _dates),
              const SizedBox(height: 36),
              Text('Select Format', style: _text(20, bold: true)),
              const SizedBox(height: 18),
              for (final format in ['pdf', 'csv']) ...[
                Container(
                    padding: EdgeInsets.all(_format == format ? 2 : 1),
                    decoration: BoxDecoration(
                        gradient: _format == format
                            ? const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF424242),
                                  Color(0xFFB9D749),
                                ])
                            : null,
                        color: _format == format
                            ? null
                            : const Color(0xFFD5DADA),
                        borderRadius: BorderRadius.circular(24)),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _downloading
                              ? null
                              : () => setState(() => _format = format),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 24),
                              child: Row(children: [
                                Icon(
                                    _format == format
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: _format == format
                                        ? _purple
                                        : Colors.grey,
                                    size: 24),
                                const SizedBox(width: 22),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(format.toUpperCase(),
                                          style: _text(28, bold: true)),
                                      const SizedBox(height: 4),
                                      Text('${format.toUpperCase()} Document',
                                          style: _text(16,
                                              color: const Color(0xFF484848))),
                                    ])),
                              ]))),
                    )),
                const SizedBox(height: 14),
              ],
            ]),
        bottom: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _downloading ? null : _download,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: _lime,
                  minimumSize: const Size(0, 58),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _downloading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: _lime, strokeWidth: 2))
                  : Text('Download Report',
                      style: _text(20, bold: true, color: _lime)),
            )),
      );
}
