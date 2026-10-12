class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String? mobile;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      mobile: json['mobile'] as String?,
    );
  }
}
