import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/report_draft.dart';

class ReportDraftService {
  ReportDraftService._();

  static const String _draftKeyPrefix =
      'smartcity_active_report_draft';

  /// Creates a different storage key for each logged-in citizen.
  ///
  /// This is important because Citizen A's unfinished report must
  /// never appear when Citizen B logs into the same device.
  static String _keyForUser(String userId) {
    return '${_draftKeyPrefix}_$userId';
  }

  /// Returns true when this citizen has an unfinished report.
  static Future<bool> hasDraft({
    required String userId,
  }) async {
    final prefs =
    await SharedPreferences.getInstance();

    final raw =
    prefs.getString(_keyForUser(userId));

    if (raw == null || raw.trim().isEmpty) {
      return false;
    }

    try {
      final decoded =
      jsonDecode(raw);

      if (decoded is! Map) {
        return false;
      }

      final draft =
      ReportDraft.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      return draft.hasData;
    } catch (_) {
      return false;
    }
  }

  /// Loads this citizen's unfinished report.
  ///
  /// Returns null when:
  /// - no draft exists
  /// - the saved data is invalid/corrupted
  static Future<ReportDraft?> loadDraft({
    required String userId,
  }) async {
    final prefs =
    await SharedPreferences.getInstance();

    final raw =
    prefs.getString(_keyForUser(userId));

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded =
      jsonDecode(raw);

      if (decoded is! Map) {
        return null;
      }

      final draft =
      ReportDraft.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (!draft.hasData) {
        return null;
      }

      return draft;
    } catch (_) {
      // Do not crash Create Report if the local
      // draft somehow becomes corrupted.
      return null;
    }
  }

  /// Saves/overwrites the citizen's active draft.
  ///
  /// There is intentionally one active Create Report draft
  /// per citizen for now.
  static Future<void> saveDraft({
    required String userId,
    required ReportDraft draft,
  }) async {
    final prefs =
    await SharedPreferences.getInstance();

    final updatedDraft =
    draft.copyWith(
      updatedAt: DateTime.now(),
    );

    final encoded =
    jsonEncode(
      updatedDraft.toJson(),
    );

    final success =
    await prefs.setString(
      _keyForUser(userId),
      encoded,
    );

    if (!success) {
      throw Exception(
        'Unable to save report draft.',
      );
    }
  }

  /// Updates only the fields supplied by the caller.
  ///
  /// If no draft exists, a new empty draft is created first.
  static Future<ReportDraft> updateDraft({
    required String userId,
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
  }) async {
    final existing =
    await loadDraft(
      userId: userId,
    );

    final base =
        existing ??
            ReportDraft.empty();

    final updated =
    base.copyWith(
      category: category,
      priority: priority,
      title: title,
      description: description,
      landmark: landmark,
      manualAddress: manualAddress,
      latitude: latitude,
      longitude: longitude,
      locationAccuracy:
      locationAccuracy,
      detectedAddress:
      detectedAddress,
      locationVerificationStatus:
      locationVerificationStatus,
      addressDistanceMeters:
      addressDistanceMeters,
      voiceTranscript:
      voiceTranscript,
      voiceLocationContext:
      voiceLocationContext,
      voiceSafetyConcern:
      voiceSafetyConcern,
      currentStep:
      currentStep,
      hasCloseUpEvidence:
      hasCloseUpEvidence,
      hasContextEvidence:
      hasContextEvidence,
      evidenceImagePaths:
      evidenceImagePaths,
      updatedAt: DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    return updated;
  }

  /// Adds an evidence path without removing previously
  /// saved evidence.
  static Future<ReportDraft> addEvidenceImage({
    required String userId,
    required String imagePath,
  }) async {
    final existing =
    await loadDraft(
      userId: userId,
    );

    final base =
        existing ??
            ReportDraft.empty();

    final paths =
    List<String>.from(
      base.evidenceImagePaths,
    );

    if (!paths.contains(imagePath)) {
      paths.add(imagePath);
    }

    final updated =
    base.copyWith(
      evidenceImagePaths: paths,
      updatedAt: DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    return updated;
  }

  /// Removes one evidence image from the draft.
  static Future<ReportDraft> removeEvidenceImage({
    required String userId,
    required String imagePath,
  }) async {
    final existing =
    await loadDraft(
      userId: userId,
    );

    final base =
        existing ??
            ReportDraft.empty();

    final paths =
    List<String>.from(
      base.evidenceImagePaths,
    );

    paths.remove(imagePath);

    final updated =
    base.copyWith(
      evidenceImagePaths: paths,
      updatedAt: DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    return updated;
  }

  /// Completely removes the unfinished report.
  ///
  /// ONLY call this when:
  /// 1. Citizen explicitly chooses "Discard Report", or
  /// 2. Report submission has completed successfully.
  static Future<void> clearDraft({
    required String userId,
  }) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.remove(
      _keyForUser(userId),
    );
  }

  /// Useful for displaying:
  /// "Draft last updated 5 minutes ago".
  static Future<DateTime?> getLastUpdated({
    required String userId,
  }) async {
    final draft =
    await loadDraft(
      userId: userId,
    );

    return draft?.updatedAt;
  }
}