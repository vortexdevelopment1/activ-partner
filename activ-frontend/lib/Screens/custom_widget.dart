
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class CustomWidget extends StatelessWidget {

  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const CustomWidget.rectangular({
    this.width = double.infinity,
    required this.height
  }): this.shapeBorder = const RoundedRectangleBorder();

  const CustomWidget.circular({
    this.width = double.infinity,
    required this.height,
    this.shapeBorder = const CircleBorder()
  });

  const CustomWidget.rectangular1({
    this.width = double.infinity,
    this.height = double.infinity,
    this.shapeBorder = const RoundedRectangleBorder()
  });

  const CustomWidget.rectangularBanner({
    this.width = double.infinity,
    required this.height,
    this.shapeBorder = const RoundedRectangleBorder()
  });

  @override
  Widget build(BuildContext context)  => Shimmer.fromColors(
    direction: ShimmerDirection.ltr,
    baseColor: Colors.grey[100]!,
    highlightColor: Colors.grey[200]!,
    period: Duration(seconds: 1),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: new BorderRadius.only(
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
          bottomRight: const Radius.circular(5),
          bottomLeft: const Radius.circular(5),
        ),
      ),
    ),
  );
}
