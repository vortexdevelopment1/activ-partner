import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../Beans/venue_image.dart';
import '../../Beans/venue_image_model.dart';
import '../../Database/auth_service.dart';
import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../CommonCode.dart';
import '../StringExtensions.dart';

/*class VenueViewImageScreen extends StatefulWidget {
  const VenueViewImageScreen({super.key});

  @override
  State<VenueViewImageScreen> createState() => _VenueImageScreenState();
}

class _VenueImageScreenState extends State<VenueViewImageScreen> {
  List<VenueImage> venueImages = [];
  VenueImage? coverImage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadVenueImages();
  }

  // =======================
  // FETCH IMAGES
  // =======================
  Future<void> loadVenueImages() async {
    try {
      await AuthService().ensureAnonymousLogin();

      final uid = FirebaseAuth.instance.currentUser!.uid;

      final doc = await FirebaseFirestore.instance
          .collection("activ_user")
          .doc(uid)
          .get();

      if (!doc.exists) {
        setState(() => isLoading = false);
        return;
      }

      final data = doc.data();
      if (data == null || !data.containsKey("venue_images")) {
        setState(() => isLoading = false);
        return;
      }

      final List list = data["venue_images"];

      venueImages = list
          .map((e) => VenueImage.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      if (venueImages.isNotEmpty) {
        coverImage = venueImages.firstWhere(
              (img) => img.coverPhoto == true,
          orElse: () => venueImages.first,
        );
      }

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("❌ Error loading images: $e");
      setState(() => isLoading = false);
    }
  }

  // =======================
  // UI
  // =======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Venue Images"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : venueImages.isEmpty
          ? const Center(child: Text("No images available"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoverImage(),
            const SizedBox(height: 16),
            _buildImageGrid(),
          ],
        ),
      ),
    );
  }

  // =======================
  // COVER IMAGE
  // =======================
  Widget _buildCoverImage() {
    if (coverImage == null) return const SizedBox();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.network(
            coverImage!.url,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Cover Photo",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }

  // =======================
  // IMAGE GRID
  // =======================
  Widget _buildImageGrid() {
    final otherImages =
    venueImages.where((img) => img.coverPhoto == false).toList();

    if (otherImages.isEmpty) return const SizedBox();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: otherImages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            otherImages[index].url,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}*/




class VenueViewImageScreen extends StatefulWidget {
  const VenueViewImageScreen({super.key});

  @override
  State<VenueViewImageScreen> createState() => _VenueImageScreenState();
}

class _VenueImageScreenState extends State<VenueViewImageScreen> {
  bool isLoading = true;
  List<VenueImageModel> images = [];

  @override
  void initState() {
    super.initState();
    fetchActivityImages();
  }

  // =======================
  // FETCH IMAGES
  // =======================
  /*Future<void> fetchImages() async {
    await AuthService().ensureAnonymousLogin();

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(uid)
        .get();

    if (!doc.exists) {
      setState(() => isLoading = false);
      return;
    }

    final data = doc.data();
    if (data == null || !data.containsKey("venue_images")) {
      setState(() => isLoading = false);
      return;
    }

    final List list = data["venue_images"];

    images = list
        .map((e) => VenueImage.fromMap(Map<String, dynamic>.from(e)))
        .toList();

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


  // =======================
  // UI
  // =======================
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
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
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        double width = constraints.maxWidth;

                        bool isMobile = width < 600;
                        bool isTablet = width >= 600 && width < 1100;

                        double containerWidth =
                        isMobile ? width * 1 : (isTablet ? 500 : 600);

                        return Container(
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              getToolTab(context),

                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(15, 0, 15, 0),
                                  child: isLoading
                                      ? const Center(child: CircularProgressIndicator())
                                      : images.isEmpty
                                      ? const Center(child: Text("No images found"))
                                      : ListView.builder(
                                    itemCount: images.length,
                                    itemBuilder: (context, index) {
                                      return _imageItem(images[index]);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    )
                  ],
                )
              ),
            ),
          )
        ],
      ),
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

          getTitleText(context, 'Venue Images', 'Venue_Images_List')

        ],
      ),
    );
  }

  // =======================
  // IMAGE ITEM (LIST)
  // =======================
  Widget _imageItem(VenueImageModel img) {
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.network(
              img.url,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

            //  COVER PHOTO TAG (TOP RIGHT)
            if (img.coverPhoto)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        ),
      ),
    );
  }
}

