import 'dart:math'
as math;

import 'package:geolocator/geolocator.dart';

import 'infrastructure_map_service.dart';

// ============================================================================
// TIME WINDOW
// ============================================================================

enum SmartMapTimeWindow {
  hours24,
  hours72,
  days7,
  days30,
  all,
}

extension SmartMapTimeWindowExtension
on SmartMapTimeWindow {
  String get label {
    switch (this) {
      case SmartMapTimeWindow.hours24:
        return '24H';

      case SmartMapTimeWindow.hours72:
        return '72H';

      case SmartMapTimeWindow.days7:
        return '7D';

      case SmartMapTimeWindow.days30:
        return '30D';

      case SmartMapTimeWindow.all:
        return 'ALL';
    }
  }

  Duration? get duration {
    switch (this) {
      case SmartMapTimeWindow.hours24:
        return const Duration(
          hours:
          24,
        );

      case SmartMapTimeWindow.hours72:
        return const Duration(
          hours:
          72,
        );

      case SmartMapTimeWindow.days7:
        return const Duration(
          days:
          7,
        );

      case SmartMapTimeWindow.days30:
        return const Duration(
          days:
          30,
        );

      case SmartMapTimeWindow.all:
        return null;
    }
  }
}

// ============================================================================
// SPATIAL INTELLIGENCE ENGINE
// ============================================================================

class SpatialIntelligenceService {
  const SpatialIntelligenceService();

  // ==========================================================================
  // TEMPORAL FILTER
  // ==========================================================================

  List<InfrastructureMapReport>
  filterByTime({
    required List<InfrastructureMapReport>
    reports,

    required SmartMapTimeWindow
    window,

    DateTime? now,
  }) {
    final Duration? duration =
        window.duration;

    if (duration ==
        null) {
      return List<
          InfrastructureMapReport>.of(
        reports,
      );
    }

    final DateTime current =
        now ??
            DateTime.now();

    final DateTime cutoff =
    current.subtract(
      duration,
    );

    return reports.where(
          (
          InfrastructureMapReport report,
          ) {
        return !report.createdAt
            .isBefore(
          cutoff,
        );
      },
    ).toList();
  }

  // ==========================================================================
  // HOTSPOT DETECTION
  // ==========================================================================

  List<SpatialHotspot>
  detectHotspots({
    required List<InfrastructureMapReport>
    allReports,

    required SmartMapTimeWindow
    window,

    double radiusMetres =
    350,

    int minimumReports =
    3,

    DateTime? now,
  }) {
    final DateTime current =
        now ??
            DateTime.now();

    final List<InfrastructureMapReport>
    currentReports =
    filterByTime(
      reports:
      allReports,

      window:
      window,

      now:
      current,
    );

    if (currentReports.length <
        minimumReports) {
      return const <
          SpatialHotspot>[];
    }

    final List<
        List<
            InfrastructureMapReport>>
    clusters =
    _connectedClusters(
      reports:
      currentReports,

      radiusMetres:
      radiusMetres,

      minimumReports:
      minimumReports,
    );

    final List<SpatialHotspot>
    results =
    <SpatialHotspot>[];

    for (final List<
        InfrastructureMapReport>
    cluster in clusters) {
      results.add(
        _buildHotspot(
          cluster:
          cluster,

          allReports:
          allReports,

          radiusMetres:
          radiusMetres,

          window:
          window,

          now:
          current,
        ),
      );
    }

    results.sort(
          (
          SpatialHotspot first,
          SpatialHotspot second,
          ) {
        return second.riskScore
            .compareTo(
          first.riskScore,
        );
      },
    );

    return results;
  }

  // ==========================================================================
  // CONNECTED SPATIAL CLUSTERS
  // ==========================================================================

