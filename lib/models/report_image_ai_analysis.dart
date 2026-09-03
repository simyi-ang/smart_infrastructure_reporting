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
  // CORE IMAGE AI RESULT
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
  // REPORT QUALITY CHECK
  //
  // Used to determine whether the citizen's typed report is
  // understandable and sufficiently useful.
  //
  // Example poor input:
  //
  // Title:
  // xxxxx
  //
  // Description:
  // fuikjeolioc fk
  //
  // AI can warn that the report needs improvement without
  // automatically deleting or replacing the citizen's input.
  // ============================================================

  final bool reportSufficient;

  // Poor / Fair / Good
  final String? reportQuality;

  final bool? titleMeaningful;

  final bool? descriptionMeaningful;

  // Explanation of why report quality may be insufficient.
  final String? reportIssue;

  // Examples:
  //
  // [
  //   "clear infrastructure problem",
  //   "description of visible damage"
  // ]
  final List<String> missingInformation;

  // AI-generated optional improvements.
  final String? suggestedTitle;

  final String? suggestedDescription;

  // ============================================================
  // HUMAN-IN-THE-LOOP AUDIT
  // ============================================================

  final bool suggestionsApplied;

  final bool reviewedByUser;

  final String? originalUserCategory;

  final String? originalUserPriority;

  final String? originalUserTitle;

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

    // ==========================================================
    // REPORT QUALITY
    //
    // Default true keeps backward compatibility with older AI
    // results that do not yet return these fields.
    // ==========================================================

    this.reportSufficient = true,

    this.reportQuality,

    this.titleMeaningful,

    this.descriptionMeaningful,

    this.reportIssue,

    this.missingInformation = const [],

    this.suggestedTitle,

    this.suggestedDescription,

    // ==========================================================
    // HUMAN REVIEW
    // ==========================================================

    this.suggestionsApplied = false,

    this.reviewedByUser = false,

    this.originalUserCategory,

    this.originalUserPriority,

    this.originalUserTitle,

    this.originalUserDescription,

    // ==========================================================
    // TIME
    // ==========================================================

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
      // ========================================================
      // IDENTIFIERS
      // ========================================================

      id:
      json['id']?.toString() ??
          '',

      reportImageId:
      json['report_image_id']
          ?.toString() ??
          '',

      // ========================================================
      // STATUS
      // ========================================================

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

      // ========================================================
      // CORE AI
      // ========================================================

      issueDetected:
      _nullableBool(
        json['issue_detected'],
      ),

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

      // ========================================================
      // ADVANCED SMART ASSIST
      // ========================================================

      categoryMatchesUser:
      _nullableBool(
        json['category_matches_user'],
      ),

      priorityChangeRecommended:
      _nullableBool(
        json['priority_change_recommended'],
      ),

      recommendedPriority:
      _nullableString(
        json['recommended_priority'],
      ),

      needsHumanReview:
      _nullableBool(
        json['needs_human_review'],
      ) ??
          false,

      retakeRecommended:
      _nullableBool(
        json['retake_recommended'],
      ) ??
          false,

      retakeReason:
      _nullableString(
        json['retake_reason'],
      ),

      // ========================================================
      // REPORT QUALITY
      // ========================================================

      reportSufficient:
      _nullableBool(
        json['report_sufficient'],
      ) ??
          true,

      reportQuality:
      _nullableString(
        json['report_quality'],
      ),

      titleMeaningful:
      _nullableBool(
        json['title_meaningful'],
      ),

      descriptionMeaningful:
      _nullableBool(
        json['description_meaningful'],
      ),

      reportIssue:
      _nullableString(
        json['report_issue'],
      ),

      missingInformation:
      _stringList(
        json['missing_information'],
      ),

      suggestedTitle:
      _nullableString(
        json['suggested_title'],
      ),

      suggestedDescription:
      _nullableString(
        json['suggested_description'],
      ),

      // ========================================================
      // HUMAN REVIEW
      // ========================================================

      suggestionsApplied:
      _nullableBool(
        json['suggestions_applied'],
      ) ??
          false,

      reviewedByUser:
      _nullableBool(
        json['reviewed_by_user'],
      ) ??
          false,

      originalUserCategory:
      _nullableString(
        json['original_user_category'],
      ),

      originalUserPriority:
      _nullableString(
        json['original_user_priority'],
      ),

      originalUserTitle:
      _nullableString(
        json['original_user_title'],
      ),

      originalUserDescription:
      _nullableString(
        json['original_user_description'],
      ),

      // ========================================================
      // TIME
      // ========================================================

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
  //
  // Used before report_images exists.
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
      // ========================================================
      // IDENTIFIERS
      // ========================================================

      'id':
      id,

      'report_image_id':
      reportImageId,

      'ai_status':
      aiStatus,

      // ========================================================
      // CORE AI
      // ========================================================

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

      // ========================================================
      // ADVANCED
      // ========================================================

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

      // ========================================================
      // REPORT QUALITY
      // ========================================================

      'report_sufficient':
      reportSufficient,

      'report_quality':
      reportQuality,

      'title_meaningful':
      titleMeaningful,

      'description_meaningful':
      descriptionMeaningful,

      'report_issue':
      reportIssue,

      'missing_information':
      missingInformation,

      'suggested_title':
      suggestedTitle,

      'suggested_description':
      suggestedDescription,

      // ========================================================
      // HUMAN REVIEW
      // ========================================================

      'suggestions_applied':
      suggestionsApplied,

      'reviewed_by_user':
      reviewedByUser,

      'original_user_category':
      originalUserCategory,

      'original_user_priority':
      originalUserPriority,

      'original_user_title':
      originalUserTitle,

      'original_user_description':
      originalUserDescription,

      // ========================================================
      // TIME
      // ========================================================

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
  //
  // Used when temporary pre-submission analysis becomes
  // permanent after report_images.id is created.
  // ============================================================

  Map<String, dynamic> toDatabaseJson({
    required String reportImageId,
  }) {
    return {
      'report_image_id':
      reportImageId,

      'ai_status':
      aiStatus,

      // ========================================================
      // CORE AI
      // ========================================================

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

      // ========================================================
      // ADVANCED
      // ========================================================

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

      // ========================================================
      // REPORT QUALITY
      // ========================================================

      'report_sufficient':
      reportSufficient,

      'report_quality':
      reportQuality,

      'title_meaningful':
      titleMeaningful,

      'description_meaningful':
      descriptionMeaningful,

      'report_issue':
      reportIssue,

      'missing_information':
      missingInformation,

      'suggested_title':
      suggestedTitle,

      'suggested_description':
      suggestedDescription,

      // ========================================================
      // HUMAN REVIEW
      // ========================================================

      'suggestions_applied':
      suggestionsApplied,

      'reviewed_by_user':
      reviewedByUser,

      'original_user_category':
      originalUserCategory,

      'original_user_priority':
      originalUserPriority,

      'original_user_title':
      originalUserTitle,

      'original_user_description':
      originalUserDescription,

      // ========================================================
      // TIME
      // ========================================================

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

    // ==========================================================
    // REPORT QUALITY
    // ==========================================================

    bool? reportSufficient,

    String? reportQuality,

    bool? titleMeaningful,

    bool? descriptionMeaningful,

    String? reportIssue,

    List<String>? missingInformation,

    String? suggestedTitle,

    String? suggestedDescription,

    // ==========================================================
    // HUMAN REVIEW
    // ==========================================================

    bool? suggestionsApplied,

    bool? reviewedByUser,

    String? originalUserCategory,

    String? originalUserPriority,

    String? originalUserTitle,

    String? originalUserDescription,

    // ==========================================================
    // TIME
    // ==========================================================

    DateTime? analyzedAt,

    DateTime? createdAt,

    DateTime? updatedAt,
  }) {
    return ReportImageAiAnalysis(
      id:
      id ??
          this.id,

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

      // ========================================================
      // REPORT QUALITY
      // ========================================================

      reportSufficient:
      reportSufficient ??
          this.reportSufficient,

      reportQuality:
      reportQuality ??
          this.reportQuality,

      titleMeaningful:
      titleMeaningful ??
          this.titleMeaningful,

      descriptionMeaningful:
      descriptionMeaningful ??
          this.descriptionMeaningful,

      reportIssue:
      reportIssue ??
          this.reportIssue,

      missingInformation:
      missingInformation ??
          this.missingInformation,

      suggestedTitle:
      suggestedTitle ??
          this.suggestedTitle,

      suggestedDescription:
      suggestedDescription ??
          this.suggestedDescription,

      // ========================================================
      // HUMAN REVIEW
      // ========================================================

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

      originalUserTitle:
      originalUserTitle ??
          this.originalUserTitle,

      originalUserDescription:
      originalUserDescription ??
          this.originalUserDescription,

      // ========================================================
      // TIME
      // ========================================================

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

  // ============================================================
  // AI RESULT AVAILABLE?
  // ============================================================

  bool get hasAnalysis =>
      isCompleted &&
          (
              category != null ||
                  description != null ||
                  severity != null ||
                  subcategory != null ||
                  reportQuality != null
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
  // REPORT QUALITY HELPERS
  // ============================================================

  bool get hasPoorReportQuality =>
      reportSufficient ==
          false ||
          reportQuality ==
              'Poor';

  bool get hasFairReportQuality =>
      reportQuality ==
          'Fair';

  bool get hasGoodReportQuality =>
      reportQuality ==
          'Good';

  // ============================================================
  // SHOULD USER BE ASKED TO IMPROVE REPORT?
  // ============================================================

  bool get shouldSuggestReportEdit =>
      reportSufficient ==
          false ||
          titleMeaningful ==
              false ||
          descriptionMeaningful ==
              false ||
          reportQuality ==
              'Poor';

  // ============================================================
  // AI HAS SUGGESTED BETTER REPORT TEXT
  // ============================================================

  bool get hasSuggestedReportText {
    final bool titleAvailable =
        suggestedTitle != null &&
            suggestedTitle!
                .trim()
                .isNotEmpty;

    final bool descriptionAvailable =
        suggestedDescription != null &&
            suggestedDescription!
                .trim()
                .isNotEmpty;

    return titleAvailable ||
        descriptionAvailable;
  }

  // ============================================================
  // REPORT QUALITY LABEL
  // ============================================================

  String get reportQualityLabel {
    if (reportQuality != null &&
        reportQuality!
            .trim()
            .isNotEmpty) {
      return reportQuality!;
    }

    if (reportSufficient) {
      return 'Good';
    }

    return 'Poor';
  }

  // ============================================================
  // REPORT QUALITY SUMMARY
  // ============================================================

  String get reportQualitySummary {
    if (reportSufficient &&
        reportQuality !=
            'Poor') {
      return 'Report information is sufficiently clear.';
    }

    if (reportIssue != null &&
        reportIssue!
            .trim()
            .isNotEmpty) {
      return reportIssue!;
    }

    return 'The report may need clearer information before submission.';
  }

  // ============================================================
  // MISSING INFORMATION TEXT
  // ============================================================

  String get missingInformationText {
    if (missingInformation.isEmpty) {
      return '';
    }

    return missingInformation.join(
      ', ',
    );
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

  // ============================================================
  // BOOLEAN HELPER
  //
  // Handles actual booleans and string values returned from
  // backend/database safely.
  // ============================================================

  static bool? _nullableBool(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is bool) {
      return value;
    }

    final String text =
    value
        .toString()
        .trim()
        .toLowerCase();

    if (text ==
        'true') {
      return true;
    }

    if (text ==
        'false') {
      return false;
    }

    return null;
  }

  // ============================================================
  // STRING LIST HELPER
  // ============================================================

  static List<String> _stringList(
      dynamic value,
      ) {
    if (value == null) {
      return const [];
    }

    if (value is List) {
      return value
          .map(
            (item) =>
        item
            ?.toString()
            .trim() ??
            '',
      )
          .where(
            (item) =>
        item.isNotEmpty,
      )
          .toList(
        growable:
        false,
      );
    }

    return const [];
  }

  // ============================================================
  // DATE HELPER
  // ============================================================

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

  // ============================================================
  // DETECT WHETHER JSON ALREADY CONTAINS AI RESULT
  // ============================================================

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
        ) ||
        json.containsKey(
          'report_sufficient',
        ) ||
        json.containsKey(
          'report_quality',
        );
  }
}