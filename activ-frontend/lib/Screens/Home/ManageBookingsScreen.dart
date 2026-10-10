import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum BookingStatus { upcoming, ongoing, canceled, noShow, completed }

class _Booking {
  final String id;
  final String customerName;
  final String phone;
  final String email;
  final String activity;
  final String date;
  final String time;
  final String bookedOn;
  final int participants;
  final double totalAmount;
  final double commission;
  final String paymentMode;
  BookingStatus status;

  _Booking({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.activity,
    required this.date,
    required this.time,
    required this.bookedOn,
    required this.participants,
    required this.totalAmount,
    required this.commission,
    required this.paymentMode,
    required this.status,
  });

  double get earnings => totalAmount - commission;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ManageBookingsScreen extends StatefulWidget {
  const ManageBookingsScreen({super.key});

  @override
  State<ManageBookingsScreen> createState() => _State();
}

class _State extends State<ManageBookingsScreen> {
  int _selectedTab = 0; // 0=Today 1=Upcoming 2=Past 3=All
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final _tabs = ['Today', 'Upcoming', 'Past', 'All'];

  final List<_Booking> _bookings = [
    _Booking(id: 'BK1234', customerName: 'Shreyas Iyer', phone: '+91 98-0123-4567', email: 'shreyas.iyer@gmail.com', activity: 'Gym class', date: '19 Nov 2025', time: '06:00 PM', bookedOn: '14 Nov 2025', participants: 2, totalAmount: 1200, commission: 180, paymentMode: 'UPI', status: BookingStatus.upcoming),
    _Booking(id: 'BK1235', customerName: 'MS Dhoni', phone: '+91 98-0123-4568', email: 'ms.dhoni@gmail.com', activity: 'Gym class', date: '19 Nov 2025', time: '07:00 PM', bookedOn: '15 Nov 2025', participants: 1, totalAmount: 600, commission: 90, paymentMode: 'UPI', status: BookingStatus.ongoing),
    _Booking(id: 'BK1236', customerName: 'Rohit Sharma', phone: '+91 98-0123-4569', email: 'rohit.sharma@gmail.com', activity: 'Gym class', date: '19 Nov 2025', time: '11:00 AM', bookedOn: '13 Nov 2025', participants: 4, totalAmount: 2400, commission: 360, paymentMode: 'Card', status: BookingStatus.canceled),
    _Booking(id: 'BK1237', customerName: 'S Tendulkar', phone: '+91 98-0123-4570', email: 's.tendulkar@gmail.com', activity: 'Gym class', date: '19 Nov 2025', time: '10:00 AM', bookedOn: '12 Nov 2025', participants: 2, totalAmount: 1200, commission: 180, paymentMode: 'UPI', status: BookingStatus.noShow),
    _Booking(id: 'BK1238', customerName: 'J Bumrah', phone: '+91 98-0123-4571', email: 'j.bumrah@gmail.com', activity: 'Gym class', date: '19 Nov 2025', time: '09:00 AM', bookedOn: '11 Nov 2025', participants: 2, totalAmount: 1200, commission: 180, paymentMode: 'UPI', status: BookingStatus.completed),
  ];

