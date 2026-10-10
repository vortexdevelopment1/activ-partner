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
      final uri = Uri.parse('$BASE_URL/payouts/my').replace(queryParameters: {
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
                          child: Text(option.value,
                              style: _text(15,
                                  color: _status == option.key
                                      ? Colors.white
                                      : const Color(0xFF484848))),
                        ))
                    .toList();
                return constraints.maxWidth < 290 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2
                    ? Wrap(spacing: 10, runSpacing: 8, children: controls)
                    : Row(children: [
                        for (var i = 0; i < controls.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(flex: [2, 5, 4, 3][i], child: controls[i]),
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
    final status = record['status'],
        date = DateTime.tryParse((record['payoutDate'] ?? '').toString());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD5DADA))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text((record['reference'] ?? '').toString(),
                  style: _text(16, bold: true))),
          const SizedBox(width: 10),
          Icon(
              status == 'success'
                  ? Icons.check_circle_outline
                  : status == 'failed'
                      ? Icons.error_outline
                      : Icons.schedule,
              color: status == 'success'
                  ? Colors.green.shade700
                  : status == 'failed'
                      ? Colors.red.shade700
                      : _purple)
        ]),
        const SizedBox(height: 12),
        Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.currency_rupee, size: 20),
                Text(
                    NumberFormat('#,##0.##', 'en_IN')
                        .format(record['amount'] ?? 0),
                    style: _text(20, bold: true))
              ]),
              Text(
                  status == 'success'
                      ? 'Successful'
                      : status == 'failed'
                          ? 'Failed'
                          : 'Pending',
                  style: _text(14)),
            ]),
        if (date != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(DateFormat('d MMM yyyy').format(date.toLocal()),
                  style: _text(14))),
        if (record['bankName'] != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  '${record['bankName']}${record['accountLast4'] == null ? '' : ' | XXXX ${record['accountLast4']}'}',
                  style: _text(14))),
        if ((record['failureReason'] ?? '').toString().isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(record['failureReason'].toString(),
                  style: _text(14, color: Colors.red.shade700))),
      ]),
    );
  }
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
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                          color: _format == format
                              ? const Color(0xFFB9D749)
                              : const Color(0xFFD5DADA),
                          width: _format == format ? 2 : 1)),
                  child: InkWell(
                      borderRadius: BorderRadius.circular(24),
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
                                color:
                                    _format == format ? _purple : Colors.grey,
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
                ),
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
