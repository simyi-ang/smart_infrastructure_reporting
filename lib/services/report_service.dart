import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/infrastructure_report.dart';
import '../models/report_final_ai_analysis.dart';
import '../models/report_image_ai_analysis.dart';

// ================================================================
// REPORT SUBMISSION RESULT
// ================================================================

class ReportSubmissionResult {
  final String id;

  final String referenceNumber;

  ReportSubmissionResult({
    required this.id,
    required this.referenceNumber,
  });
}

// ================================================================
// REPORT UPLOAD STAGE
// ================================================================

enum ReportUploadStage {
  preparing,

  creatingReport,

  uploadingEvidence,

  savingAiAnalysis,

  finalizing,

  completed,
}

// ================================================================
// REPORT UPLOAD PROGRESS
// ================================================================

class ReportUploadProgress {
  final ReportUploadStage stage;

  final int currentImage;

  final int totalImages;

  final double progress;

  final String message;

  const ReportUploadProgress({
    required this.stage,
    required this.currentImage,
    required this.totalImages,
    required this.progress,
    required this.message,
  });
}

// ================================================================
// REPORT SERVICE
// ================================================================

class ReportService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // STORAGE
  // ============================================================

  static const String evidenceBucket =
      'report-evidence';

  // ============================================================
  // DATABASE TABLES
  // ============================================================

  static const String reportsTable =
      'reports';

  static const String reportImagesTable =
      'report_images';

  static const String imageAiAnalysisTable =
      'report_image_ai_analysis';

  static const String finalAiAnalysisTable =
      'report_final_ai_analysis';

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser =>
      _supabase.auth.currentUser;

  // ============================================================
  // SUBMIT REPORT
  //
  // Supports:
  //
  // Report
  //   │
  //   ├── Image 1
  //   │      └── AI Analysis 1
  //   │
  //   ├── Image 2
  //   │      └── AI Analysis 2
  //   │
  //   └── Image 3
  //          └── AI Analysis 3
  //
  //   ↓
  //
  // Final Combined AI Analysis
  //
  //
  // IMPORTANT:
  //
  // imageAnalyses uses:
  //
  // local file path
  //      ↓
  // ReportImageAiAnalysis
  //
  // This means AI results cannot shift onto the wrong image when
  // an image is removed from the evidence list.
  // ============================================================

  Future<ReportSubmissionResult> submitReport({
    required String title,

    required String category,

    required String priority,

    required String description,

    required String address,

    required String landmark,

    double? latitude,

    double? longitude,

    required List<File> evidenceImages,

    Map<String, ReportImageAiAnalysis>
    imageAnalyses =
    const {},

    ReportFinalAiAnalysis?
    finalAiAnalysis,

    void Function(
        ReportUploadProgress progress,
        )?
    onProgress,
  }) async {
    // ==========================================================
    // AUTHENTICATION
    // ==========================================================

    final User? user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to submit a report.',
      );
    }

    // ==========================================================
    // BASIC REPORT VALIDATION
    // ==========================================================

    final String cleanTitle =
    title.trim();

    final String cleanCategory =
    category.trim();

    final String cleanPriority =
    priority.trim();

    final String cleanDescription =
    description.trim();

    final String cleanAddress =
    address.trim();

    final String cleanLandmark =
    landmark.trim();

    if (cleanTitle.isEmpty) {
      throw Exception(
        'Report title is required.',
      );
    }

    if (cleanCategory.isEmpty) {
      throw Exception(
        'Report category is required.',
      );
    }

    if (cleanPriority.isEmpty) {
      throw Exception(
        'Report priority is required.',
      );
    }

    if (cleanDescription.isEmpty) {
      throw Exception(
        'Report description is required.',
      );
    }

    if (cleanAddress.isEmpty) {
      throw Exception(
        'Report location is required.',
      );
    }

    if (evidenceImages.isEmpty) {
      throw Exception(
        'Please provide at least one evidence image.',
      );
    }

    // ==========================================================
    // VERIFY LOCAL IMAGE FILES BEFORE CREATING DB RECORD
    // ==========================================================

    for (
    int index = 0;
    index < evidenceImages.length;
    index++
    ) {
      final File file =
      evidenceImages[index];

      if (!await file.exists()) {
        throw Exception(
          'Evidence image ${index + 1} is no longer available.',
        );
      }

      final int fileSize =
      await file.length();

      if (fileSize <= 0) {
        throw Exception(
          'Evidence image ${index + 1} is empty.',
        );
      }
    }

    // ==========================================================
    // PREPARING
    // ==========================================================

    onProgress?.call(
      ReportUploadProgress(
        stage:
        ReportUploadStage.preparing,

        currentImage:
        0,

        totalImages:
        evidenceImages.length,

        progress:
        0.03,

        message:
        'Preparing your report...',
      ),
    );

    // ==========================================================
    // ROLLBACK TRACKING
    // ==========================================================

    String? reportId;

    final List<String>
    uploadedStoragePaths =
    [];

    final List<String>
    createdReportImageIds =
    [];

    try {
      // ========================================================
      // CREATE REPORT
      // ========================================================

      onProgress?.call(
        ReportUploadProgress(
          stage:
          ReportUploadStage
              .creatingReport,

          currentImage:
          0,

          totalImages:
          evidenceImages.length,

          progress:
          0.08,

          message:
          'Creating report record...',
        ),
      );

      final Map<String, dynamic> report =
      await _supabase
          .from(
        reportsTable,
      )
          .insert(
        {
          'citizen_id':
          user.id,

          'title':
          cleanTitle,

          'category':
          cleanCategory,

          'priority':
          cleanPriority,

          'description':
          cleanDescription,

          'address':
          cleanAddress,

          'landmark':
          cleanLandmark.isEmpty
              ? null
              : cleanLandmark,

          'latitude':
          latitude,

          'longitude':
          longitude,

          // ====================================================
          // INITIAL WORKFLOW
          // ====================================================

          'status':
          'pending',

          'progress_percentage':
          10,

          'assigned_department':
          null,

          'estimated_completion':
          null,

          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        },
      )
          .select()
          .single();

      reportId =
          report['id']
              .toString();

      final String referenceNumber =
      report['reference_number']
          .toString();

      // ========================================================
      // UPLOAD ALL EVIDENCE
      // ========================================================

      for (
      int index = 0;
      index < evidenceImages.length;
      index++
      ) {
        final File file =
        evidenceImages[index];

        // ======================================================
        // PROGRESS
        // ======================================================

        final double uploadStart =
            0.12 +
                (
                    0.58 *
                        index /
                        evidenceImages.length
                );

        onProgress?.call(
          ReportUploadProgress(
            stage:
            ReportUploadStage
                .uploadingEvidence,

            currentImage:
            index + 1,

            totalImages:
            evidenceImages.length,

            progress:
            uploadStart,

            message:
            'Uploading evidence '
                '${index + 1} of '
                '${evidenceImages.length}...',
          ),
        );

        // ======================================================
        // FILE NAME
        // ======================================================

        final String extension =
        _getExtension(
          file.path,
        );

        final String fileName =
            'evidence_'
            '${index + 1}_'
            '${DateTime.now().microsecondsSinceEpoch}.'
            '$extension';

        final String storagePath =
            '${user.id}/'
            '$reportId/'
            '$fileName';

        // ======================================================
        // STORAGE UPLOAD
        // ======================================================

        await _supabase.storage
            .from(
          evidenceBucket,
        )
            .upload(
          storagePath,

          file,

          fileOptions:
          const FileOptions(
            cacheControl:
            '3600',

            upsert:
            false,
          ),
        );

        uploadedStoragePaths.add(
          storagePath,
        );

        // ======================================================
        // CREATE REPORT IMAGE ROW
        //
        // IMPORTANT:
        //
        // We now SELECT the generated ID.
        // ======================================================

        final Map<String, dynamic>
        imageRow =
        await _supabase
            .from(
          reportImagesTable,
        )
            .insert(
          {
            'report_id':
            reportId,

            'storage_path':
            storagePath,
          },
        )
            .select()
            .single();

        final String reportImageId =
        imageRow['id']
            .toString();

        createdReportImageIds.add(
          reportImageId,
        );

        // ======================================================
        // FIND AI RESULT FOR THIS EXACT LOCAL FILE
        // ======================================================

        final ReportImageAiAnalysis?
        imageAnalysis =
        imageAnalyses[
        file.path];

        // ======================================================
        // SAVE INDIVIDUAL IMAGE AI ANALYSIS
        // ======================================================

        if (imageAnalysis != null) {
          onProgress?.call(
            ReportUploadProgress(
              stage:
              ReportUploadStage
                  .savingAiAnalysis,

              currentImage:
              index + 1,

              totalImages:
              evidenceImages.length,

              progress:
              (
                  uploadStart +
                      0.03
              ).clamp(
                0.0,
                0.84,
              ),

              message:
              'Saving Smart Assist result for '
                  'image ${index + 1}...',
            ),
          );

          final Map<String, dynamic>
          imageAiData =
          imageAnalysis
              .toDatabaseJson(
            reportImageId:
            reportImageId,
          );

          // ====================================================
          // ENFORCE PERMANENT IDs / STATUS
          // ====================================================

          imageAiData[
          'report_image_id'] =
              reportImageId;

          imageAiData[
          'ai_status'] =
          imageAnalysis
              .aiStatus ==
              'failed'
              ? 'failed'
              : 'completed';

          imageAiData[
          'analyzed_at'] ??=
              DateTime.now()
                  .toUtc()
                  .toIso8601String();

          imageAiData[
          'updated_at'] =
              DateTime.now()
                  .toUtc()
                  .toIso8601String();

          await _supabase
              .from(
            imageAiAnalysisTable,
          )
              .upsert(
            imageAiData,

            onConflict:
            'report_image_id',
          );
        }

        // ======================================================
        // IMAGE COMPLETE PROGRESS
        // ======================================================

        final double uploadEnd =
            0.12 +
                (
                    0.58 *
                        (
                            index + 1
                        ) /
                        evidenceImages.length
                );

        onProgress?.call(
          ReportUploadProgress(
            stage:
            ReportUploadStage
                .uploadingEvidence,

            currentImage:
            index + 1,

            totalImages:
            evidenceImages.length,

            progress:
            uploadEnd,

            message:
            imageAnalysis != null
                ? 'Evidence ${index + 1} and AI analysis saved.'
                : 'Evidence ${index + 1} uploaded.',
          ),
        );
      }

      // ========================================================
      // SAVE FINAL COMBINED AI ANALYSIS
      // ========================================================

      if (finalAiAnalysis != null) {
        onProgress?.call(
          ReportUploadProgress(
            stage:
            ReportUploadStage
                .savingAiAnalysis,

            currentImage:
            evidenceImages.length,

            totalImages:
            evidenceImages.length,

            progress:
            0.82,

            message:
            'Saving final Smart Assist assessment...',
          ),
        );

        final Map<String, dynamic>
        finalAiData =
        finalAiAnalysis
            .toDatabaseJson(
          reportId:
          reportId,
        );

        // ======================================================
        // PERMANENT REPORT ID
        // ======================================================

        finalAiData[
        'report_id'] =
            reportId;

        finalAiData[
        'ai_status'] =
        finalAiAnalysis
            .aiStatus ==
            'failed'
            ? 'failed'
            : 'completed';

        finalAiData[
        'analyzed_image_count'] =
        finalAiAnalysis
            .analyzedImageCount >
            0
            ? finalAiAnalysis
            .analyzedImageCount
            : imageAnalyses.length;

        finalAiData[
        'analyzed_at'] ??=
            DateTime.now()
                .toUtc()
                .toIso8601String();

        finalAiData[
        'updated_at'] =
            DateTime.now()
                .toUtc()
                .toIso8601String();

        await _supabase
            .from(
          finalAiAnalysisTable,
        )
            .upsert(
          finalAiData,

          onConflict:
          'report_id',
        );
      }

      // ========================================================
      // FINALIZING
      // ========================================================

      onProgress?.call(
        ReportUploadProgress(
          stage:
          ReportUploadStage
              .finalizing,

          currentImage:
          evidenceImages.length,

          totalImages:
          evidenceImages.length,

          progress:
          0.94,

          message:
          'Finalizing submission...',
        ),
      );

      // ========================================================
      // COMPLETED
      // ========================================================

      onProgress?.call(
        ReportUploadProgress(
          stage:
          ReportUploadStage
              .completed,

          currentImage:
          evidenceImages.length,

          totalImages:
          evidenceImages.length,

          progress:
          1.0,

          message:
          'Report submitted successfully.',
        ),
      );

      return ReportSubmissionResult(
        id:
        reportId,

        referenceNumber:
        referenceNumber,
      );
    } catch (e) {
      // ========================================================
      // ROLLBACK
      //
      // Submission is treated as one logical operation.
      //
      // If any important stage fails, remove:
      //
      // final AI
      // image AI
      // report_images
      // storage files
      // report
      // ========================================================

      if (reportId != null) {
        // ======================================================
        // REMOVE FINAL AI
        // ======================================================

        try {
          await _supabase
              .from(
            finalAiAnalysisTable,
          )
              .delete()
              .eq(
            'report_id',
            reportId,
          );
        } catch (_) {
          // Best-effort rollback.
        }

        // ======================================================
        // REMOVE INDIVIDUAL AI ROWS
        // ======================================================

        if (
        createdReportImageIds
            .isNotEmpty
        ) {
          try {
            await _supabase
                .from(
              imageAiAnalysisTable,
            )
                .delete()
                .inFilter(
              'report_image_id',
              createdReportImageIds,
            );
          } catch (_) {
            // Best-effort rollback.
          }
        }

        // ======================================================
        // REMOVE REPORT IMAGE RECORDS
        // ======================================================

        try {
          await _supabase
              .from(
            reportImagesTable,
          )
              .delete()
              .eq(
            'report_id',
            reportId,
          );
        } catch (_) {
          // Best-effort rollback.
        }
      }

      // ========================================================
      // REMOVE STORAGE OBJECTS
      // ========================================================

      if (
      uploadedStoragePaths
          .isNotEmpty
      ) {
        try {
          await _supabase.storage
              .from(
            evidenceBucket,
          )
              .remove(
            uploadedStoragePaths,
          );
        } catch (_) {
          // Best-effort rollback.
        }
      }

      // ========================================================
      // REMOVE REPORT
      // ========================================================

      if (reportId != null) {
        try {
          await _supabase
              .from(
            reportsTable,
          )
              .delete()
              .eq(
            'id',
            reportId,
          )
              .eq(
            'citizen_id',
            user.id,
          );
        } catch (_) {
          // Best-effort rollback.
        }
      }

      throw Exception(
        'Unable to submit report: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // EDIT PENDING REPORT
  //
  // FROM HERE DOWN:
  //
  // Keep the remainder of your current report_service.dart
  // exactly as it already is.
  // ============================================================

  Future<void> updateReport({
    required String reportId,
    required String title,
    required String category,
    required String priority,
    required String description,
    required String address,
    required String landmark,
    double? latitude,
    double? longitude,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final report =
      await getReportById(
        reportId,
      );

      if (report == null) {
        throw Exception(
          'Report not found.',
        );
      }

      if (report.status !=
          'pending') {
        throw Exception(
          'Only pending reports can be edited.',
        );
      }

      await _supabase
          .from(
        reportsTable,
      )
          .update({
        'title':
        title.trim(),

        'category':
        category,

        'priority':
        priority,

        'description':
        description.trim(),

        'address':
        address.trim(),

        'landmark':
        landmark.trim().isEmpty
            ? null
            : landmark.trim(),

        'latitude':
        latitude,

        'longitude':
        longitude,

        'updated_at':
        DateTime.now()
            .toIso8601String(),
      })
          .eq(
        'id',
        reportId,
      )
          .eq(
        'citizen_id',
        user.id,
      )
          .eq(
        'status',
        'pending',
      );
    } catch (e) {
      throw Exception(
        'Unable to update report: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET MY REPORTS
  // ============================================================

  Future<List<InfrastructureReport>>
  getMyReports() async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from(
        reportsTable,
      )
          .select()
          .eq(
        'citizen_id',
        user.id,
      )
          .order(
        'created_at',
        ascending:
        false,
      );

      return response
          .map(
            (
            item,
            ) =>
            InfrastructureReport
                .fromMap(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load your reports: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET RECENT REPORTS
  // ============================================================

  Future<List<InfrastructureReport>>
  getRecentReports({
    int limit = 3,
  }) async {
    final user =
        currentUser;

    if (user == null) {
      return [];
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from(
        reportsTable,
      )
          .select()
          .eq(
        'citizen_id',
        user.id,
      )
          .order(
        'created_at',
        ascending:
        false,
      )
          .limit(
        limit,
      );

      return response
          .map(
            (
            item,
            ) =>
            InfrastructureReport
                .fromMap(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load recent reports: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET REPORT BY ID
  // ============================================================

  Future<InfrastructureReport?>
  getReportById(
      String reportId,
      ) async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final Map<String, dynamic>?
      response =
      await _supabase
          .from(
        reportsTable,
      )
          .select()
          .eq(
        'id',
        reportId,
      )
          .eq(
        'citizen_id',
        user.id,
      )
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return InfrastructureReport
          .fromMap(
        response,
      );
    } catch (e) {
      throw Exception(
        'Unable to load report: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET ALL REPORTS
  // ============================================================

  Future<List<InfrastructureReport>>
  getAllReports() async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from(
        reportsTable,
      )
          .select()
          .order(
        'created_at',
        ascending:
        false,
      );

      return response
          .map(
            (
            item,
            ) =>
            InfrastructureReport
                .fromMap(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load reports: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // WORKER / ADMIN UPDATE WORKFLOW
  // ============================================================

  Future<void> updateReportWorkflow({
    required String reportId,

    required String status,

    required int progressPercentage,

    required String?
    assignedDepartment,

    DateTime?
    estimatedCompletion,
  }) async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    if (
    progressPercentage < 0 ||
        progressPercentage > 100
    ) {
      throw Exception(
        'Progress must be between 0 and 100.',
      );
    }

    const List<String>
    allowedStatuses =
    [
      'pending',
      'verified',
      'in_progress',
      'completed',
      'rejected',
    ];

    if (
    !allowedStatuses.contains(
      status,
    )
    ) {
      throw Exception(
        'Invalid report status.',
      );
    }

    try {
      await _supabase
          .from(
        reportsTable,
      )
          .update({
        'status':
        status,

        'progress_percentage':
        progressPercentage,

        'assigned_department':
        assignedDepartment,

        'estimated_completion':
        estimatedCompletion ==
            null
            ? null
            : _dateOnly(
          estimatedCompletion,
        ),

        'updated_at':
        DateTime.now()
            .toIso8601String(),
      })
          .eq(
        'id',
        reportId,
      );
    } catch (e) {
      throw Exception(
        'Unable to update report workflow: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // REPORT COUNT
  // ============================================================

  Future<int>
  getMyReportCount() async {
    final reports =
    await getMyReports();

    return reports.length;
  }

  // ============================================================
  // STATUS COUNTS
  // ============================================================

  Future<Map<String, int>>
  getMyReportStatusCounts() async {
    final reports =
    await getMyReports();

    int pending =
    0;

    int verified =
    0;

    int inProgress =
    0;

    int completed =
    0;

    int rejected =
    0;

    for (
    final report in reports
    ) {
      switch (report.status) {
        case 'pending':
          pending++;
          break;

        case 'verified':
          verified++;
          break;

        case 'in_progress':
          inProgress++;
          break;

        case 'completed':
          completed++;
          break;

        case 'rejected':
          rejected++;
          break;
      }
    }

    return {
      'total':
      reports.length,

      'pending':
      pending,

      'verified':
      verified,

      'in_progress':
      inProgress,

      'completed':
      completed,

      'rejected':
      rejected,
    };
  }

  // ============================================================
  // GET IMAGE PATHS
  // ============================================================

  Future<List<String>>
  getReportImagePaths(
      String reportId,
      ) async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from(
        reportImagesTable,
      )
          .select(
        'storage_path',
      )
          .eq(
        'report_id',
        reportId,
      )
          .order(
        'created_at',
        ascending:
        true,
      );

      return response
          .map(
            (
            item,
            ) =>
            item[
            'storage_path']
                .toString(),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load report images: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET PRIVATE SIGNED IMAGE URL
  // ============================================================

  Future<String>
  getSignedImageUrl(
      String storagePath, {
        int expiresInSeconds =
        3600,
      }) async {
    try {
      return await _supabase
          .storage
          .from(
        evidenceBucket,
      )
          .createSignedUrl(
        storagePath,
        expiresInSeconds,
      );
    } catch (e) {
      throw Exception(
        'Unable to load evidence image: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET ALL SIGNED IMAGE URLS
  // ============================================================

  Future<List<String>>
  getReportSignedImageUrls(
      String reportId,
      ) async {
    final paths =
    await getReportImagePaths(
      reportId,
    );

    final List<String> urls =
    [];

    for (
    final path in paths
    ) {
      try {
        final url =
        await getSignedImageUrl(
          path,
        );

        urls.add(
          url,
        );
      } catch (_) {
        // Skip broken image.
      }
    }

    return urls;
  }

  // ============================================================
  // DELETE PENDING REPORT
  // ============================================================

  Future<void> deleteReport(
      String reportId,
      ) async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final report =
      await getReportById(
        reportId,
      );

      if (report == null) {
        throw Exception(
          'Report not found.',
        );
      }

      if (
      report.status !=
          'pending'
      ) {
        throw Exception(
          'Only pending reports can be deleted.',
        );
      }

      final imagePaths =
      await getReportImagePaths(
        reportId,
      );

      if (imagePaths.isNotEmpty) {
        await _supabase
            .storage
            .from(
          evidenceBucket,
        )
            .remove(
          imagePaths,
        );
      }

      await _supabase
          .from(
        reportsTable,
      )
          .delete()
          .eq(
        'id',
        reportId,
      )
          .eq(
        'citizen_id',
        user.id,
      )
          .eq(
        'status',
        'pending',
      );
    } catch (e) {
      throw Exception(
        'Unable to delete report: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // SEARCH / FILTER / SORT
  // ============================================================

  List<InfrastructureReport>
  applyFilters({
    required List<InfrastructureReport>
    reports,

    String searchQuery =
    '',

    String category =
    'All',

    String priority =
    'All',

    String status =
    'All',

    String sortBy =
    'Newest',
  }) {
    List<InfrastructureReport> result =
    List<InfrastructureReport>.from(
      reports,
    );

    final String query =
    searchQuery
        .trim()
        .toLowerCase();

    if (query.isNotEmpty) {
      result =
          result.where(
                (
                report,
                ) {
              final String title =
              report.title
                  .toLowerCase();

              final String address =
              report.address
                  .toLowerCase();

              final String reference =
              report.referenceNumber
                  .toLowerCase();

              return title.contains(
                query,
              ) ||
                  address.contains(
                    query,
                  ) ||
                  reference.contains(
                    query,
                  );
            },
          ).toList();
    }

    if (category !=
        'All') {
      result =
          result.where(
                (
                report,
                ) {
              return report.category
                  .trim()
                  .toLowerCase() ==
                  category
                      .trim()
                      .toLowerCase();
            },
          ).toList();
    }

    if (priority !=
        'All') {
      result =
          result.where(
                (
                report,
                ) {
              return report.priority
                  .trim()
                  .toLowerCase() ==
                  priority
                      .trim()
                      .toLowerCase();
            },
          ).toList();
    }

    if (status !=
        'All') {
      final String wantedStatus =
      _normalizeStatus(
        status,
      );

      result =
          result.where(
                (
                report,
                ) {
              return _normalizeStatus(
                report.status,
              ) ==
                  wantedStatus;
            },
          ).toList();
    }

    switch (sortBy) {
      case 'Oldest':
        result.sort(
              (
              a,
              b,
              ) =>
              a.createdAt
                  .compareTo(
                b.createdAt,
              ),
        );
        break;

      case 'Priority':
        result.sort(
              (
              a,
              b,
              ) =>
              _priorityWeight(
                b.priority,
              ).compareTo(
                _priorityWeight(
                  a.priority,
                ),
              ),
        );
        break;

      case 'Status':
        result.sort(
              (
              a,
              b,
              ) =>
              _statusWeight(
                a.status,
              ).compareTo(
                _statusWeight(
                  b.status,
                ),
              ),
        );
        break;

      case 'Newest':
      default:
        result.sort(
              (
              a,
              b,
              ) =>
              b.createdAt
                  .compareTo(
                a.createdAt,
              ),
        );

        break;
    }

    return result;
  }

  // ============================================================
  // REPORT STATUS HISTORY
  // ============================================================

  Future<
      List<
          Map<String, dynamic>
      >>
  getReportStatusHistory(
      String reportId,
      ) async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from(
        'report_status_history',
      )
          .select()
          .eq(
        'report_id',
        reportId,
      )
          .order(
        'created_at',
        ascending:
        true,
      );

      return response
          .map(
            (
            item,
            ) =>
        Map<String, dynamic>.from(
          item as Map,
        ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load report status history: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // REPORT EDIT / DELETE RULES
  // ============================================================

  bool canEditReport(
      InfrastructureReport report,
      ) {
    return _normalizeStatus(
      report.status,
    ) ==
        'pending';
  }

  bool canDeleteReport(
      InfrastructureReport report,
      ) {
    return _normalizeStatus(
      report.status,
    ) ==
        'pending';
  }

  // ============================================================
  // DISPLAY STATUS
  // ============================================================

  String statusDisplayName(
      String status,
      ) {
    switch (
    _normalizeStatus(
      status,
    )
    ) {
      case 'verified':
        return 'Verified';

      case 'in_progress':
        return 'In Progress';

      case 'completed':
        return 'Completed';

      case 'rejected':
        return 'Rejected';

      default:
        return 'Pending';
    }
  }

  // ============================================================
  // NORMALIZE STATUS
  // ============================================================

  String _normalizeStatus(
      String value,
      ) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(
      '-',
      '_',
    )
        .replaceAll(
      ' ',
      '_',
    );
  }

  // ============================================================
  // PRIORITY WEIGHT
  // ============================================================

  int _priorityWeight(
      String priority,
      ) {
    switch (
    priority
        .trim()
        .toLowerCase()
    ) {
      case 'critical':
        return 4;

      case 'high':
        return 3;

      case 'medium':
        return 2;

      case 'low':
        return 1;

      default:
        return 0;
    }
  }

  // ============================================================
  // STATUS WEIGHT
  // ============================================================

  int _statusWeight(
      String status,
      ) {
    switch (
    _normalizeStatus(
      status,
    )
    ) {
      case 'pending':
        return 1;

      case 'verified':
        return 2;

      case 'in_progress':
        return 3;

      case 'completed':
        return 4;

      case 'rejected':
        return 5;

      default:
        return 99;
    }
  }

  // ============================================================
  // FILE EXTENSION
  // ============================================================

  String _getExtension(
      String path,
      ) {
    final parts =
    path.split(
      '.',
    );

    if (parts.length <
        2) {
      return 'jpg';
    }

    final String extension =
    parts.last
        .toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return extension;

      default:
        return 'jpg';
    }
  }

  // ============================================================
  // DATE ONLY
  // ============================================================

  String _dateOnly(
      DateTime date,
      ) {
    final String year =
    date.year
        .toString();

    final String month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    final String day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '$year-$month-$day';
  }

  // ============================================================
  // ERROR CLEANUP
  // ============================================================

  String _cleanError(
      Object error,
      ) {
    return error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    );
  }
}