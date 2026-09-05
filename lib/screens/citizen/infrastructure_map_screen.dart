import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide MapType;

import '../../services/infrastructure_map_service.dart';
import '../../services/location_service.dart';
import '../../services/spatial_intelligence_service.dart';
import '../../theme/app_colors.dart';
import '../reports/report_detail_screen.dart';

class InfrastructureMapScreen extends StatefulWidget {
  const InfrastructureMapScreen({
    super.key,
  });

  @override
  State<InfrastructureMapScreen> createState() =>
      _InfrastructureMapScreenState();
}

class _InfrastructureMapScreenState
    extends State<InfrastructureMapScreen>
    with WidgetsBindingObserver {
  // ==========================================================================
  // SERVICES
  // ==========================================================================

  final InfrastructureMapService mapService =
  InfrastructureMapService();

  final SpatialIntelligenceService spatialService =
  const SpatialIntelligenceService();

  final LocationService locationService =
  LocationService();

  final SupabaseClient supabase =
      Supabase.instance.client;

  // ==========================================================================
  // CONTROLLERS
  // ==========================================================================

  final TextEditingController searchController =
  TextEditingController();

  GoogleMapController? mapController;

  // ==========================================================================
  // REALTIME
  // ==========================================================================

  RealtimeChannel? realtimeChannel;

  Timer? fallbackTimer;

  Timer? realtimeDebounce;

  bool realtimeConnected = false;

  // ==========================================================================
  // DATA
  // ==========================================================================

  List<InfrastructureMapReport> reports =
  <InfrastructureMapReport>[];

  InfrastructureMapReport? selectedReport;

  SpatialHotspot? selectedHotspot;

  // ==========================================================================
  // SCREEN STATE
  // ==========================================================================

  bool loading = true;

  bool refreshing = false;

  bool locating = false;

  bool showReports = true;

  bool showHotspots = true;

  bool showHealthZones = true;

  bool showNearbyRadius = false;

  bool showCommunitySignals = true;

  bool mapControlsExpanded = false;

  bool mapOverviewExpanded = false;

  bool smartDeclutter = true;

  MapType selectedMapType =
      MapType.normal;

  String selectedCategory =
      'All';

  SmartMapTimeWindow selectedWindow =
      SmartMapTimeWindow.days7;

  double nearbyRadiusMetres =
  1000;

  double currentZoom =
  11;

  double? userLatitude;

  double? userLongitude;

  DateTime? lastSyncedAt;

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  static const LatLng malaysiaDefault =
  LatLng(
    3.1390,
    101.6869,
  );

  static const List<String> categories =
  <String>[
    'All',
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    _initialise();
  }

  Future<void> _initialise() async {
    await loadMap();

    _subscribeRealtime();

    // Realtime is primary.
    // This timer is only a fallback if the realtime connection is interrupted.
    fallbackTimer = Timer.periodic(
      const Duration(
        seconds: 30,
      ),
          (
          Timer timer,
          ) {
        if (!mounted ||
            loading ||
            refreshing) {
          return;
        }

        loadMap(
          silent: true,
        );
      },
    );
  }

  @override
  void dispose() {
    fallbackTimer?.cancel();

    realtimeDebounce?.cancel();

    WidgetsBinding.instance.removeObserver(
      this,
    );

    if (realtimeChannel != null) {
      unawaited(
        supabase.removeChannel(
          realtimeChannel!,
        ),
      );
    }

    searchController.dispose();

    mapController?.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state ==
        AppLifecycleState.resumed) {
      loadMap(
        silent: true,
      );
    }
  }

  // ==========================================================================
  // SUPABASE REALTIME
  // ==========================================================================

  void _subscribeRealtime() {
    realtimeChannel = supabase
        .channel(
      'smart-infrastructure-map-'
          '${supabase.auth.currentUser?.id ?? 'public'}',
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'reports',
      callback: (_) {
        _onRealtimeChange();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'community_report_supports',
      callback: (_) {
        _onRealtimeChange();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'community_report_feedback',
      callback: (_) {
        _onRealtimeChange();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'community_report_contributions',
      callback: (_) {
        _onRealtimeChange();
      },
    )
        .subscribe(
          (
          RealtimeSubscribeStatus status,
          Object? error,
          ) {
        if (!mounted) {
          return;
        }

        setState(() {
          realtimeConnected =
              status ==
                  RealtimeSubscribeStatus.subscribed;
        });
      },
    );
  }

  void _onRealtimeChange() {
    // Several database rows can change almost simultaneously.
    // Debounce prevents unnecessary repeated full reloads.
    realtimeDebounce?.cancel();

    realtimeDebounce = Timer(
      const Duration(
        milliseconds: 350,
      ),
          () {
        if (!mounted) {
          return;
        }

        loadMap(
          silent: true,
        );
      },
    );
  }

  // ==========================================================================
  // LOAD MAP
  // ==========================================================================

  Future<void> loadMap({
    bool silent = false,
  }) async {
    if (!mounted ||
        refreshing) {
      return;
    }

    if (mounted) {
      setState(() {
        if (silent) {
          refreshing = true;
        } else {
          loading = true;
        }
      });
    }

    try {
      final List<InfrastructureMapReport> loaded =
      await mapService.getMapReports();

      if (!mounted) {
        return;
      }

      final String? selectedReportId =
          selectedReport?.id;

      final String? selectedHotspotId =
          selectedHotspot?.id;

      setState(() {
        reports = loaded;

        loading = false;

        refreshing = false;

        lastSyncedAt =
            DateTime.now();

        if (selectedReportId != null) {
          InfrastructureMapReport? latest;

          for (final InfrastructureMapReport report
          in loaded) {
            if (report.id ==
                selectedReportId) {
              latest = report;

              break;
            }
          }

          selectedReport = latest;
        }

        // Hotspots are recalculated from the latest database state.
        if (selectedHotspotId != null) {
          SpatialHotspot? latestHotspot;

          for (final SpatialHotspot hotspot
          in hotspots) {
            if (hotspot.id ==
                selectedHotspotId) {
              latestHotspot = hotspot;

              break;
            }
          }

          selectedHotspot =
              latestHotspot;
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;

        refreshing = false;
      });

      if (!silent) {
        _message(
          _cleanError(
            e,
          ),
        );
      }
    }
  }

  String _cleanError(
      Object error,
      ) {
    return error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    )
        .trim();
  }

  // ==========================================================================
  // CATEGORY FILTER
  // ==========================================================================

  List<InfrastructureMapReport>
  get categoryReports {
    if (selectedCategory ==
        'All') {
      return reports;
    }

    return reports.where(
          (
          InfrastructureMapReport report,
          ) {
        return report.category ==
            selectedCategory;
      },
    ).toList();
  }

  // ==========================================================================
  // TIME FILTER
  // ==========================================================================

  List<InfrastructureMapReport>
  get timeReports {
    return spatialService.filterByTime(
      reports: categoryReports,
      window: selectedWindow,
    );
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  List<InfrastructureMapReport>
  get visibleReports {
    final String query =
    searchController.text
        .trim()
        .toLowerCase();

    if (query.isEmpty) {
      return timeReports;
    }

    return timeReports.where(
          (
          InfrastructureMapReport report,
          ) {
        return report.title
            .toLowerCase()
            .contains(
          query,
        ) ||
            report.description
                .toLowerCase()
                .contains(
              query,
            ) ||
            report.address
                .toLowerCase()
                .contains(
              query,
            ) ||
            report.referenceNumber
                .toLowerCase()
                .contains(
              query,
            ) ||
            report.category
                .toLowerCase()
                .contains(
              query,
            ) ||
            report.priority
                .toLowerCase()
                .contains(
              query,
            ) ||
            report.status
                .toLowerCase()
                .contains(
              query,
            );
      },
    ).toList();
  }

  // ==========================================================================
  // HOTSPOT INTELLIGENCE
  // ==========================================================================

  List<SpatialHotspot>
  get hotspots {
    return spatialService.detectHotspots(
      allReports: categoryReports,
      window: selectedWindow,
      radiusMetres: 350,
      minimumReports: 3,
    );
  }

  // ==========================================================================
  // HEALTH INTELLIGENCE
  // ==========================================================================

  SpatialHealthSummary
  get healthSummary {
    return spatialService.calculateHealth(
      visibleReports,
    );
  }

  int get activeReportCount {
    return healthSummary.activeReports;
  }

  int get resolvedReportCount {
    return healthSummary.resolvedReports;
  }

  // ==========================================================================
  // HIGH-LEVEL INTELLIGENCE
  // ==========================================================================

  int get emergingHotspotCount {
    return hotspots
        .where(
          (
          SpatialHotspot hotspot,
          ) =>
      hotspot.isEmerging,
    )
        .length;
  }

  int get recurringLocationCount {
    return hotspots
        .where(
          (
          SpatialHotspot hotspot,
          ) =>
      hotspot.recurrenceCount >= 2,
    )
        .length;
  }

  int get verificationWarningCount {
    return hotspots
        .where(
          (
          SpatialHotspot hotspot,
          ) =>
      hotspot
          .communityVerificationNeeded,
    )
        .length;
  }

  SpatialHotspot? get highestRiskHotspot {
    if (hotspots.isEmpty) {
      return null;
    }

    return hotspots.first;
  }

  // ==========================================================================
  // MAP MARKERS
  // ==========================================================================

  Set<Marker> get reportMarkers {
    if (!showReports) {
      return const <Marker>{};
    }

    final List<InfrastructureMapReport>
    items =
        visibleReports;

    return items.map(
          (
          InfrastructureMapReport report,
          ) {
        return Marker(
          markerId: MarkerId(
            'report_${report.id}',
          ),
          position: LatLng(
            report.latitude,
            report.longitude,
          ),
          icon: _markerIcon(
            report.category,
          ),
          infoWindow: InfoWindow(
            title: report.title,
            snippet:
            '${report.referenceNumber} · '
                '${_statusText(report.status)}',
            onTap: () {
              _openReportDetail(
                report,
              );
            },
          ),
          onTap: () {
            setState(() {
              selectedReport = report;

              selectedHotspot = null;
            });
          },
        );
      },
    ).toSet();
  }

  // ==========================================================================
  // HOTSPOT CIRCLES
  // ==========================================================================

  Set<Circle> get hotspotCircles {
    final Set<Circle> result =
    <Circle>{};

    if (showHotspots) {
      for (final SpatialHotspot hotspot
      in hotspots) {
        final Color color =
        _riskColor(
          hotspot.riskScore,
        );

        result.add(
          Circle(
            circleId: CircleId(
              'hotspot_${hotspot.id}',
            ),
            center: LatLng(
              hotspot.latitude,
              hotspot.longitude,
            ),
            radius:
            hotspot.radiusMetres,
            fillColor:
            color.withOpacity(
              0.12,
            ),
            strokeColor:
            color.withOpacity(
              0.9,
            ),
            strokeWidth:
            hotspot.isEmerging
                ? 3
                : 2,
            consumeTapEvents:
            true,
            onTap: () {
              setState(() {
                selectedHotspot =
                    hotspot;

                selectedReport =
                null;
              });
            },
          ),
        );
      }
    }

    if (showNearbyRadius &&
        userLatitude != null &&
        userLongitude != null) {
      result.add(
        Circle(
          circleId:
          const CircleId(
            'user_nearby_radius',
          ),
          center: LatLng(
            userLatitude!,
            userLongitude!,
          ),
          radius:
          nearbyRadiusMetres,
          fillColor:
          AppColors.primary
              .withOpacity(
            0.045,
          ),
          strokeColor:
          AppColors.primary
              .withOpacity(
            0.8,
          ),
          strokeWidth: 2,
        ),
      );
    }

    return result;
  }

  // ==========================================================================
  // HEALTH ZONES
  // ==========================================================================

  Set<Polygon> get healthPolygons {
    if (!showHealthZones) {
      return const <Polygon>{};
    }

    final Set<Polygon> result =
    <Polygon>{};

    for (int index = 0;
    index < hotspots.length;
    index++) {
      final SpatialHotspot hotspot =
      hotspots[index];

      final int zoneHealth =
          100 -
              hotspot.riskScore;

      final Color color =
      _healthColor(
        zoneHealth,
      );

      final double latitudeDelta =
          (hotspot.radiusMetres /
              111320) *
              0.82;

      final double longitudeCorrection =
          1 /
              (0.5 +
                  0.5 *
                      (
                          hotspot.latitude
                              .abs() <
                              70
                              ? 1
                              : 0.7
                      ));

      final double longitudeDelta =
          latitudeDelta *
              longitudeCorrection;

      result.add(
        Polygon(
          polygonId: PolygonId(
            'health_zone_$index',
          ),
          points: <LatLng>[
            LatLng(
              hotspot.latitude -
                  latitudeDelta,
              hotspot.longitude -
                  longitudeDelta,
            ),
            LatLng(
              hotspot.latitude -
                  latitudeDelta,
              hotspot.longitude +
                  longitudeDelta,
            ),
            LatLng(
              hotspot.latitude +
                  latitudeDelta,
              hotspot.longitude +
                  longitudeDelta,
            ),
            LatLng(
              hotspot.latitude +
                  latitudeDelta,
              hotspot.longitude -
                  longitudeDelta,
            ),
          ],
          fillColor:
          color.withOpacity(
            0.035,
          ),
          strokeColor:
          color.withOpacity(
            0.23,
          ),
          strokeWidth: 1,
        ),
      );
    }

    return result;
  }

  // ==========================================================================
  // CURRENT LOCATION
  // ==========================================================================

  Future<void> goToCurrentLocation() async {
    if (locating) {
      return;
    }

    setState(() {
      locating = true;
    });

    try {
      final result =
      await locationService
          .getCurrentLocationWithAddress();

      if (!mounted) {
        return;
      }

      setState(() {
        userLatitude =
            result.latitude;

        userLongitude =
            result.longitude;
      });

      await mapController
          ?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            result.latitude,
            result.longitude,
          ),
          15.5,
        ),
      );
    } catch (e) {
      _message(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          locating = false;
        });
      }
    }
  }

  // ==========================================================================
  // DISTANCE
  // ==========================================================================

  String distanceLabel(
      InfrastructureMapReport report,
      ) {
    if (userLatitude == null ||
        userLongitude == null) {
      return 'Location not detected';
    }

    final double distance =
    Geolocator.distanceBetween(
      userLatitude!,
      userLongitude!,
      report.latitude,
      report.longitude,
    );

    if (distance < 1000) {
      return '${distance.round()} m away';
    }

    return '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  // ==========================================================================
  // FOCUS REPORT
  // ==========================================================================

  Future<void> focusReport(
      InfrastructureMapReport report,
      ) async {
    setState(() {
      selectedReport = report;

      selectedHotspot = null;
    });

    await mapController
        ?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          report.latitude,
          report.longitude,
        ),
        17,
      ),
    );
  }

  // ==========================================================================
  // FULL REPORT DETAILS
  // ==========================================================================

  Future<void> _openReportDetail(
      InfrastructureMapReport report,
      ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (
            BuildContext context,
            ) {
          return ReportDetailScreen(
            reportId: report.id,
          );
        },
      ),
    );

    if (mounted) {
      await loadMap(
        silent: true,
      );
    }
  }

  // ==========================================================================
  // FIT VISIBLE REPORTS
  // ==========================================================================

  Future<void> fitVisibleReports() async {
    if (visibleReports.isEmpty ||
        mapController == null) {
      return;
    }

    if (visibleReports.length == 1) {
      await focusReport(
        visibleReports.first,
      );

      return;
    }

    double minLat =
        visibleReports.first.latitude;

    double maxLat =
        visibleReports.first.latitude;

    double minLng =
        visibleReports.first.longitude;

    double maxLng =
        visibleReports.first.longitude;

    for (final InfrastructureMapReport report
    in visibleReports.skip(1)) {
      if (report.latitude < minLat) {
        minLat = report.latitude;
      }

      if (report.latitude > maxLat) {
        maxLat = report.latitude;
      }

      if (report.longitude < minLng) {
        minLng = report.longitude;
      }

      if (report.longitude > maxLng) {
        maxLng = report.longitude;
      }
    }

    try {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              minLat,
              minLng,
            ),
            northeast: LatLng(
              maxLat,
              maxLng,
            ),
          ),
          55,
        ),
      );
    } catch (_) {
      // Google Maps can reject extremely small bounds.
    }
  }

  // ==========================================================================
  // REPORT BROWSER
  // ==========================================================================

  Future<void> openReportBrowser() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      AppColors.background,
      barrierColor:
      Colors.black54,
      useSafeArea: true,
      builder: (
          BuildContext sheetContext,
          ) {
        return DraggableScrollableSheet(
          initialChildSize:
          0.72,
          minChildSize:
          0.45,
          maxChildSize:
          0.96,
          expand: false,
          builder: (
              BuildContext context,
              ScrollController
              scrollController,
              ) {
            return Container(
              decoration:
              const BoxDecoration(
                color:
                AppColors.background,
                borderRadius:
                BorderRadius.vertical(
                  top:
                  Radius.circular(
                    26,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const _SheetHandle(),

                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      18,
                      4,
                      18,
                      13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration:
                          BoxDecoration(
                            color:
                            AppColors.primary
                                .withOpacity(
                              0.10,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              13,
                            ),
                          ),
                          child:
                          const Icon(
                            Icons
                                .view_list_rounded,
                            color:
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(
                          width: 11,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              const Text(
                                'Infrastructure Reports',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize: 17,
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                ),
                              ),
                              Text(
                                '${visibleReports.length} reports in '
                                    '${selectedWindow.label} view',
                                style:
                                const TextStyle(
                                  color:
                                  AppColors
                                      .textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child:
                    visibleReports.isEmpty
                        ? const _EmptySheetState(
                      icon:
                      Icons
                          .location_off_outlined,
                      title:
                      'No reports found',
                      message:
                      'Try another time range, category or search.',
                    )
                        : ListView.separated(
                      controller:
                      scrollController,
                      padding:
                      const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        24,
                      ),
                      itemCount:
                      visibleReports.length,
                      separatorBuilder:
                          (
                          _,
                          __,
                          ) =>
                      const SizedBox(
                        height: 9,
                      ),
                      itemBuilder:
                          (
                          BuildContext context,
                          int index,
                          ) {
                        final InfrastructureMapReport
                        report =
                        visibleReports[index];

                        return _ReportListCard(
                          report: report,
                          categoryIcon:
                          _categoryIcon(
                            report.category,
                          ),
                          statusText:
                          _statusText(
                            report.status,
                          ),
                          statusColor:
                          _statusColor(
                            report.status,
                          ),
                          priorityColor:
                          _priorityColor(
                            report.priority,
                          ),
                          distance:
                          distanceLabel(
                            report,
                          ),
                          onMap:
                              () {
                            Navigator.pop(
                              sheetContext,
                            );

                            focusReport(
                              report,
                            );
                          },
                          onDetails:
                              () {
                            Navigator.pop(
                              sheetContext,
                            );

                            _openReportDetail(
                              report,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // SMART INSIGHTS
  // ==========================================================================

  Future<void> openSmartInsights() async {
    final SpatialHotspot? topHotspot =
        highestRiskHotspot;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      AppColors.background,
      useSafeArea: true,
      builder: (
          BuildContext sheetContext,
          ) {
        return DraggableScrollableSheet(
          initialChildSize:
          0.72,
          minChildSize:
          0.50,
          maxChildSize:
          0.94,
          expand: false,
          builder: (
              BuildContext context,
              ScrollController
              scrollController,
              ) {
            return Container(
              decoration:
              const BoxDecoration(
                color:
                AppColors.background,
                borderRadius:
                BorderRadius.vertical(
                  top:
                  Radius.circular(
                    26,
                  ),
                ),
              ),
              child: ListView(
                controller:
                scrollController,
                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  28,
                ),
                children: [
                  const _SheetHandle(),

                  const Row(
                    children: [
                      Icon(
                        Icons
                            .auto_graph_rounded,
                        color:
                        AppColors.primary,
                      ),
                      SizedBox(
                        width: 9,
                      ),
                      Text(
                        'Smart Map Intelligence',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    'Live analysis for ${selectedWindow.label} · '
                        '$selectedCategory',
                    style:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _HealthOverviewCard(
                    health:
                    healthSummary,
                    color:
                    _healthColor(
                      healthSummary.score,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                        _InsightMetricCard(
                          icon:
                          Icons
                              .trending_up_rounded,
                          value:
                          '$emergingHotspotCount',
                          label:
                          'Emerging',
                          message:
                          'Hotspots increasing in the selected period',
                          color:
                          AppColors.warning,
                        ),
                      ),
                      const SizedBox(
                        width: 9,
                      ),
                      Expanded(
                        child:
                        _InsightMetricCard(
                          icon:
                          Icons
                              .replay_rounded,
                          value:
                          '$recurringLocationCount',
                          label:
                          'Recurring',
                          message:
                          'Locations with repeated similar incidents',
                          color:
                          AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 9,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                        _InsightMetricCard(
                          icon:
                          Icons
                              .fact_check_outlined,
                          value:
                          '$verificationWarningCount',
                          label:
                          'Verify',
                          message:
                          'Official/community signals may differ',
                          color:
                          AppColors.warning,
                        ),
                      ),
                      const SizedBox(
                        width: 9,
                      ),
                      Expanded(
                        child:
                        _InsightMetricCard(
                          icon:
                          Icons
                              .assignment_outlined,
                          value:
                          '$activeReportCount',
                          label:
                          'Active',
                          message:
                          'Current unresolved infrastructure reports',
                          color:
                          AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  if (topHotspot != null) ...[
                    const SizedBox(
                      height: 16,
                    ),

                    const _SectionHeader(
                      icon:
                      Icons
                          .local_fire_department_outlined,
                      title:
                      'Highest Risk Area',
                      subtitle:
                      'Current strongest concentration of infrastructure issues',
                    ),

                    const SizedBox(
                      height: 9,
                    ),

                    _HotspotSummaryCard(
                      hotspot:
                      topHotspot,
                      color:
                      _riskColor(
                        topHotspot.riskScore,
                      ),
                      onOpen:
                          () {
                        Navigator.pop(
                          sheetContext,
                        );

                        openHotspot(
                          topHotspot,
                        );
                      },
                    ),
                  ],

                  if (hotspots.length >= 2) ...[
                    const SizedBox(
                      height: 16,
                    ),

                    const _SectionHeader(
                      icon:
                      Icons.compare_arrows_rounded,
                      title:
                      'Area Comparison',
                      subtitle:
                      'Compare the two highest-risk hotspots',
                    ),

                    const SizedBox(
                      height: 9,
                    ),

                    _HotspotComparisonCard(
                      first:
                      hotspots[0],
                      second:
                      hotspots[1],
                      firstColor:
                      _riskColor(
                        hotspots[0]
                            .riskScore,
                      ),
                      secondColor:
                      _riskColor(
                        hotspots[1]
                            .riskScore,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 16,
                  ),

                  Container(
                    padding:
                    const EdgeInsets.all(
                      13,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.surface,
                      borderRadius:
                      BorderRadius.circular(
                        15,
                      ),
                      border:
                      Border.all(
                        color:
                        AppColors.border,
                      ),
                    ),
                    child:
                    const Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons
                              .info_outline_rounded,
                          color:
                          AppColors.primary,
                          size: 19,
                        ),
                        SizedBox(
                          width: 9,
                        ),
                        Expanded(
                          child: Text(
                            'Smart Map scores are explainable decision-support indicators. '
                                'They are calculated from actual report density, time trends, '
                                'priority, unresolved incidents, recurrence and community signals. '
                                'They do not replace official infrastructure inspection.',
                            style:
                            TextStyle(
                              color:
                              AppColors
                                  .textSecondary,
                              fontSize: 9,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // HOTSPOT EXPLANATION
  // ==========================================================================

  Future<void> explainHotspot(
      SpatialHotspot hotspot,
      ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      AppColors.background,
      useSafeArea: true,
      builder: (
          BuildContext context,
          ) {
        return DraggableScrollableSheet(
          initialChildSize:
          0.76,
          minChildSize:
          0.50,
          maxChildSize:
          0.95,
          expand: false,
          builder: (
              BuildContext context,
              ScrollController
              scrollController,
              ) {
            return ListView(
              controller:
              scrollController,
              padding:
              const EdgeInsets.fromLTRB(
                18,
                0,
                18,
                28,
              ),
              children: [
                const _SheetHandle(),

                Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration:
                      BoxDecoration(
                        color:
                        _riskColor(
                          hotspot
                              .riskScore,
                        ).withOpacity(
                          0.10,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          13,
                        ),
                      ),
                      child: Icon(
                        Icons
                            .psychology_alt_outlined,
                        color:
                        _riskColor(
                          hotspot
                              .riskScore,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 11,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            'Why ${hotspot.riskLevel}?',
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontSize: 18,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Explainable hotspot score ${hotspot.riskScore}/100',
                            style:
                            TextStyle(
                              color:
                              _riskColor(
                                hotspot
                                    .riskScore,
                              ),
                              fontSize: 9,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                for (final HotspotReason reason
                in hotspot.reasons)
                  _ReasonCard(
                    reason: reason,
                  ),

                if (hotspot
                    .communityVerificationNeeded) ...[
                  const SizedBox(
                    height: 6,
                  ),

                  const _VerificationWarningCard(),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // HOTSPOT DETAILS
  // ==========================================================================

  Future<void> openHotspot(
      SpatialHotspot hotspot,
      ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      AppColors.background,
      useSafeArea: true,
      builder: (
          BuildContext sheetContext,
          ) {
        final List<
            MapEntry<String, int>>
        composition =
        hotspot
            .categoryComposition
            .entries
            .toList()
          ..sort(
                (
                MapEntry<String, int>
                first,
                MapEntry<String, int>
                second,
                ) {
              return second.value
                  .compareTo(
                first.value,
              );
            },
          );

        return DraggableScrollableSheet(
          initialChildSize:
          0.80,
          minChildSize:
          0.55,
          maxChildSize:
          0.96,
          expand: false,
          builder: (
              BuildContext context,
              ScrollController
              scrollController,
              ) {
            final Color riskColor =
            _riskColor(
              hotspot.riskScore,
            );

            return ListView(
              controller:
              scrollController,
              padding:
              const EdgeInsets.fromLTRB(
                18,
                0,
                18,
                28,
              ),
              children: [
                const _SheetHandle(),

                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration:
                      BoxDecoration(
                        color:
                        riskColor
                            .withOpacity(
                          0.10,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Icon(
                        Icons
                            .local_fire_department_rounded,
                        color:
                        riskColor,
                      ),
                    ),

                    const SizedBox(
                      width: 11,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            '${hotspot.dominantCategory} Hotspot',
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontSize: 18,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${hotspot.riskLevel} spatial risk',
                            style:
                            TextStyle(
                              color:
                              riskColor,
                              fontSize: 9,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        riskColor
                            .withOpacity(
                          0.10,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: Text(
                        '${hotspot.riskScore}/100',
                        style:
                        TextStyle(
                          color:
                          riskColor,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 15,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PillMetric(
                      icon:
                      Icons
                          .description_outlined,
                      label:
                      'Reports',
                      value:
                      '${hotspot.reportCount}',
                    ),
                    _PillMetric(
                      icon:
                      Icons
                          .pending_actions_outlined,
                      label:
                      'Active',
                      value:
                      '${hotspot.activeCount}',
                    ),
                    _PillMetric(
                      icon:
                      Icons.groups_outlined,
                      label:
                      'Affected',
                      value:
                      '${hotspot.affectedCount}',
                    ),
                    _PillMetric(
                      icon:
                      Icons
                          .warning_amber_rounded,
                      label:
                      'Still Exists',
                      value:
                      '${hotspot.stillExistsCount}',
                    ),
                    _PillMetric(
                      icon:
                      Icons.replay,
                      label:
                      'Recurring',
                      value:
                      '${hotspot.recurrenceCount}',
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                _TrendPanel(
                  trend:
                  hotspot.trendLabel,
                  current:
                  hotspot.currentPeriodCount,
                  previous:
                  hotspot.previousPeriodCount,
                  growth:
                  hotspot.growthPercent,
                ),

                const SizedBox(
                  height: 16,
                ),

                const _SectionHeader(
                  icon:
                  Icons
                      .donut_large_outlined,
                  title:
                  'Issue Composition',
                  subtitle:
                  'What types of infrastructure problems dominate this area',
                ),

                const SizedBox(
                  height: 9,
                ),

                for (final MapEntry<String, int>
                entry in composition)
                  _CompositionRow(
                    label:
                    entry.key,
                    value:
                    entry.value,
                    total:
                    hotspot.reportCount,
                  ),

                if (hotspot
                    .communityVerificationNeeded) ...[
                  const SizedBox(
                    height: 13,
                  ),

                  const _VerificationWarningCard(),
                ],

                const SizedBox(
                  height: 18,
                ),

                const _SectionHeader(
                  icon:
                  Icons
                      .view_list_rounded,
                  title:
                  'Reports in this Hotspot',
                  subtitle:
                  'Open any contributing report for full details and evidence',
                ),

                const SizedBox(
                  height: 9,
                ),

                for (final InfrastructureMapReport report
                in hotspot.reports)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: 8,
                    ),
                    child: _CompactReportCard(
                      report: report,
                      statusText:
                      _statusText(
                        report.status,
                      ),
                      statusColor:
                      _statusColor(
                        report.status,
                      ),
                      priorityColor:
                      _priorityColor(
                        report.priority,
                      ),
                      onTap:
                          () {
                        Navigator.pop(
                          sheetContext,
                        );

                        _openReportDetail(
                          report,
                        );
                      },
                    ),
                  ),

                const SizedBox(
                  height: 4,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  child:
                  OutlinedButton.icon(
                    onPressed:
                        () {
                      Navigator.pop(
                        sheetContext,
                      );

                      explainHotspot(
                        hotspot,
                      );
                    },
                    icon:
                    const Icon(
                      Icons
                          .help_outline_rounded,
                    ),
                    label:
                    const Text(
                      'Explain Risk Score',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // NEARBY AREA INTELLIGENCE
  // ==========================================================================

  Future<void> openNearbyScanner() async {
    if (userLatitude == null ||
        userLongitude == null) {
      await goToCurrentLocation();

      if (userLatitude == null ||
          userLongitude == null) {
        return;
      }
    }

    double temporaryRadius =
        nearbyRadiusMetres;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      AppColors.background,
      useSafeArea: true,
      builder: (
          BuildContext sheetContext,
          ) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter
              setSheetState,
              ) {
            final List<
                NearbyInfrastructureReport>
            nearby =
            spatialService.nearbyReports(
              reports: visibleReports,
              latitude:
              userLatitude!,
              longitude:
              userLongitude!,
              radiusMetres:
              temporaryRadius,
            );

            final List<
                InfrastructureMapReport>
            nearbyCore =
            nearby
                .map(
                  (
                  NearbyInfrastructureReport
                  item,
                  ) =>
              item.report,
            )
                .toList();

            final SpatialHealthSummary
            areaHealth =
            spatialService.calculateHealth(
              nearbyCore,
            );

            final Map<String, int>
            categoryCounts =
            <String, int>{};

            for (final NearbyInfrastructureReport item
            in nearby) {
              categoryCounts.update(
                item.report.category,
                    (
                    int current,
                    ) =>
                current + 1,
                ifAbsent: () => 1,
              );
            }

            String dominantCategory =
                'None';

            if (categoryCounts.isNotEmpty) {
              dominantCategory =
                  categoryCounts.entries
                      .reduce(
                        (
                        MapEntry<String, int>
                        first,
                        MapEntry<String, int>
                        second,
                        ) {
                      return first.value >=
                          second.value
                          ? first
                          : second;
                    },
                  )
                      .key;
            }

            return DraggableScrollableSheet(
              initialChildSize:
              0.78,
              minChildSize:
              0.55,
              maxChildSize:
              0.95,
              expand: false,
              builder: (
                  BuildContext context,
                  ScrollController
                  scrollController,
                  ) {
                return ListView(
                  controller:
                  scrollController,
                  padding:
                  const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    28,
                  ),
                  children: [
                    const _SheetHandle(),

                    const Row(
                      children: [
                        Icon(
                          Icons
                              .radar_rounded,
                          color:
                          AppColors.primary,
                        ),
                        SizedBox(
                          width: 9,
                        ),
                        Text(
                          'Nearby Area Intelligence',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontSize: 18,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      'Analyse infrastructure conditions around your current position.',
                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .adjust_rounded,
                          color:
                          AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: Slider(
                            value:
                            temporaryRadius,
                            min: 500,
                            max: 5000,
                            divisions: 9,
                            label:
                            '${(temporaryRadius / 1000).toStringAsFixed(1)} km',
                            onChanged:
                                (
                                double value,
                                ) {
                              setSheetState(
                                    () {
                                  temporaryRadius =
                                      value;
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: 55,
                          child: Text(
                            '${(temporaryRadius / 1000).toStringAsFixed(1)} km',
                            textAlign:
                            TextAlign.right,
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    _NearbyHealthCard(
                      health:
                      areaHealth,
                      reportCount:
                      nearby.length,
                      dominantCategory:
                      dominantCategory,
                      closestDistance:
                      nearby.isEmpty
                          ? '—'
                          : nearby.first
                          .distanceLabel,
                      color:
                      _healthColor(
                        areaHealth.score,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    const _SectionHeader(
                      icon:
                      Icons
                          .near_me_outlined,
                      title:
                      'Nearby Reports',
                      subtitle:
                      'Ordered from closest to furthest',
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    if (nearby.isEmpty)
                      const _EmptySheetState(
                        icon:
                        Icons
                            .location_searching_rounded,
                        title:
                        'No issues in this radius',
                        message:
                        'Increase the radius to search a wider area.',
                      )
                    else
                      for (final NearbyInfrastructureReport item
                      in nearby)
                        Padding(
                          padding:
                          const EdgeInsets.only(
                            bottom: 8,
                          ),
                          child:
                          _NearbyReportRow(
                            item: item,
                            categoryIcon:
                            _categoryIcon(
                              item.report
                                  .category,
                            ),
                            statusColor:
                            _statusColor(
                              item.report
                                  .status,
                            ),
                            onTap:
                                () {
                              Navigator.pop(
                                sheetContext,
                              );

                              focusReport(
                                item.report,
                              );
                            },
                            onDetails:
                                () {
                              Navigator.pop(
                                sheetContext,
                              );

                              _openReportDetail(
                                item.report,
                              );
                            },
                          ),
                        ),

                    const SizedBox(
                      height: 8,
                    ),

                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          nearbyRadiusMetres =
                              temporaryRadius;

                          showNearbyRadius =
                          true;
                        });

                        Navigator.pop(
                          sheetContext,
                        );
                      },
                      icon:
                      const Icon(
                        Icons
                            .radar_rounded,
                      ),
                      label:
                      const Text(
                        'Show Radius on Map',
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // LAYER MANAGER
  // ==========================================================================

  Future<void> openLayerManager() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      AppColors.background,
      useSafeArea: true,
      showDragHandle: false,
      builder: (
          BuildContext sheetContext,
          ) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter
              setSheetState,
              ) {
            void update(
                VoidCallback change,
                ) {
              setSheetState(
                change,
              );

              setState(
                change,
              );
            }

            return Padding(
              padding:
              const EdgeInsets.fromLTRB(
                18,
                10,
                18,
                24,
              ),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const _SheetHandle(),

                  const Row(
                    children: [
                      Icon(
                        Icons
                            .layers_outlined,
                        color:
                        AppColors.primary,
                      ),
                      SizedBox(
                        width: 9,
                      ),
                      Text(
                        'Map Layers',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  const Text(
                    'Control the information displayed on your Smart Map.',
                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _LayerSwitch(
                    icon:
                    Icons
                        .location_on_outlined,
                    title:
                    'Infrastructure Reports',
                    subtitle:
                    'Show individual report markers',
                    value:
                    showReports,
                    onChanged:
                        (
                        bool value,
                        ) {
                      update(
                            () {
                          showReports =
                              value;
                        },
                      );
                    },
                  ),

                  _LayerSwitch(
                    icon:
                    Icons
                        .local_fire_department_outlined,
                    title:
                    'Hotspot Intelligence',
                    subtitle:
                    'Show concentrated and emerging issue areas',
                    value:
                    showHotspots,
                    onChanged:
                        (
                        bool value,
                        ) {
                      update(
                            () {
                          showHotspots =
                              value;
                        },
                      );
                    },
                  ),

                  _LayerSwitch(
                    icon:
                    Icons
                        .health_and_safety_outlined,
                    title:
                    'Infrastructure Health Zones',
                    subtitle:
                    'Visualise area condition around hotspots',
                    value:
                    showHealthZones,
                    onChanged:
                        (
                        bool value,
                        ) {
                      update(
                            () {
                          showHealthZones =
                              value;
                        },
                      );
                    },
                  ),

                  _LayerSwitch(
                    icon:
                    Icons.radar,
                    title:
                    'Nearby Scanner Radius',
                    subtitle:
                    'Display your selected nearby analysis area',
                    value:
                    showNearbyRadius,
                    onChanged:
                        (
                        bool value,
                        ) {
                      update(
                            () {
                          showNearbyRadius =
                              value;
                        },
                      );
                    },
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  const Text(
                    'MAP STYLE',
                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 8,
                      fontWeight:
                      FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                        _MapStyleButton(
                          selected:
                          selectedMapType ==
                              MapType.normal,
                          icon:
                          Icons
                              .map_outlined,
                          label:
                          'Standard',
                          onTap:
                              () {
                            update(
                                  () {
                                selectedMapType =
                                    MapType.normal;
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child:
                        _MapStyleButton(
                          selected:
                          selectedMapType ==
                              MapType.hybrid,
                          icon:
                          Icons
                              .satellite_alt_outlined,
                          label:
                          'Hybrid',
                          onTap:
                              () {
                            update(
                                  () {
                                selectedMapType =
                                    MapType.hybrid;
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // MAP OVERVIEW
  // ==========================================================================

  void toggleOverview() {
    setState(() {
      mapOverviewExpanded =
      !mapOverviewExpanded;
    });
  }

  // ==========================================================================
  // COLORS / ICONS
  // ==========================================================================

  BitmapDescriptor _markerIcon(
      String category,
      ) {
    switch (category) {
      case 'Road Damage':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        );

      case 'Street Light':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );

      case 'Drainage':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        );

      case 'Public Facility':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );

      default:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
    }
  }

  IconData _categoryIcon(
      String category,
      ) {
    switch (category) {
      case 'Road Damage':
        return Icons
            .add_road_rounded;

      case 'Street Light':
        return Icons
            .lightbulb_outline_rounded;

      case 'Drainage':
        return Icons
            .water_drop_outlined;

      case 'Public Facility':
        return Icons
            .location_city_outlined;

      default:
        return Icons
            .report_problem_outlined;
    }
  }

  Color _categoryColor(
      String category,
      ) {
    switch (category) {
      case 'Road Damage':
        return AppColors.danger;

      case 'Street Light':
        return AppColors.warning;

      case 'Drainage':
        return Colors.lightBlueAccent;

      case 'Public Facility':
        return Colors.purpleAccent;

      default:
        return AppColors.primary;
    }
  }

  Color _riskColor(
      int score,
      ) {
    if (score >= 80) {
      return AppColors.danger;
    }

    if (score >= 60) {
      return Colors.deepOrangeAccent;
    }

    if (score >= 40) {
      return AppColors.warning;
    }

    return AppColors.primary;
  }

  Color _healthColor(
      int score,
      ) {
    if (score >= 80) {
      return AppColors.success;
    }

    if (score >= 60) {
      return AppColors.primary;
    }

    if (score >= 40) {
      return AppColors.warning;
    }

    return AppColors.danger;
  }

  Color _statusColor(
      String status,
      ) {
    final String normalized =
    status
        .trim()
        .toLowerCase()
        .replaceAll(
      ' ',
      '_',
    );

    switch (normalized) {
      case 'completed':
      case 'resolved':
        return AppColors.success;

      case 'rejected':
        return AppColors.danger;

      case 'pending':
      case 'submitted':
        return AppColors.warning;

      default:
        return AppColors.primary;
    }
  }

  Color _priorityColor(
      String priority,
      ) {
    switch (priority
        .trim()
        .toLowerCase()) {
      case 'critical':
        return AppColors.danger;

      case 'high':
        return Colors.deepOrangeAccent;

      case 'medium':
        return AppColors.warning;

      default:
        return AppColors.primary;
    }
  }

  String _statusText(
      String status,
      ) {
    final String value =
    status
        .replaceAll(
      '_',
      ' ',
    )
        .trim();

    if (value.isEmpty) {
      return 'Pending';
    }

    return value
        .split(
      ' ',
    )
        .map(
          (
          String word,
          ) {
        if (word.isEmpty) {
          return word;
        }

        return '${word[0].toUpperCase()}'
            '${word.substring(1).toLowerCase()}';
      },
    )
        .join(
      ' ',
    );
  }

  String _syncLabel() {
    if (refreshing) {
      return 'Syncing';
    }

    if (realtimeConnected) {
      return 'Live';
    }

    return 'Fallback';
  }

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _message(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final SpatialHealthSummary health =
        healthSummary;

    return Scaffold(
      backgroundColor:
      AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ================================================================
            // PROFESSIONAL HEADER
            // ================================================================

            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                10,
              ),
              child: Row(
                children: [
                  _HeaderIconButton(
                    tooltip:
                    'Back',
                    icon:
                    Icons.arrow_back_rounded,
                    onTap:
                        () {
                      Navigator.pop(
                        context,
                      );
                    },
                  ),

                  const SizedBox(
                    width: 11,
                  ),

                  Container(
                    width: 43,
                    height: 43,
                    decoration:
                    BoxDecoration(
                      gradient:
                      LinearGradient(
                        begin:
                        Alignment.topLeft,
                        end:
                        Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.primary
                              .withOpacity(
                            0.28,
                          ),
                          AppColors.primary
                              .withOpacity(
                            0.07,
                          ),
                        ],
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        13,
                      ),
                      border:
                      Border.all(
                        color:
                        AppColors.primary
                            .withOpacity(
                          0.28,
                        ),
                      ),
                    ),
                    child:
                    const Icon(
                      Icons
                          .travel_explore_rounded,
                      color:
                      AppColors.primary,
                      size: 22,
                    ),
                  ),

                  const SizedBox(
                    width: 11,
                  ),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Infrastructure Map',
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontSize: 17,
                            fontWeight:
                            FontWeight.w800,
                            letterSpacing:
                            -0.15,
                          ),
                        ),
                        SizedBox(
                          height: 2,
                        ),
                        Text(
                          'Live spatial intelligence & community signals',
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          TextStyle(
                            color:
                            AppColors.textSecondary,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  _LiveStatusPill(
                    live:
                    realtimeConnected,
                    refreshing:
                    refreshing,
                    label:
                    _syncLabel(),
                  ),
                ],
              ),
            ),

            // ================================================================
            // SEARCH
            // ================================================================

            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Container(
                height: 48,
                decoration:
                BoxDecoration(
                  color:
                  AppColors.surface,
                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                  border:
                  Border.all(
                    color:
                    AppColors.border,
                  ),
                ),
                child: TextField(
                  controller:
                  searchController,
                  onChanged:
                      (_) {
                    setState(() {
                      selectedReport =
                      null;

                      selectedHotspot =
                      null;
                    });
                  },
                  style:
                  const TextStyle(
                    fontSize: 12,
                  ),
                  decoration:
                  InputDecoration(
                    hintText:
                    'Search reports, addresses or categories',
                    hintStyle:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    prefixIcon:
                    const Icon(
                      Icons
                          .search_rounded,
                      size: 20,
                    ),
                    suffixIcon:
                    searchController.text
                        .isEmpty
                        ? IconButton(
                      tooltip:
                      'Show reports',
                      icon:
                      const Icon(
                        Icons
                            .view_list_outlined,
                        size: 19,
                      ),
                      onPressed:
                      openReportBrowser,
                    )
                        : IconButton(
                      icon:
                      const Icon(
                        Icons
                            .close_rounded,
                        size: 18,
                      ),
                      onPressed:
                          () {
                        searchController.clear();

                        setState(() {});
                      },
                    ),
                    border:
                    InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            // ================================================================
            // TIME RANGE
            // ================================================================

            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection:
                Axis.horizontal,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                itemCount:
                SmartMapTimeWindow
                    .values.length,
                separatorBuilder:
                    (
                    _,
                    __,
                    ) =>
                const SizedBox(
                  width: 7,
                ),
                itemBuilder:
                    (
                    BuildContext context,
                    int index,
                    ) {
                  final SmartMapTimeWindow
                  window =
                  SmartMapTimeWindow
                      .values[index];

                  final bool selected =
                      selectedWindow ==
                          window;

                  return _FilterChip(
                    selected:
                    selected,
                    label:
                    window.label,
                    icon:
                    selected
                        ? Icons
                        .check_rounded
                        : null,
                    onTap:
                        () {
                      setState(() {
                        selectedWindow =
                            window;

                        selectedReport =
                        null;

                        selectedHotspot =
                        null;
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            // ================================================================
            // CATEGORY
            // ================================================================

            SizedBox(
              height: 35,
              child: ListView.separated(
                scrollDirection:
                Axis.horizontal,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                itemCount:
                categories.length,
                separatorBuilder:
                    (
                    _,
                    __,
                    ) =>
                const SizedBox(
                  width: 7,
                ),
                itemBuilder:
                    (
                    BuildContext context,
                    int index,
                    ) {
                  final String category =
                  categories[index];

                  final bool selected =
                      selectedCategory ==
                          category;

                  return _FilterChip(
                    selected:
                    selected,
                    label:
                    category,
                    icon:
                    category ==
                        'All'
                        ? Icons
                        .apps_rounded
                        : _categoryIcon(
                      category,
                    ),
                    onTap:
                        () {
                      setState(() {
                        selectedCategory =
                            category;

                        selectedReport =
                        null;

                        selectedHotspot =
                        null;
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            // ================================================================
            // MAP AREA
            // ================================================================

            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  12,
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    22,
                  ),
                  child: Stack(
                    children: [
                      // ======================================================
                      // GOOGLE MAP
                      // ======================================================

                      Positioned.fill(
                        child: GoogleMap(
                          initialCameraPosition:
                          const CameraPosition(
                            target:
                            malaysiaDefault,
                            zoom: 11,
                          ),
                          mapType:
                          selectedMapType,
                          markers:
                          reportMarkers,
                          circles:
                          hotspotCircles,
                          polygons:
                          healthPolygons,
                          myLocationEnabled:
                          userLatitude != null &&
                              userLongitude != null,
                          myLocationButtonEnabled:
                          false,
                          zoomControlsEnabled:
                          false,
                          mapToolbarEnabled:
                          false,
                          compassEnabled:
                          true,
                          buildingsEnabled:
                          true,
                          trafficEnabled:
                          false,
                          onMapCreated:
                              (
                              GoogleMapController
                              controller,
                              ) {
                            mapController =
                                controller;
                          },
                          onCameraMove:
                              (
                              CameraPosition
                              position,
                              ) {
                            currentZoom =
                                position.zoom;
                          },
                          onTap:
                              (
                              LatLng position,
                              ) {
                            setState(() {
                              selectedReport =
                              null;

                              selectedHotspot =
                              null;
                            });
                          },
                        ),
                      ),

                      // ======================================================
                      // LOADING
                      // ======================================================

                      if (loading)
                        Positioned.fill(
                          child: Container(
                            color:
                            AppColors.background
                                .withOpacity(
                              0.62,
                            ),
                            alignment:
                            Alignment.center,
                            child:
                            const _MapLoadingCard(),
                          ),
                        ),

                      // ======================================================
                      // AREA HEALTH CARD
                      // ======================================================

                      if (!loading)
                        Positioned(
                          left: 12,
                          top: 12,
                          right: 72,
                          child:
                          _MapHealthOverlay(
                            expanded:
                            mapOverviewExpanded,
                            score:
                            health.score,
                            healthLabel:
                            health.level,
                            visibleReports:
                            visibleReports.length,
                            activeReports:
                            activeReportCount,
                            hotspots:
                            hotspots.length,
                            emerging:
                            emergingHotspotCount,
                            color:
                            _healthColor(
                              health.score,
                            ),
                            window:
                            selectedWindow.label,
                            onTap:
                            toggleOverview,
                            onInsights:
                            openSmartInsights,
                          ),
                        ),

                      // ======================================================
                      // RIGHT MAP CONTROLS
                      // ======================================================

                      Positioned(
                        right: 12,
                        top: 12,
                        child: Column(
                          children: [
                            _FloatingMapButton(
                              tooltip:
                              'My Location',
                              icon:
                              Icons
                                  .my_location_rounded,
                              loading:
                              locating,
                              onTap:
                              goToCurrentLocation,
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            _FloatingMapButton(
                              tooltip:
                              'Map Layers',
                              icon:
                              Icons
                                  .layers_outlined,
                              onTap:
                              openLayerManager,
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            _FloatingMapButton(
                              tooltip:
                              'Nearby Intelligence',
                              icon:
                              Icons
                                  .radar_rounded,
                              onTap:
                              openNearbyScanner,
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            _FloatingMapButton(
                              tooltip:
                              'Fit Reports',
                              icon:
                              Icons
                                  .zoom_out_map_rounded,
                              onTap:
                              fitVisibleReports,
                            ),
                          ],
                        ),
                      ),

                      // ======================================================
                      // BOTTOM QUICK ACTIONS WHEN NOTHING SELECTED
                      // ======================================================

                      if (!loading &&
                          selectedReport == null &&
                          selectedHotspot == null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child:
                          _MapBottomNavigation(
                            reportCount:
                            visibleReports.length,
                            hotspotCount:
                            hotspots.length,
                            onReports:
                            openReportBrowser,
                            onInsights:
                            openSmartInsights,
                            onRefresh:
                                () {
                              loadMap(
                                silent: true,
                              );
                            },
                            refreshing:
                            refreshing,
                          ),
                        ),

                      // ======================================================
                      // SELECTED REPORT PREVIEW
                      // ======================================================

                      if (selectedReport != null)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child:
                          _SelectedReportCard(
                            report:
                            selectedReport!,
                            categoryIcon:
                            _categoryIcon(
                              selectedReport!
                                  .category,
                            ),
                            categoryColor:
                            _categoryColor(
                              selectedReport!
                                  .category,
                            ),
                            statusText:
                            _statusText(
                              selectedReport!
                                  .status,
                            ),
                            statusColor:
                            _statusColor(
                              selectedReport!
                                  .status,
                            ),
                            priorityColor:
                            _priorityColor(
                              selectedReport!
                                  .priority,
                            ),
                            distance:
                            distanceLabel(
                              selectedReport!,
                            ),
                            showCommunity:
                            showCommunitySignals,
                            onClose:
                                () {
                              setState(() {
                                selectedReport =
                                null;
                              });
                            },
                            onCenter:
                                () {
                              focusReport(
                                selectedReport!,
                              );
                            },
                            onDetails:
                                () {
                              _openReportDetail(
                                selectedReport!,
                              );
                            },
                          ),
                        ),

                      // ======================================================
                      // SELECTED HOTSPOT PREVIEW
                      // ======================================================

                      if (selectedHotspot != null)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child:
                          _SelectedHotspotCard(
                            hotspot:
                            selectedHotspot!,
                            color:
                            _riskColor(
                              selectedHotspot!
                                  .riskScore,
                            ),
                            onClose:
                                () {
                              setState(() {
                                selectedHotspot =
                                null;
                              });
                            },
                            onOpen:
                                () {
                              openHotspot(
                                selectedHotspot!,
                              );
                            },
                            onExplain:
                                () {
                              explainHotspot(
                                selectedHotspot!,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER BUTTON
// ============================================================================

class _HeaderIconButton extends StatelessWidget {
  final String tooltip;

  final IconData icon;

  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color: AppColors.surface,
      borderRadius:
      BorderRadius.circular(
        13,
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        onTap: onTap,
        child: Container(
          width: 43,
          height: 43,
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              13,
            ),
            border:
            Border.all(
              color:
              AppColors.border,
            ),
          ),
          alignment:
          Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LIVE STATUS
// ============================================================================

class _LiveStatusPill extends StatelessWidget {
  final bool live;

  final bool refreshing;

  final String label;

  const _LiveStatusPill({
    required this.live,
    required this.refreshing,
    required this.label,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final Color color =
    live
        ? AppColors.success
        : AppColors.warning;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration:
      BoxDecoration(
        color:
        color.withOpacity(
          0.09,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            0.25,
          ),
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          if (refreshing)
            SizedBox(
              width: 8,
              height: 8,
              child:
              CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            )
          else
            Container(
              width: 7,
              height: 7,
              decoration:
              BoxDecoration(
                color: color,
                shape:
                BoxShape.circle,
                boxShadow:
                <BoxShadow>[
                  BoxShadow(
                    color:
                    color.withOpacity(
                      0.35,
                    ),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style:
            TextStyle(
              color: color,
              fontSize: 7.5,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FILTER CHIP
// ============================================================================

class _FilterChip extends StatelessWidget {
  final bool selected;

  final String label;

  final IconData? icon;

  final VoidCallback onTap;

  const _FilterChip({
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color:
      selected
          ? AppColors.primary
          : AppColors.surface,
      borderRadius:
      BorderRadius.circular(
        11,
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          11,
        ),
        onTap: onTap,
        child: Container(
          height: 34,
          padding:
          const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              11,
            ),
            border:
            Border.all(
              color:
              selected
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color:
                  selected
                      ? AppColors.background
                      : AppColors.primary,
                ),
                const SizedBox(
                  width: 5,
                ),
              ],
              Text(
                label,
                style:
                TextStyle(
                  color:
                  selected
                      ? AppColors.background
                      : Colors.white,
                  fontSize: 9,
                  fontWeight:
                  selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAP HEALTH OVERLAY
// ============================================================================

class _MapHealthOverlay extends StatelessWidget {
  final bool expanded;

  final int score;

  final String healthLabel;

  final int visibleReports;

  final int activeReports;

  final int hotspots;

  final int emerging;

  final Color color;

  final String window;

  final VoidCallback onTap;

  final VoidCallback onInsights;

  const _MapHealthOverlay({
    required this.expanded,
    required this.score,
    required this.healthLabel,
    required this.visibleReports,
    required this.activeReports,
    required this.hotspots,
    required this.emerging,
    required this.color,
    required this.window,
    required this.onTap,
    required this.onInsights,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color:
      Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 220,
          ),
          padding:
          EdgeInsets.all(
            expanded
                ? 13
                : 10,
          ),
          decoration:
          BoxDecoration(
            color:
            AppColors.surface
                .withOpacity(
              0.96,
            ),
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            border:
            Border.all(
              color:
              color.withOpacity(
                0.28,
              ),
            ),
            boxShadow:
            <BoxShadow>[
              BoxShadow(
                color:
                Colors.black
                    .withOpacity(
                  0.18,
                ),
                blurRadius: 14,
                offset:
                const Offset(
                  0,
                  4,
                ),
              ),
            ],
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width:
                    expanded
                        ? 43
                        : 36,
                    height:
                    expanded
                        ? 43
                        : 36,
                    decoration:
                    BoxDecoration(
                      color:
                      color.withOpacity(
                        0.10,
                      ),
                      shape:
                      BoxShape.circle,
                      border:
                      Border.all(
                        color:
                        color.withOpacity(
                          0.75,
                        ),
                        width: 2,
                      ),
                    ),
                    alignment:
                    Alignment.center,
                    child: Text(
                      '$score',
                      style:
                      TextStyle(
                        color: color,
                        fontSize:
                        expanded
                            ? 13
                            : 11,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 9,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        const Text(
                          'Area Health',
                          style:
                          TextStyle(
                            color:
                            AppColors
                                .textSecondary,
                            fontSize: 7.5,
                          ),
                        ),
                        Text(
                          healthLabel,
                          maxLines: 1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.background
                          .withOpacity(
                        0.65,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        8,
                      ),
                    ),
                    child: Text(
                      window,
                      style:
                      const TextStyle(
                        color:
                        AppColors.primary,
                        fontSize: 7,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 4,
                  ),

                  Icon(
                    expanded
                        ? Icons
                        .keyboard_arrow_up
                        : Icons
                        .keyboard_arrow_down,
                    color:
                    AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),

              if (expanded) ...[
                const SizedBox(
                  height: 11,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                      _OverlayMetric(
                        label:
                        'Reports',
                        value:
                        '$visibleReports',
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child:
                      _OverlayMetric(
                        label:
                        'Active',
                        value:
                        '$activeReports',
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child:
                      _OverlayMetric(
                        label:
                        'Hotspots',
                        value:
                        '$hotspots',
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child:
                      _OverlayMetric(
                        label:
                        'Emerging',
                        value:
                        '$emerging',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 9,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  height: 30,
                  child:
                  TextButton.icon(
                    onPressed:
                    onInsights,
                    style:
                    TextButton.styleFrom(
                      backgroundColor:
                      AppColors.primary
                          .withOpacity(
                        0.08,
                      ),
                      foregroundColor:
                      AppColors.primary,
                    ),
                    icon:
                    const Icon(
                      Icons
                          .auto_graph_rounded,
                      size: 14,
                    ),
                    label:
                    const Text(
                      'View Spatial Intelligence',
                      style:
                      TextStyle(
                        fontSize: 8,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// OVERLAY METRIC
// ============================================================================

class _OverlayMetric extends StatelessWidget {
  final String label;

  final String value;

  const _OverlayMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Text(
          value,
          style:
          const TextStyle(
            color:
            Colors.white,
            fontSize: 11,
            fontWeight:
            FontWeight.w800,
          ),
        ),
        const SizedBox(
          height: 1,
        ),
        Text(
          label,
          style:
          const TextStyle(
            color:
            AppColors.textSecondary,
            fontSize: 6.5,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width: 1,
      height: 24,
      color:
      AppColors.border,
    );
  }
}

// ============================================================================
// FLOATING MAP BUTTON
// ============================================================================

class _FloatingMapButton extends StatelessWidget {
  final String tooltip;

  final IconData icon;

  final VoidCallback onTap;

  final bool loading;

  const _FloatingMapButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color:
      AppColors.surface
          .withOpacity(
        0.96,
      ),
      shape:
      const CircleBorder(),
      elevation: 4,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder:
          const CircleBorder(),
          onTap:
          loading
              ? null
              : onTap,
          child: SizedBox(
            width: 43,
            height: 43,
            child: Center(
              child:
              loading
                  ? const SizedBox(
                width: 17,
                height: 17,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : Icon(
                icon,
                color:
                AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAP LOADING
// ============================================================================

class _MapLoadingCard extends StatelessWidget {
  const _MapLoadingCard();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child:
      const Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(
            height: 10,
          ),
          Text(
            'Loading infrastructure intelligence...',
            style:
            TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MAP BOTTOM NAVIGATION
// ============================================================================

class _MapBottomNavigation extends StatelessWidget {
  final int reportCount;

  final int hotspotCount;

  final VoidCallback onReports;

  final VoidCallback onInsights;

  final VoidCallback onRefresh;

  final bool refreshing;

  const _MapBottomNavigation({
    required this.reportCount,
    required this.hotspotCount,
    required this.onReports,
    required this.onInsights,
    required this.onRefresh,
    required this.refreshing,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      height: 48,
      padding:
      const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 6,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface
            .withOpacity(
          0.97,
        ),
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
        boxShadow:
        <BoxShadow>[
          BoxShadow(
            color:
            Colors.black
                .withOpacity(
              0.20,
            ),
            blurRadius: 14,
            offset:
            const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child:
            _BottomMapAction(
              icon:
              Icons
                  .view_list_rounded,
              text:
              '$reportCount Reports',
              onTap:
              onReports,
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color:
            AppColors.border,
          ),
          Expanded(
            child:
            _BottomMapAction(
              icon:
              Icons
                  .local_fire_department_outlined,
              text:
              '$hotspotCount Hotspots',
              onTap:
              onInsights,
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color:
            AppColors.border,
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              tooltip:
              'Refresh',
              onPressed:
              refreshing
                  ? null
                  : onRefresh,
              icon:
              refreshing
                  ? const SizedBox(
                width: 15,
                height: 15,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons
                    .sync_rounded,
                size: 19,
                color:
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomMapAction extends StatelessWidget {
  final IconData icon;

  final String text;

  final VoidCallback onTap;

  const _BottomMapAction({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(
        10,
      ),
      onTap: onTap,
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 15,
            color:
            AppColors.primary,
          ),
          const SizedBox(
            width: 5,
          ),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              style:
              const TextStyle(
                color:
                Colors.white,
                fontSize: 8,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SELECTED REPORT CARD
// ============================================================================

class _SelectedReportCard extends StatelessWidget {
  final InfrastructureMapReport report;

  final IconData categoryIcon;

  final Color categoryColor;

  final String statusText;

  final Color statusColor;

  final Color priorityColor;

  final String distance;

  final bool showCommunity;

  final VoidCallback onClose;

  final VoidCallback onCenter;

  final VoidCallback onDetails;

  const _SelectedReportCard({
    required this.report,
    required this.categoryIcon,
    required this.categoryColor,
    required this.statusText,
    required this.statusColor,
    required this.priorityColor,
    required this.distance,
    required this.showCommunity,
    required this.onClose,
    required this.onCenter,
    required this.onDetails,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final double progress =
    (report.progressPercentage /
        100)
        .clamp(
      0.0,
      1.0,
    );

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface
            .withOpacity(
          0.98,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border:
        Border.all(
          color:
          categoryColor
              .withOpacity(
            0.42,
          ),
        ),
        boxShadow:
        <BoxShadow>[
          BoxShadow(
            color:
            Colors.black
                .withOpacity(
              0.28,
            ),
            blurRadius: 18,
            offset:
            const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                BoxDecoration(
                  color:
                  categoryColor
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  categoryIcon,
                  color:
                  categoryColor,
                  size: 21,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.category
                          .toUpperCase(),
                      style:
                      TextStyle(
                        color:
                        categoryColor,
                        fontSize: 7.5,
                        fontWeight:
                        FontWeight.w800,
                        letterSpacing:
                        0.7,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      report.title,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w800,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      report.referenceNumber,
                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 7.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 7,
              ),

              InkWell(
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
                onTap:
                onClose,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment:
                  Alignment.center,
                  child:
                  const Icon(
                    Icons.close_rounded,
                    size: 17,
                    color:
                    AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              _StatusPill(
                text:
                statusText,
                color:
                statusColor,
              ),
              const SizedBox(
                width: 6,
              ),
              _StatusPill(
                text:
                report.priority
                    .toUpperCase(),
                color:
                priorityColor,
              ),
              const Spacer(),
              const Icon(
                Icons
                    .near_me_outlined,
                color:
                AppColors.primary,
                size: 13,
              ),
              const SizedBox(
                width: 4,
              ),
              Text(
                distance,
                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 7.5,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons
                    .location_on_outlined,
                color:
                AppColors.primary,
                size: 15,
              ),
              const SizedBox(
                width: 5,
              ),
              Expanded(
                child: Text(
                  report.address,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 8.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              const Text(
                'Progress',
                style:
                TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 7.5,
                ),
              ),
              const Spacer(),
              Text(
                '${report.progressPercentage}%',
                style:
                TextStyle(
                  color:
                  statusColor,
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 5,
          ),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            child:
            LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor:
              AppColors.border,
              color:
              statusColor,
            ),
          ),

          if (showCommunity) ...[
            const SizedBox(
              height: 10,
            ),

            Row(
              children: [
                Expanded(
                  child:
                  _CommunityMiniMetric(
                    icon:
                    Icons.groups_2_outlined,
                    value:
                    '${report.affectedCount}',
                    label:
                    'Affected',
                  ),
                ),
                Expanded(
                  child:
                  _CommunityMiniMetric(
                    icon:
                    Icons
                        .warning_amber_rounded,
                    value:
                    '${report.stillExistsCount}',
                    label:
                    'Still Exists',
                  ),
                ),
                Expanded(
                  child:
                  _CommunityMiniMetric(
                    icon:
                    Icons
                        .task_alt_rounded,
                    value:
                    '${report.looksFixedCount}',
                    label:
                    'Looks Fixed',
                  ),
                ),
                Expanded(
                  child:
                  _CommunityMiniMetric(
                    icon:
                    Icons
                        .collections_outlined,
                    value:
                    '${report.contributionCount}',
                    label:
                    'Evidence',
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(
            height: 11,
          ),

          Row(
            children: [
              SizedBox(
                width: 42,
                height: 39,
                child:
                OutlinedButton(
                  onPressed:
                  onCenter,
                  style:
                  OutlinedButton.styleFrom(
                    padding:
                    EdgeInsets.zero,
                  ),
                  child:
                  const Icon(
                    Icons
                        .center_focus_strong_rounded,
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child:
                FilledButton.icon(
                  onPressed:
                  onDetails,
                  icon:
                  const Icon(
                    Icons
                        .open_in_new_rounded,
                    size: 16,
                  ),
                  label:
                  const Text(
                    'View Full Report Details',
                    style:
                    TextStyle(
                      fontSize: 9,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS PILL
// ============================================================================

class _StatusPill extends StatelessWidget {
  final String text;

  final Color color;

  const _StatusPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration:
      BoxDecoration(
        color:
        color.withOpacity(
          0.09,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            0.28,
          ),
        ),
      ),
      child: Text(
        text,
        style:
        TextStyle(
          color: color,
          fontSize: 6.5,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================================================================
// COMMUNITY MINI METRIC
// ============================================================================

class _CommunityMiniMetric extends StatelessWidget {
  final IconData icon;

  final String value;

  final String label;

  const _CommunityMiniMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12,
              color:
              AppColors.primary,
            ),
            const SizedBox(
              width: 3,
            ),
            Text(
              value,
              style:
              const TextStyle(
                color:
                Colors.white,
                fontSize: 8,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          label,
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style:
          const TextStyle(
            color:
            AppColors.textSecondary,
            fontSize: 6,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SELECTED HOTSPOT
// ============================================================================

class _SelectedHotspotCard extends StatelessWidget {
  final SpatialHotspot hotspot;

  final Color color;

  final VoidCallback onClose;

  final VoidCallback onOpen;

  final VoidCallback onExplain;

  const _SelectedHotspotCard({
    required this.hotspot,
    required this.color,
    required this.onClose,
    required this.onOpen,
    required this.onExplain,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface
            .withOpacity(
          0.98,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            0.55,
          ),
        ),
        boxShadow:
        <BoxShadow>[
          BoxShadow(
            color:
            Colors.black
                .withOpacity(
              0.28,
            ),
            blurRadius: 18,
            offset:
            const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                BoxDecoration(
                  color:
                  color.withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  Icons
                      .local_fire_department_rounded,
                  color: color,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${hotspot.dominantCategory} Hotspot',
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${hotspot.riskLevel} · ${hotspot.reportCount} reports',
                      style:
                      TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${hotspot.riskScore}',
                style:
                TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),

              const Text(
                '/100',
                style:
                TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 7,
                ),
              ),

              const SizedBox(
                width: 5,
              ),

              IconButton(
                onPressed:
                onClose,
                visualDensity:
                VisualDensity.compact,
                icon:
                const Icon(
                  Icons.close_rounded,
                  size: 17,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              Expanded(
                child:
                _HotspotMiniStat(
                  label:
                  'Active',
                  value:
                  '${hotspot.activeCount}',
                ),
              ),
              Expanded(
                child:
                _HotspotMiniStat(
                  label:
                  'Affected',
                  value:
                  '${hotspot.affectedCount}',
                ),
              ),
              Expanded(
                child:
                _HotspotMiniStat(
                  label:
                  'Still Exists',
                  value:
                  '${hotspot.stillExistsCount}',
                ),
              ),
              Expanded(
                child:
                _HotspotMiniStat(
                  label:
                  'Recurring',
                  value:
                  '${hotspot.recurrenceCount}',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          Row(
            children: [
              Icon(
                hotspot.trendLabel ==
                    'Rapidly Increasing' ||
                    hotspot.trendLabel ==
                        'Increasing'
                    ? Icons
                    .trending_up_rounded
                    : hotspot.trendLabel ==
                    'Declining'
                    ? Icons
                    .trending_down_rounded
                    : Icons
                    .trending_flat_rounded,
                color:
                AppColors.primary,
                size: 16,
              ),
              const SizedBox(
                width: 5,
              ),
              Expanded(
                child: Text(
                  '${hotspot.trendLabel} · '
                      '${hotspot.growthPercent >= 0 ? '+' : ''}'
                      '${hotspot.growthPercent.toStringAsFixed(0)}% vs previous period',
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 7.5,
                  ),
                ),
              ),
            ],
          ),

          if (hotspot
              .communityVerificationNeeded) ...[
            const SizedBox(
              height: 7,
            ),
            const Row(
              children: [
                Icon(
                  Icons
                      .fact_check_outlined,
                  size: 14,
                  color:
                  AppColors.warning,
                ),
                SizedBox(
                  width: 5,
                ),
                Text(
                  'Community verification may be needed',
                  style:
                  TextStyle(
                    color:
                    AppColors.warning,
                    fontSize: 7.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              Expanded(
                child:
                OutlinedButton.icon(
                  onPressed:
                  onExplain,
                  icon:
                  const Icon(
                    Icons
                        .help_outline_rounded,
                    size: 15,
                  ),
                  label:
                  const Text(
                    'Why?',
                    style:
                    TextStyle(
                      fontSize: 8.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                flex: 2,
                child:
                FilledButton.icon(
                  onPressed:
                  onOpen,
                  icon:
                  const Icon(
                    Icons
                        .analytics_outlined,
                    size: 15,
                  ),
                  label:
                  const Text(
                    'Open Hotspot Intelligence',
                    style:
                    TextStyle(
                      fontSize: 8.5,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HotspotMiniStat extends StatelessWidget {
  final String label;

  final String value;

  const _HotspotMiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Text(
          value,
          style:
          const TextStyle(
            color:
            Colors.white,
            fontSize: 10,
            fontWeight:
            FontWeight.w800,
          ),
        ),
        Text(
          label,
          style:
          const TextStyle(
            color:
            AppColors.textSecondary,
            fontSize: 6,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SHEET HANDLE
// ============================================================================

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin:
        const EdgeInsets.only(
          top: 10,
          bottom: 14,
        ),
        decoration:
        BoxDecoration(
          color:
          AppColors.border,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration:
          BoxDecoration(
            color:
            AppColors.primary
                .withOpacity(
              0.08,
            ),
            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),
          child: Icon(
            icon,
            color:
            AppColors.primary,
            size: 17,
          ),
        ),
        const SizedBox(
          width: 9,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                subtitle,
                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 7.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// HEALTH OVERVIEW
// ============================================================================

class _HealthOverviewCard extends StatelessWidget {
  final SpatialHealthSummary health;

  final Color color;

  const _HealthOverviewCard({
    required this.health,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            0.30,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,
              color:
              color.withOpacity(
                0.06,
              ),
              border:
              Border.all(
                color: color,
                width: 5,
              ),
            ),
            alignment:
            Alignment.center,
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text(
                  '${health.score}',
                  style:
                  TextStyle(
                    color: color,
                    fontSize: 20,
                    height: 1,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const Text(
                  '/100',
                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Infrastructure Health',
                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 8,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  health.level,
                  style:
                  TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  '${health.activeReports} active · '
                      '${health.resolvedReports} resolved · '
                      '${health.criticalHighReports} high/critical',
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 8,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  'Average progress ${health.averageProgress.toStringAsFixed(0)}%',
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INSIGHT METRIC
// ============================================================================

class _InsightMetricCard extends StatelessWidget {
  final IconData icon;

  final String value;

  final String label;

  final String message;

  final Color color;

  const _InsightMetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.message,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        12,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          15,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            value,
            style:
            TextStyle(
              color: color,
              fontSize: 18,
              fontWeight:
              FontWeight.w900,
            ),
          ),
          Text(
            label,
            style:
            const TextStyle(
              color:
              Colors.white,
              fontSize: 9,
              fontWeight:
              FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            message,
            maxLines: 2,
            overflow:
            TextOverflow.ellipsis,
            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 7,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HOTSPOT SUMMARY
// ============================================================================

class _HotspotSummaryCard extends StatelessWidget {
  final SpatialHotspot hotspot;

  final Color color;

  final VoidCallback onOpen;

  const _HotspotSummaryCard({
    required this.hotspot,
    required this.color,
    required this.onOpen,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(
        16,
      ),
      onTap: onOpen,
      child: Container(
        padding:
        const EdgeInsets.all(
          13,
        ),
        decoration:
        BoxDecoration(
          color:
          AppColors.surface,
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          border:
          Border.all(
            color:
            color.withOpacity(
              0.34,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration:
              BoxDecoration(
                color:
                color.withOpacity(
                  0.10,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                Icons
                    .local_fire_department_rounded,
                color: color,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    hotspot
                        .dominantCategory,
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    '${hotspot.reportCount} reports · '
                        '${hotspot.activeCount} active · '
                        '${hotspot.trendLabel}',
                    style:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${hotspot.riskScore}',
              style:
              TextStyle(
                color: color,
                fontSize: 18,
                fontWeight:
                FontWeight.w900,
              ),
            ),
            const Icon(
              Icons
                  .chevron_right_rounded,
              color:
              AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HOTSPOT COMPARISON
// ============================================================================

class _HotspotComparisonCard extends StatelessWidget {
  final SpatialHotspot first;

  final SpatialHotspot second;

  final Color firstColor;

  final Color secondColor;

  const _HotspotComparisonCard({
    required this.first,
    required this.second,
    required this.firstColor,
    required this.secondColor,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        13,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child: Column(
        children: [
          _ComparisonRow(
            label:
            'Risk',
            first:
            '${first.riskScore}',
            second:
            '${second.riskScore}',
            firstColor:
            firstColor,
            secondColor:
            secondColor,
          ),
          const Divider(
            color:
            AppColors.border,
          ),
          _ComparisonRow(
            label:
            'Reports',
            first:
            '${first.reportCount}',
            second:
            '${second.reportCount}',
          ),
          _ComparisonRow(
            label:
            'Active',
            first:
            '${first.activeCount}',
            second:
            '${second.activeCount}',
          ),
          _ComparisonRow(
            label:
            'Affected',
            first:
            '${first.affectedCount}',
            second:
            '${second.affectedCount}',
          ),
          _ComparisonRow(
            label:
            'Trend',
            first:
            first.trendLabel,
            second:
            second.trendLabel,
          ),
          const SizedBox(
            height: 7,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  first.dominantCategory,
                  textAlign:
                  TextAlign.center,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  TextStyle(
                    color:
                    firstColor,
                    fontSize: 8,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(
                width: 30,
              ),
              Expanded(
                child: Text(
                  second.dominantCategory,
                  textAlign:
                  TextAlign.center,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  TextStyle(
                    color:
                    secondColor,
                    fontSize: 8,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;

  final String first;

  final String second;

  final Color? firstColor;

  final Color? secondColor;

  const _ComparisonRow({
    required this.label,
    required this.first,
    required this.second,
    this.firstColor,
    this.secondColor,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              first,
              textAlign:
              TextAlign.center,
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              style:
              TextStyle(
                color:
                firstColor ??
                    Colors.white,
                fontSize: 8,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              label,
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 7,
              ),
            ),
          ),
          Expanded(
            child: Text(
              second,
              textAlign:
              TextAlign.center,
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              style:
              TextStyle(
                color:
                secondColor ??
                    Colors.white,
                fontSize: 8,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REASON CARD
// ============================================================================

class _ReasonCard extends StatelessWidget {
  final HotspotReason reason;

  const _ReasonCard({
    required this.reason,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final double progress =
    reason.maximum <= 0
        ? 0
        : (reason.points /
        reason.maximum)
        .clamp(
      0.0,
      1.0,
    );

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 9,
      ),
      padding:
      const EdgeInsets.all(
        12,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reason.title,
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${reason.points}/${reason.maximum}',
                style:
                const TextStyle(
                  color:
                  AppColors.primary,
                  fontSize: 9,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 7,
          ),
          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            child:
            LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor:
              AppColors.border,
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            reason.explanation,
            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 8,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// VERIFICATION WARNING
// ============================================================================

class _VerificationWarningCard extends StatelessWidget {
  const _VerificationWarningCard();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        13,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.warning
            .withOpacity(
          0.07,
        ),
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        border:
        Border.all(
          color:
          AppColors.warning
              .withOpacity(
            0.33,
          ),
        ),
      ),
      child:
      const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .fact_check_outlined,
            color:
            AppColors.warning,
            size: 20,
          ),
          SizedBox(
            width: 9,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Verification Needed',
                  style:
                  TextStyle(
                    color:
                    AppColors.warning,
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                SizedBox(
                  height: 4,
                ),
                Text(
                  'Official progress is advanced, but recent community signals '
                      'continue to report that the issue exists. This is an advisory '
                      'signal only and does not change the worker status.',
                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 8,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PILL METRIC
// ============================================================================

class _PillMetric extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;

  const _PillMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          11,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color:
            AppColors.primary,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            value,
            style:
            const TextStyle(
              color:
              Colors.white,
              fontSize: 8,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            label,
            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TREND PANEL
// ============================================================================

class _TrendPanel extends StatelessWidget {
  final String trend;

  final int current;

  final int previous;

  final double growth;

  const _TrendPanel({
    required this.trend,
    required this.current,
    required this.previous,
    required this.growth,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool increasing =
        trend == 'Increasing' ||
            trend ==
                'Rapidly Increasing';

    final bool declining =
        trend == 'Declining';

    final IconData icon =
    increasing
        ? Icons
        .trending_up_rounded
        : declining
        ? Icons
        .trending_down_rounded
        : Icons
        .trending_flat_rounded;

    final Color color =
    increasing
        ? AppColors.warning
        : declining
        ? AppColors.success
        : AppColors.primary;

    return Container(
      padding:
      const EdgeInsets.all(
        13,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          15,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            0.24,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
            BoxDecoration(
              color:
              color.withOpacity(
                0.08,
              ),
              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  trend,
                  style:
                  TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  '$current current period · $previous previous period',
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 7.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${growth >= 0 ? '+' : ''}'
                '${growth.toStringAsFixed(0)}%',
            style:
            TextStyle(
              color: color,
              fontSize: 14,
              fontWeight:
              FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSITION
// ============================================================================

class _CompositionRow extends StatelessWidget {
  final String label;

  final int value;

  final int total;

  const _CompositionRow({
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final double ratio =
    total <= 0
        ? 0
        : value / total;

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 9,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 8,
                  ),
                ),
              ),
              Text(
                '$value · ${(ratio * 100).round()}%',
                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 4,
          ),
          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            child:
            LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor:
              AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPACT REPORT
// ============================================================================

class _CompactReportCard extends StatelessWidget {
  final InfrastructureMapReport report;

  final String statusText;

  final Color statusColor;

  final Color priorityColor;

  final VoidCallback onTap;

  const _CompactReportCard({
    required this.report,
    required this.statusText,
    required this.statusColor,
    required this.priorityColor,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color:
      AppColors.surface,
      borderRadius:
      BorderRadius.circular(
        13,
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        onTap: onTap,
        child: Container(
          padding:
          const EdgeInsets.all(
            11,
          ),
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              13,
            ),
            border:
            Border.all(
              color:
              AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration:
                BoxDecoration(
                  color:
                  statusColor
                      .withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  Icons
                      .location_on_outlined,
                  color:
                  statusColor,
                  size: 17,
                ),
              ),
              const SizedBox(
                width: 9,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 9,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${report.referenceNumber} · $statusText',
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 7,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                decoration:
                BoxDecoration(
                  color:
                  priorityColor
                      .withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
                child: Text(
                  report.priority,
                  style:
                  TextStyle(
                    color:
                    priorityColor,
                    fontSize: 6.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// NEARBY HEALTH CARD
// ============================================================================

class _NearbyHealthCard extends StatelessWidget {
  final SpatialHealthSummary health;

  final int reportCount;

  final String dominantCategory;

  final String closestDistance;

  final Color color;

  const _NearbyHealthCard({
    required this.health,
    required this.reportCount,
    required this.dominantCategory,
    required this.closestDistance,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            0.28,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  border:
                  Border.all(
                    color: color,
                    width: 4,
                  ),
                ),
                alignment:
                Alignment.center,
                child: Text(
                  '${health.score}',
                  style:
                  TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Area',
                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 8,
                      ),
                    ),
                    Text(
                      health.level,
                      style:
                      TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '$reportCount reports · ${health.activeReports} active',
                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 11,
          ),
          Row(
            children: [
              Expanded(
                child:
                _SimpleInfo(
                  label:
                  'Dominant Issue',
                  value:
                  dominantCategory,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color:
                AppColors.border,
              ),
              Expanded(
                child:
                _SimpleInfo(
                  label:
                  'Closest Issue',
                  value:
                  closestDistance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleInfo extends StatelessWidget {
  final String label;

  final String value;

  const _SimpleInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Text(
          label,
          style:
          const TextStyle(
            color:
            AppColors.textSecondary,
            fontSize: 7,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          value,
          textAlign:
          TextAlign.center,
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style:
          const TextStyle(
            color:
            Colors.white,
            fontSize: 8,
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// NEARBY REPORT ROW
// ============================================================================

class _NearbyReportRow extends StatelessWidget {
  final NearbyInfrastructureReport item;

  final IconData categoryIcon;

  final Color statusColor;

  final VoidCallback onTap;

  final VoidCallback onDetails;

  const _NearbyReportRow({
    required this.item,
    required this.categoryIcon,
    required this.statusColor,
    required this.onTap,
    required this.onDetails,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        10,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
            BoxDecoration(
              color:
              statusColor
                  .withOpacity(
                0.08,
              ),
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              categoryIcon,
              color:
              statusColor,
              size: 18,
            ),
          ),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    item.report.title,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontSize: 9,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    '${item.distanceLabel} · '
                        '${item.report.category}',
                    style:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip:
            'Full Details',
            onPressed:
            onDetails,
            icon:
            const Icon(
              Icons
                  .open_in_new_rounded,
              color:
              AppColors.primary,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REPORT LIST CARD
// ============================================================================

class _ReportListCard extends StatelessWidget {
  final InfrastructureMapReport report;

  final IconData categoryIcon;

  final String statusText;

  final Color statusColor;

  final Color priorityColor;

  final String distance;

  final VoidCallback onMap;

  final VoidCallback onDetails;

  const _ReportListCard({
    required this.report,
    required this.categoryIcon,
    required this.statusText,
    required this.statusColor,
    required this.priorityColor,
    required this.distance,
    required this.onMap,
    required this.onDetails,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        13,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  color:
                  statusColor
                      .withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  categoryIcon,
                  color:
                  statusColor,
                  size: 20,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 10,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${report.referenceNumber} · $distance',
                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 7,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 7,
              ),

              _StatusPill(
                text:
                report.priority
                    .toUpperCase(),
                color:
                priorityColor,
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          Row(
            children: [
              _StatusPill(
                text:
                statusText,
                color:
                statusColor,
              ),
              const Spacer(),
              Text(
                '${report.progressPercentage}%',
                style:
                const TextStyle(
                  color:
                  AppColors.primary,
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 7,
          ),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            child:
            LinearProgressIndicator(
              value:
              (report.progressPercentage /
                  100)
                  .clamp(
                0.0,
                1.0,
              ),
              minHeight: 4,
              backgroundColor:
              AppColors.border,
              color:
              statusColor,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              Expanded(
                child:
                OutlinedButton.icon(
                  onPressed:
                  onMap,
                  icon:
                  const Icon(
                    Icons
                        .map_outlined,
                    size: 15,
                  ),
                  label:
                  const Text(
                    'Map',
                    style:
                    TextStyle(
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                flex: 2,
                child:
                FilledButton.icon(
                  onPressed:
                  onDetails,
                  icon:
                  const Icon(
                    Icons
                        .open_in_new_rounded,
                    size: 15,
                  ),
                  label:
                  const Text(
                    'Full Report Details',
                    style:
                    TextStyle(
                      fontSize: 8,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LAYER SWITCH
// ============================================================================

class _LayerSwitch extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  final bool value;

  final ValueChanged<bool>
  onChanged;

  const _LayerSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 7,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged:
        onChanged,
        secondary: Icon(
          icon,
          color:
          value
              ? AppColors.primary
              : AppColors
              .textSecondary,
        ),
        title: Text(
          title,
          style:
          const TextStyle(
            color:
            Colors.white,
            fontSize: 10,
            fontWeight:
            FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style:
          const TextStyle(
            color:
            AppColors.textSecondary,
            fontSize: 7,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAP STYLE BUTTON
// ============================================================================

class _MapStyleButton extends StatelessWidget {
  final bool selected;

  final IconData icon;

  final String label;

  final VoidCallback onTap;

  const _MapStyleButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(
        12,
      ),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration:
        BoxDecoration(
          color:
          selected
              ? AppColors.primary
              .withOpacity(
            0.10,
          )
              : AppColors.surface,
          borderRadius:
          BorderRadius.circular(
            12,
          ),
          border:
          Border.all(
            color:
            selected
                ? AppColors.primary
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color:
              selected
                  ? AppColors.primary
                  : AppColors
                  .textSecondary,
            ),
            const SizedBox(
              width: 6,
            ),
            Text(
              label,
              style:
              TextStyle(
                color:
                selected
                    ? AppColors.primary
                    : Colors.white,
                fontSize: 9,
                fontWeight:
                selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY SHEET STATE
// ============================================================================

class _EmptySheetState extends StatelessWidget {
  final IconData icon;

  final String title;

  final String message;

  const _EmptySheetState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 35,
        horizontal: 20,
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration:
            BoxDecoration(
              color:
              AppColors.surface,
              shape:
              BoxShape.circle,
              border:
              Border.all(
                color:
                AppColors.border,
              ),
            ),
            child: Icon(
              icon,
              color:
              AppColors.textSecondary,
              size: 27,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            title,
            style:
            const TextStyle(
              color:
              Colors.white,
              fontSize: 12,
              fontWeight:
              FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            message,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}