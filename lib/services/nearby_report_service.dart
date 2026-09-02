import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nearby_report.dart';

class NearbyReportService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // GET NEARBY REPORTS
  // ============================================================

  Future<List<NearbyReport>> getNearbyReports({
    required double latitude,
    required double longitude,
    required String category,
    double radiusMeters = 500,
  }) async {
    try {
      final dynamic rpcResponse =
      await _supabase.rpc(
        'get_nearby_report_candidates',
      );

      if (rpcResponse == null) {
        return [];
      }

      final List<dynamic> response =
      List<dynamic>.from(
        rpcResponse as List,
      );

      final List<NearbyReport> nearbyReports =
      [];

      for (final dynamic item in response) {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> map =
        Map<String, dynamic>.from(
          item,
        );

        final double? reportLatitude =
        _toDouble(
          map['latitude'],
        );

        final double? reportLongitude =
        _toDouble(
          map['longitude'],
        );

        if (reportLatitude == null ||
            reportLongitude == null) {
          continue;
        }

        // ======================================================
        // CATEGORY MATCH
        // ======================================================

        final String reportCategory =
            map['category']
                ?.toString()
                .trim() ??
                '';

        if (reportCategory.toLowerCase() !=
            category.trim().toLowerCase()) {
          continue;
        }

        // ======================================================
        // CALCULATE DISTANCE
        // ======================================================

        final double distanceMeters =
        Geolocator.distanceBetween(
          latitude,
          longitude,
          reportLatitude,
          reportLongitude,
        );

        // ======================================================
        // CHECK RADIUS
        // ======================================================

        if (distanceMeters >
            radiusMeters) {
          continue;
        }

        // ======================================================
        // STATUS
        // ======================================================

        final String status =
            map['status']
                ?.toString()
                .trim()
                .toLowerCase() ??
                'pending';

        // Extra safety even though RPC already excludes rejected.
        if (status == 'rejected') {
          continue;
        }

        // ======================================================
        // CREATE MODEL
        // ======================================================

        nearbyReports.add(
          NearbyReport(
            id:
            map['id']
                ?.toString() ??
                '',

            referenceNumber:
            map['reference_number']
                ?.toString() ??
                'Unknown',

            title:
            map['title']
                ?.toString() ??
                'Infrastructure Report',

            category:
            reportCategory,

            priority:
            map['priority']
                ?.toString() ??
                'Unknown',

            status:
            status,

            address:
            map['address']
                ?.toString() ??
                'Unknown location',

            latitude:
            reportLatitude,

            longitude:
            reportLongitude,

            distanceMeters:
            distanceMeters,
          ),
        );
      }

      // ========================================================
      // SORT NEAREST FIRST
      // ========================================================

      nearbyReports.sort(
            (
            a,
            b,
            ) =>
            a.distanceMeters.compareTo(
              b.distanceMeters,
            ),
      );

      return nearbyReports;
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to check nearby reports: ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unable to check nearby reports: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ============================================================
  // FIND POSSIBLE DUPLICATE
  // ============================================================

  Future<NearbyReport?>
  findPossibleDuplicate({
    required double latitude,
    required double longitude,
    required String category,
    double duplicateRadiusMeters = 100,
  }) async {
    final List<NearbyReport> reports =
    await getNearbyReports(
      latitude:
      latitude,

      longitude:
      longitude,

      category:
      category,

      radiusMeters:
      duplicateRadiusMeters,
    );

    if (reports.isEmpty) {
      return null;
    }

    return reports.first;
  }

  // ============================================================
  // HAS POSSIBLE DUPLICATE
  // ============================================================

  Future<bool> hasPossibleDuplicate({
    required double latitude,
    required double longitude,
    required String category,
    double duplicateRadiusMeters = 100,
  }) async {
    final NearbyReport? report =
    await findPossibleDuplicate(
      latitude:
      latitude,

      longitude:
      longitude,

      category:
      category,

      duplicateRadiusMeters:
      duplicateRadiusMeters,
    );

    return report != null;
  }

  // ============================================================
  // GET NEAREST SIMILAR REPORT
  // ============================================================

  Future<NearbyReport?>
  getNearestSimilarReport({
    required double latitude,
    required double longitude,
    required String category,
    double radiusMeters = 500,
  }) async {
    final List<NearbyReport> reports =
    await getNearbyReports(
      latitude:
      latitude,

      longitude:
      longitude,

      category:
      category,

      radiusMeters:
      radiusMeters,
    );

    if (reports.isEmpty) {
      return null;
    }

    return reports.first;
  }

  // ============================================================
  // GET VERY CLOSE REPORTS
  // ============================================================

  Future<List<NearbyReport>>
  getVeryCloseReports({
    required double latitude,
    required double longitude,
    required String category,
  }) async {
    return await getNearbyReports(
      latitude:
      latitude,

      longitude:
      longitude,

      category:
      category,

      radiusMeters:
      100,
    );
  }

  // ============================================================
  // GET REPORTS WITHIN 500M
  // ============================================================

  Future<List<NearbyReport>>
  getReportsWithin500Meters({
    required double latitude,
    required double longitude,
    required String category,
  }) async {
    return await getNearbyReports(
      latitude:
      latitude,

      longitude:
      longitude,

      category:
      category,

      radiusMeters:
      500,
    );
  }

  // ============================================================
  // CONVERT DATABASE NUMBER -> DOUBLE
  // ============================================================

  double? _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}