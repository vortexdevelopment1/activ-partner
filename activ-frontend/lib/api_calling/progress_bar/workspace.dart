import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../Style/app_colors.dart';

class WorkSpace extends StatelessWidget {
  const WorkSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.gray2,
      highlightColor: AppColors.white,
      child: Container(
        width: 96,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.gray2,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
