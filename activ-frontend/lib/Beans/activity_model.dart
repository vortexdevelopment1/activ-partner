class ActivityModel {
  final String activityId;
  final String title;
  final Map<String, dynamic> operateValue;
  final List<dynamic> images;
  final List<dynamic> placeOffer;
  final Map<String, dynamic> venueTiming;
  final String activitySuited;
  final String activityVariation;
  final String anythingElse;
  final String equipmentProvided;
  final String participantsFollow;
  final String physicalSetup;
  final String safetyMeasures;
  final String activityStatus;
  final String numberOfCourt;
  final String flooringType;
  final String maximumCapacity;
  final String description;

  ActivityModel({
    required this.activityId,
    required this.title,
    required this.operateValue,
    required this.images,
    required this.placeOffer,
    required this.venueTiming,
    required this.activitySuited,
    required this.activityVariation,
    required this.anythingElse,
    required this.equipmentProvided,
    required this.participantsFollow,
    required this.physicalSetup,
    required this.safetyMeasures,
    required this.activityStatus,
    required this.numberOfCourt,
    required this.flooringType,
    required this.maximumCapacity,
    required this.description,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      activityId: json['activity_id'],
      operateValue: json['operate_value'] ?? {},
      title: json['operate_value']?['title'] ?? "Untitled",
      images: json['images'] ?? [],
      placeOffer: json['venue_amenities']?['place_offer'] ?? [],
      venueTiming: json['venue_timing'] ?? {}, // 👈 SAFE
      activitySuited: json['activity_suited'] ?? "",
      activityVariation: json['activity_variation'] ?? "",
      anythingElse: json['anything_else'] ?? "",
      equipmentProvided: json['equipment_provided'] ?? "",
      participantsFollow: json['participants_follow'] ?? "",
      physicalSetup: json['physical_setup'] ?? "",
      safetyMeasures: json['safety_measures'] ?? "",
      activityStatus: json['activity_status'] ?? "",
      numberOfCourt: json['number_of_court'] ?? "",
      flooringType: json['flooring_type'] ?? "",
      maximumCapacity: json['maximum_capacity'] ?? "",
      description: json['description'] ?? "",
    );
  }
}
