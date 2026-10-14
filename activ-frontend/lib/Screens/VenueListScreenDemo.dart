import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VenueListScreenDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    CollectionReference venueRef =
    FirebaseFirestore.instance.collection('venue_operate_type');

    return Scaffold(
      appBar: AppBar(title: Text("Venue Types")),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('venue_operate_type')
              .doc('main_document') // 👈 yahi ID rakhi jo upar set() me use ki
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error loading data"));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text("No data found"));
            }

            final docData = snapshot.data!.data() as Map<String, dynamic>;
            final List<dynamic> venueList = docData['venue_type'] ?? [];

            return ListView.builder(
              itemCount: venueList.length,
              itemBuilder: (context, index) {
                final venue = venueList[index] as Map<String, dynamic>;

                return ListTile(
                  title: Text(venue['title'] ?? "", style: TextStyle(color: AppColors.black1)),
                  subtitle: Text(venue['description'] ?? ""),
                );
              },
            );
          },
        )

    );
  }
}
