import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../Style/app_colors.dart';

class WorkSpace extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SpinKitFadingCircle(
          color: AppColors.black),
    );
  }
}
