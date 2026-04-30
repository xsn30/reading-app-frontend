class LoginResponseModel {
  final int id;
  final String username;
  final String role;
  final String linkedStudentUsername;
  final String phone;

  LoginResponseModel({
    required this.id,
    required this.username,
    required this.role,
    required this.linkedStudentUsername,
    required this.phone,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      id: (json['id'] as num).toInt(),
      username: (json['username'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      linkedStudentUsername: (json['linkedStudentUsername'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
    );
  }
}