class VenueImageModel {
  final String url;
  final bool coverPhoto;

  VenueImageModel({
    required this.url,
    required this.coverPhoto,
  });

  factory VenueImageModel.fromJson(Map<String, dynamic> json) {
    return VenueImageModel(
      url: json['url'] ?? '',
      coverPhoto: json['coverPhoto'] ?? false,
    );
  }
}