  List<List<InfrastructureMapReport>>
  _connectedClusters({
    required List<InfrastructureMapReport>
    reports,

    required double
    radiusMetres,

    required int
    minimumReports,
  }) {
    final List<InfrastructureMapReport>
    remaining =
    List<
        InfrastructureMapReport>.of(
      reports,
    );

    final List<
        List<
            InfrastructureMapReport>>
    clusters =
    <List<
        InfrastructureMapReport>>[];

    while (remaining.isNotEmpty) {
      final InfrastructureMapReport
      seed =
      remaining.removeAt(
        0,
      );

      final List<InfrastructureMapReport>
      cluster =
      <InfrastructureMapReport>[
        seed,
      ];

      bool expanded =
      true;

      while (expanded) {
        expanded =
        false;

        final List<
            InfrastructureMapReport>
        matches =
        <
            InfrastructureMapReport>[];

        for (final InfrastructureMapReport
        candidate
        in remaining) {
          final bool connected =
          cluster.any(
                (
                InfrastructureMapReport
                existing,
                ) {
              final double distance =
              Geolocator
                  .distanceBetween(
                existing.latitude,
                existing.longitude,
                candidate.latitude,
                candidate.longitude,
              );

              return distance <=
                  radiusMetres;
            },
          );

          if (connected) {
            matches.add(
              candidate,
            );
          }
        }

        if (matches.isNotEmpty) {
          cluster.addAll(
            matches,
          );

          remaining.removeWhere(
            matches.contains,
          );

          expanded =
          true;
        }
      }

      if (cluster.length >=
          minimumReports) {
        clusters.add(
          cluster,
        );
      }
    }

    return clusters;
  }

  // ==========================================================================
  // BUILD COMPLETE HOTSPOT INTELLIGENCE
  // ==========================================================================

