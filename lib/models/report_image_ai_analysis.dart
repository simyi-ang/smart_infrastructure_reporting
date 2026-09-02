class ReportImageAiAnalysis {
  final String id;
  final String reportImageId;

  final String aiStatus;

  final bool? issueDetected;

  final String? category;
  final String? subcategory;
  final String? severity;
  final String? confidence;

  final String? description;
  final String? evidenceQuality;
  final String? safetyConcern;

  final DateTime? analyzedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportImageAiAnalysis({
    required this.id,
    required this.reportImageId,
    required this.aiStatus,
    required this.issueDetected,
    required this.category,
    required this.subcategory,
    required this.severity,
    required this.confidence,
    required this.description,
    required this.evidenceQuality,
    required this.safetyConcern,
    required this.analyzedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ============================================================
  // CREATE MODEL FROM SUPABASE JSON
  // ============================================================

  factory ReportImageAiAnalysis.fromJson(
      Map<String, dynamic> json,
      ) {
    return ReportImageAiAnalysis(
      id:
      json['id']?.toString() ?? '',

      reportImageId:
      json['report_image_id']?.toString() ?? '',

      aiStatus:
      json['ai_status']?.toString() ??
          'not_analyzed',

      issueDetected:
      json['issue_detected'] as bool?,

      category:
      json['category']?.toString(),

      subcategory:
      json['subcategory']?.toString(),

      severity:
      json['severity']?.toString(),

      confidence:
      json['confidence']?.toString(),

      description:
      json['description']?.toString(),

      evidenceQuality:
      json['evidence_quality']?.toString(),

      safetyConcern:
      json['safety_concern']?.toString(),

      analyzedAt:
      json['analyzed_at'] == null
          ? null
          : DateTime.tryParse(
        json['analyzed_at'].toString(),
      ),

      createdAt:
      DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      ) ??
          DateTime.now(),

      updatedAt:
      DateTime.tryParse(
        json['updated_at']?.toString() ?? '',
      ) ??
          DateTime.now(),
    );
  }

  // ============================================================
  // CONVERT MODEL TO JSON
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

      'analyzed_at':
      analyzedAt?.toIso8601String(),

      'created_at':
      createdAt.toIso8601String(),

      'updated_at':
      updatedAt.toIso8601String(),
    };
  }

  // ============================================================
  // CREATE COPY WITH CHANGES
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
    DateTime? analyzedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportImageAiAnalysis(
      id:
      id ?? this.id,

      reportImageId:
      reportImageId ?? this.reportImageId,

      aiStatus:
      aiStatus ?? this.aiStatus,

      issueDetected:
      issueDetected ?? this.issueDetected,

      category:
      category ?? this.category,

      subcategory:
      subcategory ?? this.subcategory,

      severity:
      severity ?? this.severity,

      confidence:
      confidence ?? this.confidence,

      description:
      description ?? this.description,

      evidenceQuality:
      evidenceQuality ?? this.evidenceQuality,

      safetyConcern:
      safetyConcern ?? this.safetyConcern,

      analyzedAt:
      analyzedAt ?? this.analyzedAt,

      createdAt:
      createdAt ?? this.createdAt,

      updatedAt:
      updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // CONVENIENCE STATUS HELPERS
  // ============================================================

  bool get isNotAnalyzed =>
      aiStatus == 'not_analyzed';

  bool get isAnalyzing =>
      aiStatus == 'analyzing';

  bool get isCompleted =>
      aiStatus == 'completed';

  bool get isFailed =>
      aiStatus == 'failed';

  // ============================================================
  // AI RESULT AVAILABLE?
  // ============================================================

  bool get hasAnalysis =>
      isCompleted &&
          (
              category != null ||
                  description != null ||
                  severity != null
          );
}