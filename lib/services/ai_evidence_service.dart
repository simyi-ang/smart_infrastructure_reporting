import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_image_ai_analysis.dart';

// ============================================================
// AI EVIDENCE SERVICE
//
// SmartCity supports TWO AI analysis flows:
//
// ============================================================
//
// FLOW A — PRE-SUBMISSION SMART ASSIST
//
// Citizen enters report details
//      ↓
// Selects evidence image
//      ↓
// Image compression
//      ↓
// Local compressed File
//      ↓
// Supabase Edge Function
//      ↓
// Gemini multimodal analysis
//      ↓
// Context-aware AI assessment
//      ↓
// ReportImageAiAnalysis
//
// No report_id or report_image_id exists at this point.
//
// ============================================================
//
// FLOW B — SAVED REPORT IMAGE ANALYSIS
//
// report_images.id
//      ↓
// Mark AI status = analyzing
//      ↓
// Protected Edge Function
//      ↓
// Ownership verification
//      ↓
// Load stored evidence
//      ↓
// Gemini
//      ↓
// Save permanent result
//      ↓
// report_image_ai_analysis
//
// ============================================================
//
// SECURITY:
//
// Gemini API key is NEVER stored in Flutter.
//
// Flutter
//    ↓ authenticated request
// Supabase Edge Function
//    ↓
// Gemini API
//
// ============================================================

class AiEvidenceService {
  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // DATABASE TABLE
  // ============================================================

  static const String analysisTable =
      'report_image_ai_analysis';

  // ============================================================
  // EDGE FUNCTION
  // ============================================================

  static const String edgeFunctionName =
      'analyze-report-image';

  // ============================================================
  // IMAGE SIZE LIMIT
  //
  // Images should already be optimized by
  // ImageCompressionService.
  //
  // Client-side validation reduces unnecessary requests.
  // Server-side validation must still remain in the
  // Edge Function.
  // ============================================================

  static const int maxAiImageBytes =
      8 * 1024 * 1024;

  // ============================================================
  // PRE-SUBMISSION SMART ASSIST
  //
  // Used by CreateReportEvidenceScreen.
  //
  // Gemini receives:
  //
  // - compressed evidence image
  // - citizen category
  // - citizen priority
  // - citizen title
  // - citizen description
  //
  // This allows Smart Assist to compare the visual evidence
  // against the user's report instead of analyzing the image
  // without context.
  // ============================================================

