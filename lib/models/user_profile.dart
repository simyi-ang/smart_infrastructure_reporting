class UserProfile {
  final String id;

  final String fullName;

  final String email;

  final String phone;

  final String role;

  final String accountStatus;

  final String? profileImageUrl;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.accountStatus,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive =>
      accountStatus ==
          'active';

  bool get isPendingDeletion =>
      accountStatus ==
          'pending_deletion';

  factory UserProfile.fromMap(
      Map<String, dynamic> map,
      ) {
    return UserProfile(
      id:
      map['id']?.toString() ??
          '',

      fullName:
      map['full_name']
          ?.toString() ??
          '',

      email:
      map['email']?.toString() ??
          '',

      phone:
      map['phone']?.toString() ??
          '',

      role:
      map['role']?.toString() ??
          'citizen',

      accountStatus:
      map['account_status']
          ?.toString() ??
          'active',

      profileImageUrl:
      map['profile_image_url']
          ?.toString(),

      createdAt:
      map['created_at'] == null
          ? null
          : DateTime.tryParse(
        map['created_at']
            .toString(),
      ),

      updatedAt:
      map['updated_at'] == null
          ? null
          : DateTime.tryParse(
        map['updated_at']
            .toString(),
      ),
    );
  }
}