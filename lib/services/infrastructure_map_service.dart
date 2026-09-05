import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_report.dart';
import 'community_service.dart';

class InfrastructureMapReport {
  final String id;

  final String referenceNumber;

  final String title;

  final String description;

  final String category;

  final String priority;

  final String status;

  final String address;

  final double latitude;

  final double longitude;

  final int progressPercentage;

  final DateTime createdAt;

  final DateTime updatedAt;

  // ============================================================
  // COMMUNITY INTELLIGENCE
  // ============================================================

  final int affectedCount;

  final int stillExistsCount;

  final int looksFixedCount;

  final int contributionCount;

  final double communityImpactScore;

  const InfrastructureMapReport({
    required this.id,
    required this.referenceNumber,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.progressPercentage,
    required this.createdAt,
    required this.updatedAt,
    this.affectedCount = 0,
    this.stillExistsCount = 0,
    this.looksFixedCount = 0,
    this.contributionCount = 0,
    this.communityImpactScore = 0,
  });

  // ============================================================
  // COPY WITH COMMUNITY DATA
  // ============================================================

  InfrastructureMapReport copyWithCommunity({
    int? affectedCount,
    int? stillExistsCount,
    int? looksFixedCount,
    int? contributionCount,
    double? communityImpactScore,
  }) {
    return InfrastructureMapReport(
      id:
      id,

      referenceNumber:
      referenceNumber,

      title:
      title,

      description:
      description,

      category:
      category,

      priority:
      priority,

      status:
      status,

      address:
      address,

      latitude:
      latitude,

      longitude:
      longitude,

      progressPercentage:
      progressPercentage,

      createdAt:
      createdAt,

      updatedAt:
      updatedAt,

      affectedCount:
      affectedCount ??
          this.affectedCount,

      stillExistsCount:
      stillExistsCount ??
          this.stillExistsCount,

      looksFixedCount:
      looksFixedCount ??
          this.looksFixedCount,

      contributionCount:
      contributionCount ??
          this.contributionCount,

      communityImpactScore:
      communityImpactScore ??
          this.communityImpactScore,
    );
  }

  // ============================================================
  // DATABASE MAP
  // ============================================================

  factory InfrastructureMapReport.fromMap(
      Map<String, dynamic> map,
      ) {
    double parseDouble(
        dynamic value,
        ) {
      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(
        value?.toString() ??
            '',
      ) ??
          0;
    }

    int parseInt(
        dynamic value,
        ) {
      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.round();
      }

      return int.tryParse(
        value?.toString() ??
            '',
      ) ??
          0;
    }

    DateTime parseDate(
        dynamic value,
        ) {
      return DateTime.tryParse(
        value?.toString() ??
            '',
      ) ??
          DateTime.fromMillisecondsSinceEpoch(
            0,
          );
    }

    return InfrastructureMapReport(
      id:
      map['id']
          ?.toString() ??
          '',

      referenceNumber:
      map['reference_number']
          ?.toString() ??
          '',

      title:
      map['title']
          ?.toString() ??
          '',

      description:
      map['description']
          ?.toString() ??
          '',

      category:
      map['category']
          ?.toString() ??
          'Other',

      priority:
      map['priority']
          ?.toString() ??
          'Medium',

      status:
      map['status']
          ?.toString() ??
          'pending',

      address:
      map['address']
          ?.toString() ??
          '',

      latitude:
      parseDouble(
        map['latitude'],
      ),

      longitude:
      parseDouble(
        map['longitude'],
      ),

      progressPercentage:
      parseInt(
        map['progress_percentage'],
      ),

      createdAt:
      parseDate(
        map['created_at'],
      ),

      updatedAt:
      parseDate(
        map['updated_at'],
      ),
    );
  }
}

// ============================================================================
// MAP SERVICE
// ============================================================================

class InfrastructureMapService {
  final SupabaseClient supabase =
      Supabase.instance.client;

  final CommunityService communityService =
      CommunityService.instance;

  // ============================================================
  // LOAD OFFICIAL + COMMUNITY INFORMATION
  // ============================================================

  Future<List<InfrastructureMapReport>>
  getMapReports() async {
    // ----------------------------------------------------------
    // OFFICIAL REPORT DATA
    // ----------------------------------------------------------

    final List<dynamic> response =
    await supabase
        .from(
      'reports',
    )
        .select(
      '''
              id,
              reference_number,
              title,
              description,
              category,
              priority,
              status,
              address,
              latitude,
              longitude,
              progress_percentage,
              created_at,
              updated_at
              ''',
    )
        .not(
      'latitude',
      'is',
      null,
    )
        .not(
      'longitude',
      'is',
      null,
    )
        .order(
      'created_at',
      ascending:
      false,
    );

    final List<InfrastructureMapReport>
    officialReports =
    response.map(
          (
          dynamic row,
          ) {
        return InfrastructureMapReport.fromMap(
          Map<String, dynamic>.from(
            row as Map,
          ),
        );
      },
    ).where(
          (
          InfrastructureMapReport report,
          ) {
        if (report.id.isEmpty) {
          return false;
        }

        if (report.latitude <
            -90 ||
            report.latitude >
                90) {
          return false;
        }

        if (report.longitude <
            -180 ||
            report.longitude >
                180) {
          return false;
        }

        if (report.latitude ==
            0 &&
            report.longitude ==
                0) {
          return false;
        }

        return true;
      },
    ).toList();

    // ----------------------------------------------------------
    // COMMUNITY ENRICHMENT
    //
    // Community failures must not break the official map.
    // ----------------------------------------------------------

    try {
      final List<CommunityReport>
      communityReports =
      await communityService
          .getReports(
        latitude:
        null,

        longitude:
        null,

        radiusMetres:
        500000,

        category:
        null,

        status:
        null,

        sort:
        'recent',

        limit:
        500,
      );

      final Map<String, CommunityReport>
      communityLookup =
      <String, CommunityReport>{
        for (final CommunityReport item
        in communityReports)
          item.id:
          item,
      };

      return officialReports.map(
            (
            InfrastructureMapReport report,
            ) {
          final CommunityReport? community =
          communityLookup[
          report.id];

          if (community ==
              null) {
            return report;
          }

          return report.copyWithCommunity(
            affectedCount:
            community
                .affectedCount,

            stillExistsCount:
            community
                .stillExistsCount,

            looksFixedCount:
            community
                .looksFixedCount,

            contributionCount:
            community
                .contributionCount,

            communityImpactScore:
            community
                .impactScore,
          );
        },
      ).toList();
    } catch (_) {
      // Community is an enhancement.
      // Do not disable the map if its RPC is temporarily unavailable.

      return officialReports;
    }
  }
}