  Future<ReportImageAiAnalysis>
  analyzeLocalImage({
    required File imageFile,

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
    // FILE VALIDATION
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
    // READ IMAGE
    // ==========================================================

    final List<int> imageBytes =
    await imageFile.readAsBytes();

    if (imageBytes.isEmpty) {
      throw Exception(
        'The selected evidence image contains no usable data.',
      );
    }

    // ==========================================================
    // BASE64
    // ==========================================================

    final String imageBase64 =
    base64Encode(
      imageBytes,
    );

    // ==========================================================
    // MIME TYPE
    // ==========================================================

    final String mimeType =
    _detectMimeType(
      imageFile.path,
    );

    // ==========================================================
    // NORMALIZE REPORT CONTEXT
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
    // EDGE FUNCTION REQUEST
    // ==========================================================

    try {
      final FunctionResponse response =
      await _supabase.functions.invoke(
        edgeFunctionName,

        body: {
          // ====================================================
          // ANALYSIS MODE
          // ====================================================

          'analysis_mode':
          'pre_submission',

          // ====================================================
          // IMAGE
          // ====================================================

          'image_base64':
          imageBase64,

          'mime_type':
          mimeType,

          // ====================================================
          // CITIZEN REPORT CONTEXT
          //
          // Gemini uses this to compare:
          //
          // citizen report
          // vs
          // visible evidence
          // ====================================================

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

      // ========================================================
      // PARSE FUNCTION RESPONSE
      // ========================================================

      final Map<String, dynamic> data =
      _parseFunctionResponse(
        response.data,
      );

      // ========================================================
      // CREATE TEMPORARY AI MODEL
      //
      // Database identifiers are intentionally empty because
      // report_images has not been created yet.
      // ========================================================

      return ReportImageAiAnalysis
          .fromAiResult(
        data,
      )
          .copyWith(
        originalUserCategory:
        cleanCategory,

        originalUserPriority:
        cleanPriority,

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
  // START SAVED IMAGE ANALYSIS
  //
  // Creates or updates:
  //
  // ai_status = analyzing
  //
  // for an existing report_images record.
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
  //
  // The Edge Function will:
  //
  // 1. identify authenticated caller
  // 2. load report_images
  // 3. verify report ownership
  // 4. download image from report-evidence
  // 5. call Gemini
  // 6. return structured result
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
  //
  // Preferred persistence method.
  //
  // Saves:
  //
  // core result
  // advanced result
  // citizen comparison
  // human review information
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

      // ========================================================
      // ENSURE COMPLETED STATUS
      // ========================================================

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
  // LEGACY / BASIC SAVE METHOD
  //
  // Retained so existing code using saveCompletedAnalysis()
  // does not break.
  //
  // New code should preferably use saveAnalysis().
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
      DateTime.now().toUtc(),
    );

    return saveAnalysis(
      reportImageId:
      reportImageId,

      analysis:
      analysis,
    );
  }

  // ============================================================
  // SAVE PRE-SUBMISSION AI RESULT
  //
  // Call AFTER:
  //
  // report inserted
  //      ↓
  // image uploaded
  //      ↓
  // report_images row inserted
  //      ↓
  // report_image_id available
  //
  // The temporary AI result can now become permanent.
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

    final ReportImageAiAnalysis
    permanentAnalysis =
    analysis.copyWith(
      reportImageId:
      cleanId,

      aiStatus:
      'completed',

      analyzedAt:
      analysis.analyzedAt ??
          DateTime.now().toUtc(),

      updatedAt:
      DateTime.now().toUtc(),
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
  //
  // Failure logging should NEVER stop the citizen from using
  // normal manual reporting.
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
      // ========================================================
      // INTENTIONAL
      //
      // An AI logging failure must not prevent:
      //
      // report submission
      // evidence upload
      // location selection
      // worker processing
      // ========================================================
    }
  }

  // ============================================================
  // GET EXISTING AI ANALYSIS
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
  // DELETE AI ANALYSIS
  //
  // Useful if:
  //
  // report image is deleted
  // analysis must be regenerated
  //
  // ON DELETE CASCADE should normally handle deletion when the
  // report image itself is removed.
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
  //
  // Existing flow preserved:
  //
  // report_images.id
  //       ↓
  // ai_status = analyzing
  //       ↓
  // Edge Function
  //       ↓
  // Gemini
  //       ↓
  // parse structured result
  //       ↓
  // save permanent result
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
      // ========================================================
      // STEP 1 — STATUS
      // ========================================================

      await startAnalysis(
        reportImageId:
        cleanId,
      );

      // ========================================================
      // STEP 2 — EDGE FUNCTION
      // ========================================================

      final Map<String, dynamic> aiResult =
      await callAiBackend(
        reportImageId:
        cleanId,
      );

      // ========================================================
      // STEP 3 — PARSE
      // ========================================================

      final ReportImageAiAnalysis analysis =
      ReportImageAiAnalysis
          .fromAiResult(
        aiResult,
      );

      // ========================================================
      // STEP 4 — PERSIST
      // ========================================================

      return await saveTemporaryAnalysis(
        reportImageId:
        cleanId,

        analysis:
        analysis,
      );
    } catch (e) {
      // ========================================================
      // FAILURE STATUS
      // ========================================================

      await markAnalysisFailed(
        reportImageId:
        cleanId,
      );

      rethrow;
    }
  }

  // ============================================================
  // SAVE HUMAN REVIEW DECISION
  //
  // Allows the report workflow to record whether the citizen:
  //
  // - reviewed the AI result
  // - applied AI suggestions
  //
  // without re-running Gemini.
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
    // ==========================================================
    // NULL
    // ==========================================================

    if (rawData == null) {
      throw Exception(
        'AI analysis returned no data.',
      );
    }

    // ==========================================================
    // EXPECT OBJECT
    // ==========================================================

    if (rawData is! Map) {
      throw Exception(
        'Invalid AI response format.',
      );
    }

    final Map<String, dynamic> data =
    Map<String, dynamic>.from(
      rawData,
    );

    // ==========================================================
    // BACKEND ERROR
    // ==========================================================

    final String? backendError =
    data['error']?.toString();

    if (backendError != null &&
        backendError.trim().isNotEmpty) {
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

    if (lower.endsWith(
      '.png',
    )) {
      return 'image/png';
    }

    if (lower.endsWith(
      '.webp',
    )) {
      return 'image/webp';
    }

    if (lower.endsWith(
      '.jpg',
    ) ||
        lower.endsWith(
          '.jpeg',
        )) {
      return 'image/jpeg';
    }

    // ==========================================================
    // HEIC / HEIF
    //
    // Your Edge Function currently accepts only the configured
    // supported formats.
    //
    // If compression converts HEIC to JPEG, the resulting file
    // extension should normally be JPEG.
    // ==========================================================

    if (lower.endsWith(
      '.heic',
    ) ||
        lower.endsWith(
          '.heif',
        )) {
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
    // ==========================================================
    // DETAILS
    // ==========================================================

    final dynamic rawDetails =
        error.details;

    if (rawDetails != null) {
      // ========================================================
      // MAP DETAILS
      // ========================================================

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

      // ========================================================
      // STRING DETAILS
      // ========================================================

      final String details =
      rawDetails
          .toString()
          .trim();

      if (details.isNotEmpty &&
          details != 'null' &&
          details != '{}') {
        return 'AI analysis failed: $details';
      }
    }

    // ==========================================================
    // HTTP REASON
    // ==========================================================

    final String? reason =
        error.reasonPhrase;

    if (reason != null &&
        reason.trim().isNotEmpty) {
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