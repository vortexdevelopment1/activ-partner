import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../Style/app_colors.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import 'ContactSupportFormScreen.dart';

class OnboardingStyles {
  static const body = TextStyle(
    fontFamily: 'OnboardingRegular',
    fontSize: 14,
    height: 1.25,
    color: AppColors.darkBlack,
  );
  static const heading = TextStyle(
    fontFamily: 'OnboardingSemibold',
    fontSize: 28,
    height: 1.15,
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
  const OnboardingScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.yellowBottom,
        systemNavigationBarIconBrightness: Brightness.dark,
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
                  child: child,
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
  Widget build(BuildContext context) => Center(
        child: Image.asset(
          'assets/logo.png',
          width: 105,
          height: 68,
          fit: BoxFit.contain,
          semanticLabel: 'ACTIV Partner',
        ),
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
            fontFamily: 'OnboardingSemibold',
            fontSize: fontSize,
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.yellow,
                  semanticsLabel: 'Loading',
                ),
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
  static const double _initialBottom = 24;

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

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _callSupport() async {
    _close();
    const phone = String.fromEnvironment('SUPPORT_PHONE');
    if (phone.isEmpty) {
      _message(
          'Phone support is not available yet. Please use Chat with support.');
      return;
    }
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!opened && mounted) _message('Unable to open the phone app.');
    } catch (_) {
      if (mounted) _message('Unable to open the phone app.');
    }
  }

  Future<List<dynamic>> _loadFaqs() async {
    final response = await (widget.client?.get ??
        http.get)(Uri.parse('$BASE_URL/faqs/public'));
    if (response.statusCode != 200) throw Exception('Unable to load FAQs.');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? [];
  }

  void _showFaqs() {
    _close();
    var future = _loadFaqs()..ignore();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: StatefulBuilder(builder: (context, update) {
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(children: [
                  Expanded(
                      child: Text('FAQs',
                          style:
                              OnboardingStyles.heading.copyWith(fontSize: 20))),
                  IconButton(
                      tooltip: 'Close FAQs',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
              ),
              Expanded(
                  child: FutureBuilder<List<dynamic>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: TextButton.icon(
                      onPressed: () => update(() {
                        future = _loadFaqs()..ignore();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry loading FAQs'),
                    ));
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('No FAQs available yet.'));
                  }
                  return ListView(
                      children: items
                          .map((item) => ExpansionTile(
                                title: Text(item['question']?.toString() ?? '',
                                    style: OnboardingStyles.body),
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                          item['answer']?.toString() ?? '',
                                          style: OnboardingStyles.body))
                                ],
                              ))
                          .toList());
                },
              )),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _item(String asset, String label, VoidCallback action) => InkWell(
        onTap: action,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            SvgPicture.asset(asset, width: 24, height: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: OnboardingStyles.body)),
          ]),
        ),
      );

  Widget _panel() => Material(
        key: const Key('onboarding-support-panel'),
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x1A000000),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Help & Support',
                  style: OnboardingStyles.heading.copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              Text.rich(
                  const TextSpan(children: [
                    TextSpan(
                        text:
                            'We are here to help you succeed! Available from ',
                        style: TextStyle(color: AppColors.darkGray)),
                    TextSpan(text: '9 AM - 9PM'),
                  ]),
                  style: OnboardingStyles.body.copyWith(fontSize: 11)),
              const Divider(height: 16, color: AppColors.gray),
              _item('assets/ic_chat.svg', 'Chat with support', () {
                _close();
                CommonUtilities.NavigateWithPush(
                    context, const ContactSupportFormScreen());
              }),
              _item('assets/ic_phone.svg', 'Call support', _callSupport),
              _item('assets/ic_faq.svg', 'FAQs', _showFaqs),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _open) _close();
      },
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          final renderObject = this.context.findRenderObject();
          if (renderObject is! RenderBox) return const SizedBox.shrink();
          final anchorTopLeft = renderObject.localToGlobal(Offset.zero);
          final anchorSize = renderObject.size;
          final anchorRect = anchorTopLeft & anchorSize;
          final screenSize = MediaQuery.sizeOf(context);
          final padding = MediaQuery.paddingOf(context);
          const edgePadding = 20.0;
          const gap = 8.0;
          final width = math.min(390.0, MediaQuery.sizeOf(context).width - 40);
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
                      : SvgPicture.asset('assets/ic_faq.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
