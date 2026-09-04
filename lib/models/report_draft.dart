class ReportDraft {
  final String? id;

  final String category;
  final String priority;
  final String title;
  final String description;

  final String? landmark;
  final String? manualAddress;

  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;

  final String? detectedAddress;

  final String? locationVerificationStatus;
  final double? addressDistanceMeters;

  final String? voiceTranscript;
  final String? voiceLocationContext;
  final String? voiceSafetyConcern;

  final int currentStep;

  final bool hasCloseUpEvidence;
  final bool hasContextEvidence;

  final List<String> evidenceImagePaths;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportDraft({
    this.id,
    this.category = '',
    this.priority = '',
    this.title = '',
    this.description = '',
    this.landmark,
    this.manualAddress,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.detectedAddress,
    this.locationVerificationStatus,
    this.addressDistanceMeters,
    this.voiceTranscript,
    this.voiceLocationContext,
    this.voiceSafetyConcern,
    this.currentStep = 0,
    this.hasCloseUpEvidence = false,
    this.hasContextEvidence = false,
    this.evidenceImagePaths = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportDraft.empty() {
    final now = DateTime.now();

    return ReportDraft(
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get hasData {
    return category.trim().isNotEmpty ||
        priority.trim().isNotEmpty ||
        title.trim().isNotEmpty ||
        description.trim().isNotEmpty ||
        landmark?.trim().isNotEmpty == true ||
        manualAddress?.trim().isNotEmpty == true ||
        latitude != null ||
        longitude != null ||
        voiceTranscript?.trim().isNotEmpty == true ||
        evidenceImagePaths.isNotEmpty;
  }

  bool get hasLocation {
    return latitude != null && longitude != null;
  }

  bool get hasVoiceData {
    return voiceTranscript?.trim().isNotEmpty == true;
  }

  bool get hasEvidence {
    return evidenceImagePaths.isNotEmpty;
  }

  ReportDraft copyWith({
    String? id,
    String? category,
    String? priority,
    String? title,
    String? description,
    String? landmark,
    String? manualAddress,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    String? detectedAddress,
    String? locationVerificationStatus,
    double? addressDistanceMeters,
    String? voiceTranscript,
    String? voiceLocationContext,
    String? voiceSafetyConcern,
    int? currentStep,
    bool? hasCloseUpEvidence,
    bool? hasContextEvidence,
    List<String>? evidenceImagePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportDraft(
      id: id ?? this.id,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      landmark: landmark ?? this.landmark,
      manualAddress: manualAddress ?? this.manualAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracy:
      locationAccuracy ?? this.locationAccuracy,
      detectedAddress:
      detectedAddress ?? this.detectedAddress,
      locationVerificationStatus:
      locationVerificationStatus ??
          this.locationVerificationStatus,
      addressDistanceMeters:
      addressDistanceMeters ??
          this.addressDistanceMeters,
      voiceTranscript:
      voiceTranscript ?? this.voiceTranscript,
      voiceLocationContext:
      voiceLocationContext ??
          this.voiceLocationContext,
      voiceSafetyConcern:
      voiceSafetyConcern ??
          this.voiceSafetyConcern,
      currentStep:
      currentStep ?? this.currentStep,
      hasCloseUpEvidence:
      hasCloseUpEvidence ??
          this.hasCloseUpEvidence,
      hasContextEvidence:
      hasContextEvidence ??
          this.hasContextEvidence,
      evidenceImagePaths:
      evidenceImagePaths ??
          this.evidenceImagePaths,
      createdAt:
      createdAt ?? this.createdAt,
      updatedAt:
      updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'priority': priority,
      'title': title,
      'description': description,
      'landmark': landmark,
      'manualAddress': manualAddress,
      'latitude': latitude,
      'longitude': longitude,
      'locationAccuracy': locationAccuracy,
      'detectedAddress': detectedAddress,
      'locationVerificationStatus':
      locationVerificationStatus,
      'addressDistanceMeters':
      addressDistanceMeters,
      'voiceTranscript': voiceTranscript,
      'voiceLocationContext':
      voiceLocationContext,
      'voiceSafetyConcern':
      voiceSafetyConcern,
      'currentStep': currentStep,
      'hasCloseUpEvidence':
      hasCloseUpEvidence,
      'hasContextEvidence':
      hasContextEvidence,
      'evidenceImagePaths':
      evidenceImagePaths,
      'createdAt':
      createdAt.toIso8601String(),
      'updatedAt':
      updatedAt.toIso8601String(),
    };
  }

  factory ReportDraft.fromJson(
      Map<String, dynamic> json,
      ) {
    return ReportDraft(
      id: json['id']?.toString(),
      category:
      json['category']?.toString() ?? '',
      priority:
      json['priority']?.toString() ?? '',
      title:
      json['title']?.toString() ?? '',
      description:
      json['description']?.toString() ?? '',
      landmark:
      json['landmark']?.toString(),
      manualAddress:
      json['manualAddress']?.toString(),
      latitude:
      _toDouble(json['latitude']),
      longitude:
      _toDouble(json['longitude']),
      locationAccuracy:
      _toDouble(json['locationAccuracy']),
      detectedAddress:
      json['detectedAddress']?.toString(),
      locationVerificationStatus:
      json['locationVerificationStatus']
          ?.toString(),
      addressDistanceMeters:
      _toDouble(
        json['addressDistanceMeters'],
      ),
      voiceTranscript:
      json['voiceTranscript']?.toString(),
      voiceLocationContext:
      json['voiceLocationContext']
          ?.toString(),
      voiceSafetyConcern:
      json['voiceSafetyConcern']
          ?.toString(),
      currentStep:
      _toInt(json['currentStep']),
      hasCloseUpEvidence:
      json['hasCloseUpEvidence'] ==
          true,
      hasContextEvidence:
      json['hasContextEvidence'] ==
          true,
      evidenceImagePaths:
      _toStringList(
        json['evidenceImagePaths'],
      ),
      createdAt: _toDateTime(
        json['createdAt'],
      ),
      updatedAt: _toDateTime(
        json['updatedAt'],
      ),
    );
  }

  static double? _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  static int _toInt(
      dynamic value,
      ) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  static DateTime _toDateTime(
      dynamic value,
      ) {
    if (value == null) {
      return DateTime.now();
    }

    return DateTime.tryParse(
      value.toString(),
    ) ??
        DateTime.now();
  }

  static List<String> _toStringList(
      dynamic value,
      ) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) => item.toString(),
    )
        .toList();
  }
}