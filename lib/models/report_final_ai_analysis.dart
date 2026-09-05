class ReportFinalAiAnalysis {

  final String id;

  final String reportId;

  final String aiStatus;

  final int analyzedImageCount;

  final List<String> sourceEvidenceIds;

  final bool? issueDetected;

  final String? category;

  final String? subcategory;

  final String? severity;

  final String? confidence;

  final String? evidenceQuality;

  final String? description;

  final String? safetyConcern;

  final String? evidenceConsistency;

  final bool conflictingEvidence;

  final String? conflictingEvidenceReason;

  final bool? categoryMatchesUser;

  final bool? priorityChangeRecommended;

  final String? recommendedPriority;

  final bool needsHumanReview;

  final String? humanReviewReason;

  final bool reportSufficient;

  final String? reportQuality;

  final bool? titleMeaningful;

  final bool? descriptionMeaningful;

  final String? reportIssue;

  final List<String> missingInformation;

  final String? suggestedTitle;

  final String? suggestedDescription;

  final bool suggestionsApplied;

  final bool reviewedByUser;

  final String? originalUserCategory;

  final String? originalUserPriority;

  final String? originalUserTitle;

  final String? originalUserDescription;

  final DateTime? analyzedAt;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  const ReportFinalAiAnalysis({
    this.id = '',
    this.reportId = '',
    this.aiStatus = 'not_analyzed',

    this.analyzedImageCount = 0,

    this.sourceEvidenceIds = const [],

    this.issueDetected,

    this.category,

    this.subcategory,

    this.severity,

    this.confidence,

    this.evidenceQuality,

    this.description,

    this.safetyConcern,

    this.evidenceConsistency,

    this.conflictingEvidence = false,

    this.conflictingEvidenceReason,

    this.categoryMatchesUser,

    this.priorityChangeRecommended,

    this.recommendedPriority,

    this.needsHumanReview = false,

    this.humanReviewReason,

    this.reportSufficient = true,

    this.reportQuality,

    this.titleMeaningful,

    this.descriptionMeaningful,

    this.reportIssue,

    this.missingInformation = const [],

    this.suggestedTitle,

    this.suggestedDescription,

    this.suggestionsApplied = false,

    this.reviewedByUser = false,

    this.originalUserCategory,

    this.originalUserPriority,

    this.originalUserTitle,

    this.originalUserDescription,

    this.analyzedAt,

    this.createdAt,

    this.updatedAt,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory ReportFinalAiAnalysis.fromJson(
      Map<String, dynamic> json,
      ) {
    return ReportFinalAiAnalysis(
      // ========================================================
      // IDENTIFIERS
      // ========================================================

      id:
      json['id']
          ?.toString() ??
          '',

      reportId:
      json['report_id']
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
      // SOURCE IMAGES
      // ========================================================

      analyzedImageCount:
      _parseInt(
        json['analyzed_image_count'],
      ) ??
          0,

      sourceEvidenceIds:
      _stringList(
        json['source_evidence_ids'],
      ),

      // ========================================================
      // FINAL COMBINED RESULT
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

      evidenceQuality:
      _nullableString(
        json['evidence_quality'],
      ),

      description:
      _nullableString(
        json['description'],
      ),

      safetyConcern:
      _nullableString(
        json['safety_concern'],
      ),

      // ========================================================
      // MULTI-IMAGE CONSISTENCY
      // ========================================================

      evidenceConsistency:
      _nullableString(
        json['evidence_consistency'],
      ),

      conflictingEvidence:
      _nullableBool(
        json['conflicting_evidence'],
      ) ??
          false,

      conflictingEvidenceReason:
      _nullableString(
        json['conflicting_evidence_reason'],
      ),

      // ========================================================
      // REPORT COMPARISON
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

      // ========================================================
      // HUMAN REVIEW
      // ========================================================

      needsHumanReview:
      _nullableBool(
        json['needs_human_review'],
      ) ??
          false,

      humanReviewReason:
      _nullableString(
        json['human_review_reason'],
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
      // USER DECISION
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

      // ========================================================
      // ORIGINAL USER INFORMATION
      // ========================================================

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
  // FROM TEMPORARY COMBINED AI RESULT
  //
  // Used before reports.id exists.
  // ============================================================

  factory ReportFinalAiAnalysis.fromAiResult(
      Map<String, dynamic> json, {
        int analyzedImageCount = 0,
        List<String> sourceEvidenceIds =
        const [],
      }) {
    return ReportFinalAiAnalysis.fromJson(
      {
        ...json,

        'ai_status':
        'completed',

        'analyzed_image_count':
        analyzedImageCount,

        'source_evidence_ids':
        sourceEvidenceIds,
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

      'report_id':
      reportId,

      'ai_status':
      aiStatus,

      // ========================================================
      // SOURCE IMAGES
      // ========================================================

      'analyzed_image_count':
      analyzedImageCount,

      'source_evidence_ids':
      sourceEvidenceIds,

      // ========================================================
      // FINAL AI
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

      'evidence_quality':
      evidenceQuality,

      'description':
      description,

      'safety_concern':
      safetyConcern,

      // ========================================================
      // CONSISTENCY
      // ========================================================

      'evidence_consistency':
      evidenceConsistency,

      'conflicting_evidence':
      conflictingEvidence,

      'conflicting_evidence_reason':
      conflictingEvidenceReason,

      // ========================================================
      // COMPARISON
      // ========================================================

      'category_matches_user':
      categoryMatchesUser,

      'priority_change_recommended':
      priorityChangeRecommended,

      'recommended_priority':
      recommendedPriority,

      // ========================================================
      // HUMAN REVIEW
      // ========================================================

      'needs_human_review':
      needsHumanReview,

      'human_review_reason':
      humanReviewReason,

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
      // USER DECISION
      // ========================================================

      'suggestions_applied':
      suggestionsApplied,

      'reviewed_by_user':
      reviewedByUser,

      // ========================================================
      // ORIGINAL VALUES
      // ========================================================

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
  // Used later when reports.id exists.
  // ============================================================

  Map<String, dynamic> toDatabaseJson({
    required String reportId,
  }) {
    return {
      'report_id':
      reportId,

      'ai_status':
      aiStatus,

      'analyzed_image_count':
      analyzedImageCount,

      'source_evidence_ids':
      sourceEvidenceIds,

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

      'evidence_quality':
      evidenceQuality,

      'description':
      description,

      'safety_concern':
      safetyConcern,

      'evidence_consistency':
      evidenceConsistency,

      'conflicting_evidence':
      conflictingEvidence,

      'conflicting_evidence_reason':
      conflictingEvidenceReason,

      'category_matches_user':
      categoryMatchesUser,

      'priority_change_recommended':
      priorityChangeRecommended,

      'recommended_priority':
      recommendedPriority,

      'needs_human_review':
      needsHumanReview,

      'human_review_reason':
      humanReviewReason,

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

  ReportFinalAiAnalysis copyWith({
    String? id,

    String? reportId,

    String? aiStatus,

    int? analyzedImageCount,

    List<String>? sourceEvidenceIds,

    bool? issueDetected,

    String? category,

    String? subcategory,

    String? severity,

    String? confidence,

    String? evidenceQuality,

    String? description,

    String? safetyConcern,

    String? evidenceConsistency,

    bool? conflictingEvidence,

    String? conflictingEvidenceReason,

    bool? categoryMatchesUser,

    bool? priorityChangeRecommended,

    String? recommendedPriority,

    bool? needsHumanReview,

    String? humanReviewReason,

    bool? reportSufficient,

    String? reportQuality,

    bool? titleMeaningful,

    bool? descriptionMeaningful,

    String? reportIssue,

    List<String>? missingInformation,

    String? suggestedTitle,

    String? suggestedDescription,

    bool? suggestionsApplied,

    bool? reviewedByUser,

    String? originalUserCategory,

    String? originalUserPriority,

    String? originalUserTitle,

    String? originalUserDescription,

    DateTime? analyzedAt,

    DateTime? createdAt,

    DateTime? updatedAt,
  }) {
    return ReportFinalAiAnalysis(
      id:
      id ??
          this.id,

      reportId:
      reportId ??
          this.reportId,

      aiStatus:
      aiStatus ??
          this.aiStatus,

      analyzedImageCount:
      analyzedImageCount ??
          this.analyzedImageCount,

      sourceEvidenceIds:
      sourceEvidenceIds ??
          this.sourceEvidenceIds,

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

      evidenceQuality:
      evidenceQuality ??
          this.evidenceQuality,

      description:
      description ??
          this.description,

      safetyConcern:
      safetyConcern ??
          this.safetyConcern,

      evidenceConsistency:
      evidenceConsistency ??
          this.evidenceConsistency,

      conflictingEvidence:
      conflictingEvidence ??
          this.conflictingEvidence,

      conflictingEvidenceReason:
      conflictingEvidenceReason ??
          this.conflictingEvidenceReason,

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

      humanReviewReason:
      humanReviewReason ??
          this.humanReviewReason,

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
      reportId.isEmpty;

  // ============================================================
  // RESULT AVAILABLE?
  // ============================================================

  bool get hasAnalysis =>
      isCompleted &&
          (
              issueDetected != null ||
                  category != null ||
                  description != null ||
                  severity != null ||
                  reportQuality != null
          );

  // ============================================================
  // ISSUE LABEL
  // ============================================================

  String get issueLabel {
    if (issueDetected !=
        true) {
      return 'No clear issue detected';
    }

    if (
    subcategory != null &&
        subcategory!
            .trim()
            .isNotEmpty
    ) {
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
  // AI REPORT SUGGESTIONS AVAILABLE?
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
    if (
    reportQuality != null &&
        reportQuality!
            .trim()
            .isNotEmpty
    ) {
      return reportQuality!;
    }

    return reportSufficient
        ? 'Good'
        : 'Poor';
  }

  // ============================================================
  // CONSISTENCY LABEL
  // ============================================================

  String get evidenceConsistencyLabel {
    if (
    evidenceConsistency !=
        null &&
        evidenceConsistency!
            .trim()
            .isNotEmpty
    ) {
      return evidenceConsistency!;
    }

    if (analyzedImageCount <=
        1) {
      return 'Single Evidence';
    }

    return conflictingEvidence
        ? 'Mixed'
        : 'Consistent';
  }

  // ============================================================
  // FINAL NEEDS ATTENTION?
  // ============================================================

  bool get needsAttention =>
      needsHumanReview ||
          conflictingEvidence ||
          hasPoorReportQuality;

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
  // INTEGER HELPER
  // ============================================================

  static int? _parseInt(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
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
        growable: false,
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
  // DOES JSON CONTAIN FINAL AI RESULT?
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
          'recommended_priority',
        ) ||
        json.containsKey(
          'report_sufficient',
        ) ||
        json.containsKey(
          'evidence_consistency',
        );
  }
}