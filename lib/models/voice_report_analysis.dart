// ================================================================
// VOICE REPORT ANALYSIS
// ================================================================
//
// Immutable, defensively parsed structured result returned by the
// server-side Voice Intelligence Edge Function.
//
// IMPORTANT:
//
// - AI output is NEVER trusted directly.
// - Category and priority are validated against controlled values.
// - Confidence is clamped.
// - Strings are normalized.
// - Empty required fields cause parsing failure.
// - Citizen must explicitly accept this result before report fields
//   are modified.
// ================================================================

class VoiceReportAnalysis {
  // ============================================================
  // CONTROLLED APPLICATION VALUES
  // ============================================================

  static const Set<String> allowedCategories =
  <String>{
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  };

  static const Set<String> allowedPriorities =
  <String>{
    'Low',
    'Medium',
    'High',
    'Critical',
  };

  // ============================================================
  // STRUCTURED RESULT
  // ============================================================

  final String category;
  final String priority;

  final String title;
  final String description;

  final String? locationContext;
  final String? safetyConcern;

  final List<String> missingInformation;

  /// Language inferred by the server-side AI.
  ///
  /// Examples:
  /// English
  /// Malay
  /// Chinese
  /// Mixed Malay-English
  /// Mixed Chinese-English
  final String detectedLanguage;

  /// BCP-47-like suggestion where possible.
  ///
  /// Examples:
  /// en
  /// ms
  /// zh
  /// en-MY
  ///
  /// AI detection is advisory only.
  final String? detectedLanguageCode;

  /// 0.0–1.0 confidence in the overall structured extraction.
  ///
  /// This is not a probability that the infrastructure incident
  /// is factually true.
  final double confidence;

  /// Short citizen-facing explanation of what AI extracted.
  ///
  /// Must NOT contain hidden chain-of-thought.
  final String summary;

  /// Whether the transcript contains enough information to form
  /// a usable report.
  final bool reportInformationSufficient;

  /// Indicates whether human review is especially important.
  ///
  /// All AI results are reviewed regardless, but this provides a
  /// stronger warning for uncertain results.
  final bool requiresCarefulReview;

  const VoiceReportAnalysis({
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    required this.locationContext,
    required this.safetyConcern,
    required this.missingInformation,
    required this.detectedLanguage,
    required this.detectedLanguageCode,
    required this.confidence,
    required this.summary,
    required this.reportInformationSufficient,
    required this.requiresCarefulReview,
  });

  // ============================================================
  // JSON PARSER
  // ============================================================

  factory VoiceReportAnalysis.fromJson(
      Map<String, dynamic> json,
      ) {
    final String category =
    _requiredText(
      json,
      'category',
      label:
      'category',
    );

    final String priority =
    _requiredText(
      json,
      'priority',
      label:
      'priority',
    );

    // ----------------------------------------------------------
    // CONTROLLED ENUM VALIDATION
    // ----------------------------------------------------------

    if (!allowedCategories.contains(
      category,
    )) {
      throw FormatException(
        'Unsupported AI category: $category',
      );
    }

    if (!allowedPriorities.contains(
      priority,
    )) {
      throw FormatException(
        'Unsupported AI priority: $priority',
      );
    }

    final String title =
    _requiredText(
      json,
      'title',
      label:
      'title',
    );

    final String description =
    _requiredText(
      json,
      'description',
      label:
      'description',
    );

    // ----------------------------------------------------------
    // DEFENSIVE SIZE LIMITS
    //
    // Server already restricts these.
    // Client repeats the check as defense-in-depth.
    // ----------------------------------------------------------

    if (title.length > 100) {
      throw const FormatException(
        'AI title exceeds the supported length.',
      );
    }

    if (description.length > 500) {
      throw const FormatException(
        'AI description exceeds the supported length.',
      );
    }

    final List<String> missingInformation =
    _parseStringList(
      json['missingInformation'],
      maximumItems:
      8,
      maximumItemLength:
      160,
    );

    final double confidence =
    _parseConfidence(
      json['confidence'],
    );

    return VoiceReportAnalysis(
      category:
      category,

      priority:
      priority,

      title:
      title,

      description:
      description,

      locationContext:
      _nullableText(
        json['locationContext'],
        maximumLength:
        300,
      ),

      safetyConcern:
      _nullableText(
        json['safetyConcern'],
        maximumLength:
        400,
      ),

      missingInformation:
      missingInformation,

      detectedLanguage:
      _nullableText(
        json['detectedLanguage'],
        maximumLength:
        80,
      ) ??
          'Unknown',

      detectedLanguageCode:
      _nullableText(
        json['detectedLanguageCode'],
        maximumLength:
        30,
      ),

      confidence:
      confidence,

      summary:
      _nullableText(
        json['summary'],
        maximumLength:
        500,
      ) ??
          '',

      reportInformationSufficient:
      _requiredBool(
        json,
        'reportInformationSufficient',
      ),

      requiresCarefulReview:
      _requiredBool(
        json,
        'requiresCarefulReview',
      ),
    );
  }

  // ============================================================
  // DERIVED UI STATE
  // ============================================================

  bool get hasLocationContext =>
      locationContext != null &&
          locationContext!.isNotEmpty;

  bool get hasSafetyConcern =>
      safetyConcern != null &&
          safetyConcern!.isNotEmpty;

  bool get hasMissingInformation =>
      missingInformation.isNotEmpty;

  bool get isLowConfidence =>
      confidence < 0.60;

  int get confidencePercentage =>
      (confidence * 100)
          .round();

  // ============================================================
  // PARSER HELPERS
  // ============================================================

  static String _requiredText(
      Map<String, dynamic> json,
      String key, {
        required String label,
      }) {
    final String? value =
    _nullableText(
      json[key],
    );

    if (value == null) {
      throw FormatException(
        'AI response is missing $label.',
      );
    }

    return value;
  }

  static String? _nullableText(
      dynamic value, {
        int? maximumLength,
      }) {
    if (value == null) {
      return null;
    }

    final String normalized =
    value
        .toString()
        .replaceAll(
      RegExp(
        r'\s+',
        unicode: true,
      ),
      ' ',
    )
        .trim();

    if (normalized.isEmpty) {
      return null;
    }

    if (maximumLength != null &&
        normalized.length >
            maximumLength) {
      return normalized.substring(
        0,
        maximumLength,
      );
    }

    return normalized;
  }

  static bool _requiredBool(
      Map<String, dynamic> json,
      String key,
      ) {
    final dynamic value =
    json[key];

    if (value is bool) {
      return value;
    }

    throw FormatException(
      'AI response contains an invalid $key value.',
    );
  }

  static double _parseConfidence(
      dynamic value,
      ) {
    double parsed;

    if (value is num) {
      parsed =
          value.toDouble();
    } else {
      parsed =
          double.tryParse(
            value?.toString() ??
                '',
          ) ??
              0;
    }

    return parsed
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();
  }

  static List<String> _parseStringList(
      dynamic value, {
        required int maximumItems,
        required int maximumItemLength,
      }) {
    if (value is! List) {
      return const <String>[];
    }

    final List<String> result =
    <String>[];

    for (final dynamic item
    in value) {
      if (result.length >=
          maximumItems) {
        break;
      }

      final String? normalized =
      _nullableText(
        item,
        maximumLength:
        maximumItemLength,
      );

      if (normalized == null) {
        continue;
      }

      if (!result.contains(
        normalized,
      )) {
        result.add(
          normalized,
        );
      }
    }

    return List<String>.unmodifiable(
      result,
    );
  }
}