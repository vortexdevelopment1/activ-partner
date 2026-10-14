import 'package:flutter/material.dart';
import '../onboarding_widgets.dart';

class DashboardSetupCards extends StatefulWidget {
  const DashboardSetupCards(
      {super.key,
      required this.pricingRequired,
      required this.teamRequired,
      required this.onPricing,
      required this.onTeam});
  final bool pricingRequired, teamRequired;
  final VoidCallback onPricing, onTeam;

  @override
  State<DashboardSetupCards> createState() => _DashboardSetupCardsState();
}

class _DashboardSetupCardsState extends State<DashboardSetupCards> {
  final _dismissed = <String>{};
  final _pages = PageController(viewportFraction: .9);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DashboardSetupCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pricingRequired != widget.pricingRequired ||
        oldWidget.teamRequired != widget.teamRequired) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = [
      if (widget.pricingRequired && !_dismissed.contains('pricing')) 'pricing',
      if (widget.teamRequired && !_dismissed.contains('team')) 'team'
    ];
    if (tasks.isEmpty) return const SizedBox.shrink();
    final height = 190 +
        (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 32) * 8;
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(children: [
          SizedBox(
              height: height.toDouble(),
              child: PageView.builder(
                  key: const Key('dashboard-setup-carousel'),
                  controller: _pages,
                  itemCount: tasks.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final pricing = task == 'pricing';
                    return Container(
                        key: Key('setup-$task'),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD2DFE0))),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Text(
                                            pricing
                                                ? 'Add pricing to start accepting bookings'
                                                : 'Add team members',
                                            style: OnboardingStyles.heading
                                                .copyWith(
                                                    fontSize: 17,
                                                    height: 1.35))),
                                    SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: IconButton(
                                            padding: EdgeInsets.zero,
                                            tooltip:
                                                'Dismiss ${pricing ? 'pricing' : 'team'} reminder',
                                            icon: const Icon(Icons.close,
                                                size: 20),
                                            onPressed: () {
                                              setState(() {
                                                _dismissed.add(task);
                                                _index = 0;
                                              });
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                if (mounted &&
                                                    _pages.hasClients) {
                                                  _pages.jumpToPage(0);
                                                }
                                              });
                                            })),
                                  ]),
                              const SizedBox(height: 8),
                              Text(
                                  pricing
                                      ? "Congratulations on your venue's approval! Set your prices per slot and start accepting bookings."
                                      : 'Invite your team members to smoothly operate and manage your venue.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: OnboardingStyles.body
                                      .copyWith(fontSize: 14, height: 1.35)),
                              const Spacer(),
                              SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: TextButton(
                                      style: TextButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFA634EB),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      onPressed: pricing
                                          ? widget.onPricing
                                          : widget.onTeam,
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                                child: Text(
                                                    pricing
                                                        ? 'Set Pricing'
                                                        : 'Add team members',
                                                    style: OnboardingStyles.body
                                                        .copyWith(
                                                            fontSize: 16,
                                                            color:
                                                                Colors.white))),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward,
                                                size: 19),
                                          ]))),
                            ]));
                  })),
          if (tasks.length > 1)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < tasks.length; i++)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: i == _index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: i == _index
                                    ? const Color(0xFFA634EB)
                                    : const Color(0xFFD0DFDF),
                                borderRadius: BorderRadius.circular(3)))),
                ])),
        ]));
  }
}

bool dashboardNeedsPricing(Map<String, dynamic> venue) {
  final services = (venue['services'] as List? ?? [])
      .where((service) => service['status'] == 'approved');
  return services.any((service) {
    final days = service['availability'] ??
        venue['availability']?[service['categoryId']] ??
        [];
    final slots = (days as List).expand((day) => day['slots'] as List? ?? []);
    return slots.isEmpty ||
        slots.any((slot) =>
            (double.tryParse(slot['price']?.toString() ?? '') ?? 0) <= 0);
  });
}
