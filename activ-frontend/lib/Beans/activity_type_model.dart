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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['image'] = this.image;
    data['type'] = this.type;
    data['title'] = this.title;
    data['description'] = this.description;
    data['active'] = this.active;
    data['isSelected'] = this.isSelected;

    return data;
  }
}