  SpatialHotspot _buildHotspot({
    required List<InfrastructureMapReport>
    cluster,

    required List<InfrastructureMapReport>
    allReports,

    required double
    radiusMetres,

    required SmartMapTimeWindow
    window,

    required DateTime
    now,
  }) {
    final double latitude =
        cluster
            .map(
              (
              InfrastructureMapReport
              report,
              ) =>
          report
              .latitude,
        )
            .reduce(
              (
              double a,
              double b,
              ) =>
          a +
              b,
        ) /
            cluster.length;

    final double longitude =
        cluster
            .map(
              (
              InfrastructureMapReport
              report,
              ) =>
          report
              .longitude,
        )
            .reduce(
              (
              double a,
              double b,
              ) =>
          a +
              b,
        ) /
            cluster.length;

    int active =
    0;

    int resolved =
    0;

    int priorityTotal =
    0;

    int affected =
    0;

    int stillExists =
    0;

    int looksFixed =
    0;

    int contributions =
    0;

    final Map<String, int>
    composition =
    <String, int>{};

    for (final InfrastructureMapReport report
    in cluster) {
      composition.update(
        report.category,
            (
            int value,
            ) =>
        value +
            1,
        ifAbsent:
            () =>
        1,
      );

      if (isResolved(
        report.status,
      )) {
        resolved++;
      } else {
        active++;
      }

      priorityTotal +=
          priorityWeight(
            report.priority,
          );

      affected +=
          report.affectedCount;

      stillExists +=
          report.stillExistsCount;

      looksFixed +=
          report.looksFixedCount;

      contributions +=
          report.contributionCount;
    }

    final MapEntry<String, int>
    dominant =
    composition.entries.reduce(
          (
          MapEntry<String, int> first,
          MapEntry<String, int> second,
          ) {
        return first.value >=
            second.value
            ? first
            : second;
      },
    );

    // ========================================================================
    // TREND ANALYSIS
    // ========================================================================

    final _TrendResult trend =
    _calculateTrend(
      latitude:
      latitude,

      longitude:
      longitude,

      allReports:
      allReports,

      window:
      window,

      radiusMetres:
      radiusMetres,

      now:
      now,
    );

    // ========================================================================
    // RECURRENCE
    // ========================================================================

    final _RecurrenceResult recurrence =
    _calculateRecurrence(
      latitude:
      latitude,

      longitude:
      longitude,

      allReports:
      allReports,

      category:
      dominant.key,

      radiusMetres:
      math.min(
        radiusMetres,
        200,
      ),

      now:
      now,
    );

    // ========================================================================
    // EXPLAINABLE COMPONENTS
    // ========================================================================

    final double densityScore =
    (cluster.length /
        8)
        .clamp(
      0.0,
      1.0,
    );

    final double activeScore =
        active /
            cluster.length;

    final double priorityScore =
        priorityTotal /
            (cluster.length *
                4);

    final double recurrenceScore =
    (recurrence.count /
        5)
        .clamp(
      0.0,
      1.0,
    );

    final double communityScore =
    ((affected *
        0.60 +
        stillExists *
            1.20 +
        contributions *
            0.40 -
        looksFixed *
            0.50) /
        25)
        .clamp(
      0.0,
      1.0,
    );

    // ========================================================================
    // FINAL RISK
    //
    // Spatial Density       25
    // Recent Growth         20
    // Priority Pressure     15
    // Unresolved Pressure   15
    // Recurrence            10
    // Community Impact      15
    //
    // TOTAL                100
    // ========================================================================

    final int risk =
    (densityScore *
        25 +
        trend.score *
            20 +
        priorityScore *
            15 +
        activeScore *
            15 +
        recurrenceScore *
            10 +
        communityScore *
            15)
        .clamp(
      0,
      100,
    )
        .round();

    final List<HotspotReason>
    reasons =
    <HotspotReason>[
      HotspotReason(
        title:
        'Spatial Density',

        points:
        (densityScore *
            25)
            .round(),

        maximum:
        25,

        explanation:
        '${cluster.length} reports are spatially connected within approximately ${radiusMetres.round()} m.',
      ),

      HotspotReason(
        title:
        'Recent Growth',

        points:
        (trend.score *
            20)
            .round(),

        maximum:
        20,

        explanation:
        trend.explanation,
      ),

      HotspotReason(
        title:
        'Priority Pressure',

        points:
        (priorityScore *
            15)
            .round(),

        maximum:
        15,

        explanation:
        'Average priority weight is ${(priorityTotal / cluster.length).toStringAsFixed(1)} of 4.',
      ),

      HotspotReason(
        title:
        'Unresolved Pressure',

        points:
        (activeScore *
            15)
            .round(),

        maximum:
        15,

        explanation:
        '$active of ${cluster.length} reports remain active.',
      ),

      HotspotReason(
        title:
        'Recurrence',

        points:
        (recurrenceScore *
            10)
            .round(),

        maximum:
        10,

        explanation:
        recurrence.explanation,
      ),

      HotspotReason(
        title:
        'Community Impact',

        points:
        (communityScore *
            15)
            .round(),

        maximum:
        15,

        explanation:
        '$affected affected · '
            '$stillExists still exists · '
            '$looksFixed looks fixed · '
            '$contributions community evidence item(s).',
      ),
    ];

    return SpatialHotspot(
      id:
      '${latitude.toStringAsFixed(5)}_'
          '${longitude.toStringAsFixed(5)}',

      latitude:
      latitude,

      longitude:
      longitude,

      radiusMetres:
      radiusMetres,

      reports:
      List<
          InfrastructureMapReport>.unmodifiable(
        cluster,
      ),

      reportCount:
      cluster.length,

      activeCount:
      active,

      resolvedCount:
      resolved,

      dominantCategory:
      dominant.key,

      dominantCategoryCount:
      dominant.value,

      categoryComposition:
      Map<String, int>.unmodifiable(
        composition,
      ),

      affectedCount:
      affected,

      stillExistsCount:
      stillExists,

      looksFixedCount:
      looksFixed,

      contributionCount:
      contributions,

      riskScore:
      risk,

      currentPeriodCount:
      trend.currentCount,

      previousPeriodCount:
      trend.previousCount,

      growthPercent:
      trend.growthPercent,

      trendLabel:
      trend.label,

      recurrenceCount:
      recurrence.count,

      reasons:
      List<
          HotspotReason>.unmodifiable(
        reasons,
      ),
    );
  }

