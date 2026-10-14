import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CurvePopupDesign extends StatelessWidget {
  final Widget child;
  final screenName;
  final VoidCallback? onClose;

  const CurvePopupDesign({super.key, required this.child, this.screenName, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Main popup container
            Container(
              width: MediaQuery.of(context).size.width, // Full screen width
              margin: const EdgeInsets.only(top: 20), // only top spacing for triangle
              padding: const EdgeInsets.only(
                top: 20,
                left: 0, // No left padding
                right: 0, // No right padding
                bottom: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: child,
            ),

            // Triangle shape
            Positioned(
              top: 0,
              child: ClipPath(
                clipper: CurvedTriangleClipper(),
                child: Container(
                  width: 40,
                  height: 20,
                  color: Colors.white,
                ),
              ),
            ),

            // Close button
            Positioned(
              top: 0,
              child: InkWell(
                onTap: ()
                {
                  // print('---------onClose----------- : ' + onClose.toString());

                  if (onClose != null)
                  {
                    onClose!(); // <-- Call the passed callback
                  } else {
                    // If User Come After Recharge Then Popup Automatically Close
                    if(screenName == "afterRecharge")
                    {}
                    else{
                      Navigator.pop(context); // fallback
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.only(top: 17, bottom: 10, left: 10, right: 10),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/close_popup.svg',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class CurvedTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, 0, size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}