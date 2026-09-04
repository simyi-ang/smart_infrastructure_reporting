import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class EditableReportEvidence {
  final String id;

  final String type;

  final String storagePath;

  final String sourceTable;

  final String? signedUrl;

  final String? evidenceRole;

  final DateTime? capturedAt;

  const EditableReportEvidence({
    required this.id,
    required this.type,
    required this.storagePath,
    required this.sourceTable,
    this.signedUrl,
    this.evidenceRole,
    this.capturedAt,
  });

  bool get isImage =>
      type == 'image';

  bool get isVideo =>
      type == 'video';
}

class ReportEditEvidenceService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  static const String evidenceBucket =
      'report-evidence';

  static const String reportImagesTable =
      'report_images';

  static const String reportEvidenceTable =
      'report_evidence';

  static const String imageAiAnalysisTable =
      'report_image_ai_analysis';

  // ============================================================
  // LOAD EXISTING EVIDENCE
  // ============================================================

  Future<List<EditableReportEvidence>>
  loadEvidence({
    required String reportId,
  }) async {
    final String cleanId =
    reportId.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Report ID is required.',
      );
    }

    try {
      final List<dynamic> imageRows =
      await _supabase
          .from(
        reportImagesTable,
      )
          .select(
        'id, storage_path, created_at',
      )
          .eq(
        'report_id',
        cleanId,
      )
          .order(
        'created_at',
        ascending: true,
      );

      final List<dynamic> genericRows =
      await _supabase
          .from(
        reportEvidenceTable,
      )
          .select(
        'id, evidence_type, storage_path, '
            'evidence_role, created_at',
      )
          .eq(
        'report_id',
        cleanId,
      )
          .order(
        'created_at',
        ascending: true,
      );

      final List<EditableReportEvidence>
      evidence =
      [];

      // ========================================================
      // LEGACY / CURRENT IMAGE TABLE
      // ========================================================

      for (final dynamic item in imageRows) {
        final Map<String, dynamic> row =
        Map<String, dynamic>.from(
          item as Map,
        );

        final String path =
            row['storage_path']
                ?.toString() ??
                '';

        evidence.add(
          EditableReportEvidence(
            id:
            row['id'].toString(),
            type:
            'image',
            storagePath:
            path,
            sourceTable:
            reportImagesTable,
            signedUrl:
            await _signedUrl(
              path,
            ),
            capturedAt:
            _date(
              row['created_at'],
            ),
          ),
        );
      }

      // ========================================================
      // GENERIC IMAGE / VIDEO TABLE
      // ========================================================

      for (final dynamic item in genericRows) {
        final Map<String, dynamic> row =
        Map<String, dynamic>.from(
          item as Map,
        );

        final String type =
            row['evidence_type']
                ?.toString()
                .toLowerCase() ??
                'video';

        final String path =
            row['storage_path']
                ?.toString() ??
                '';

        evidence.add(
          EditableReportEvidence(
            id:
            row['id'].toString(),
            type:
            type == 'image'
                ? 'image'
                : 'video',
            storagePath:
            path,
            sourceTable:
            reportEvidenceTable,
            signedUrl:
            type == 'image'
                ? await _signedUrl(
              path,
            )
                : null,
            evidenceRole:
            row['evidence_role']
                ?.toString(),
            capturedAt:
            _date(
              row['created_at'],
            ),
          ),
        );
      }

      return evidence;
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to load evidence: '
            '${e.message}',
      );
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'Unable to load evidence.',
        ),
      );
    }
  }

  // ============================================================
  // ADD IMAGE
  // ============================================================

  Future<EditableReportEvidence>
  addImage({
    required String reportId,
    required File file,
  }) async {
    final User? user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    if (!await file.exists()) {
      throw Exception(
        'The selected image is no longer available.',
      );
    }

    if (await file.length() <= 0) {
      throw Exception(
        'The selected image is empty.',
      );
    }

    final String extension =
    _extension(
      file.path,
      fallback: 'jpg',
    );

    final String storagePath =
        '${user.id}/'
        '$reportId/'
        'edit_image_'
        '${DateTime.now().microsecondsSinceEpoch}.'
        '$extension';

    try {
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

      try {
        final Map<String, dynamic> row =
        await _supabase
            .from(
          reportImagesTable,
        )
            .insert({
          'report_id':
          reportId,
          'storage_path':
          storagePath,
        })
            .select(
          'id, storage_path, created_at',
        )
            .single();

        return EditableReportEvidence(
          id:
          row['id'].toString(),
          type:
          'image',
          storagePath:
          storagePath,
          sourceTable:
          reportImagesTable,
          signedUrl:
          await _signedUrl(
            storagePath,
          ),
          capturedAt:
          _date(
            row['created_at'],
          ) ??
              DateTime.now()
                  .toUtc(),
        );
      } catch (_) {
        await _safeDeleteStorage(
          storagePath,
        );

        rethrow;
      }
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'Unable to add evidence image.',
        ),
      );
    }
  }

  // ============================================================
  // ADD VIDEO
  // ============================================================

  Future<EditableReportEvidence>
  addVideo({
    required String reportId,
    required File file,
    double? latitude,
    double? longitude,
  }) async {
    final User? user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    if (!await file.exists()) {
      throw Exception(
        'The selected video is no longer available.',
      );
    }

    if (await file.length() <= 0) {
      throw Exception(
        'The selected video is empty.',
      );
    }

    final String extension =
    _extension(
      file.path,
      fallback: 'mp4',
    );

    final String storagePath =
        '${user.id}/'
        '$reportId/'
        'edit_video_'
        '${DateTime.now().microsecondsSinceEpoch}.'
        '$extension';

    try {
      await _supabase.storage
          .from(
        evidenceBucket,
      )
          .upload(
        storagePath,
        file,
        fileOptions:
        FileOptions(
          cacheControl:
          '3600',
          upsert:
          false,
          contentType:
          _videoMimeType(
            extension,
          ),
        ),
      );

      try {
        final Map<String, dynamic> row =
        await _supabase
            .from(
          reportEvidenceTable,
        )
            .insert({
          'report_id':
          reportId,

          'evidence_type':
          'video',

          'storage_path':
          storagePath,

          'original_file_name':
          _fileName(
            file.path,
          ),

          'mime_type':
          _videoMimeType(
            extension,
          ),

          'file_size_bytes':
          await file.length(),

          'duration_seconds':
          null,

          'thumbnail_storage_path':
          null,

          'evidence_role':
          'supporting',

          'latitude':
          latitude,

          'longitude':
          longitude,
        })
            .select()
            .single();

        return EditableReportEvidence(
          id:
          row['id'].toString(),
          type:
          'video',
          storagePath:
          storagePath,
          sourceTable:
          reportEvidenceTable,
          evidenceRole:
          row['evidence_role']
              ?.toString(),
          capturedAt:
          _date(
            row['created_at'],
          ) ??
              DateTime.now()
                  .toUtc(),
        );
      } catch (_) {
        await _safeDeleteStorage(
          storagePath,
        );

        rethrow;
      }
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'Unable to add evidence video.',
        ),
      );
    }
  }

  // ============================================================
  // REMOVE EVIDENCE
  //
  // IMPORTANT:
  // Supabase DELETE with RLS can succeed at HTTP level while
  // affecting ZERO rows. The previous implementation treated that
  // as a successful delete, so the UI removed the card locally but
  // the evidence returned when Edit Report was opened again.
  //
  // This implementation requests the deleted id using .select('id')
  // and requires exactly one matching row to be returned.
  // ============================================================

  Future<void> removeEvidence({
    required EditableReportEvidence evidence,
  }) async {
    final User? user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to remove evidence.',
      );
    }

    final String evidenceId =
    evidence.id.trim();

    if (evidenceId.isEmpty) {
      throw Exception(
        'Evidence ID is required.',
      );
    }

    try {
      List<dynamic> deletedRows =
      <dynamic>[];

      if (evidence.sourceTable ==
          reportImagesTable) {
        // --------------------------------------------------------
        // Delete per-image AI first.
        // --------------------------------------------------------

        try {
          await _supabase
              .from(
            imageAiAnalysisTable,
          )
              .delete()
              .eq(
            'report_image_id',
            evidenceId,
          );
        } catch (_) {
          // AI cleanup is best effort. The evidence row deletion
          // below is authoritative.
        }

        deletedRows =
        await _supabase
            .from(
          reportImagesTable,
        )
            .delete()
            .eq(
          'id',
          evidenceId,
        )
            .select(
          'id',
        );
      } else if (evidence.sourceTable ==
          reportEvidenceTable) {
        deletedRows =
        await _supabase
            .from(
          reportEvidenceTable,
        )
            .delete()
            .eq(
          'id',
          evidenceId,
        )
            .select(
          'id',
        );
      } else {
        throw Exception(
          'Unsupported evidence source: ${evidence.sourceTable}.',
        );
      }

      // ========================================================
      // VERIFY DATABASE DELETE
      //
      // Zero rows commonly means an RLS DELETE policy prevented
      // the citizen from deleting the row.
      // ========================================================

      final bool deleted =
      deletedRows.any(
            (
            row,
            ) {
          if (row is! Map) {
            return false;
          }

          return row['id']
              ?.toString() ==
              evidenceId;
        },
      );

      if (!deleted) {
        throw Exception(
          'The evidence was not deleted from the database. '
              'Your Supabase Row Level Security DELETE policy may '
              'not allow the current citizen to delete this evidence.',
        );
      }

      // ========================================================
      // STORAGE CLEANUP
      //
      // Database deletion is already confirmed. Storage cleanup is
      // best effort so a storage problem cannot resurrect a DB row.
      // ========================================================

      await _safeDeleteStorage(
        evidence.storagePath,
      );
    } catch (e) {
      throw Exception(
        _cleanError(
          e,
          fallback:
          'Unable to remove evidence.',
        ),
      );
    }
  }

  // ============================================================
  // SIGNED URL
  // ============================================================

  Future<String?> _signedUrl(
      String path,
      ) async {
    if (path.trim().isEmpty) {
      return null;
    }

    try {
      return await _supabase.storage
          .from(
        evidenceBucket,
      )
          .createSignedUrl(
        path,
        3600,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeDeleteStorage(
      String path,
      ) async {
    if (path.trim().isEmpty) {
      return;
    }

    try {
      await _supabase.storage
          .from(
        evidenceBucket,
      )
          .remove([
        path,
      ]);
    } catch (_) {}
  }

  // ============================================================
  // HELPERS
  // ============================================================

  DateTime? _date(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  String _extension(
      String path, {
        required String fallback,
      }) {
    final String name =
    _fileName(
      path,
    );

    final int index =
    name.lastIndexOf(
      '.',
    );

    if (index < 0 ||
        index ==
            name.length - 1) {
      return fallback;
    }

    return name
        .substring(
      index + 1,
    )
        .toLowerCase();
  }

  String _fileName(
      String path,
      ) {
    return path
        .replaceAll(
      '\\',
      '/',
    )
        .split(
      '/',
    )
        .last;
  }

  String _videoMimeType(
      String extension,
      ) {
    switch (extension.toLowerCase()) {
      case 'mov':
        return 'video/quicktime';

      case 'webm':
        return 'video/webm';

      case 'mkv':
        return 'video/x-matroska';

      case '3gp':
        return 'video/3gpp';

      case 'mp4':
      default:
        return 'video/mp4';
    }
  }

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

    return message.isEmpty
        ? fallback
        : message;
  }
}