  // ==========================================================================
  // TREND
  // ==========================================================================

  _TrendResult _calculateTrend({
    required double latitude,

    required double longitude,

    required List<InfrastructureMapReport>
    allReports,

    required SmartMapTimeWindow
    window,

    required double
    radiusMetres,

    required DateTime
    now,
  }) {
    final Duration duration =
        window.duration ??
            const Duration(
              days:
              30,
            );

    final DateTime currentStart =
    now.subtract(
      duration,
    );

    final DateTime previousStart =
    currentStart.subtract(
      duration,
    );

    int currentCount =
    0;

    int previousCount =
    0;

    for (final InfrastructureMapReport report
    in allReports) {
      final double distance =
      Geolocator.distanceBetween(
        latitude,
        longitude,
        report.latitude,
        report.longitude,
      );

      if (distance >
          radiusMetres) {
        continue;
      }

      if (!report.createdAt.isBefore(
        currentStart,
      ) &&
          !report.createdAt.isAfter(
            now,
          )) {
        currentCount++;
      } else if (!report.createdAt.isBefore(
        previousStart,
      ) &&
          report.createdAt.isBefore(
            currentStart,
          )) {
        previousCount++;
      }
    }

    double growth =
    0;

    if (previousCount ==
        0) {
      growth =
      currentCount >
          0
          ? 100
          : 0;
    } else {
      growth =
          ((currentCount -
              previousCount) /
              previousCount) *
              100;
    }

    String label;

    double score;

    if (currentCount >=
        previousCount +
            3 &&
        growth >=
            100) {
      label =
      'Rapidly Increasing';

      score =
      1;
    } else if (currentCount >
        previousCount &&
        growth >=
            30) {
      label =
      'Increasing';

      score =
      0.75;
    } else if (currentCount <
        previousCount &&
        growth <=
            -30) {
      label =
      'Declining';

      score =
      0.15;
    } else {
      label =
      'Stable';

      score =
      0.35;
    }

    return _TrendResult(
      currentCount:
      currentCount,

      previousCount:
      previousCount,

      growthPercent:
      growth,

      label:
      label,

      score:
      score,

      explanation:
      '$currentCount report(s) in the current period compared with '
          '$previousCount in the previous equal period '
          '(${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(0)}%).',
    );
  }

  // ==========================================================================
  // RECURRENCE
  // ==========================================================================

  _RecurrenceResult
  _calculateRecurrence({
    required double latitude,

    required double longitude,

    required List<InfrastructureMapReport>
    allReports,

    required String category,

    required double
    radiusMetres,

    required DateTime now,
  }) {
    final DateTime cutoff =
    now.subtract(
      const Duration(
        days:
        180,
      ),
    );

    int count =
    0;

    int resolved =
    0;

    for (final InfrastructureMapReport report
    in allReports) {
      if (report.category !=
          category) {
        continue;
      }

      if (report.createdAt.isBefore(
        cutoff,
      )) {
        continue;
      }

      final double distance =
      Geolocator.distanceBetween(
        latitude,
        longitude,
        report.latitude,
        report.longitude,
      );

      if (distance <=
          radiusMetres) {
        count++;

        if (isResolved(
          report.status,
        )) {
          resolved++;
        }
      }
    }

    return _RecurrenceResult(
      count:
      count,

      explanation:
      count <
          2
          ? 'No strong recurring pattern is currently visible.'
          : '$count similar $category reports occurred within '
          '${radiusMetres.round()} m during the last 180 days. '
          '$resolved are currently recorded as resolved/completed.',
    );
  }

  // ==========================================================================
  // HEALTH
  // ==========================================================================

