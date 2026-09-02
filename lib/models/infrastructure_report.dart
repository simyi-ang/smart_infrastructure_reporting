class InfrastructureReport {
  final String id;
  final String referenceNumber;
  final String citizenId;

  final String title;
  final String category;
  final String priority;
  final String description;

  final String address;
  final String? landmark;

  final double? latitude;
  final double? longitude;

  final String status;

  final String? assignedDepartment;

  final int progressPercentage;

  final DateTime? estimatedCompletion;

  final DateTime createdAt;
  final DateTime updatedAt;

  InfrastructureReport({
    required this.id,
    required this.referenceNumber,
    required this.citizenId,
    required this.title,
    required this.category,
    required this.priority,
    required this.description,
    required this.address,
    this.landmark,
    this.latitude,
    this.longitude,
    required this.status,
    this.assignedDepartment,
    required this.progressPercentage,
    this.estimatedCompletion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InfrastructureReport.fromMap(
      Map<String, dynamic> map,
      ) {
    return InfrastructureReport(
      id:
      map['id']?.toString() ??
          '',

      referenceNumber:
      map['reference_number']
          ?.toString() ??
          '',

      citizenId:
      map['citizen_id']
          ?.toString() ??
          '',

      title:
      map['title']?.toString() ??
          '',

      category:
      map['category']?.toString() ??
          '',

      priority:
      map['priority']?.toString() ??
          '',

      description:
      map['description']
          ?.toString() ??
          '',

      address:
      map['address']?.toString() ??
          '',

      landmark:
      map['landmark']?.toString(),

      latitude:
      map['latitude'] == null
          ? null
          : (map['latitude'] as num)
          .toDouble(),

      longitude:
      map['longitude'] == null
          ? null
          : (map['longitude'] as num)
          .toDouble(),

      status:
      map['status']?.toString() ??
          'pending',

      assignedDepartment:
      map['assigned_department']
          ?.toString(),

      progressPercentage:
      map['progress_percentage']
      as int? ??
          0,

      estimatedCompletion:
      map['estimated_completion'] !=
          null
          ? DateTime.tryParse(
        map['estimated_completion']
            .toString(),
      )
          : null,

      createdAt:
      DateTime.parse(
        map['created_at'].toString(),
      ),

      updatedAt:
      DateTime.parse(
        map['updated_at'].toString(),
      ),
    );
  }
}