class ReportVideoAiAnalysis {
  final String aiStatus;

  final bool issueDetected;

  final String? category;
  final String? subcategory;

  final String? severity;
  final String? confidence;

  final String? description;

  final String? evidenceQuality;

  /// Does the issue remain visible / consistent across
  /// the sampled timeline?
  final String? temporalConsistency;

  /// Number of frames in which AI found useful evidence.
  final int usefulFrameCount;

  final int analyzedFrameCount;

  final bool? categoryMatchesUser;

  final bool? priorityChangeRecommended;

  final String? recommendedPriority;

  final String? suggestedTitle;

  final String? suggestedDescription;

  final String? reportQuality;

  final bool? reportSufficient;

  final String? safetyConcern;

  final List<String> missingInformation;

  /// Short citizen-facing explanation.
  final String? summary;

  /// Important because sampled frames are not equivalent
  /// to full continuous video analysis.
  final String? limitationNotice;

  final DateTime? analyzedAt;

  const ReportVideoAiAnalysis({
    required this.aiStatus,
    required this.issueDetected,
    required this.category,
    required this.subcategory,
    required this.severity,
    required this.confidence,
    required this.description,
    required this.evidenceQuality,
    required this.temporalConsistency,
    required this.usefulFrameCount,
    required this.analyzedFrameCount,
    required this.categoryMatchesUser,
    required this.priorityChangeRecommended,
    required this.recommendedPriority,
    required this.suggestedTitle,
    required this.suggestedDescription,
    required this.reportQuality,
    required this.reportSufficient,
    required this.safetyConcern,
    required this.missingInformation,
    required this.summary,
    required this.limitationNotice,
    required this.analyzedAt,
  });

  factory ReportVideoAiAnalysis.fromJson(
      Map<String, dynamic> json,
      ) {
    String? nullableString(
        dynamic value,
        ) {
      if (value == null) {
        return null;
      }

      final String text =
      value.toString().trim();

      return text.isEmpty
          ? null
          : text;
    }

    List<String> stringList(
        dynamic value,
        ) {
      if (value is! List) {
        return const [];
      }

      return value
          .map(
            (dynamic item) =>
            item.toString().trim(),
      )
          .where(
            (String item) =>
        item.isNotEmpty,
      )
          .take(
        8,
      )
          .toList(
        growable: false,
      );
    }

    return ReportVideoAiAnalysis(
      aiStatus:
      json['ai_status']
          ?.toString() ??
          'completed',

      issueDetected:
      json['issue_detected']
      as bool? ??
          false,

      category:
      nullableString(
        json['category'],
      ),

      subcategory:
      nullableString(
        json['subcategory'],
      ),

      severity:
      nullableString(
        json['severity'],
      ),

      confidence:
      nullableString(
        json['confidence'],
      ),

      description:
      nullableString(
        json['description'],
      ),

      evidenceQuality:
      nullableString(
        json['evidence_quality'],
      ),

      temporalConsistency:
      nullableString(
        json['temporal_consistency'],
      ),

      usefulFrameCount:
      _toInt(
        json['useful_frame_count'],
      ),

      analyzedFrameCount:
      _toInt(
        json['analyzed_frame_count'],
      ),

      categoryMatchesUser:
      json['category_matches_user']
      as bool?,

      priorityChangeRecommended:
      json[
      'priority_change_recommended']
      as bool?,

      recommendedPriority:
      nullableString(
        json['recommended_priority'],
      ),

      suggestedTitle:
      nullableString(
        json['suggested_title'],
      ),

      suggestedDescription:
      nullableString(
        json['suggested_description'],
      ),

      reportQuality:
      nullableString(
        json['report_quality'],
      ),

      reportSufficient:
      json['report_sufficient']
      as bool?,

      safetyConcern:
      nullableString(
        json['safety_concern'],
      ),

      missingInformation:
      stringList(
        json['missing_information'],
      ),

      summary:
      nullableString(
        json['summary'],
      ),

      limitationNotice:
      nullableString(
        json['limitation_notice'],
      ),

      analyzedAt:
      DateTime.tryParse(
        json['analyzed_at']
            ?.toString() ??
            '',
      ),
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

  bool get hasUsefulEvidence =>
      issueDetected &&
          usefulFrameCount > 0;

  bool get hasMissingInformation =>
      missingInformation.isNotEmpty;
}