  SpatialHealthSummary
  calculateHealth(
      List<InfrastructureMapReport>
      reports,
      ) {
    if (reports.isEmpty) {
      return const SpatialHealthSummary(
        score:
        100,

        level:
        'Healthy',

        activeReports:
        0,

        resolvedReports:
        0,

        criticalHighReports:
        0,

        communityPressure:
        0,

        averageProgress:
        100,
      );
    }

    int active =
    0;

    int resolved =
    0;

    int severe =
    0;

    int community =
    0;

    int progressTotal =
    0;

    for (final InfrastructureMapReport report
    in reports) {
      if (isResolved(
        report.status,
      )) {
        resolved++;
      } else {
        active++;
      }

      final String priority =
      report.priority
          .trim()
          .toLowerCase();

      if (priority ==
          'high' ||
          priority ==
              'critical') {
        severe++;
      }

      community +=
          report
              .stillExistsCount +
              (report.affectedCount ~/
                  2);

      progressTotal +=
          report
              .progressPercentage
              .clamp(
            0,
            100,
          );
    }

    final double activeRatio =
        active /
            reports.length;

    final double severeRatio =
        severe /
            reports.length;

    final double communityRatio =
    (community /
        30)
        .clamp(
      0.0,
      1.0,
    );

    final double averageProgress =
        progressTotal /
            reports.length;

    final int score =
    (100 -
        activeRatio *
            45 -
        severeRatio *
            20 -
        communityRatio *
            20 -
        ((100 -
            averageProgress) /
            100) *
            15)
        .clamp(
      0,
      100,
    )
        .round();

    return SpatialHealthSummary(
      score:
      score,

      level:
      healthLevel(
        score,
      ),

      activeReports:
      active,

      resolvedReports:
      resolved,

      criticalHighReports:
      severe,

      communityPressure:
      community,

      averageProgress:
      averageProgress,
    );
  }

  // ==========================================================================
  // NEARBY
  // ==========================================================================

  List<NearbyInfrastructureReport>
  nearbyReports({
    required List<InfrastructureMapReport>
    reports,

    required double latitude,

    required double longitude,

    required double
    radiusMetres,
  }) {
    final List<
        NearbyInfrastructureReport>
    results =
    <
        NearbyInfrastructureReport>[];

    for (final InfrastructureMapReport report
    in reports) {
      final double distance =
      Geolocator.distanceBetween(
        latitude,
        longitude,
        report.latitude,
        report.longitude,
      );

      if (distance <=
          radiusMetres) {
        results.add(
          NearbyInfrastructureReport(
            report:
            report,

            distanceMetres:
            distance,
          ),
        );
      }
    }

    results.sort(
          (
          NearbyInfrastructureReport a,
          NearbyInfrastructureReport b,
          ) {
        return a.distanceMetres
            .compareTo(
          b.distanceMetres,
        );
      },
    );

    return results;
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  bool isResolved(
      String status,
      ) {
    final String value =
    status
        .trim()
        .toLowerCase()
        .replaceAll(
      ' ',
      '_',
    );

    return value ==
        'completed' ||
        value ==
            'resolved' ||
        value ==
            'rejected';
  }

  int priorityWeight(
      String priority,
      ) {
    switch (priority
        .trim()
        .toLowerCase()) {
      case 'critical':
        return 4;

      case 'high':
        return 3;

      case 'medium':
        return 2;

      case 'low':
        return 1;

      default:
        return 2;
    }
  }

  String healthLevel(
      int score,
      ) {
    if (score >=
        90) {
      return 'Healthy';
    }

    if (score >=
        70) {
      return 'Minor Issues';
    }

    if (score >=
        50) {
      return 'Needs Attention';
    }

    if (score >=
        30) {
      return 'Poor Infrastructure';
    }

    return 'Critical Zone';
  }
}

// ============================================================================
// HOTSPOT
// ============================================================================

class SpatialHotspot {
  final String id;

  final double latitude;

  final double longitude;

