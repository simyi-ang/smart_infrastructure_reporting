import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/infrastructure_map_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';

class InfrastructureMapScreen
    extends StatefulWidget {
  const InfrastructureMapScreen({
    super.key,
  });

  @override
  State<InfrastructureMapScreen>
  createState() =>
      _InfrastructureMapScreenState();
}

class _InfrastructureMapScreenState
    extends State<InfrastructureMapScreen> {
  final InfrastructureMapService
  mapService =
  InfrastructureMapService();

  final LocationService locationService =
  LocationService();

  GoogleMapController? mapController;

  List<InfrastructureMapReport> reports =
  [];

  bool loading = true;

  bool locatingUser = false;

  String selectedCategory = 'All';

  double? userLatitude;
  double? userLongitude;

  InfrastructureMapReport? selectedReport;

  final List<String> categories = const [
    'All',
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  static const LatLng malaysiaDefault =
  LatLng(
    3.1390,
    101.6869,
  );

  @override
  void initState() {
    super.initState();

    loadMap();
  }

  // ============================================================
  // LOAD MAP
  // ============================================================

  Future<void> loadMap() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      final List<InfrastructureMapReport>
      result =
      await mapService
          .getMapReports();

      if (!mounted) {
        return;
      }

      setState(() {
        reports = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // FILTERED REPORTS
  // ============================================================

  List<InfrastructureMapReport>
  get filteredReports {
    if (selectedCategory == 'All') {
      return reports;
    }

    return reports
        .where(
          (report) =>
      report.category ==
          selectedCategory,
    )
        .toList();
  }

  // ============================================================
  // MARKERS
  // ============================================================

  Set<Marker> get reportMarkers {
    return filteredReports
        .map(
          (
          InfrastructureMapReport report,
          ) {
        return Marker(
          markerId:
          MarkerId(
            report.id,
          ),

          position:
          LatLng(
            report.latitude,
            report.longitude,
          ),

          icon:
          markerColorForCategory(
            report.category,
          ),

          infoWindow:
          InfoWindow(
            title:
            report.title,

            snippet:
            report.referenceNumber,
          ),

          onTap:
              () {
            setState(() {
              selectedReport =
                  report;
            });
          },
        );
      },
    )
        .toSet();
  }

  // ============================================================
  // MARKER COLOR BY CATEGORY
  // ============================================================

  BitmapDescriptor markerColorForCategory(
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

  // ============================================================
  // CATEGORY ICON
  // ============================================================

  String categoryEmoji(
      String category,
      ) {
    switch (category) {
      case 'Road Damage':
        return '🛣️';

      case 'Street Light':
        return '💡';

      case 'Drainage':
        return '🌊';

      case 'Public Facility':
        return '🏗️';

      default:
        return '📌';
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(
      String status,
      ) {
    switch (status) {
      case 'completed':
        return AppColors.success;

      case 'rejected':
        return AppColors.danger;

      case 'pending':
        return AppColors.warning;

      default:
        return AppColors.primary;
    }
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String statusText(
      String status,
      ) {
    switch (status) {
      case 'verified':
        return 'VERIFIED';

      case 'in_progress':
        return 'IN PROGRESS';

      case 'completed':
        return 'COMPLETED';

      case 'rejected':
        return 'REJECTED';

      default:
        return 'PENDING';
    }
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> goToCurrentLocation() async {
    if (locatingUser) {
      return;
    }

    setState(() {
      locatingUser = true;
    });

    try {
      final result =
      await locationService
          .getCurrentLocationWithAddress();

      userLatitude =
          result.latitude;

      userLongitude =
          result.longitude;

      final LatLng position =
      LatLng(
        result.latitude,
        result.longitude,
      );

      await mapController
          ?.animateCamera(
        CameraUpdate.newLatLngZoom(
          position,
          15,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          locatingUser = false;
        });
      }
    }
  }

  // ============================================================
  // DISTANCE FROM USER
  // ============================================================

  String distanceFromUser(
      InfrastructureMapReport report,
      ) {
    final double? lat =
        userLatitude;

    final double? lng =
        userLongitude;

    if (lat == null ||
        lng == null) {
      return 'Tap location button to calculate distance';
    }

    final double meters =
    Geolocator.distanceBetween(
      lat,
      lng,
      report.latitude,
      report.longitude,
    );

    if (meters < 1000) {
      return '${meters.round()} m away';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  // ============================================================
  // MOVE TO REPORT
  // ============================================================

  Future<void> focusReport(
      InfrastructureMapReport report,
      ) async {
    setState(() {
      selectedReport =
          report;
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

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                10,
              ),

              child: Row(
                children: [
                  Container(
                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.surface,

                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors.border,
                      ),
                    ),

                    child:
                    IconButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },

                      icon:
                      const Icon(
                        Icons.arrow_back,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Infrastructure Map',

                          style:
                          TextStyle(
                            fontSize: 21,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        Text(
                          'Explore reported infrastructure issues',

                          style:
                          TextStyle(
                            color:
                            AppColors.textSecondary,

                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed:
                    loadMap,

                    icon:
                    const Icon(
                      Icons.refresh,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CATEGORY FILTER
            // ==================================================

            SizedBox(
              height: 43,

              child:
              ListView.separated(
                scrollDirection:
                Axis.horizontal,

                padding:
                const EdgeInsets.symmetric(
                  horizontal: 14,
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
                    context,
                    index,
                    ) {
                  final String category =
                  categories[index];

                  final bool selected =
                      selectedCategory ==
                          category;

                  return GestureDetector(
                    onTap:
                        () {
                      setState(() {
                        selectedCategory =
                            category;

                        selectedReport =
                        null;
                      });
                    },

                    child:
                    AnimatedContainer(
                      duration:
                      const Duration(
                        milliseconds: 150,
                      ),

                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        selected
                            ? AppColors.primary
                            .withOpacity(
                          0.12,
                        )
                            : AppColors.surface,

                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),

                        border:
                        Border.all(
                          color:
                          selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),

                      child:
                      Text(
                        category,

                        style:
                        TextStyle(
                          color:
                          selected
                              ? AppColors.primary
                              : AppColors.textSecondary,

                          fontSize: 9,

                          fontWeight:
                          selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            // ==================================================
            // MAP
            // ==================================================

            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition:
                    const CameraPosition(
                      target:
                      malaysiaDefault,

                      zoom:
                      11,
                    ),

                    markers:
                    reportMarkers,

                    myLocationEnabled:
                    userLatitude != null,

                    myLocationButtonEnabled:
                    false,

                    zoomControlsEnabled:
                    false,

                    compassEnabled:
                    true,

                    onMapCreated:
                        (
                        GoogleMapController controller,
                        ) {
                      mapController =
                          controller;
                    },

                    onTap:
                        (_) {
                      setState(() {
                        selectedReport =
                        null;
                      });
                    },
                  ),

                  // ============================================
                  // LOADING
                  // ============================================

                  if (loading)
                    Container(
                      color:
                      Colors.black
                          .withOpacity(
                        0.25,
                      ),

                      child:
                      const Center(
                        child:
                        CircularProgressIndicator(),
                      ),
                    ),

                  // ============================================
                  // REPORT COUNT
                  // ============================================

                  Positioned(
                    left: 14,
                    top: 14,

                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.surface
                            .withOpacity(
                          0.95,
                        ),

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

                      child: Text(
                        '${filteredReports.length} report${filteredReports.length == 1 ? '' : 's'}',

                        style:
                        const TextStyle(
                          fontSize: 9,

                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // ============================================
                  // CURRENT LOCATION
                  // ============================================

                  Positioned(
                    right: 14,
                    bottom:
                    selectedReport ==
                        null
                        ? 20
                        : 210,

                    child:
                    FloatingActionButton(
                      heroTag:
                      'map_current_location',

                      mini: true,

                      backgroundColor:
                      AppColors.primaryDark,

                      onPressed:
                      locatingUser
                          ? null
                          : goToCurrentLocation,

                      child:
                      locatingUser
                          ? const Padding(
                        padding:
                        EdgeInsets.all(
                          10,
                        ),

                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,

                          color:
                          Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons.my_location,
                      ),
                    ),
                  ),

                  // ============================================
                  // SELECTED REPORT CARD
                  // ============================================

                  if (selectedReport !=
                      null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,

                      child:
                      _SelectedReportCard(
                        report:
                        selectedReport!,

                        categoryEmoji:
                        categoryEmoji(
                          selectedReport!
                              .category,
                        ),

                        statusText:
                        statusText(
                          selectedReport!
                              .status,
                        ),

                        statusColor:
                        statusColor(
                          selectedReport!
                              .status,
                        ),

                        distanceText:
                        distanceFromUser(
                          selectedReport!,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ==================================================
            // NEARBY REPORT LIST
            // ==================================================

            Container(
              height: 120,

              decoration:
              const BoxDecoration(
                color:
                AppColors.background,

                border:
                Border(
                  top:
                  BorderSide(
                    color:
                    AppColors.border,
                  ),
                ),
              ),

              child:
              filteredReports.isEmpty
                  ? const Center(
                child: Text(
                  'No infrastructure reports found for this category.',

                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,

                    fontSize: 10,
                  ),
                ),
              )
                  : ListView.separated(
                scrollDirection:
                Axis.horizontal,

                padding:
                const EdgeInsets.all(
                  10,
                ),

                itemCount:
                filteredReports.length,

                separatorBuilder:
                    (
                    _,
                    __,
                    ) =>
                const SizedBox(
                  width: 9,
                ),

                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final report =
                  filteredReports[index];

                  return GestureDetector(
                    onTap: () {
                      focusReport(
                        report,
                      );
                    },

                    child:
                    Container(
                      width: 195,

                      padding:
                      const EdgeInsets.all(
                        11,
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

                      child:
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          Text(
                            categoryEmoji(
                              report.category,
                            ),

                            style:
                            const TextStyle(
                              fontSize: 20,
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child:
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,

                              children: [
                                Text(
                                  report.title,

                                  maxLines: 2,

                                  overflow:
                                  TextOverflow.ellipsis,

                                  style:
                                  const TextStyle(
                                    fontSize: 10,

                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                const Spacer(),

                                Text(
                                  distanceFromUser(
                                    report,
                                  ),

                                  maxLines: 1,

                                  overflow:
                                  TextOverflow.ellipsis,

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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// SELECTED REPORT CARD
// =================================================================

class _SelectedReportCard
    extends StatelessWidget {
  final InfrastructureMapReport report;

  final String categoryEmoji;

  final String statusText;

  final Color statusColor;

  final String distanceText;

  const _SelectedReportCard({
    required this.report,
    required this.categoryEmoji,
    required this.statusText,
    required this.statusColor,
    required this.distanceText,
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
          AppColors.primaryDark,
        ),

        boxShadow:
        const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(
              0,
              3,
            ),
          ),
        ],
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,

                alignment:
                Alignment.center,

                decoration:
                BoxDecoration(
                  color:
                  statusColor.withOpacity(
                    0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child:
                Text(
                  categoryEmoji,

                  style:
                  const TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                Column(
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
                        fontSize: 12,

                        fontWeight:
                        FontWeight.bold,
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
                        AppColors.primary,

                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),

                decoration:
                BoxDecoration(
                  color:
                  statusColor.withOpacity(
                    0.1,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),

                child:
                Text(
                  statusText,

                  style:
                  TextStyle(
                    color:
                    statusColor,

                    fontSize: 7,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            '📍 ${report.address}',

            maxLines: 2,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize: 9,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Row(
            children: [
              const Icon(
                Icons.near_me_outlined,

                color:
                AppColors.primary,

                size: 14,
              ),

              const SizedBox(
                width: 5,
              ),

              Expanded(
                child:
                Text(
                  distanceText,

                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,

                    fontSize: 9,
                  ),
                ),
              ),

              Text(
                report.category,

                style:
                const TextStyle(
                  color:
                  AppColors.primary,

                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}