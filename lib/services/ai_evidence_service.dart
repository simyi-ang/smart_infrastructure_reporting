import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_final_ai_analysis.dart';
import '../models/report_image_ai_analysis.dart';

class AiEvidenceService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // DATABASE TABLE
  // ============================================================

  static const String analysisTable =
      'report_image_ai_analysis';

  // ============================================================
  // EDGE FUNCTIONS
  // ============================================================

  static const String edgeFunctionName =
      'analyze-report-image';

  static const String combinedEdgeFunctionName =
      'combine-report-ai-analysis';

  // ============================================================
  // LIMITS
  // ============================================================

  static const int maxAiImageBytes =
      8 * 1024 * 1024;

  static const int maxCombinedImageAnalyses =
  5;

  // ============================================================
  // ANALYZE ONE LOCAL IMAGE
  // ============================================================

  Future<ReportImageAiAnalysis>
  analyzeLocalImage({
    required File imageFile,
    required String userCategory,
    required String userPriority,
    required String userTitle,
    required String userDescription,
  }) async {
    final Session? session =
        _supabase.auth.currentSession;

    if (session == null) {
      throw Exception(
        'Please sign in before using Smart Assist.',
      );
    }

    // ==========================================================
    // FILE EXISTS
    // ==========================================================

    if (!await imageFile.exists()) {
      throw Exception(
        'The selected evidence image could not be found.',
      );
    }

    final int fileSize =
    await imageFile.length();

    if (fileSize <= 0) {
      throw Exception(
        'The selected evidence image is empty.',
      );
    }

    if (fileSize > maxAiImageBytes) {
      throw Exception(
        'The evidence image is too large for Smart Assist. '
            'Please use a smaller image.',
      );
    }

    // ==========================================================
    // IMAGE DATA
    // ==========================================================

    final List<int> imageBytes =
    await imageFile.readAsBytes();

    if (imageBytes.isEmpty) {
      throw Exception(
        'The selected evidence image contains no usable data.',
      );
    }

    final String imageBase64 =
    base64Encode(
      imageBytes,
    );

    final String mimeType =
    _detectMimeType(
      imageFile.path,
    );

    // ==========================================================
    // REPORT CONTEXT
    // ==========================================================

    final String cleanCategory =
    userCategory.trim();

    final String cleanPriority =
    userPriority.trim();

    final String cleanTitle =
    userTitle.trim();

    final String cleanDescription =
    userDescription.trim();

    // ==========================================================
    // CALL SINGLE-IMAGE EDGE FUNCTION
    // ==========================================================

    try {
      final FunctionResponse response =
      await _supabase.functions.invoke(
        edgeFunctionName,

        body: {
          'analysis_mode':
          'pre_submission',

          'image_base64':
          imageBase64,

          'mime_type':
          mimeType,

          'report_context': {
            'category':
            cleanCategory,

            'priority':
            cleanPriority,

            'title':
            cleanTitle,

            'description':
            cleanDescription,
          },
        },
      );

      final Map<String, dynamic> data =
      _parseFunctionResponse(
        response.data,
      );

      return ReportImageAiAnalysis
          .fromAiResult(
        data,
      )
          .copyWith(
        originalUserCategory:
        cleanCategory,

        originalUserPriority:
        cleanPriority,

        originalUserTitle:
        cleanTitle,

        originalUserDescription:
        cleanDescription,
      );
    } on FunctionException catch (e) {
      throw Exception(
        _functionErrorMessage(
          e,
        ),
      );
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'Unable to analyze the evidence image.',
        ),
      );
    }
  }

  // ============================================================
  // COMBINE MULTIPLE IMAGE ANALYSES
  //
  // Example:
  //
  // image 1
  //   ↓
  // ReportImageAiAnalysis #1
  //
  // image 2
  //   ↓
  // ReportImageAiAnalysis #2
  //
  // image 3
  //   ↓
  // ReportImageAiAnalysis #3
  //
  //        ↓
  //
  // combineImageAnalyses()
  //
  //        ↓
  //
  // ReportFinalAiAnalysis
  // ============================================================

  Future<ReportFinalAiAnalysis>
  combineImageAnalyses({
    required Map<
        String,
        ReportImageAiAnalysis
    > imageAnalyses,

    required String userCategory,
    required String userPriority,
    required String userTitle,
    required String userDescription,
  }) async {
    // ==========================================================
    // AUTHENTICATION
    // ==========================================================

    final Session? session =
        _supabase.auth.currentSession;

    if (session == null) {
      throw Exception(
        'Please sign in before using Smart Assist.',
      );
    }

    // ==========================================================
    // ANALYSIS REQUIRED
    // ==========================================================

    if (imageAnalyses.isEmpty) {
      throw Exception(
        'At least one evidence image must be analyzed '
            'before creating the final Smart Assist result.',
      );
    }

    if (
    imageAnalyses.length >
        maxCombinedImageAnalyses
    ) {
      throw Exception(
        'Smart Assist can combine a maximum of '
            '$maxCombinedImageAnalyses evidence images.',
      );
    }

    // ==========================================================
    // CLEAN REPORT CONTEXT
    // ==========================================================

    final String cleanCategory =
    userCategory.trim();

    final String cleanPriority =
    userPriority.trim();

    final String cleanTitle =
    userTitle.trim();

    final String cleanDescription =
    userDescription.trim();

    if (cleanTitle.isEmpty) {
      throw Exception(
        'Report title is required.',
      );
    }

    if (cleanDescription.isEmpty) {
      throw Exception(
        'Report description is required.',
      );
    }

    // ==========================================================
    // STRUCTURED IMAGE ANALYSIS PAYLOAD
    //
    // Key:
    // local image path
    //
    // Value:
    // AI result for that exact image
    //
    // This avoids index mismatch when images are deleted.
    // ==========================================================

    final List<Map<String, dynamic>>
    analysisPayload = [];

    final List<String>
    sourceEvidenceIds = [];

    for (
    final MapEntry<
        String,
        ReportImageAiAnalysis
    > entry
    in imageAnalyses.entries
    ) {
      final String sourceEvidenceId =
      entry.key.trim();

      final ReportImageAiAnalysis analysis =
          entry.value;

      if (sourceEvidenceId.isNotEmpty) {
        sourceEvidenceIds.add(
          sourceEvidenceId,
        );
      }

      analysisPayload.add(
        {
          'source_evidence_id':
          sourceEvidenceId,

          'issue_detected':
          analysis.issueDetected,

          'category':
          analysis.category,

          'subcategory':
          analysis.subcategory,

          'severity':
          analysis.severity,

          'confidence':
          analysis.confidence,

          'evidence_quality':
          analysis.evidenceQuality,

          'description':
          analysis.description,

          'safety_concern':
          analysis.safetyConcern,

          'needs_human_review':
          analysis.needsHumanReview,

          'retake_recommended':
          analysis.retakeRecommended,

          'retake_reason':
          analysis.retakeReason,
        },
      );
    }

    // ==========================================================
    // CALL FINAL COMBINED EDGE FUNCTION
    // ==========================================================

    try {
      final FunctionResponse response =
      await _supabase.functions.invoke(
        combinedEdgeFunctionName,

        body: {
          'analysis_mode':
          'combine_analysis',

          'report_context': {
            'category':
            cleanCategory,

            'priority':
            cleanPriority,

            'title':
            cleanTitle,

            'description':
            cleanDescription,
          },

          'image_analyses':
          analysisPayload,
        },
      );

      final Map<String, dynamic> data =
      _parseFunctionResponse(
        response.data,
      );

      // ========================================================
      // CREATE TEMPORARY FINAL MODEL
      //
      // reportId remains empty until final submission.
      // ========================================================

      return ReportFinalAiAnalysis
          .fromAiResult(
        data,

        analyzedImageCount:
        analysisPayload.length,

        sourceEvidenceIds:
        sourceEvidenceIds,
      )
          .copyWith(
        originalUserCategory:
        cleanCategory,

        originalUserPriority:
        cleanPriority,

        originalUserTitle:
        cleanTitle,

        originalUserDescription:
        cleanDescription,
      );
    } on FunctionException catch (e) {
      throw Exception(
        _functionErrorMessage(
          e,
        ),
      );
    } catch (e) {
      throw Exception(
        _cleanError(
          e,

          fallback:
          'Unable to create the final Smart Assist analysis.',
        ),
      );
    }
  }

  // ============================================================
  // START SAVED IMAGE ANALYSIS
  // ============================================================

  Future<ReportImageAiAnalysis>
  startAnalysis({
    required String reportImageId,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Report image ID is required.',
      );
    }

    try {
      final String now =
      DateTime.now()
          .toUtc()
          .toIso8601String();

      final Map<String, dynamic> data =
      await _supabase
          .from(
        analysisTable,
      )
          .upsert(
        {
          'report_image_id':
          cleanId,

          'ai_status':
          'analyzing',

          'updated_at':
          now,
        },

        onConflict:
        'report_image_id',
      )
          .select()
          .single();

      return ReportImageAiAnalysis
          .fromJson(
        data,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to start AI analysis: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'Unable to start AI analysis.',
        ),
      );
    }
  }

  // ============================================================
  // CALL BACKEND FOR SAVED IMAGE
  // ============================================================

  Future<Map<String, dynamic>>
  callAiBackend({
    required String reportImageId,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Report image ID is required.',
      );
    }

    try {
      final FunctionResponse response =
      await _supabase.functions.invoke(
        edgeFunctionName,

        body: {
          'analysis_mode':
          'saved_image',

          'report_image_id':
          cleanId,
        },
      );

      return _parseFunctionResponse(
        response.data,
      );
    } on FunctionException catch (e) {
      throw Exception(
        _functionErrorMessage(
          e,
        ),
      );
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'AI analysis failed.',
        ),
      );
    }
  }

  // ============================================================
  // SAVE COMPLETE AI MODEL
  // ============================================================

  Future<ReportImageAiAnalysis>
  saveAnalysis({
    required String reportImageId,
    required ReportImageAiAnalysis analysis,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Report image ID is required.',
      );
    }

    try {
      final Map<String, dynamic>
      databaseData =
      analysis.toDatabaseJson(
        reportImageId:
        cleanId,
      );

      databaseData['ai_status'] =
      'completed';

      databaseData['report_image_id'] =
          cleanId;

      databaseData['analyzed_at'] =
          analysis.analyzedAt
              ?.toUtc()
              .toIso8601String() ??
              DateTime.now()
                  .toUtc()
                  .toIso8601String();

      databaseData['updated_at'] =
          DateTime.now()
              .toUtc()
              .toIso8601String();

      final Map<String, dynamic> data =
      await _supabase
          .from(
        analysisTable,
      )
          .upsert(
        databaseData,

        onConflict:
        'report_image_id',
      )
          .select()
          .single();

      return ReportImageAiAnalysis
          .fromJson(
        data,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to save AI analysis: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'Unable to save AI analysis.',
        ),
      );
    }
  }

  // ============================================================
  // LEGACY SAVE METHOD
  // ============================================================

  Future<ReportImageAiAnalysis>
  saveCompletedAnalysis({
    required String reportImageId,
    required bool issueDetected,
    required String category,
    required String subcategory,
    required String severity,
    required String confidence,
    required String description,
    required String evidenceQuality,
    required String safetyConcern,
  }) async {
    final ReportImageAiAnalysis analysis =
    ReportImageAiAnalysis(
      aiStatus:
      'completed',

      issueDetected:
      issueDetected,

      category:
      category,

      subcategory:
      subcategory,

      severity:
      severity,

      confidence:
      confidence,

      description:
      description,

      evidenceQuality:
      evidenceQuality,

      safetyConcern:
      safetyConcern,

      analyzedAt:
      DateTime.now()
          .toUtc(),
    );

    return saveAnalysis(
      reportImageId:
      reportImageId,

      analysis:
      analysis,
    );
  }

  // ============================================================
  // SAVE TEMPORARY PRE-SUBMISSION RESULT
  // ============================================================

  Future<ReportImageAiAnalysis>
  saveTemporaryAnalysis({
    required String reportImageId,
    required ReportImageAiAnalysis analysis,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Report image ID is required.',
      );
    }

    final ReportImageAiAnalysis permanentAnalysis =
    analysis.copyWith(
      reportImageId:
      cleanId,

      aiStatus:
      'completed',

      analyzedAt:
      analysis.analyzedAt ??
          DateTime.now()
              .toUtc(),

      updatedAt:
      DateTime.now()
          .toUtc(),
    );

    return saveAnalysis(
      reportImageId:
      cleanId,

      analysis:
      permanentAnalysis,
    );
  }

  // ============================================================
  // MARK ANALYSIS FAILED
  // ============================================================

  Future<void> markAnalysisFailed({
    required String reportImageId,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      return;
    }

    try {
      await _supabase
          .from(
        analysisTable,
      )
          .upsert(
        {
          'report_image_id':
          cleanId,

          'ai_status':
          'failed',

          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        },

        onConflict:
        'report_image_id',
      );
    } catch (_) {
      // AI logging must never block normal reporting.
    }
  }

  // ============================================================
  // GET EXISTING ANALYSIS
  // ============================================================

  Future<ReportImageAiAnalysis?>
  getAnalysis({
    required String reportImageId,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic>? data =
      await _supabase
          .from(
        analysisTable,
      )
          .select()
          .eq(
        'report_image_id',
        cleanId,
      )
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return ReportImageAiAnalysis
          .fromJson(
        data,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to load AI analysis: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'Unable to load AI analysis.',
        ),
      );
    }
  }

  // ============================================================
  // DELETE ANALYSIS
  // ============================================================

  Future<void> deleteAnalysis({
    required String reportImageId,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      return;
    }

    try {
      await _supabase
          .from(
        analysisTable,
      )
          .delete()
          .eq(
        'report_image_id',
        cleanId,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to delete AI analysis: ${e.message}',
      );
    }
  }

  // ============================================================
  // COMPLETE SAVED-IMAGE ANALYSIS
  // ============================================================

  Future<ReportImageAiAnalysis>
  analyzeImage({
    required String reportImageId,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Report image ID is required.',
      );
    }

    try {
      await startAnalysis(
        reportImageId:
        cleanId,
      );

      final Map<String, dynamic> aiResult =
      await callAiBackend(
        reportImageId:
        cleanId,
      );

      final ReportImageAiAnalysis analysis =
      ReportImageAiAnalysis
          .fromAiResult(
        aiResult,
      );

      return await saveTemporaryAnalysis(
        reportImageId:
        cleanId,

        analysis:
        analysis,
      );
    } catch (e) {
      await markAnalysisFailed(
        reportImageId:
        cleanId,
      );

      rethrow;
    }
  }

  // ============================================================
  // UPDATE HUMAN REVIEW
  // ============================================================

  Future<ReportImageAiAnalysis>
  updateHumanReview({
    required String reportImageId,
    required bool suggestionsApplied,
    required bool reviewedByUser,
  }) async {
    final String cleanId =
    reportImageId.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Report image ID is required.',
      );
    }

    try {
      final Map<String, dynamic> data =
      await _supabase
          .from(
        analysisTable,
      )
          .update(
        {
          'suggestions_applied':
          suggestionsApplied,

          'reviewed_by_user':
          reviewedByUser,

          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        },
      )
          .eq(
        'report_image_id',
        cleanId,
      )
          .select()
          .single();

      return ReportImageAiAnalysis
          .fromJson(
        data,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to update AI review: ${e.message}',
      );
    }
  }

  // ============================================================
  // PARSE EDGE FUNCTION RESPONSE
  // ============================================================

  Map<String, dynamic>
  _parseFunctionResponse(
      dynamic rawData,
      ) {
    if (rawData == null) {
      throw Exception(
        'AI analysis returned no data.',
      );
    }

    if (rawData is! Map) {
      throw Exception(
        'Invalid AI response format.',
      );
    }

    final Map<String, dynamic> data =
    Map<String, dynamic>.from(
      rawData,
    );

    final String? backendError =
    data['error']
        ?.toString();

    if (
    backendError != null &&
        backendError
            .trim()
            .isNotEmpty
    ) {
      throw Exception(
        backendError.trim(),
      );
    }

    return data;
  }

  // ============================================================
  // MIME TYPE
  // ============================================================

  String _detectMimeType(
      String path,
      ) {
    final String lower =
    path
        .trim()
        .toLowerCase();

    if (
    lower.endsWith(
      '.png',
    )
    ) {
      return 'image/png';
    }

    if (
    lower.endsWith(
      '.webp',
    )
    ) {
      return 'image/webp';
    }

    if (
    lower.endsWith(
      '.jpg',
    ) ||
        lower.endsWith(
          '.jpeg',
        )
    ) {
      return 'image/jpeg';
    }

    if (
    lower.endsWith(
      '.heic',
    ) ||
        lower.endsWith(
          '.heif',
        )
    ) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  // ============================================================
  // FUNCTION ERROR MESSAGE
  // ============================================================

  String _functionErrorMessage(
      FunctionException error,
      ) {
    final dynamic rawDetails =
        error.details;

    if (rawDetails != null) {
      if (rawDetails is Map) {
        final dynamic nestedError =
        rawDetails['error'];

        if (nestedError != null) {
          final String message =
          nestedError
              .toString()
              .trim();

          if (message.isNotEmpty) {
            return 'AI analysis failed: $message';
          }
        }
      }

      final String details =
      rawDetails
          .toString()
          .trim();

      if (
      details.isNotEmpty &&
          details !=
              'null' &&
          details !=
              '{}'
      ) {
        return 'AI analysis failed: $details';
      }
    }

    final String? reason =
        error.reasonPhrase;

    if (
    reason != null &&
        reason
            .trim()
            .isNotEmpty
    ) {
      return 'AI analysis failed: '
          '${reason.trim()}';
    }

    return 'Smart Assist is currently unavailable.';
  }

  // ============================================================
  // CLEAN ERROR
  // ============================================================

  String _cleanError(
      Object error, {
        required String fallback,
      }) {
    final String message =
    error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    )
        .trim();

    if (message.isEmpty) {
      return fallback;
    }

    return message;
  }
}