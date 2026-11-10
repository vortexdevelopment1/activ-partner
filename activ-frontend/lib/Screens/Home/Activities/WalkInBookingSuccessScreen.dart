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

  static const _backgroundColor = Color(0xFFF0F6D2);
  static const _cardBorderRadius = BorderRadius.all(Radius.circular(22));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: const ValueKey('walk-in-success-card'),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6FAF3D),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Walk-In Slot Reserved!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'This time slot is now blocked on the\nACTIV app to prevent double bookings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Slot Details',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: _cardBorderRadius,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (venueName.isNotEmpty) ...[
                            _row(Icons.location_on, venueName, iconSize: 20),
                            const SizedBox(height: 12),
                          ],
                          _row(Icons.calendar_today_outlined, date,
                              iconSize: 18),
                          if (court.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _row(Icons.grid_on_outlined, court, iconSize: 18),
                          ],
                          ...slots.map(
                            (slot) => Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _row(Icons.access_time, slot,
                                  iconSize: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Participant Details',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: _cardBorderRadius,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row(Icons.account_circle_outlined, participantName,
                              iconSize: 20),
                          const SizedBox(height: 12),
                          _row(Icons.call, participantPhone, iconSize: 19),
                          if (participantEmail?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            _row(Icons.email, participantEmail!.trim(),
                                iconSize: 19),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDF6DE),
                          foregroundColor: Colors.black,
                          side: const BorderSide(
                              color: Colors.black, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Book Another Slot',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: const Color(0xFFDAFF50),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Back To Activity Management',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFFDAFF50),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _row(IconData icon, String text, {double iconSize = 19}) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF666666), size: iconSize),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF202124),
              ),
            ),
          ),
        ],
      );
}
