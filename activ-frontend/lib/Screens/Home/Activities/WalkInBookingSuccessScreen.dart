import 'package:flutter/material.dart';

class WalkInBookingSuccessScreen extends StatelessWidget {
  const WalkInBookingSuccessScreen({
    super.key,
    required this.venueName,
    required this.date,
    required this.slots,
    required this.court,
    required this.participantName,
    required this.participantPhone,
    this.participantEmail,
  });

  final String venueName;
  final String date;
  final List<String> slots;
  final String court;
  final String participantName;
  final String participantPhone;
  final String? participantEmail;

  static const _text = TextStyle(
      fontFamily: 'Satoshi',
      fontSize: 16,
      height: 1.35,
      color: Color(0xFF202124));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF0F7D2),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                key: const ValueKey('walk-in-success-card'),
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  Container(
                      width: 62,
                      height: 62,
                      decoration: const BoxDecoration(
                          color: Color(0xFF76AD3D), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          size: 45, color: Colors.white)),
                  const SizedBox(height: 10),
                  const Text('Walk-In Slot Reserved!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                  const SizedBox(height: 10),
                  Text(
                      'This time slot is now blocked on the ACTIV app to prevent double bookings.',
                      textAlign: TextAlign.center,
                      style: _text.copyWith(
                          fontSize: 13, color: const Color(0xFF626262))),
                ]),
              ),
              const SizedBox(height: 10),
              _heading('Slot Details'),
              const SizedBox(height: 6),
              _card([
                _detail(Icons.location_on, venueName),
                _detail(Icons.calendar_today_outlined, date),
                _detail(Icons.sports_tennis_outlined, court),
                ...slots.map((slot) => _detail(Icons.access_time, slot)),
              ]),
              const SizedBox(height: 10),
              _heading('Participant Details'),
              const SizedBox(height: 6),
              _card([
                _detail(Icons.account_circle_outlined, participantName),
                _detail(Icons.call, participantPhone),
                if (participantEmail?.trim().isNotEmpty == true)
                  _detail(Icons.email, participantEmail!),
              ]),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  backgroundColor: const Color(0xFFFDF6DE),
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: _text.copyWith(fontWeight: FontWeight.w700),
                ),
                child: const Text('Book Another Slot',
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  backgroundColor: Colors.black,
                  foregroundColor: const Color(0xFFDAFF50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: _text.copyWith(fontWeight: FontWeight.w700),
                ),
                child: const Text('Back To Activity Management',
                    textAlign: TextAlign.center),
              ),
              ],
            ),
          ),
        ))),
      );

  Widget _heading(String title) => Text(title,
      style: _text.copyWith(fontSize: 17, fontWeight: FontWeight.w700));

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(children: children),
      );

  Widget _detail(IconData icon, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF777777), size: 23),
          const SizedBox(width: 11),
          Expanded(child: Text(value, style: _text.copyWith(fontSize: 14))),
        ]),
      );
}
