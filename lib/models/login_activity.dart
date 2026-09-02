class LoginActivity {
  final String id;
  final String userId;
  final String loginMethod;
  final String deviceInfo;
  final String platform;
  final bool success;
  final DateTime createdAt;

  const LoginActivity({
    required this.id,
    required this.userId,
    required this.loginMethod,
    required this.deviceInfo,
    required this.platform,
    required this.success,
    required this.createdAt,
  });

  factory LoginActivity.fromMap(
      Map<String, dynamic> map,
      ) {
    return LoginActivity(
      id:
      map['id']?.toString() ??
          '',

      userId:
      map['user_id']?.toString() ??
          '',

      loginMethod:
      map['login_method']
          ?.toString() ??
          'Unknown',

      deviceInfo:
      map['device_info']
          ?.toString() ??
          'Unknown Device',

      platform:
      map['platform']
          ?.toString() ??
          'Unknown',

      success:
      map['success'] as bool? ??
          true,

      createdAt:
      DateTime.parse(
        map['created_at'].toString(),
      ),
    );
  }
}