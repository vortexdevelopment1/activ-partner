import 'package:flutter/material.dart';

class HelpSupportDemo extends StatefulWidget {
  const HelpSupportDemo({super.key});

  @override
  State<HelpSupportDemo> createState() => _HelpSupportDemoState();
}

class _HelpSupportDemoState extends State<HelpSupportDemo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool isOpen = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      reverseDuration: const Duration(milliseconds: 450),
    );

    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
      reverseCurve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  void toggleHelp() {
    if (isOpen) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() => isOpen = !isOpen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F9D2),
      body: Stack(
        children: [
          /// Main Screen Content
          Center(
            child: ElevatedButton(
              onPressed: () {},
              child: const Text("Send Code"),
            ),
          ),

          /// Help Card
          Positioned(
            left: 20,
            right: 20,
            bottom: 120,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.bottomRight,
                  child: _helpCard(),
                ),
              ),
            ),
          ),
        ],
      ),

      /// Floating Action Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.grey.shade700,
        onPressed: toggleHelp,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return RotationTransition(
              turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            isOpen ? Icons.close : Icons.help_outline,
            key: ValueKey(isOpen),
          ),
        ),
      ),
    );
  }

  Widget _helpCard() {
    return Material(
      elevation: 10,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Help & Support",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "We are here to help you succeed!\nAvailable from 9 AM - 9 PM",
              style: TextStyle(color: Colors.grey),
            ),
            Divider(height: 24),

            _HelpItem(icon: Icons.chat, text: "Chat with support"),
            _HelpItem(icon: Icons.call, text: "Call support"),
            _HelpItem(icon: Icons.help_outline, text: "FAQs"),
          ],
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HelpItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
