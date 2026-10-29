import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Default partner photo, scaled to the surrounding avatar's size.
class DefaultPartnerAvatar extends StatelessWidget {
  const DefaultPartnerAvatar({super.key});

  @override
  Widget build(BuildContext context) => ClipOval(
        child: ColoredBox(
          color: const Color(0xFFD0D0D0),
          child: SvgPicture.asset(
            'assets/iconamoon_profile.svg',
            fit: BoxFit.contain,
            semanticsLabel: 'Partner profile',
          ),
        ),
      );
}
