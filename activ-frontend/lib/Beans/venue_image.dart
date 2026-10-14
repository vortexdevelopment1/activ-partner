class VenueImage {
  final String url;
  final bool coverPhoto;

  VenueImage({
    required this.url,
    required this.coverPhoto,
  });

  factory VenueImage.fromMap(Map<String, dynamic> map) {
    return VenueImage(
      url: map["url"] ?? "",
      coverPhoto: map["coverPhoto"] ?? false,
    );
  }
}
