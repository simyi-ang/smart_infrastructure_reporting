class ReportImageAiAnalysis {
  // ============================================================
  // DATABASE IDENTIFIERS
  // ============================================================

  final String id;
  final String reportImageId;

  // ============================================================
  // AI STATUS
  // ============================================================

  final String aiStatus;

  // ============================================================
  // CORE AI RESULT
  // ============================================================

  final bool? issueDetected;

  final String? category;
  final String? subcategory;

  final String? severity;
  final String? confidence;

  final String? description;
  final String? evidenceQuality;
  final String? safetyConcern;

  // ============================================================
  // ADVANCED SMART ASSIST RESULT
  // ============================================================

  final bool? categoryMatchesUser;

  final bool? priorityChangeRecommended;

  final String? recommendedPriority;

  final bool needsHumanReview;

  final bool retakeRecommended;

  final String? retakeReason;

  // ============================================================
  // HUMAN-IN-THE-LOOP AUDIT
  // ============================================================

  final bool suggestionsApplied;

  final bool reviewedByUser;

  final String? originalUserCategory;

  final String? originalUserPriority;

  final String? originalUserDescription;

  // ============================================================
  // TIMESTAMPS
  // ============================================================

  final DateTime? analyzedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  const ReportImageAiAnalysis({
    this.id = '',
    this.reportImageId = '',
    this.aiStatus = 'not_analyzed',
    this.issueDetected,
    this.category,
    this.subcategory,
    this.severity,
    this.confidence,
    this.description,
    this.evidenceQuality,
    this.safetyConcern,
    this.categoryMatchesUser,
    this.priorityChangeRecommended,
    this.recommendedPriority,
    this.needsHumanReview = false,
    this.retakeRecommended = false,
    this.retakeReason,
    this.suggestionsApplied = false,
    this.reviewedByUser = false,
    this.originalUserCategory,
    this.originalUserPriority,
    this.originalUserDescription,
    this.analyzedAt,
    this.createdAt,
    this.updatedAt,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory ReportImageAiAnalysis.fromJson(
      Map<String, dynamic> json,
      ) {
    return ReportImageAiAnalysis(
      id:
      json['id']?.toString() ??
          '',

      reportImageId:
      json['report_image_id']
          ?.toString() ??
          '',

      aiStatus:
      json['ai_status']
          ?.toString() ??
          (
              _hasAiResultFields(
                json,
              )
                  ? 'completed'
                  : 'not_analyzed'
          ),

      issueDetected:
      json['issue_detected']
      as bool?,

      category:
      _nullableString(
        json['category'],
      ),

      subcategory:
      _nullableString(
        json['subcategory'],
      ),

      severity:
      _nullableString(
        json['severity'],
      ),

      confidence:
      _nullableString(
        json['confidence'],
      ),

      description:
      _nullableString(
        json['description'],
      ),

      evidenceQuality:
      _nullableString(
        json['evidence_quality'],
      ),

      safetyConcern:
      _nullableString(
        json['safety_concern'],
      ),

      categoryMatchesUser:
      json['category_matches_user']
      as bool?,

      priorityChangeRecommended:
      json['priority_change_recommended']
      as bool?,

      recommendedPriority:
      _nullableString(
        json['recommended_priority'],
      ),

      needsHumanReview:
      json['needs_human_review']
      as bool? ??
          false,

      retakeRecommended:
      json['retake_recommended']
      as bool? ??
          false,

      retakeReason:
      _nullableString(
        json['retake_reason'],
      ),

      suggestionsApplied:
      json['suggestions_applied']
      as bool? ??
          false,

      reviewedByUser:
      json['reviewed_by_user']
      as bool? ??
          false,

      originalUserCategory:
      _nullableString(
        json['original_user_category'],
      ),

      originalUserPriority:
      _nullableString(
        json['original_user_priority'],
      ),

      originalUserDescription:
      _nullableString(
        json['original_user_description'],
      ),

      analyzedAt:
      _parseDate(
        json['analyzed_at'],
      ),

      createdAt:
      _parseDate(
        json['created_at'],
      ),

      updatedAt:
      _parseDate(
        json['updated_at'],
      ),
    );
  }

  // ============================================================
  // TEMPORARY GEMINI RESULT
  // ============================================================

  factory ReportImageAiAnalysis.fromAiResult(
      Map<String, dynamic> json,
      ) {
    return ReportImageAiAnalysis.fromJson(
      {
        ...json,
        'ai_status':
        'completed',
      },
    );
  }

  // ============================================================
  // FULL JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id':
      id,

      'report_image_id':
      reportImageId,

      'ai_status':
      aiStatus,

      'issue_detected':
      issueDetected,

      'category':
      category,

      'subcategory':
      subcategory,

      'severity':
      severity,

      'confidence':
      confidence,

      'description':
      description,

      'evidence_quality':
      evidenceQuality,

      'safety_concern':
      safetyConcern,

      'category_matches_user':
      categoryMatchesUser,

      'priority_change_recommended':
      priorityChangeRecommended,

      'recommended_priority':
      recommendedPriority,

      'needs_human_review':
      needsHumanReview,

      'retake_recommended':
      retakeRecommended,

      'retake_reason':
      retakeReason,

      'suggestions_applied':
      suggestionsApplied,

      'reviewed_by_user':
      reviewedByUser,

      'original_user_category':
      originalUserCategory,

      'original_user_priority':
      originalUserPriority,

      'original_user_description':
      originalUserDescription,

      'analyzed_at':
      analyzedAt
          ?.toIso8601String(),

      'created_at':
      createdAt
          ?.toIso8601String(),

      'updated_at':
      updatedAt
          ?.toIso8601String(),
    };
  }

  // ============================================================
  // DATABASE JSON
  // ============================================================

  Map<String, dynamic> toDatabaseJson({
    required String reportImageId,
  }) {
    return {
      'report_image_id':
      reportImageId,

      'ai_status':
      aiStatus,

      'issue_detected':
      issueDetected,

      'category':
      category,

      'subcategory':
      subcategory,

      'severity':
      severity,

      'confidence':
      confidence,

      'description':
      description,

      'evidence_quality':
      evidenceQuality,

      'safety_concern':
      safetyConcern,

      'category_matches_user':
      categoryMatchesUser,

      'priority_change_recommended':
      priorityChangeRecommended,

      'recommended_priority':
      recommendedPriority,

      'needs_human_review':
      needsHumanReview,

      'retake_recommended':
      retakeRecommended,

      'retake_reason':
      retakeReason,

      'suggestions_applied':
      suggestionsApplied,

      'reviewed_by_user':
      reviewedByUser,

      'original_user_category':
      originalUserCategory,

      'original_user_priority':
      originalUserPriority,

      'original_user_description':
      originalUserDescription,

      'analyzed_at':
      analyzedAt
          ?.toIso8601String(),

      'updated_at':
      DateTime.now()
          .toUtc()
          .toIso8601String(),
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  ReportImageAiAnalysis copyWith({
    String? id,
    String? reportImageId,
    String? aiStatus,
    bool? issueDetected,
    String? category,
    String? subcategory,
    String? severity,
    String? confidence,
    String? description,
    String? evidenceQuality,
    String? safetyConcern,
    bool? categoryMatchesUser,
    bool? priorityChangeRecommended,
    String? recommendedPriority,
    bool? needsHumanReview,
    bool? retakeRecommended,
    String? retakeReason,
    bool? suggestionsApplied,
    bool? reviewedByUser,
    String? originalUserCategory,
    String? originalUserPriority,
    String? originalUserDescription,
    DateTime? analyzedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportImageAiAnalysis(
      id:
      id ?? this.id,

      reportImageId:
      reportImageId ??
          this.reportImageId,

      aiStatus:
      aiStatus ??
          this.aiStatus,

      issueDetected:
      issueDetected ??
          this.issueDetected,

      category:
      category ??
          this.category,

      subcategory:
      subcategory ??
          this.subcategory,

      severity:
      severity ??
          this.severity,

      confidence:
      confidence ??
          this.confidence,

      description:
      description ??
          this.description,

      evidenceQuality:
      evidenceQuality ??
          this.evidenceQuality,

      safetyConcern:
      safetyConcern ??
          this.safetyConcern,

      categoryMatchesUser:
      categoryMatchesUser ??
          this.categoryMatchesUser,

      priorityChangeRecommended:
      priorityChangeRecommended ??
          this.priorityChangeRecommended,

      recommendedPriority:
      recommendedPriority ??
          this.recommendedPriority,

      needsHumanReview:
      needsHumanReview ??
          this.needsHumanReview,

      retakeRecommended:
      retakeRecommended ??
          this.retakeRecommended,

      retakeReason:
      retakeReason ??
          this.retakeReason,

      suggestionsApplied:
      suggestionsApplied ??
          this.suggestionsApplied,

      reviewedByUser:
      reviewedByUser ??
          this.reviewedByUser,

      originalUserCategory:
      originalUserCategory ??
          this.originalUserCategory,

      originalUserPriority:
      originalUserPriority ??
          this.originalUserPriority,

      originalUserDescription:
      originalUserDescription ??
          this.originalUserDescription,

      analyzedAt:
      analyzedAt ??
          this.analyzedAt,

      createdAt:
      createdAt ??
          this.createdAt,

      updatedAt:
      updatedAt ??
          this.updatedAt,
    );
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  bool get isNotAnalyzed =>
      aiStatus ==
          'not_analyzed';

  bool get isAnalyzing =>
      aiStatus ==
          'analyzing';

  bool get isCompleted =>
      aiStatus ==
          'completed';

  bool get isFailed =>
      aiStatus ==
          'failed';

  bool get isTemporary =>
      reportImageId.isEmpty;

  bool get hasAnalysis =>
      isCompleted &&
          (
              category != null ||
                  description != null ||
                  severity != null ||
                  subcategory != null
          );

  // ============================================================
  // FRIENDLY ISSUE LABEL
  // ============================================================

  String get issueLabel {
    if (issueDetected != true) {
      return 'No clear issue detected';
    }

    if (subcategory != null &&
        subcategory!
            .trim()
            .isNotEmpty) {
      return subcategory!;
    }

    return category ??
        'Infrastructure Issue';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static String? _nullableString(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    final String text =
    value
        .toString()
        .trim();

    return text.isEmpty
        ? null
        : text;
  }

  static DateTime? _parseDate(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  static bool _hasAiResultFields(
      Map<String, dynamic> json,
      ) {
    return json.containsKey(
      'issue_detected',
    ) ||
        json.containsKey(
          'category',
        ) ||
        json.containsKey(
          'subcategory',
        ) ||
        json.containsKey(
          'severity',
        ) ||
        json.containsKey(
          'description',
        );
  }
}