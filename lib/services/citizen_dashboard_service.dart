import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/infrastructure_report.dart';

class CitizenDashboardStats {
  final int totalReports;

  final int pendingReports;

  final int verifiedReports;

  final int inProgressReports;

  final int completedReports;

  final int rejectedReports;

  final int contributionPoints;

  final int impactScore;

  final int citizenRank;

  const CitizenDashboardStats({
    required this.totalReports,
    required this.pendingReports,
    required this.verifiedReports,
    required this.inProgressReports,
    required this.completedReports,
    required this.rejectedReports,
    required this.contributionPoints,
    required this.impactScore,
    required this.citizenRank,
  });

  // ============================================================
  // EMPTY
  // ============================================================

  factory CitizenDashboardStats.empty() {
    return const CitizenDashboardStats(
      totalReports: 0,
      pendingReports: 0,
      verifiedReports: 0,
      inProgressReports: 0,
      completedReports: 0,
      rejectedReports: 0,
      contributionPoints: 0,
      impactScore: 0,
      citizenRank: 0,
    );
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  factory CitizenDashboardStats.fromMap(
      Map<String, dynamic> map,
      ) {
    return CitizenDashboardStats(
      totalReports:
      _toInt(
        map['total_reports'],
      ),

      pendingReports:
      _toInt(
        map['pending_reports'],
      ),

      verifiedReports:
      _toInt(
        map['verified_reports'],
      ),

      inProgressReports:
      _toInt(
        map['in_progress_reports'],
      ),

      completedReports:
      _toInt(
        map['completed_reports'],
      ),

      rejectedReports:
      _toInt(
        map['rejected_reports'],
      ),

      contributionPoints:
      _toInt(
        map['contribution_points'],
      ),

      impactScore:
      _toInt(
        map['impact_score'],
      ),

      citizenRank:
      _toInt(
        map['citizen_rank'],
      ),
    );
  }

  static int _toInt(
      dynamic value,
      ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }
}

class CitizenDashboardData {
  final CitizenDashboardStats stats;

  final List<InfrastructureReport>
  recentReports;

  const CitizenDashboardData({
    required this.stats,
    required this.recentReports,
  });
}

class CitizenDashboardService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  User? get currentUser =>
      _supabase.auth.currentUser;

  // ============================================================
  // LOAD EVERYTHING
  // ============================================================

  Future<CitizenDashboardData>
  loadDashboard() async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    final results =
    await Future.wait<dynamic>(
      [
        getDashboardStats(),
        getRecentReports(),
      ],
    );

    return CitizenDashboardData(
      stats:
      results[0]
      as CitizenDashboardStats,

      recentReports:
      results[1]
      as List<InfrastructureReport>,
    );
  }

  // ============================================================
  // GET DASHBOARD STATS
  // ============================================================

  Future<CitizenDashboardStats>
  getDashboardStats() async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final dynamic response =
      await _supabase.rpc(
        'get_citizen_dashboard_stats',
      );

      if (response == null) {
        return CitizenDashboardStats.empty();
      }

      // PostgreSQL RETURNS TABLE normally returns a list.
      if (response is List) {
        if (response.isEmpty) {
          return CitizenDashboardStats.empty();
        }

        final first =
            response.first;

        if (first is Map) {
          return CitizenDashboardStats.fromMap(
            Map<String, dynamic>.from(
              first,
            ),
          );
        }
      }

      if (response is Map) {
        return CitizenDashboardStats.fromMap(
          Map<String, dynamic>.from(
            response,
          ),
        );
      }

      return CitizenDashboardStats.empty();
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to load dashboard statistics: '
            '${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load dashboard statistics: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ============================================================
  // RECENT REPORTS
  // ============================================================

  Future<List<InfrastructureReport>>
  getRecentReports({
    int limit = 3,
  }) async {
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
          .from('reports')
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
            (dynamic item) {
          return InfrastructureReport
              .fromMap(
            Map<String, dynamic>.from(
              item as Map,
            ),
          );
        },
      )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to load recent reports: '
            '${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load recent reports: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }
}