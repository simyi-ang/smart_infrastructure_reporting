class CommunityReport {
  final String id;
  final String referenceNumber;
  final String title;
  final String category;
  final String priority;
  final String? description;
  final String address;
  final String status;
  final int progressPercentage;
  final double? latitude;
  final double? longitude;
  final double? distanceMetres;
  final int affectedCount;
  final int stillExistsCount;
  final int looksFixedCount;
  final int contributionCount;
  final bool userAffected;
  final String? userFeedback;
  final double impactScore;

  const CommunityReport({
    required this.id,
    required this.referenceNumber,
    required this.title,
    required this.category,
    required this.priority,
    required this.description,
    required this.address,
    required this.status,
    required this.progressPercentage,
    required this.latitude,
    required this.longitude,
    required this.distanceMetres,
    required this.affectedCount,
    required this.stillExistsCount,
    required this.looksFixedCount,
    required this.contributionCount,
    required this.userAffected,
    required this.userFeedback,
    required this.impactScore,
  });

  factory CommunityReport.fromMap(Map<String, dynamic> map) {
    int i(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    double? d(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    return CommunityReport(
      id: '${map['id'] ?? ''}',
      referenceNumber: '${map['reference_number'] ?? ''}',
      title: '${map['title'] ?? 'Untitled report'}',
      category: '${map['category'] ?? 'Other'}',
      priority: '${map['priority'] ?? 'Medium'}',
      description: map['description']?.toString(),
      address: '${map['address'] ?? ''}',
      status: '${map['status'] ?? 'Submitted'}',
      progressPercentage: i(map['progress_percentage']),
      latitude: d(map['latitude']),
      longitude: d(map['longitude']),
      distanceMetres: d(map['distance_m']),
      affectedCount: i(map['affected_count']),
      stillExistsCount: i(map['still_exists_count']),
      looksFixedCount: i(map['looks_fixed_count']),
      contributionCount: i(map['contribution_count']),
      userAffected: map['user_affected'] == true,
      userFeedback: map['user_feedback']?.toString(),
      impactScore: d(map['impact_score']) ?? 0,
    );
  }

  CommunityReport copyWith({
    int? affectedCount,
    int? stillExistsCount,
    int? looksFixedCount,
    int? contributionCount,
    bool? userAffected,
    String? userFeedback,
  }) {
    return CommunityReport(
      id: id,
      referenceNumber: referenceNumber,
      title: title,
      category: category,
      priority: priority,
      description: description,
      address: address,
      status: status,
      progressPercentage: progressPercentage,
      latitude: latitude,
      longitude: longitude,
      distanceMetres: distanceMetres,
      affectedCount: affectedCount ?? this.affectedCount,
      stillExistsCount: stillExistsCount ?? this.stillExistsCount,
      looksFixedCount: looksFixedCount ?? this.looksFixedCount,
      contributionCount: contributionCount ?? this.contributionCount,
      userAffected: userAffected ?? this.userAffected,
      userFeedback: userFeedback ?? this.userFeedback,
      impactScore: impactScore,
    );
  }

  String get distanceLabel {
    if (distanceMetres == null) return 'Distance unavailable';
    if (distanceMetres! < 1000) return '${distanceMetres!.round()} m away';
    return '${(distanceMetres! / 1000).toStringAsFixed(1)} km away';
  }
}

class CommunityContribution {
  final String id;
  final String reportId;
  final String evidenceType;
  final String storagePath;
  final String? note;
  final String? signedUrl;
  final bool isMine;

  const CommunityContribution({
    required this.id,
    required this.reportId,
    required this.evidenceType,
    required this.storagePath,
    required this.note,
    required this.signedUrl,
    required this.isMine,
  });

  bool get isImage => evidenceType == 'image';
  bool get isVideo => evidenceType == 'video';
}
