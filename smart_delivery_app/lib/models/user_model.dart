class UserModel {
  final int userId;
  final String name;
  final String login;
  final String role;
  final int? driverId;
  final String? phone;
  final String? email;
  final String? driverProfileImageBase64;

  const UserModel({
    required this.userId,
    required this.name,
    required this.login,
    required this.role,
    this.driverId,
    this.phone,
    this.email,
    this.driverProfileImageBase64,
  });

  bool get isDriver => role == 'driver';
  bool get isCustomer => role == 'customer';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as int,
      name: json['name'] as String? ?? '',
      login: json['login'] as String? ?? '',
      role: json['role'] as String? ?? 'customer',
      driverId: json['driver_id'] as int?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      driverProfileImageBase64:
          json['driver_profile_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'login': login,
    'role': role,
    'driver_id': driverId,
    'phone': phone,
    'email': email,
    'driver_profile_image': driverProfileImageBase64,
  };
}
