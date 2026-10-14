class VenueTypeModel {
  String id;
  String type;
  String title;
  String description;
  String image;
  bool active;
  bool isSelected;

  VenueTypeModel({
    this.id = "",
    this.type = "",
    this.title = "",
    this.description = "",
    this.image = "",
    this.active = true,
    this.isSelected = false,
  });

  factory VenueTypeModel.fromJson(Map<String, dynamic> json) {
    return VenueTypeModel(
      id: json['id'] ?? "",
      type: json['type'] ?? "",
      title: json['title'] ?? "",
      description: json['description'] ?? "",
      image: json['image'] ?? "",
      active: json['active'] ?? true,
      isSelected: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "type": type,
      "title": title,
      "description": description,
      "image": image,
      "active": active,
      "isSelected": isSelected,
    };
  }
}
