class ActivityTypeModel {
  String id="";
  String image="";
  String type="";
  String title="";
  String description="";
  bool active = false;

  bool isSelected = false;

  ActivityTypeModel();

  ActivityTypeModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    image = json['image'];
    type = json['type'];
    title = json['title'];
    description = json['description'];
    active = json['active'];
    isSelected = json['isSelected'];

  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['image'] = image;
    data['type'] = type;
    data['title'] = title;
    data['description'] = description;
    data['active'] = active;
    data['isSelected'] = isSelected;

    return data;
  }
}