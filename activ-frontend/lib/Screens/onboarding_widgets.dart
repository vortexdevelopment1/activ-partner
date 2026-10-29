import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils;
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../Style/app_colors.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'HelpSupportScreen.dart';
import 'StringExtensions.dart';

class OnboardingStyles {
  static const body = TextStyle(
    fontFamily: 'Satoshi',
    fontSize: 14,
    height: 1.25,
    color: AppColors.darkBlack,
  );
  static const heading = TextStyle(
    fontFamily: 'Satoshi',
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w700,
    color: AppColors.darkBlack,
  );

  static InputDecoration inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: body.copyWith(color: AppColors.hintColor),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gray1),
      ),
    );
  }
}

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    this.showLogo = true,
  });

  final Widget child;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.yellowBottom,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.noScaling,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.3, 1],
              colors: [AppColors.yellowTop, AppColors.yellowBottom],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: DefaultTextStyle(
                    style: OnboardingStyles.body,
                    child: showLogo
                        ? Column(
                            children: [
                              const OnboardingHeader(),
                              Expanded(child: child),
                            ],
                          )
                        : child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingLogo extends StatelessWidget {
  const OnboardingLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return Center(
      child: Image.asset(
        'assets/logo.png',
        width: compact ? 100 : 118,
        height: compact ? 60 : 68,
        fit: BoxFit.contain,
        semanticLabel: 'ACTIV Partner',
      ),
    );
  }
}

/// Keep the logo at the login screen's safe-area offset on every setup step.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 14),
        child: OnboardingLogo(),
      );
}

class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.loading = false,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.fontSize = 18,
    this.horizontalPadding = 16,
    this.borderRadius = 12,
    this.minHeight = 56,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final double fontSize;
  final double horizontalPadding;
  final double borderRadius;
  final double minHeight;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size(0, minHeight),
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          backgroundColor: outlined ? AppColors.cream : Colors.black,
          foregroundColor: outlined ? Colors.black : AppColors.yellow,
          disabledBackgroundColor: loading
              ? Colors.black
              : disabledBackgroundColor ??
                  (outlined ? AppColors.cream : Colors.black),
          disabledForegroundColor: disabledForegroundColor ?? AppColors.yellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: outlined
                ? const BorderSide(color: AppColors.gray1)
                : BorderSide.none,
          ),
          textStyle: TextStyle(
            fontFamily: 'Satoshi',
            fontSize: fontSize,
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? Shimmer.fromColors(
                baseColor: AppColors.yellow.withValues(alpha: 0.45),
                highlightColor: AppColors.yellow.withValues(alpha: 0.95),
                child: Text('$label…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: fontSize,
                        color: AppColors.yellow)),
              )
            : icon == null
                ? Text(label, textAlign: TextAlign.center)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 26),
                      const SizedBox(width: 12),
                      Flexible(child: Text(label, textAlign: TextAlign.center))
                    ],
                  ),
      ),
    );
  }
}

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.width = double.infinity, this.height = 18, this.radius = 8});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.gray2,
        highlightColor: AppColors.white,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: AppColors.gray2,
              borderRadius: BorderRadius.circular(radius)),
        ),
      );
}

class OnboardingSupportMenu extends StatefulWidget {
  const OnboardingSupportMenu({
    super.key,
    required this.buttonKey,
    this.enabled = true,
    this.client,
  });

  final Key buttonKey;
  final bool enabled;
  final http.Client? client;

  @override
  State<OnboardingSupportMenu> createState() => _OnboardingSupportMenuState();
}

class DraggableOnboardingSupportMenu extends StatefulWidget {
  const DraggableOnboardingSupportMenu({
    super.key,
    required this.buttonKey,
    this.enabled = true,
    this.client,
  });

  final Key buttonKey;
  final bool enabled;
  final http.Client? client;

  @override
  State<DraggableOnboardingSupportMenu> createState() =>
      _DraggableOnboardingSupportMenuState();
}

