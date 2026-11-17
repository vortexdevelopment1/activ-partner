import 'package:flutter/material.dart';

import 'app_colors.dart';

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
