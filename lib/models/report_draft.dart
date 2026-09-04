class ReportDraft {
  // ============================================================
  // SENTINEL
  //
  // Allows copyWith() to distinguish:
  //
  // field not supplied  -> keep old value
  // field: null         -> intentionally clear value
  //
  // This fixes the common nullable copyWith problem.
  // ============================================================

  static const Object _unset = Object();

  final String? id;

  // ============================================================
  // REPORT DETAILS
  // ============================================================

  final String category;
  final String priority;
  final String title;
  final String description;

  // ============================================================
  // LOCATION
  // ============================================================

  final String? landmark;
  final String? manualAddress;

  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;

  final String? detectedAddress;

  final String? locationVerificationStatus;
  final double? addressDistanceMeters;

  // ============================================================
  // VOICE QUICK REPORT
  // ============================================================

  final String? voiceTranscript;
  final String? voiceLocationContext;
  final String? voiceSafetyConcern;

  // ============================================================
  // CURRENT CREATE-REPORT STEP
  //
  // Recommended:
  //
  // 1 = Details
  // 2 = Evidence
  // 3 = Location
  // 4 = Preview
  // ============================================================

  final int currentStep;

  // ============================================================
  // VERIFIED EVIDENCE
  // ============================================================

  final bool hasCloseUpEvidence;
  final bool hasContextEvidence;

  // ============================================================
  // EVIDENCE
  //
  // IMPORTANT:
  // These should contain persistent local application paths,
  // NOT temporary image_picker paths.
  // ============================================================

  final List<String> evidenceImagePaths;
  final List<String> evidenceVideoPaths;

  // ============================================================
  // TIMESTAMPS
  // ============================================================

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
    this.evidenceVideoPaths = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // ============================================================
  // EMPTY DRAFT
  // ============================================================

  factory ReportDraft.empty() {
    final DateTime now = DateTime.now();

    return ReportDraft(
      createdAt: now,
      updatedAt: now,
    );
  }

  // ============================================================
  // HAS ANY USEFUL DATA?
  // ============================================================

  bool get hasData {
    return category.trim().isNotEmpty ||
        priority.trim().isNotEmpty ||
        title.trim().isNotEmpty ||
        description.trim().isNotEmpty ||
        landmark?.trim().isNotEmpty == true ||
        manualAddress?.trim().isNotEmpty == true ||
        latitude != null ||
        longitude != null ||
        detectedAddress?.trim().isNotEmpty == true ||
        voiceTranscript?.trim().isNotEmpty == true ||
        evidenceImagePaths.isNotEmpty ||
        evidenceVideoPaths.isNotEmpty;
  }

  // ============================================================
  // LOCATION HELPERS
  // ============================================================

  bool get hasLocation {
    return latitude != null &&
        longitude != null;
  }

  bool get hasVoiceData {
    return voiceTranscript
        ?.trim()
        .isNotEmpty ==
        true;
  }

  // ============================================================
  // EVIDENCE HELPERS
  // ============================================================

  bool get hasEvidence {
    return evidenceImagePaths.isNotEmpty ||
        evidenceVideoPaths.isNotEmpty;
  }

  bool get hasImages {
    return evidenceImagePaths.isNotEmpty;
  }

  bool get hasVideos {
    return evidenceVideoPaths.isNotEmpty;
  }

  int get evidenceImageCount {
    return evidenceImagePaths.length;
  }

  int get evidenceVideoCount {
    return evidenceVideoPaths.length;
  }

  int get totalEvidenceCount {
    return evidenceImagePaths.length +
        evidenceVideoPaths.length;
  }

  // ============================================================
  // COPY WITH
  //
  // Nullable fields use Object? + sentinel so they can
  // intentionally be cleared.
  // ============================================================

  ReportDraft copyWith({
    Object? id = _unset,
    String? category,
    String? priority,
    String? title,
    String? description,
    Object? landmark = _unset,
    Object? manualAddress = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    Object? locationAccuracy = _unset,
    Object? detectedAddress = _unset,
    Object? locationVerificationStatus =
        _unset,
    Object? addressDistanceMeters = _unset,
    Object? voiceTranscript = _unset,
    Object? voiceLocationContext = _unset,
    Object? voiceSafetyConcern = _unset,
    int? currentStep,
    bool? hasCloseUpEvidence,
    bool? hasContextEvidence,
    List<String>? evidenceImagePaths,
    List<String>? evidenceVideoPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportDraft(
      id: identical(id, _unset)
          ? this.id
          : id as String?,

      category:
      category ?? this.category,

      priority:
      priority ?? this.priority,

      title:
      title ?? this.title,

      description:
      description ?? this.description,

      landmark:
      identical(landmark, _unset)
          ? this.landmark
          : landmark as String?,

      manualAddress:
      identical(
        manualAddress,
        _unset,
      )
          ? this.manualAddress
          : manualAddress as String?,

      latitude:
      identical(latitude, _unset)
          ? this.latitude
          : latitude as double?,

      longitude:
      identical(longitude, _unset)
          ? this.longitude
          : longitude as double?,

      locationAccuracy:
      identical(
        locationAccuracy,
        _unset,
      )
          ? this.locationAccuracy
          : locationAccuracy as double?,

      detectedAddress:
      identical(
        detectedAddress,
        _unset,
      )
          ? this.detectedAddress
          : detectedAddress as String?,

      locationVerificationStatus:
      identical(
        locationVerificationStatus,
        _unset,
      )
          ? this
          .locationVerificationStatus
          : locationVerificationStatus
      as String?,

      addressDistanceMeters:
      identical(
        addressDistanceMeters,
        _unset,
      )
          ? this.addressDistanceMeters
          : addressDistanceMeters
      as double?,

      voiceTranscript:
      identical(
        voiceTranscript,
        _unset,
      )
          ? this.voiceTranscript
          : voiceTranscript as String?,

      voiceLocationContext:
      identical(
        voiceLocationContext,
        _unset,
      )
          ? this.voiceLocationContext
          : voiceLocationContext
      as String?,

      voiceSafetyConcern:
      identical(
        voiceSafetyConcern,
        _unset,
      )
          ? this.voiceSafetyConcern
          : voiceSafetyConcern
      as String?,

      currentStep:
      currentStep ??
          this.currentStep,

      hasCloseUpEvidence:
      hasCloseUpEvidence ??
          this.hasCloseUpEvidence,

      hasContextEvidence:
      hasContextEvidence ??
          this.hasContextEvidence,

      evidenceImagePaths:
      evidenceImagePaths ??
          this.evidenceImagePaths,

      evidenceVideoPaths:
      evidenceVideoPaths ??
          this.evidenceVideoPaths,

      createdAt:
      createdAt ?? this.createdAt,

      updatedAt:
      updatedAt ?? DateTime.now(),
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,

      'category': category,
      'priority': priority,
      'title': title,
      'description': description,

      'landmark': landmark,
      'manualAddress':
      manualAddress,

      'latitude': latitude,
      'longitude': longitude,
      'locationAccuracy':
      locationAccuracy,

      'detectedAddress':
      detectedAddress,

      'locationVerificationStatus':
      locationVerificationStatus,

      'addressDistanceMeters':
      addressDistanceMeters,

      'voiceTranscript':
      voiceTranscript,

      'voiceLocationContext':
      voiceLocationContext,

      'voiceSafetyConcern':
      voiceSafetyConcern,

      'currentStep':
      currentStep,

      'hasCloseUpEvidence':
      hasCloseUpEvidence,

      'hasContextEvidence':
      hasContextEvidence,

      'evidenceImagePaths':
      evidenceImagePaths,

      'evidenceVideoPaths':
      evidenceVideoPaths,

      'createdAt':
      createdAt.toIso8601String(),

      'updatedAt':
      updatedAt.toIso8601String(),
    };
  }

  // ============================================================
  // FROM JSON
  //
  // Old drafts that do not yet contain evidenceVideoPaths
  // are still supported automatically.
  // ============================================================

  factory ReportDraft.fromJson(
      Map<String, dynamic> json,
      ) {
    return ReportDraft(
      id:
      json['id']?.toString(),

      category:
      json['category']
          ?.toString() ??
          '',

      priority:
      json['priority']
          ?.toString() ??
          '',

      title:
      json['title']
          ?.toString() ??
          '',

      description:
      json['description']
          ?.toString() ??
          '',

      landmark:
      json['landmark']
          ?.toString(),

      manualAddress:
      json['manualAddress']
          ?.toString(),

      latitude:
      _toDouble(
        json['latitude'],
      ),

      longitude:
      _toDouble(
        json['longitude'],
      ),

      locationAccuracy:
      _toDouble(
        json['locationAccuracy'],
      ),

      detectedAddress:
      json['detectedAddress']
          ?.toString(),

      locationVerificationStatus:
      json[
      'locationVerificationStatus']
          ?.toString(),

      addressDistanceMeters:
      _toDouble(
        json['addressDistanceMeters'],
      ),

      voiceTranscript:
      json['voiceTranscript']
          ?.toString(),

      voiceLocationContext:
      json[
      'voiceLocationContext']
          ?.toString(),

      voiceSafetyConcern:
      json[
      'voiceSafetyConcern']
          ?.toString(),

      currentStep:
      _toInt(
        json['currentStep'],
      ),

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

      // Old saved drafts will simply receive [] here.
      evidenceVideoPaths:
      _toStringList(
        json['evidenceVideoPaths'],
      ),

      createdAt:
      _toDateTime(
        json['createdAt'],
      ),

      updatedAt:
      _toDateTime(
        json['updatedAt'],
      ),
    );
  }

  // ============================================================
  // PARSING HELPERS
  // ============================================================

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

    if (value is num) {
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

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
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
      return <String>[];
    }

    return value
        .where(
          (item) =>
      item != null &&
          item
              .toString()
              .trim()
              .isNotEmpty,
    )
        .map(
          (item) =>
          item.toString(),
    )
        .toList();
  }
}