import 'package:supabase_flutter/supabase_flutter.dart';

class InfrastructureMapReport {
  final String id;
  final String referenceNumber;
  final String title;
  final String category;
  final String priority;
  final String status;
  final String address;

  final double latitude;
  final double longitude;

  const InfrastructureMapReport({
    required this.id,
    required this.referenceNumber,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory InfrastructureMapReport.fromMap(
      Map<String, dynamic> map,
      ) {
    return InfrastructureMapReport(
      id:
      map['id']?.toString() ?? '',

      referenceNumber:
      map['reference_number']?.toString() ??
          'Unknown',

      title:
      map['title']?.toString() ??
          'Infrastructure Report',

      category:
      map['category']?.toString() ??
          'Other',

      priority:
      map['priority']?.toString() ??
          'Unknown',

      status:
      map['status']?.toString() ??
          'pending',

      address:
      map['address']?.toString() ??
          'Unknown location',

      latitude:
      _toDouble(
        map['latitude'],
      ) ??
          0,

      longitude:
      _toDouble(
        map['longitude'],
      ) ??
          0,
    );
  }

  static double? _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}

class InfrastructureMapService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // LOAD MAP REPORTS
  // ============================================================

  Future<List<InfrastructureMapReport>>
  getMapReports() async {
    try {
      final dynamic response =
      await _supabase.rpc(
        'get_nearby_report_candidates',
      );

      if (response == null) {
        return [];
      }

      final List<dynamic> rows =
      List<dynamic>.from(
        response as List,
      );

      final List<InfrastructureMapReport>
      reports = [];

      for (final dynamic row in rows) {
        if (row is! Map) {
          continue;
        }

        final Map<String, dynamic> map =
        Map<String, dynamic>.from(
          row,
        );

        if (map['latitude'] == null ||
            map['longitude'] == null) {
          continue;
        }

        final report =
        InfrastructureMapReport.fromMap(
          map,
        );

        if (report.latitude == 0 &&
            report.longitude == 0) {
          continue;
        }

        reports.add(
          report,
        );
      }

      return reports;
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to load infrastructure map: '
            '${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load infrastructure map: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }
}