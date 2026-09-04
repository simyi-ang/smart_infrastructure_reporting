import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_report.dart';

class CommunityService {
  CommunityService._();
  static final CommunityService instance = CommunityService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  User get _user {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to use Community.');
    }
    return user;
  }

  Future<List<CommunityReport>> getReports({
    double? latitude,
    double? longitude,
    int radiusMetres = 5000,
    String? category,
    String? status,
    String sort = 'nearby',
    int limit = 50,
  }) async {
    _user;

    final response = await _supabase.rpc(
      'get_community_reports',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_m': radiusMetres,
        'p_category': category,
        'p_status': status,
        'p_sort': sort,
        'p_limit': limit,
      },
    );

    if (response is! List) return [];

    return response
        .whereType<Map>()
        .map((row) => CommunityReport.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<CommunityReport> getReportDetail({
    required String reportId,
    double? latitude,
    double? longitude,
  }) async {
    _user;

    final response = await _supabase.rpc(
      'get_community_report_detail',
      params: {
        'p_report_id': reportId,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );

    if (response is! List || response.isEmpty) {
      throw Exception('Community report could not be found.');
    }

    return CommunityReport.fromMap(
      Map<String, dynamic>.from(response.first as Map),
    );
  }

  Future<CommunityReport> setAffected({
    required CommunityReport report,
    required bool affected,
  }) async {
    _user;

    final response = await _supabase.rpc(
      'set_community_report_support',
      params: {
        'p_report_id': report.id,
        'p_supported': affected,
      },
    );

    if (response is! List || response.isEmpty) {
      throw Exception('Unable to update community impact.');
    }

    final row = Map<String, dynamic>.from(response.first as Map);

    return report.copyWith(
      affectedCount: int.tryParse('${row['affected_count'] ?? ''}') ??
          report.affectedCount,
      userAffected: row['user_affected'] == true,
    );
  }

  Future<CommunityReport> setFeedback({
    required CommunityReport report,
    String? feedback,
  }) async {
    _user;

    final response = await _supabase.rpc(
      'set_community_report_feedback',
      params: {
        'p_report_id': report.id,
        'p_feedback': feedback,
      },
    );

    if (response is! List || response.isEmpty) {
      throw Exception('Unable to update community feedback.');
    }

    final row = Map<String, dynamic>.from(response.first as Map);

    return report.copyWith(
      stillExistsCount:
          int.tryParse('${row['still_exists_count'] ?? ''}') ??
              report.stillExistsCount,
      looksFixedCount:
          int.tryParse('${row['looks_fixed_count'] ?? ''}') ??
              report.looksFixedCount,
      userFeedback: row['user_feedback']?.toString(),
    );
  }

  Future<List<CommunityContribution>> getContributions({
    required String reportId,
  }) async {
    final user = _user;

    final rows = await _supabase
        .from('community_report_contributions')
        .select(
          'id, report_id, contributor_id, evidence_type, storage_path, note',
        )
        .eq('report_id', reportId)
        .order('created_at', ascending: false);

    final result = <CommunityContribution>[];

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final storagePath = '${row['storage_path'] ?? ''}'.trim();

      String? signedUrl;
      if (storagePath.isNotEmpty) {
        try {
          signedUrl = await _supabase.storage
              .from('community-evidence')
              .createSignedUrl(storagePath, 3600);
        } catch (_) {}
      }

      result.add(
        CommunityContribution(
          id: '${row['id'] ?? ''}',
          reportId: '${row['report_id'] ?? ''}',
          evidenceType: '${row['evidence_type'] ?? 'image'}',
          storagePath: storagePath,
          note: row['note']?.toString(),
          signedUrl: signedUrl,
          isMine: '${row['contributor_id'] ?? ''}' == user.id,
        ),
      );
    }

    return result;
  }

  Future<CommunityContribution> addContribution({
    required String reportId,
    required File file,
    required String evidenceType,
    String? note,
  }) async {
    final user = _user;

    if (evidenceType != 'image' && evidenceType != 'video') {
      throw Exception('Unsupported evidence type.');
    }
    if (!await file.exists() || await file.length() <= 0) {
      throw Exception('Selected evidence is unavailable or empty.');
    }
    if (await file.length() > 50 * 1024 * 1024) {
      throw Exception('Community evidence must be 50 MB or smaller.');
    }

    final extension = _extension(
      file.path,
      evidenceType == 'image' ? 'jpg' : 'mp4',
    );

    final storagePath =
        '${user.id}/$reportId/community_${DateTime.now().microsecondsSinceEpoch}.$extension';

    final mimeType = evidenceType == 'image'
        ? (extension == 'png' ? 'image/png' : 'image/jpeg')
        : (extension == 'mov' ? 'video/quicktime' : 'video/mp4');

    await _supabase.storage.from('community-evidence').upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: mimeType,
          ),
        );

    try {
      final row = await _supabase
          .from('community_report_contributions')
          .insert({
            'report_id': reportId,
            'contributor_id': user.id,
            'evidence_type': evidenceType,
            'storage_path': storagePath,
            'original_file_name': _fileName(file.path),
            'mime_type': mimeType,
            'file_size_bytes': await file.length(),
            'note': _cleanNote(note),
          })
          .select()
          .single();

      final signedUrl = await _supabase.storage
          .from('community-evidence')
          .createSignedUrl(storagePath, 3600);

      return CommunityContribution(
        id: '${row['id']}',
        reportId: reportId,
        evidenceType: evidenceType,
        storagePath: storagePath,
        note: row['note']?.toString(),
        signedUrl: signedUrl,
        isMine: true,
      );
    } catch (_) {
      try {
        await _supabase.storage.from('community-evidence').remove([storagePath]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> deleteContribution(
    CommunityContribution contribution,
  ) async {
    final user = _user;

    if (!contribution.isMine) {
      throw Exception('You can remove only evidence you contributed.');
    }

    final deleted = await _supabase
        .from('community_report_contributions')
        .delete()
        .eq('id', contribution.id)
        .eq('contributor_id', user.id)
        .select('id');

    if (deleted.isEmpty) {
      throw Exception('Community evidence could not be removed.');
    }

    try {
      await _supabase.storage
          .from('community-evidence')
          .remove([contribution.storagePath]);
    } catch (_) {}
  }

  String _fileName(String path) =>
      path.replaceAll('\\', '/').split('/').last;

  String _extension(String path, String fallback) {
    final name = _fileName(path);
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return fallback;
    final ext = name.substring(dot + 1).toLowerCase();
    return ext.length <= 6 ? ext : fallback;
  }

  String? _cleanNote(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return null;
    return clean.length <= 250 ? clean : clean.substring(0, 250);
  }
}
