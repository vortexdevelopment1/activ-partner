import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_svg/svg.dart';

import '../../Beans/venue_image_model.dart';
import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../CommonCode.dart';
import '../StringExtensions.dart';

class VenueImageCarouselScreen extends StatefulWidget {
  const VenueImageCarouselScreen({super.key});

  @override
  State<VenueImageCarouselScreen> createState() =>
      _VenueImageCarouselScreenState();
}

class _VenueImageCarouselScreenState extends State<VenueImageCarouselScreen> {
  List<VenueImageModel> images = [];
  bool isLoading = true;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchActivityImages();
  }

  /*Future<void> fetchVenueImages() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(uid)
        .get();

    final List list = doc.data()?['venue_images'] ?? [];

    images = list
        .map((e) => VenueImageModel.fromJson(e))
        .toList();

    // 👇 Cover image ko first pe lao (optional but recommended)
    images.sort((a, b) => b.coverPhoto ? 1 : -1);

    setState(() => isLoading = false);
  }*/

  Future<void> fetchActivityImages() async {
    setState(() => isLoading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(uid)
        .get();

    final data = doc.data();

    if (data == null) {
      images = [];
      setState(() => isLoading = false);
      return;
    }

    // Extract the first activity's images (or all activities if needed)
    final List activityList = data['activity_list'] ?? [];
    List<dynamic> imageList = [];

    if (activityList.isNotEmpty) {
      imageList = activityList[0]['images'] ?? [];
    }

    // Map to your model
    images = imageList
        .map((e) => VenueImageModel.fromJson(e))
        .toList();

    // Sort cover photo first
    images.sort((a, b) => b.coverPhoto ? 1 : -1);

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (images.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No images found")),
      );
    }

    return Stack(
      children: [
        /*To Set Top Header Color*/
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 100,
            color: AppColors.yellowTop,
          ),
        ),
        /*To Set Bottom Header Color*/
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 100,
            color: AppColors.white,
          ),
        ),
        SafeArea(
          top: true,
          bottom: true,
          left: false,
          right: false,
          child: Scaffold(
            body: Container(
              decoration: context.getYellowGradient,
              child: Column(
                children: [

                  getToolTab(context),

                  Container(
                    margin: EdgeInsets.fromLTRB(0, 5, 0, 0),
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        ///  CAROUSEL
                        CarouselSlider(
                          options: CarouselOptions(
                            //height: MediaQuery.of(context).size.height * 0.5,
                            viewportFraction: 1,
                            enableInfiniteScroll: true,
                            // 🔁 AUTO SCROLL
                            autoPlay: true,
                            autoPlayInterval: const Duration(seconds: 3),
                            autoPlayAnimationDuration:
                            const Duration(milliseconds: 800),
                            autoPlayCurve: Curves.easeInOut,
                            pauseAutoPlayOnTouch: true,
                            pauseAutoPlayOnManualNavigate: true,
                            onPageChanged: (index, reason) {
                              setState(() => currentIndex = index);
                            },
                          ),
                          items: images.map((img) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  img.url,
                                 // fit: BoxFit.cover,
                                ),

                                /// TOP GRADIENT
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.center,
                                      colors: [
                                        Colors.black.withOpacity(0.5),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),

                                /// 🔖 COVER PHOTO LABEL
                                if (img.coverPhoto)
                                  Positioned(
                                    //top: MediaQuery.of(context).padding.top + 0,
                                    top: 20,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        "Cover Photo",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),

                        /// 🔘 DOT INDICATOR
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: currentIndex == index ? 10 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: currentIndex == index
                                      ? AppColors.white
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            ),
          ),
        )
      ],
    );
  }

  // To show the toolbar
  Widget getToolTab(BuildContext context)
  {
    return Container(
      height: AppSize.toolTabSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: InkWell(onTap: ()
              {
                Navigator.pop(context);
              },
                  child: Container(
                    padding: EdgeInsets.fromLTRB(15,10,15,10),
                    child: SvgPicture.asset('assets/ic_back.svg',),
                  )
              ),
            ),
          ),

          getTitleText(context, 'Venue Images', 'Venue_Image_Slider')

        ],
      ),
    );
  }

}