class _DraggableOnboardingSupportMenuState
    extends State<DraggableOnboardingSupportMenu> {
  static const double _buttonSize = 64;
  static const double _edgeGap = 12;
  static const double _initialBottom = 86;

  Offset? _position;

  double _maxX(Size size) =>
      math.max(_edgeGap, size.width - _buttonSize - _edgeGap);

  double _maxY(Size size) =>
      math.max(_edgeGap, size.height - _buttonSize - _edgeGap);

  Offset _clamp(Offset position, Size size) {
    return Offset(
      position.dx.clamp(_edgeGap, _maxX(size)).toDouble(),
      position.dy.clamp(_edgeGap, _maxY(size)).toDouble(),
    );
  }

  Offset _snapToHorizontalEdge(Offset position, Size size) {
    final centerX = position.dx + (_buttonSize / 2);
    return Offset(
      centerX < size.width / 2 ? _edgeGap : _maxX(size),
      position.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final fallbackPosition = Offset(
          _maxX(size),
          math.max(_edgeGap, size.height - _buttonSize - _initialBottom),
        );
        final position = _clamp(_position ?? fallbackPosition, size);
        if (_position != null && _position != position) _position = position;

        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  setState(() {
                    _position =
                        _clamp((_position ?? position) + details.delta, size);
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _position = _clamp(
                        _snapToHorizontalEdge(_position ?? position, size),
                        size);
                  });
                },
                child: OnboardingSupportMenu(
                  buttonKey: widget.buttonKey,
                  enabled: widget.enabled,
                  client: widget.client,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _OnboardingSupportMenuState extends State<OnboardingSupportMenu> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  bool _open = false;

  void _close() {
    _portal.hide();
    if (mounted) setState(() => _open = false);
  }

  Future<void> _toggle() async {
    if (_open) {
      _close();
      return;
    }
    FocusScope.of(context).unfocus();
    await Scrollable.ensureVisible(context,
        duration: const Duration(milliseconds: 150));
    if (!mounted || !widget.enabled) return;
    setState(() => _open = true);
    _portal.show();
  }

  Widget _item(IconData icon, String label, VoidCallback action) => InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(icon, size: 22, color: AppColors.darkBlack),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: OnboardingStyles.body.copyWith(fontSize: 17),
              ),
            ),
          ]),
        ),
      );

  Widget _panel() => Material(
        key: const Key('onboarding-support-panel'),
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x1A000000),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Help & Support',
                  style: OnboardingStyles.heading.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text('We are here to help you succeed!',
                  style: OnboardingStyles.body.copyWith(
                    fontSize: 13,
                    color: AppColors.darkGray,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const Divider(height: 20, color: AppColors.gray),
              _item(Icons.phone_in_talk_outlined, 'Request Callback', () {
                _close();
                _showRequestCallbackOverlay();
              }),
              _item(Icons.help_outline_rounded, 'FAQs', () {
                _close();
                _showFaqOverlay();
              }),
            ],
          ),
        ),
      );

  Future<void> _showRequestCallbackOverlay() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (_) => _LoginCallbackDialog(client: widget.client),
    );
  }

  Future<void> _showFaqOverlay() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (_) => _LoginFaqDialog(client: widget.client),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _open) _close();
      },
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayChildBuilder: (context, info) {
          // Read the anchor after layout, so an open panel follows every drag
          // and edge snap instead of retaining the button's previous position.
          final anchorRect = MatrixUtils.transformRect(
              info.childPaintTransform, Offset.zero & info.childSize);
          final screenSize = info.overlaySize;
          final padding = MediaQuery.paddingOf(context);
          const edgePadding = 20.0;
          const gap = 8.0;
          final width = math.min(390.0, screenSize.width - 40);
          final availableAbove =
              math.max(0.0, anchorRect.top - padding.top - edgePadding - gap);
          final availableBelow = math.max(
              0.0, screenSize.height - padding.bottom - edgePadding - gap - anchorRect.bottom);
          final showBelow = availableBelow > availableAbove;
          final height = math.max(
              0.0, showBelow ? availableBelow : availableAbove);
          final left = (anchorRect.right - width)
              .clamp(edgePadding, screenSize.width - width - edgePadding)
              .toDouble();

          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: showBelow ? anchorRect.bottom + gap : null,
                  bottom: showBelow
                      ? null
                      : screenSize.height - anchorRect.top + gap,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: height, minWidth: width, maxWidth: width),
                    child: TapRegion(
                        groupId: _link,
                        child: SingleChildScrollView(child: _panel())),
                  ),
                ),
              ],
            ),
          );
        },
        child: TapRegion(
          groupId: _link,
          onTapOutside: (_) {
            if (_open) _close();
          },
          child: CompositedTransformTarget(
            link: _link,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Material(
                color: _open ? AppColors.hintColor : AppColors.black1,
                elevation: 3,
                shape: const CircleBorder(),
                child: IconButton(
                  key: widget.buttonKey,
                  tooltip: _open ? 'Close support' : 'Help & Support',
                  onPressed: widget.enabled ? _toggle : null,
                  icon: _open
                      ? const Icon(Icons.close, size: 24, color: Colors.white)
                      : const Icon(Icons.help_outline,
                          size: 24, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFaqDialog extends StatefulWidget {
  const _LoginFaqDialog({this.client});

  final http.Client? client;

  @override
  State<_LoginFaqDialog> createState() => _LoginFaqDialogState();
}

class _LoginFaqDialogState extends State<_LoginFaqDialog> {
  List<_LoginFaqEntry> _faqs = const [];
  int _open = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(FAQ_PUBLIC_URL),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Unable to load FAQs');
      }

      final decoded = jsonDecode(response.body);
      final records = decoded is Map<String, dynamic>
          ? decoded['data']
          : decoded;
      final faqs = records is List
          ? records
              .whereType<Map>()
              .map(
                (record) => _LoginFaqEntry(
                  record['question']?.toString().trim() ?? '',
                  record['answer']?.toString().trim() ?? '',
                ),
              )
              .where((faq) => faq.question.isNotEmpty && faq.answer.isNotEmpty)
              .toList()
          : <_LoginFaqEntry>[];

      if (!mounted) return;
      setState(() {
        _faqs = faqs;
        _open = faqs.isEmpty ? -1 : 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load FAQs';
      });
    }
  }

  Widget _faqTile(_LoginFaqEntry faq, int index) {
    final open = _open == index;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = open ? -1 : index),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.question,
                      style: OnboardingStyles.body.copyWith(fontSize: 14),
                    ),
                  ),
                  Icon(
                    open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.darkBlack,
                  ),
                ],
              ),
              if (open) ...[
                const Divider(height: 20, color: AppColors.gray),
                Text(
                  faq.answer,
                  style: OnboardingStyles.body.copyWith(
                    fontSize: 13,
                    color: AppColors.darkGray,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Dialog(
      backgroundColor: const Color(0xFFF0F7D2),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Frequently Asked Questions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OnboardingStyles.heading.copyWith(fontSize: 17),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 24),
                    tooltip: 'Close FAQs',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(children: [
                            AppSkeleton(height: 48),
                            SizedBox(height: 12),
                            AppSkeleton(height: 48),
                            SizedBox(height: 12),
                            AppSkeleton(height: 48),
                            SizedBox(height: 12),
                            AppSkeleton(height: 48),
                          ]))
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!,
                                      style: OnboardingStyles.body.copyWith(
                                          fontSize: 16)),
                                  TextButton(
                                    onPressed: _loadFaqs,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _faqs.isEmpty
                              ? Center(
                                  child: Text(
                                    'No FAQs available yet.',
                                    style: OnboardingStyles.body
                                        .copyWith(fontSize: 16),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  itemCount: _faqs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) =>
                                      _faqTile(_faqs[index], index),
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

class _LoginFaqEntry {
  const _LoginFaqEntry(this.question, this.answer);

  final String question;
  final String answer;
}

class _LoginCallbackDialog extends StatefulWidget {
  const _LoginCallbackDialog({this.client});

  final http.Client? client;

  @override
  State<_LoginCallbackDialog> createState() => _LoginCallbackDialogState();
}

class _LoginCallbackDialogState extends State<_LoginCallbackDialog> {
  final _partner = TextEditingController();
  final _venue = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _query = TextEditingController();
  String _callbackDate = '';
  String _callbackTime = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDetails();
  }

  Future<void> _loadSavedDetails() async {
    _partner.text = checkString(await SharedPreference.readStr('owner_full_name'));
    _email.text = checkString(await SharedPreference.readStr('owner_email'));
    _phone.text = checkString(await SharedPreference.readStr('userMobileNumber'))
        .replaceAll(RegExp(r'\D'), '');
    final rawVenue = checkString(await SharedPreference.readStr('venue_details'));
    try {
      final venue = rawVenue.isEmpty ? {} : jsonDecode(rawVenue);
      _venue.text = checkString(venue['venue_name']);
      _city.text = checkString(venue['venue_city']);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _partner.dispose();
    _venue.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    _query.dispose();
    super.dispose();
  }

  String get _defaultCallbackDate {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final required = [_partner, _venue, _city, _phone, _email, _query];
    if (required.any((field) => field.text.trim().isEmpty)) {
      CommonUtilities.createSnackBar(context, 'Please fill all required fields');
      return;
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
          'callbackDate':
              _callbackDate.isEmpty ? _defaultCallbackDate : _callbackDate,
          'callbackTime':
              _callbackTime.isEmpty ? '10:00 AM' : _callbackTime,
        }),
      );
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Unable to request callback. Please try again.');
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Callback requested successfully.')),
      );
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to request callback. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      backgroundColor: const Color(0xFFF3F9D7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Request Callback',
                          style:
                              OnboardingStyles.heading.copyWith(fontSize: 26)),
                    ),
                    IconButton(
                      onPressed:
                          _submitting ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 26),
                    ),
                  ],
                ),
                Text(
                  'Fill in your details and our team will get in touch shortly.',
                  style: OnboardingStyles.body
                      .copyWith(fontSize: 16, height: 1.35),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dialogInput('Venue Partner Name', _partner),
                          _dialogInput('Venue Name', _venue),
                          _dialogInput('City', _city),
                          _dialogPhoneInput(),
                          _dialogInput('Email', _email,
                              keyboardType: TextInputType.emailAddress),
                          _dialogInput('Please write your Query', _query,
                              maxLines: 4),
                          _dialogPicker(
                            'Preferred Callback Date',
                            _callbackDate,
                            Icons.calendar_today_outlined,
                            _pickCallbackDate,
                          ),
                          _dialogPicker(
                            'Preferred Time Slots',
                            _callbackTime,
                            Icons.access_time,
                            _pickCallbackTime,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 54,
                      child: OutlinedButton(
                        onPressed:
                            _submitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          fixedSize: const Size(100, 54),
                          minimumSize: const Size(100, 54),
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.darkBlack,
                          side: const BorderSide(color: AppColors.darkBlack),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Cancel',
                            style: OnboardingStyles.heading
                                .copyWith(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OnboardingButton(
                          label: _submitting
                              ? 'Requesting...'
                              : 'Request Call Back',
                          onPressed: _submitting ? null : _submit,
                          fontSize: 15,
                          horizontalPadding: 8,
                          minHeight: 54,
                          borderRadius: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCallbackDate() async {
    final initial = DateTime.tryParse(_callbackDate) ??
        DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _callbackDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickCallbackTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _callbackTime = picked.format(context);
    });
  }

  Widget _dialogPicker(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dialogLabel(label),
          const SizedBox(height: 7),
          InkWell(
            onTap: _submitting ? null : onTap,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: _dialogDecoration().copyWith(
                suffixIcon: Icon(icon, color: AppColors.black1),
              ),
              child: Text(
                value.isEmpty ? 'Select' : value,
                style: OnboardingStyles.body.copyWith(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogInput(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dialogLabel(label),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            enabled: !_submitting,
            style: OnboardingStyles.body.copyWith(fontSize: 15),
            decoration: _dialogDecoration(),
          ),
        ],
      ),
    );
  }

  Widget _dialogPhoneInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dialogLabel('Phone Number'),
          const SizedBox(height: 7),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 110,
                  child: Center(
                    child: Text('IND (+91)', style: OnboardingStyles.body),
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.gray),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    enabled: !_submitting,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogLabel(String label) => Text.rich(
        TextSpan(children: [
          TextSpan(text: label),
          const TextSpan(text: '*', style: TextStyle(color: AppColors.red)),
        ]),
        style: OnboardingStyles.body.copyWith(fontSize: 16),
      );

  InputDecoration _dialogDecoration() => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          borderSide: const BorderSide(color: AppColors.gray1),
        ),
      );
}
