class StateModel {
  String id;
  String name;
  bool active;

  StateModel({
    required this.id,
    required this.name,
    required this.active,
  });

  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      active: json['active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'active': active,
    };
  }
}