  final double radiusMetres;

  final List<InfrastructureMapReport>
  reports;

  final int reportCount;

  final int activeCount;

  final int resolvedCount;

  final String dominantCategory;

  final int dominantCategoryCount;

  final Map<String, int>
  categoryComposition;

  final int affectedCount;

  final int stillExistsCount;

  final int looksFixedCount;

  final int contributionCount;

  final int riskScore;

  final int currentPeriodCount;

  final int previousPeriodCount;

  final double growthPercent;

  final String trendLabel;

  final int recurrenceCount;

  final List<HotspotReason>
  reasons;

  const SpatialHotspot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMetres,
    required this.reports,
    required this.reportCount,
    required this.activeCount,
    required this.resolvedCount,
    required this.dominantCategory,
    required this.dominantCategoryCount,
    required this.categoryComposition,
    required this.affectedCount,
    required this.stillExistsCount,
    required this.looksFixedCount,
    required this.contributionCount,
    required this.riskScore,
    required this.currentPeriodCount,
    required this.previousPeriodCount,
    required this.growthPercent,
    required this.trendLabel,
    required this.recurrenceCount,
    required this.reasons,
  });

  String get riskLevel {
    if (riskScore >=
        80) {
      return 'Critical';
    }

    if (riskScore >=
        60) {
      return 'Elevated';
    }

    if (riskScore >=
        40) {
      return 'Emerging';
    }

    return 'Watch';
  }

  bool get isEmerging {
    return trendLabel ==
        'Increasing' ||
        trendLabel ==
            'Rapidly Increasing';
  }

  bool get communityVerificationNeeded {
    if (reports.isEmpty) {
      return false;
    }

    final double progress =
        reports
            .map(
              (
              InfrastructureMapReport
              report,
              ) =>
          report
              .progressPercentage,
        )
            .reduce(
              (
              int a,
              int b,
              ) =>
          a +
              b,
        ) /
            reports.length;

    return progress >=
        75 &&
        stillExistsCount >=
            3 &&
        stillExistsCount >
            looksFixedCount *
                2;
  }
}

// ============================================================================
// EXPLANATION
// ============================================================================

class HotspotReason {
  final String title;

  final int points;

  final int maximum;

  final String explanation;

  const HotspotReason({
    required this.title,
    required this.points,
    required this.maximum,
    required this.explanation,
  });
}

// ============================================================================
// HEALTH
// ============================================================================

class SpatialHealthSummary {
  final int score;

  final String level;

  final int activeReports;

  final int resolvedReports;

  final int criticalHighReports;

  final int communityPressure;

  final double averageProgress;

  const SpatialHealthSummary({
    required this.score,
    required this.level,
    required this.activeReports,
    required this.resolvedReports,
    required this.criticalHighReports,
    required this.communityPressure,
    required this.averageProgress,
  });
}

// ============================================================================
// NEARBY
// ============================================================================

class NearbyInfrastructureReport {
  final InfrastructureMapReport report;

  final double distanceMetres;

  const NearbyInfrastructureReport({
    required this.report,
    required this.distanceMetres,
  });

  String get distanceLabel {
    if (distanceMetres <
        1000) {
      return '${distanceMetres.round()} m';
    }

    return '${(distanceMetres / 1000).toStringAsFixed(1)} km';
  }
}

// ============================================================================
// INTERNAL TREND RESULT
// ============================================================================

class _TrendResult {
  final int currentCount;

  final int previousCount;

  final double growthPercent;

  final String label;

  final double score;

  final String explanation;

  const _TrendResult({
    required this.currentCount,
    required this.previousCount,
    required this.growthPercent,
    required this.label,
    required this.score,
    required this.explanation,
  });
}

// ============================================================================
// INTERNAL RECURRENCE RESULT
// ============================================================================

class _RecurrenceResult {
  final int count;

  final String explanation;

  const _RecurrenceResult({
    required this.count,
    required this.explanation,
  });
}