  List<_Booking> get _filtered {
    var list = _bookings.where((b) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return b.customerName.toLowerCase().contains(q) || b.id.toLowerCase().contains(q);
      }
      return true;
    }).toList();
    if (_selectedTab == 1) list = list.where((b) => b.status == BookingStatus.upcoming).toList();
    if (_selectedTab == 2) list = list.where((b) => b.status == BookingStatus.completed || b.status == BookingStatus.canceled || b.status == BookingStatus.noShow).toList();
    return list;
  }

  int get _todayBookings => _bookings.length;
  double get _todayRevenue => _bookings.where((b) => b.status != BookingStatus.canceled).fold(0, (s, b) => s + b.totalAmount);
  int get _completed => _bookings.where((b) => b.status == BookingStatus.completed).length;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Status helpers ──────────────────────────────────────────────────────────

  static const _statusLabels = {
    BookingStatus.upcoming: 'Upcoming',
    BookingStatus.ongoing: 'Ongoing',
    BookingStatus.canceled: 'Canceled',
    BookingStatus.noShow: 'No Show',
    BookingStatus.completed: 'Completed',
  };

  static const _statusColors = {
    BookingStatus.upcoming: Color(0xFFFFA000),
    BookingStatus.ongoing: Color(0xFF2EB944),
    BookingStatus.canceled: Color(0xFF9E9E9E),
    BookingStatus.noShow: Color(0xFFFE6B6B),
    BookingStatus.completed: Color(0xFF9D38EB),
  };

  static const _statusBg = {
    BookingStatus.upcoming: Color(0xFFFFF3E0),
    BookingStatus.ongoing: Color(0xFFE8F5E9),
    BookingStatus.canceled: Color(0xFFF5F5F5),
    BookingStatus.noShow: Color(0xFFFFEBEB),
    BookingStatus.completed: Color(0xFFF3E8FF),
  };

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5E8),
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _buildStats(),
                    const SizedBox(height: 16),
                    _buildTabs(),
                    const SizedBox(height: 12),
                    _buildSearch(),
                    const SizedBox(height: 12),
                    ..._filtered.map(_buildBookingCard),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF1F1F1F)),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Manage bookings',
              style: TextStyle(fontSize: 18, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statCard('Today\'s Bookings', '$_todayBookings', Icons.calendar_today_outlined, const Color(0xFF3F3F3F))),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Today\'s Revenue', '₹${_todayRevenue.toStringAsFixed(2)}', Icons.currency_rupee, const Color(0xFF9D38EB))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Completed', '$_completed', Icons.check_circle_outline, const Color(0xFF2EB944))),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF3F3F3F))),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = i == _selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF9D38EB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(_tabs[i],
                      style: TextStyle(
                          fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF3F3F3F))),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(0xFF9E9E9E)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', color: Color(0xFF1F1F1F)),
              decoration: const InputDecoration(
                border: InputBorder.none, hintText: 'Search by name, booking id...',
                hintStyle: TextStyle(fontSize: 13, fontFamily: 'Satoshi', color: Color(0xFF9E9E9E)),
                isDense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(_Booking b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showBookingDetails(b),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(b.customerName,
                        style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                  ),
                  _statusBadge(b.status),
                ],
              ),
              const SizedBox(height: 4),
              Text('${b.activity}  |  ${b.date}  |  ${b.time}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF7F7F7F))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('₹${b.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                  const Text('  |  ',
                      style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF7F7F7F))),
                  Text('${b.participants} ${b.participants == 1 ? 'person' : 'persons'}',
                      style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF1F1F1F))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(BookingStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusBg[status],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_statusLabels[status]!,
          style: TextStyle(fontSize: 11, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: _statusColors[status])),
    );
  }

  // ── Booking details dialog ──────────────────────────────────────────────────

  void _showBookingDetails(_Booking b) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row
                Row(
                  children: [
                    const Expanded(
                      child: Text('Booking details',
                          style: TextStyle(fontSize: 16, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: const Icon(Icons.close, size: 20, color: Color(0xFF1F1F1F)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Customer info
                _sectionTitle('Customer information'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _infoField('Full Name', b.customerName)),
                    const SizedBox(width: 12),
                    Expanded(child: _infoField('Phone Number', b.phone)),
                  ],
                ),
                const SizedBox(height: 10),
                _infoField('Email Address', b.email),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                // Booking info
                _sectionTitle('Booking information'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _infoField('Booking ID', b.id)),
                    const SizedBox(width: 12),
                    Expanded(child: _infoField('Activity', b.activity.replaceAll(' class', ''))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _infoField('Date', b.date)),
                    const SizedBox(width: 12),
                    Expanded(child: _infoField('Time', b.time)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _infoField('Participants', '${b.participants} people')),
                    const SizedBox(width: 12),
                    Expanded(child: _infoField('Booked On', b.bookedOn)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                // Payment info
                _sectionTitle('Payment information'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _infoField('Payment Mode', b.paymentMode)),
                    const SizedBox(width: 12),
                    Expanded(child: _infoField('Total Amount', '₹${b.totalAmount.toStringAsFixed(0)}')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _infoField('Commission', '₹${b.commission.toStringAsFixed(0)}')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Earnings',
                              style: TextStyle(fontSize: 12, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF7F7F7F))),
                          const SizedBox(height: 2),
                          Text('₹${b.earnings.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF9D38EB))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                // Manage booking
                _sectionTitle('Manage Booking'),
                const SizedBox(height: 12),
                _buildManageActions(b, ctx, setLocal),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)));

  Widget _infoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF7F7F7F))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F))),
      ],
    );
  }

  Widget _buildManageActions(_Booking b, BuildContext ctx, StateSetter setLocal) {
    if (b.status == BookingStatus.canceled || b.status == BookingStatus.noShow || b.status == BookingStatus.completed) {
      return _statusBadge(b.status);
    }

    final isUpcoming = b.status == BookingStatus.upcoming;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setLocal(() => b.status = BookingStatus.noShow);
              setState(() {});
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFE6B6B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text('Mark No-show',
                style: TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Color(0xFFFE6B6B))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setLocal(() => b.status = isUpcoming ? BookingStatus.ongoing : BookingStatus.completed);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D38EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              elevation: 0,
            ),
            child: Text(isUpcoming ? 'Check-in' : 'Mark Completed',
                style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
