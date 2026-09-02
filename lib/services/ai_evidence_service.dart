import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_image_ai_analysis.dart';

// ============================================================
// AI EVIDENCE SERVICE
//
// Responsibilities:
//
// 1. Create / update AI analysis status in Supabase.
// 2. Call the backend AI analysis endpoint.
// 3. Parse the structured AI result.
// 4. Save the final AI result.
// 5. Return a ReportImageAiAnalysis object to Flutter UI.
//
// IMPORTANT:
//
// Gemini API key should NOT be stored inside Flutter.
// The actual Gemini call will be handled securely by a
// Supabase Edge Function in the next step.
// ============================================================

class AiEvidenceService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // TABLE NAME
  // ============================================================

  static const String analysisTable =
      'report_image_ai_analysis';

  // ============================================================
  // START AI ANALYSIS
  //
  // Creates or updates the AI analysis row to:
  //
  // ai_status = analyzing
  // ============================================================

  Future<ReportImageAiAnalysis> startAnalysis({
    required String reportImageId,
  }) async {
    if (reportImageId.trim().isEmpty) {
      throw Exception(
        'Report image ID is required.',
      );
    }

    try {
      final Map<String, dynamic> data =
      await _supabase
          .from(analysisTable)
          .upsert(
        {
          'report_image_id':
          reportImageId,

          'ai_status':
          'analyzing',

          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
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
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // CALL BACKEND AI ANALYSIS
  //
  // This calls a Supabase Edge Function named:
  //
  // analyze-report-image
  //
  // The Edge Function will later:
  //
  // - receive report_image_id
  // - load image from storage
  // - call Gemini securely
  // - return structured JSON
  // ============================================================

  Future<Map<String, dynamic>> callAiBackend({
    required String reportImageId,
  }) async {
    if (reportImageId.trim().isEmpty) {
      throw Exception(
        'Report image ID is required.',
      );
    }

    try {
      final FunctionResponse response =
      await _supabase.functions.invoke(
        'analyze-report-image',

        body: {
          'report_image_id':
          reportImageId,
        },
      );

      final dynamic rawData =
          response.data;

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

      return data;
    } on FunctionException catch (e) {
      throw Exception(
        'AI analysis failed: ${e.reasonPhrase ?? 'Unknown error'}',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // SAVE COMPLETED AI RESULT
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
    try {
      final String now =
      DateTime.now()
          .toUtc()
          .toIso8601String();

      final Map<String, dynamic> data =
      await _supabase
          .from(analysisTable)
          .upsert(
        {
          'report_image_id':
          reportImageId,

          'ai_status':
          'completed',

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
          now,

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
        'Unable to save AI analysis: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // MARK AI ANALYSIS AS FAILED
  // ============================================================

  Future<void> markAnalysisFailed({
    required String reportImageId,
  }) async {
    try {
      await _supabase
          .from(analysisTable)
          .upsert(
        {
          'report_image_id':
          reportImageId,

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
      // AI failure logging should not prevent the user
      // from continuing the infrastructure report manually.
    }
  }

  // ============================================================
  // GET EXISTING AI ANALYSIS
  // ============================================================

  Future<ReportImageAiAnalysis?>
  getAnalysis({
    required String reportImageId,
  }) async {
    try {
      final Map<String, dynamic>? data =
      await _supabase
          .from(analysisTable)
          .select()
          .eq(
        'report_image_id',
        reportImageId,
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
    }
  }

  // ============================================================
  // COMPLETE AI ANALYSIS FLOW
  //
  // This is the main method your Upload Evidence screen
  // will eventually call.
  //
  // Flow:
  //
  // report image
  //      ↓
  // mark analyzing
  //      ↓
  // call Edge Function
  //      ↓
  // receive structured JSON
  //      ↓
  // save AI result
  //      ↓
  // return model
  // ============================================================

  Future<ReportImageAiAnalysis> analyzeImage({
    required String reportImageId,
  }) async {
    try {
      // ========================================================
      // 1. MARK ANALYZING
      // ========================================================

      await startAnalysis(
        reportImageId:
        reportImageId,
      );

      // ========================================================
      // 2. CALL BACKEND
      // ========================================================

      final Map<String, dynamic> aiResult =
      await callAiBackend(
        reportImageId:
        reportImageId,
      );

      // ========================================================
      // 3. PARSE STRUCTURED RESULT
      // ========================================================

      final bool issueDetected =
          aiResult['issue_detected']
          as bool? ??
              false;

      final String category =
          aiResult['category']
              ?.toString() ??
              'Other';

      final String subcategory =
          aiResult['subcategory']
              ?.toString() ??
              'Unknown';

      final String severity =
          aiResult['severity']
              ?.toString() ??
              'Low';

      final String confidence =
          aiResult['confidence']
              ?.toString() ??
              'Low';

      final String description =
          aiResult['description']
              ?.toString() ??
              '';

      final String evidenceQuality =
          aiResult['evidence_quality']
              ?.toString() ??
              'Poor';

      final String safetyConcern =
          aiResult['safety_concern']
              ?.toString() ??
              '';

      // ========================================================
      // 4. SAVE RESULT
      // ========================================================

      return await saveCompletedAnalysis(
        reportImageId:
        reportImageId,

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
      );
    } catch (e) {
      // ========================================================
      // FAILURE
      // ========================================================

      await markAnalysisFailed(
        reportImageId:
        reportImageId,
      );

      rethrow;
    }
  }
}