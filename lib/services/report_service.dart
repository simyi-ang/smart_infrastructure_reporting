import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/infrastructure_report.dart';

class ReportSubmissionResult {
  final String id;
  final String referenceNumber;

  ReportSubmissionResult({
    required this.id,
    required this.referenceNumber,
  });
}

enum ReportUploadStage {
  preparing,
  creatingReport,
  uploadingEvidence,
  finalizing,
  completed,
}

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

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String evidenceBucket = 'report-evidence';

  User? get currentUser => _supabase.auth.currentUser;

  // ============================================================
  // SUBMIT REPORT
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
    void Function(ReportUploadProgress progress)? onProgress,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to submit a report.',
      );
    }

    if (evidenceImages.isEmpty) {
      throw Exception(
        'Please provide at least one evidence image.',
      );
    }

    onProgress?.call(
      ReportUploadProgress(
        stage: ReportUploadStage.preparing,
        currentImage: 0,
        totalImages: evidenceImages.length,
        progress: 0.05,
        message: 'Preparing your report...',
      ),
    );

    String? reportId;

    final List<String> uploadedStoragePaths = [];

    try {
      // ========================================================
      // CREATE REPORT
      // ========================================================

      onProgress?.call(
        ReportUploadProgress(
          stage: ReportUploadStage.creatingReport,
          currentImage: 0,
          totalImages: evidenceImages.length,
          progress: 0.10,
          message: 'Creating report record...',
        ),
      );

      final Map<String, dynamic> report =
      await _supabase
          .from('reports')
          .insert({
        'citizen_id': user.id,
        'title': title.trim(),
        'category': category,
        'priority': priority,
        'description': description.trim(),
        'address': address.trim(),
        'landmark': landmark.trim().isEmpty
            ? null
            : landmark.trim(),
        'latitude': latitude,
        'longitude': longitude,

        // Initial workflow
        'status': 'pending',
        'progress_percentage': 10,
        'assigned_department': null,
        'estimated_completion': null,

        'updated_at':
        DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      reportId = report['id'].toString();

      final String referenceNumber =
      report['reference_number'].toString();

      // ========================================================
      // UPLOAD EVIDENCE IMAGES
      // ========================================================

      for (
      int index = 0;
      index < evidenceImages.length;
      index++
      ) {
        final File file = evidenceImages[index];

        final double uploadStart =
            0.15 + (0.70 * index / evidenceImages.length);

        onProgress?.call(
          ReportUploadProgress(
            stage: ReportUploadStage.uploadingEvidence,
            currentImage: index + 1,
            totalImages: evidenceImages.length,
            progress: uploadStart,
            message: 'Uploading evidence ${index + 1} of ${evidenceImages.length}...',
          ),
        );

        final String extension =
        _getExtension(
          file.path,
        );

        final String fileName =
            'evidence_${index + 1}_${DateTime.now().millisecondsSinceEpoch}.$extension';

        final String storagePath =
            '${user.id}/$reportId/$fileName';

        await _supabase.storage
            .from(evidenceBucket)
            .upload(
          storagePath,
          file,
          fileOptions:
          const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );

        uploadedStoragePaths.add(
          storagePath,
        );

        // ======================================================
        // SAVE IMAGE RECORD
        // ======================================================

        await _supabase
            .from('report_images')
            .insert({
          'report_id': reportId,
          'storage_path': storagePath,
        });

        final double uploadEnd =
            0.15 + (0.70 * (index + 1) / evidenceImages.length);

        onProgress?.call(
          ReportUploadProgress(
            stage: ReportUploadStage.uploadingEvidence,
            currentImage: index + 1,
            totalImages: evidenceImages.length,
            progress: uploadEnd,
            message: 'Evidence ${index + 1} of ${evidenceImages.length} uploaded.',
          ),
        );
      }

      onProgress?.call(
        ReportUploadProgress(
          stage: ReportUploadStage.finalizing,
          currentImage: evidenceImages.length,
          totalImages: evidenceImages.length,
          progress: 0.92,
          message: 'Finalizing submission...',
        ),
      );

      onProgress?.call(
        ReportUploadProgress(
          stage: ReportUploadStage.completed,
          currentImage: evidenceImages.length,
          totalImages: evidenceImages.length,
          progress: 1.0,
          message: 'Report submitted successfully.',
        ),
      );

      return ReportSubmissionResult(
        id: reportId,
        referenceNumber: referenceNumber,
      );
    } catch (e) {
      // ========================================================
      // CLEAN UP STORAGE IF SUBMISSION FAILS
      // ========================================================

      if (uploadedStoragePaths.isNotEmpty) {
        try {
          await _supabase.storage
              .from(evidenceBucket)
              .remove(
            uploadedStoragePaths,
          );
        } catch (_) {}
      }

      // ========================================================
      // CLEAN UP REPORT IF SUBMISSION FAILS
      // ========================================================

      if (reportId != null) {
        try {
          await _supabase
              .from('reports')
              .delete()
              .eq(
            'id',
            reportId,
          )
              .eq(
            'citizen_id',
            user.id,
          );
        } catch (_) {}
      }

      throw Exception(
        'Unable to submit report: ${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // EDIT PENDING REPORT
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

      if (report.status != 'pending') {
        throw Exception(
          'Only pending reports can be edited.',
        );
      }

      await _supabase
          .from('reports')
          .update({
        'title': title.trim(),
        'category': category,
        'priority': priority,
        'description': description.trim(),
        'address': address.trim(),
        'landmark': landmark.trim().isEmpty
            ? null
            : landmark.trim(),
        'latitude': latitude,
        'longitude': longitude,

        'updated_at':
        DateTime.now().toIso8601String(),
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
        'Unable to update report: ${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET MY REPORTS
  // ============================================================

  Future<List<InfrastructureReport>>
  getMyReports() async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from('reports')
          .select()
          .eq(
        'citizen_id',
        user.id,
      )
          .order(
        'created_at',
        ascending: false,
      );

      return response
          .map(
            (item) =>
            InfrastructureReport.fromMap(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load your reports: ${_cleanError(e)}',
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
    final user = currentUser;

    if (user == null) {
      return [];
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from('reports')
          .select()
          .eq(
        'citizen_id',
        user.id,
      )
          .order(
        'created_at',
        ascending: false,
      )
          .limit(
        limit,
      );

      return response
          .map(
            (item) =>
            InfrastructureReport.fromMap(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load recent reports: ${_cleanError(e)}',
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
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final Map<String, dynamic>? response =
      await _supabase
          .from('reports')
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

      return InfrastructureReport.fromMap(
        response,
      );
    } catch (e) {
      throw Exception(
        'Unable to load report: ${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET ALL REPORTS FOR WORKER / ADMIN
  // ============================================================

  Future<List<InfrastructureReport>>
  getAllReports() async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from('reports')
          .select()
          .order(
        'created_at',
        ascending: false,
      );

      return response
          .map(
            (item) =>
            InfrastructureReport.fromMap(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load reports: ${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // WORKER / ADMIN UPDATE REPORT WORKFLOW
  // ============================================================

  Future<void> updateReportWorkflow({
    required String reportId,
    required String status,
    required int progressPercentage,
    required String? assignedDepartment,
    DateTime? estimatedCompletion,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    if (progressPercentage < 0 ||
        progressPercentage > 100) {
      throw Exception(
        'Progress must be between 0 and 100.',
      );
    }

    const allowedStatuses = [
      'pending',
      'verified',
      'in_progress',
      'completed',
      'rejected',
    ];

    if (!allowedStatuses.contains(status)) {
      throw Exception(
        'Invalid report status.',
      );
    }

    try {
      await _supabase
          .from('reports')
          .update({
        'status': status,

        'progress_percentage':
        progressPercentage,

        'assigned_department':
        assignedDepartment,

        'estimated_completion':
        estimatedCompletion == null
            ? null
            : _dateOnly(
          estimatedCompletion,
        ),

        'updated_at':
        DateTime.now().toIso8601String(),
      })
          .eq(
        'id',
        reportId,
      );
    } catch (e) {
      throw Exception(
        'Unable to update report workflow: ${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // REPORT COUNT
  // ============================================================

  Future<int> getMyReportCount() async {
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

    int pending = 0;
    int verified = 0;
    int inProgress = 0;
    int completed = 0;
    int rejected = 0;

    for (final report in reports) {
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
      'total': reports.length,
      'pending': pending,
      'verified': verified,
      'in_progress': inProgress,
      'completed': completed,
      'rejected': rejected,
    };
  }

  // ============================================================
  // GET IMAGE PATHS
  // ============================================================

  Future<List<String>>
  getReportImagePaths(
      String reportId,
      ) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from('report_images')
          .select(
        'storage_path',
      )
          .eq(
        'report_id',
        reportId,
      )
          .order(
        'created_at',
        ascending: true,
      );

      return response
          .map(
            (item) =>
            item['storage_path'].toString(),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load report images: ${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // GET PRIVATE SIGNED IMAGE URL
  // ============================================================

  Future<String> getSignedImageUrl(
      String storagePath, {
        int expiresInSeconds = 3600,
      }) async {
    try {
      return await _supabase.storage
          .from(evidenceBucket)
          .createSignedUrl(
        storagePath,
        expiresInSeconds,
      );
    } catch (e) {
      throw Exception(
        'Unable to load evidence image: ${_cleanError(e)}',
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

    final List<String> urls = [];

    for (final path in paths) {
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

      if (report.status != 'pending') {
        throw Exception(
          'Only pending reports can be deleted.',
        );
      }

      // ========================================================
      // GET IMAGE PATHS BEFORE DELETING
      // ========================================================

      final imagePaths =
      await getReportImagePaths(
        reportId,
      );

      // ========================================================
      // DELETE STORAGE IMAGES
      // ========================================================

      if (imagePaths.isNotEmpty) {
        await _supabase.storage
            .from(evidenceBucket)
            .remove(
          imagePaths,
        );
      }

      // ========================================================
      // DELETE DATABASE REPORT
      // ========================================================

      await _supabase
          .from('reports')
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
        'Unable to delete report: ${_cleanError(e)}',
      );
    }
  }


  // ============================================================
  // SEARCH / FILTER / SORT MY REPORTS
  // ============================================================

  List<InfrastructureReport> applyFilters({
    required List<InfrastructureReport> reports,
    String searchQuery = '',
    String category = 'All',
    String priority = 'All',
    String status = 'All',
    String sortBy = 'Newest',
  }) {
    List<InfrastructureReport> result =
    List<InfrastructureReport>.from(reports);

    final query = searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where((report) {
        final title = report.title.toLowerCase();
        final address = report.address.toLowerCase();
        final reference = report.referenceNumber.toLowerCase();

        return title.contains(query) ||
            address.contains(query) ||
            reference.contains(query);
      }).toList();
    }

    if (category != 'All') {
      result = result.where((report) {
        return report.category.trim().toLowerCase() ==
            category.trim().toLowerCase();
      }).toList();
    }

    if (priority != 'All') {
      result = result.where((report) {
        return report.priority.trim().toLowerCase() ==
            priority.trim().toLowerCase();
      }).toList();
    }

    if (status != 'All') {
      final wantedStatus = _normalizeStatus(status);

      result = result.where((report) {
        return _normalizeStatus(report.status) == wantedStatus;
      }).toList();
    }

    switch (sortBy) {
      case 'Oldest':
        result.sort(
              (a, b) => a.createdAt.compareTo(b.createdAt),
        );
        break;

      case 'Priority':
        result.sort(
              (a, b) => _priorityWeight(b.priority)
              .compareTo(_priorityWeight(a.priority)),
        );
        break;

      case 'Status':
        result.sort(
              (a, b) => _statusWeight(a.status)
              .compareTo(_statusWeight(b.status)),
        );
        break;

      case 'Newest':
      default:
        result.sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
        );
        break;
    }

    return result;
  }

  // ============================================================
  // REPORT STATUS HISTORY
  // ============================================================

  Future<List<Map<String, dynamic>>> getReportStatusHistory(
      String reportId,
      ) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from('report_status_history')
          .select()
          .eq(
        'report_id',
        reportId,
      )
          .order(
        'created_at',
        ascending: true,
      );

      return response
          .map(
            (item) => Map<String, dynamic>.from(
          item as Map,
        ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load report status history: ${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // REPORT EDIT / DELETE RULES
  // ============================================================

  bool canEditReport(
      InfrastructureReport report,
      ) {
    return _normalizeStatus(report.status) == 'pending';
  }

  bool canDeleteReport(
      InfrastructureReport report,
      ) {
    return _normalizeStatus(report.status) == 'pending';
  }

  // ============================================================
  // DISPLAY HELPERS
  // ============================================================

  String statusDisplayName(
      String status,
      ) {
    switch (_normalizeStatus(status)) {
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

  String _normalizeStatus(
      String value,
      ) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  int _priorityWeight(
      String priority,
      ) {
    switch (priority.trim().toLowerCase()) {
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

  int _statusWeight(
      String status,
      ) {
    switch (_normalizeStatus(status)) {
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
    path.split('.');

    if (parts.length < 2) {
      return 'jpg';
    }

    final extension =
    parts.last.toLowerCase();

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
  // DATE ONLY FOR POSTGRES DATE COLUMN
  // ============================================================

  String _dateOnly(
      DateTime date,
      ) {
    final year =
    date.year.toString();

    final month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    final day =
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