import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/nearby_report.dart';
import '../../models/report_image_ai_analysis.dart';
import '../../services/location_service.dart';
import '../../services/nearby_report_service.dart';
import '../../theme/app_colors.dart';

import 'map_picker_screen.dart';
import 'report_preview_screen.dart';

class CreateReportLocationScreen
    extends StatefulWidget {
  final String category;

  final String priority;

  final String title;

  final String description;

  final List<File> evidenceImages;

  // ============================================================
  // AI SMART ASSIST RESULT
  //
  // Optional so the existing manual reporting flow still works
  // when AI is unavailable or no analysis was completed.
  // ============================================================

  final ReportImageAiAnalysis? aiAnalysis;

  const CreateReportLocationScreen({
    super.key,
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    required this.evidenceImages,
    this.aiAnalysis,
  });

  @override
  State<CreateReportLocationScreen>
  createState() =>
      _CreateReportLocationScreenState();
}

class _CreateReportLocationScreenState
    extends State<CreateReportLocationScreen> {
  final LocationService locationService =
  LocationService();

  final NearbyReportService nearbyReportService =
  NearbyReportService();

  final TextEditingController
  addressController =
  TextEditingController();

  final TextEditingController
  landmarkController =
  TextEditingController();

  double? latitude;

  double? longitude;

  // GPS accuracy in metres. This is only available when
  // the location came from the phone/emulator GPS.
  double? gpsAccuracy;

  bool gettingLocation = false;

  bool locationDetected = false;

  bool checkingNearby = false;

  List<NearbyReport> nearbyReports = [];

  NearbyReport? possibleDuplicate;

  // ============================================================
  // GET CURRENT LOCATION
  // ============================================================

  Future<void> detectCurrentLocation() async {
    if (gettingLocation) {
      return;
    }

    setState(() {
      gettingLocation = true;
    });

    try {
      final result =
      await locationService
          .getCurrentLocationWithAddress();

      if (!mounted) {
        return;
      }

      setState(() {
        latitude =
            result.latitude;

        longitude =
            result.longitude;

        gpsAccuracy =
            result.accuracy;

        addressController.text =
            result.address;

        locationDetected =
        true;
      });

      await checkNearbyReports();

      if (!mounted) {
        return;
      }

      if (result.accuracy > 50) {
        showMessage(
          'Location detected, but GPS accuracy is low '
              '(±${result.accuracy.toStringAsFixed(0)} m). '
              'You can use Choose on Map to adjust the exact point.',
        );
      } else {
        showMessage(
          'Location detected successfully.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      await showLocationErrorDialog(
        message,
      );
    } finally {
      if (mounted) {
        setState(() {
          gettingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // MAP PICKER
  // ============================================================

  Future<void> openMapPicker() async {
    double startingLatitude =
        latitude ??
            3.1390;

    double startingLongitude =
        longitude ??
            101.6869;

    if (latitude == null ||
        longitude == null) {
      try {
        final result =
        await locationService
            .getCurrentLocationWithAddress();

        startingLatitude =
            result.latitude;

        startingLongitude =
            result.longitude;
      } catch (_) {
        // Kuala Lumpur fallback for map starting position only.
      }
    }

    if (!mounted) {
      return;
    }

    final MapPickerResult? result =
    await Navigator.push<MapPickerResult>(
      context,

      MaterialPageRoute(
        builder: (_) =>
            MapPickerScreen(
              initialLatitude:
              startingLatitude,

              initialLongitude:
              startingLongitude,
            ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      latitude =
          result.latitude;

      longitude =
          result.longitude;

      gpsAccuracy =
      null;

      addressController.text =
          result.address;

      locationDetected =
      true;
    });

    await checkNearbyReports();
  }

  // ============================================================
  // NEARBY REPORTS
  // ============================================================

  Future<void> checkNearbyReports() async {
    final double? currentLatitude =
        latitude;

    final double? currentLongitude =
        longitude;

    if (currentLatitude == null ||
        currentLongitude == null) {
      return;
    }

    setState(() {
      checkingNearby = true;
    });

    try {
      final List<NearbyReport> reports =
      await nearbyReportService
          .getNearbyReports(
        latitude:
        currentLatitude,

        longitude:
        currentLongitude,

        category:
        widget.category,

        radiusMeters:
        500,
      );

      NearbyReport? duplicate;

      for (final report in reports) {
        if (report.distanceMeters <=
            100) {
          duplicate =
              report;

          break;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        nearbyReports =
            reports;

        possibleDuplicate =
            duplicate;

        checkingNearby =
        false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        nearbyReports = [];

        possibleDuplicate = null;

        checkingNearby = false;
      });
    }
  }

  // ============================================================
  // LOCATION ERROR
  // ============================================================

  Future<void> showLocationErrorDialog(
      String message,
      ) async {
    await showDialog<void>(
      context:
      context,

      builder:
          (dialogContext) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,

          title:
          const Row(
            children: [
              Icon(
                Icons
                    .location_off_outlined,

                color:
                AppColors.warning,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Text(
                  'Location Unavailable',
                ),
              ),
            ],
          ),

          content:
          Text(
            message,
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'Cancel',
              ),
            ),

            TextButton(
              onPressed:
                  () async {
                Navigator.pop(
                  dialogContext,
                );

                await locationService
                    .openLocationSettings();
              },

              child:
              const Text(
                'Location Settings',
              ),
            ),

            TextButton(
              onPressed:
                  () async {
                Navigator.pop(
                  dialogContext,
                );

                await locationService
                    .openAppSettings();
              },

              child:
              const Text(
                'App Settings',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PREVIEW
  // ============================================================

  Future<void> previewReport() async {
    final String address =
    addressController.text.trim();

    if (address.isEmpty) {
      showMessage(
        'Please detect, select or enter the issue location.',
      );

      return;
    }

    if (latitude == null ||
        longitude == null) {
      final bool? continueWithoutGps =
      await showDialog<bool>(
        context:
        context,

        builder:
            (dialogContext) {
          return AlertDialog(
            backgroundColor:
            AppColors.surface,

            title:
            const Text(
              'No GPS Coordinates',
            ),

            content:
            const Text(
              'You entered an address manually, but no GPS coordinates are attached. '
                  'Using the map or GPS is recommended for accurate issue tracking.',
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },

                child:
                const Text(
                  'Choose Location',
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },

                child:
                const Text(
                  'Continue',
                ),
              ),
            ],
          );
        },
      );

      if (continueWithoutGps !=
          true) {
        return;
      }
    }

    if (possibleDuplicate != null) {
      final bool? continueDuplicate =
      await _showDuplicateWarning();

      if (continueDuplicate !=
          true) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
            ReportPreviewScreen(
              category:
              widget.category,

              priority:
              widget.priority,

              title:
              widget.title,

              description:
              widget.description,

              evidenceImages:
              widget.evidenceImages,

              address:
              address,

              landmark:
              landmarkController.text
                  .trim(),

              latitude:
              latitude,

              longitude:
              longitude,

              aiAnalysis:
              widget.aiAnalysis,
            ),
      ),
    );
  }

  // ============================================================
  // DUPLICATE WARNING
  // ============================================================

  Future<bool?>
  _showDuplicateWarning() {
    final NearbyReport? report =
        possibleDuplicate;

    if (report == null) {
      return Future.value(
        true,
      );
    }

    return showDialog<bool>(
      context:
      context,

      builder:
          (dialogContext) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,

          title:
          const Row(
            children: [
              Icon(
                Icons
                    .warning_amber_rounded,

                color:
                AppColors.warning,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Text(
                  'Possible Duplicate',
                ),
              ),
            ],
          ),

          content:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              const Text(
                'A similar infrastructure issue has already been reported very close to this location.',
              ),

              const SizedBox(
                height:
                14,
              ),

              Text(
                report.title,

                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                5,
              ),

              Text(
                report.referenceNumber,

                style:
                const TextStyle(
                  color:
                  AppColors.primary,
                ),
              ),

              const SizedBox(
                height:
                5,
              ),

              Text(
                report.distanceText,

                style:
                const TextStyle(
                  color:
                  AppColors
                      .textSecondary,
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
              const Text(
                'Go Back',
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
              const Text(
                'Submit Anyway',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // GPS ACCURACY DISPLAY
  // ============================================================

  String get _gpsAccuracyText {
    final double? accuracy =
        gpsAccuracy;

    if (accuracy == null) {
      return 'Unavailable';
    }

    if (accuracy <= 10) {
      return 'Excellent • ±${accuracy.toStringAsFixed(0)} m';
    }

    if (accuracy <= 25) {
      return 'Good • ±${accuracy.toStringAsFixed(0)} m';
    }

    if (accuracy <= 50) {
      return 'Moderate • ±${accuracy.toStringAsFixed(0)} m';
    }

    return 'Low • ±${accuracy.toStringAsFixed(0)} m';
  }

  Color get _gpsAccuracyColor {
    final double? accuracy =
        gpsAccuracy;

    if (accuracy == null) {
      return AppColors.textSecondary;
    }

    if (accuracy <= 25) {
      return AppColors.success;
    }

    if (accuracy <= 50) {
      return AppColors.warning;
    }

    return AppColors.danger;
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

  @override
  void dispose() {
    addressController.dispose();

    landmarkController.dispose();

    super.dispose();
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

      body:
      SafeArea(
        child:
        Column(
          children: [
            Expanded(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.all(
                  20,
                ),

                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    // ==========================================
                    // HEADER
                    // ==========================================

                    Row(
                      children: [
                        Container(
                          decoration:
                          BoxDecoration(
                            color:
                            AppColors
                                .surface,

                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),

                            border:
                            Border.all(
                              color:
                              AppColors
                                  .border,
                            ),
                          ),

                          child:
                          IconButton(
                            onPressed:
                                () {
                              Navigator.pop(
                                context,
                              );
                            },

                            icon:
                            const Icon(
                              Icons
                                  .arrow_back,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width:
                          14,
                        ),

                        const Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            Text(
                              'Report Issue',

                              style:
                              TextStyle(
                                fontSize:
                                22,

                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            SizedBox(
                              height:
                              2,
                            ),

                            Text(
                              'Set issue location',

                              style:
                              TextStyle(
                                color:
                                AppColors
                                    .textSecondary,

                                fontSize:
                                12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                      18,
                    ),

                    const _LocationProgress(),

                    const SizedBox(
                      height:
                      24,
                    ),

                    // ==========================================
                    // GPS
                    // ==========================================

                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets.all(
                        18,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.surface,

                        borderRadius:
                        BorderRadius
                            .circular(
                          18,
                        ),

                        border:
                        Border.all(
                          color:
                          locationDetected
                              ? AppColors
                              .success
                              : AppColors
                              .primaryDark,
                        ),
                      ),

                      child:
                      Column(
                        children: [
                          Container(
                            width:
                            70,

                            height:
                            70,

                            decoration:
                            BoxDecoration(
                              color:
                              AppColors
                                  .primary
                                  .withOpacity(
                                0.1,
                              ),

                              shape:
                              BoxShape.circle,
                            ),

                            child:
                            const Icon(
                              Icons
                                  .my_location_outlined,

                              size:
                              35,

                              color:
                              AppColors
                                  .primary,
                            ),
                          ),

                          const SizedBox(
                            height:
                            14,
                          ),

                          Text(
                            locationDetected
                                ? 'Location Selected'
                                : 'Choose Issue Location',

                            style:
                            const TextStyle(
                              fontSize:
                              16,

                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),

                          const SizedBox(
                            height:
                            6,
                          ),

                          const Text(
                            'Use GPS or choose the exact issue location from the map.',

                            textAlign:
                            TextAlign.center,

                            style:
                            TextStyle(
                              color:
                              AppColors
                                  .textSecondary,

                              fontSize:
                              11,

                              height:
                              1.4,
                            ),
                          ),

                          const SizedBox(
                            height:
                            16,
                          ),

                          SizedBox(
                            width:
                            double.infinity,

                            child:
                            ElevatedButton.icon(
                              style:
                              ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                AppColors
                                    .primaryDark,

                                minimumSize:
                                const Size
                                    .fromHeight(
                                  48,
                                ),
                              ),

                              onPressed:
                              gettingLocation
                                  ? null
                                  : detectCurrentLocation,

                              icon:
                              gettingLocation
                                  ? const SizedBox(
                                width:
                                18,

                                height:
                                18,

                                child:
                                CircularProgressIndicator(
                                  strokeWidth:
                                  2,

                                  color:
                                  Colors.white,
                                ),
                              )
                                  : const Icon(
                                Icons
                                    .gps_fixed,
                              ),

                              label:
                              Text(
                                gettingLocation
                                    ? 'Detecting...'
                                    : 'Use Current GPS',
                              ),
                            ),
                          ),

                          const SizedBox(
                            height:
                            10,
                          ),

                          SizedBox(
                            width:
                            double.infinity,

                            child:
                            OutlinedButton.icon(
                              onPressed:
                              openMapPicker,

                              icon:
                              const Icon(
                                Icons
                                    .map_outlined,
                              ),

                              label:
                              const Text(
                                'Choose on Map',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==========================================
                    // COORDINATES
                    // ==========================================

                    if (latitude != null &&
                        longitude != null) ...[
                      const SizedBox(
                        height:
                        12,
                      ),

                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets.all(
                          12,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          AppColors.success
                              .withOpacity(
                            0.07,
                          ),

                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),

                          border:
                          Border.all(
                            color:
                            AppColors.success
                                .withOpacity(
                              0.5,
                            ),
                          ),
                        ),

                        child:
                        Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .check_circle_outline,

                                  color:
                                  AppColors
                                      .success,

                                  size:
                                  18,
                                ),

                                const SizedBox(
                                  width:
                                  9,
                                ),

                                Expanded(
                                  child:
                                  Text(
                                    '${latitude!.toStringAsFixed(6)}, '
                                        '${longitude!.toStringAsFixed(6)}',

                                    style:
                                    const TextStyle(
                                      color:
                                      AppColors
                                          .textSecondary,

                                      fontSize:
                                      10,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (gpsAccuracy != null) ...[
                              const SizedBox(
                                height:
                                8,
                              ),

                              Row(
                                children: [
                                  Icon(
                                    Icons.gps_fixed,

                                    color:
                                    _gpsAccuracyColor,
                                    size:
                                    16,
                                  ),

                                  const SizedBox(
                                    width:
                                    8,
                                  ),

                                  Expanded(
                                    child:
                                    Text(
                                      'GPS Accuracy: $_gpsAccuracyText',

                                      style:
                                      TextStyle(
                                        color:
                                        _gpsAccuracyColor,
                                        fontSize:
                                        9,
                                        fontWeight:
                                        FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // ==========================================
                    // NEARBY CHECK
                    // ==========================================

                    if (checkingNearby) ...[
                      const SizedBox(
                        height:
                        12,
                      ),

                      const LinearProgressIndicator(),
                    ],

                    if (!checkingNearby &&
                        nearbyReports.isNotEmpty) ...[
                      const SizedBox(
                        height:
                        12,
                      ),

                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets.all(
                          13,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          possibleDuplicate !=
                              null
                              ? AppColors
                              .warning
                              .withOpacity(
                            0.07,
                          )
                              : AppColors
                              .primary
                              .withOpacity(
                            0.05,
                          ),

                          borderRadius:
                          BorderRadius
                              .circular(
                            13,
                          ),

                          border:
                          Border.all(
                            color:
                            possibleDuplicate !=
                                null
                                ? AppColors
                                .warning
                                : AppColors
                                .primaryDark,
                          ),
                        ),

                        child:
                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            Icon(
                              possibleDuplicate !=
                                  null
                                  ? Icons
                                  .warning_amber_rounded
                                  : Icons
                                  .info_outline,

                              color:
                              possibleDuplicate !=
                                  null
                                  ? AppColors
                                  .warning
                                  : AppColors
                                  .primary,
                            ),

                            const SizedBox(
                              width:
                              9,
                            ),

                            Expanded(
                              child:
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                                children: [
                                  Text(
                                    possibleDuplicate !=
                                        null
                                        ? 'Possible Duplicate Detected'
                                        : '${nearbyReports.length} similar issue(s) nearby',

                                    style:
                                    const TextStyle(
                                      fontWeight:
                                      FontWeight
                                          .bold,

                                      fontSize:
                                      11,
                                    ),
                                  ),

                                  if (nearbyReports
                                      .isNotEmpty) ...[
                                    const SizedBox(
                                      height:
                                      4,
                                    ),

                                    Text(
                                      'Closest: ${nearbyReports.first.title} • '
                                          '${nearbyReports.first.distanceText}',

                                      style:
                                      const TextStyle(
                                        color:
                                        AppColors
                                            .textSecondary,

                                        fontSize:
                                        9,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(
                      height:
                      23,
                    ),

                    // ==========================================
                    // ADDRESS
                    // ==========================================

                    const _FieldLabel(
                      'ADDRESS',
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    TextField(
                      controller:
                      addressController,

                      minLines:
                      2,

                      maxLines:
                      3,

                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                      ),

                      decoration:
                      _inputDecoration(
                        hint:
                        'Detect GPS, choose map or enter address manually',

                        prefixIcon:
                        const Icon(
                          Icons
                              .location_on_outlined,

                          color:
                          AppColors
                              .primary,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    // ==========================================
                    // LANDMARK
                    // ==========================================

                    const _FieldLabel(
                      'ADDITIONAL LANDMARK',
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    TextField(
                      controller:
                      landmarkController,

                      decoration:
                      _inputDecoration(
                        hint:
                        'e.g. opposite Maybank, near traffic light',

                        prefixIcon:
                        const Icon(
                          Icons
                              .place_outlined,

                          color:
                          AppColors
                              .textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    // ==========================================
                    // INFO
                    // ==========================================

                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets.all(
                        13,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.primary
                            .withOpacity(
                          0.06,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          13,
                        ),

                        border:
                        Border.all(
                          color:
                          AppColors
                              .primaryDark,
                        ),
                      ),

                      child:
                      const Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [
                          Icon(
                            Icons
                                .info_outline,

                            color:
                            AppColors
                                .primary,

                            size:
                            18,
                          ),

                          SizedBox(
                            width:
                            9,
                          ),

                          Expanded(
                            child:
                            Text(
                              'SmartCity automatically checks for similar reports within 500 metres. '
                                  'Issues within 100 metres are flagged as possible duplicates. '
                                  'For best results, GPS accuracy should normally be within ±50 metres.',

                              style:
                              TextStyle(
                                color:
                                AppColors
                                    .textSecondary,

                                fontSize:
                                10,

                                height:
                                1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==============================================
            // BOTTOM
            // ==============================================

            Container(
              padding:
              const EdgeInsets.all(
                18,
              ),

              decoration:
              const BoxDecoration(
                color:
                AppColors.background,

                border:
                Border(
                  top:
                  BorderSide(
                    color:
                    AppColors
                        .border,
                  ),
                ),
              ),

              child:
              Row(
                children: [
                  OutlinedButton(
                    onPressed:
                        () {
                      Navigator.pop(
                        context,
                      );
                    },

                    child:
                    const Text(
                      'Back',
                    ),
                  ),

                  const SizedBox(
                    width:
                    10,
                  ),

                  Expanded(
                    child:
                    ElevatedButton(
                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        AppColors
                            .primaryDark,

                        minimumSize:
                        const Size
                            .fromHeight(
                          54,
                        ),
                      ),

                      onPressed:
                      previewReport,

                      child:
                      const Text(
                        'Preview Report →',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PROGRESS
// ================================================================

class _LocationProgress
    extends StatelessWidget {
  const _LocationProgress();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const Row(
      children: [
        Expanded(
          child:
          Column(
            children: [
              Divider(
                thickness:
                4,

                color:
                AppColors.success,
              ),

              Text(
                '✓ Details',

                style:
                TextStyle(
                  color:
                  AppColors.success,

                  fontSize:
                  10,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child:
          Column(
            children: [
              Divider(
                thickness:
                4,

                color:
                AppColors.success,
              ),

              Text(
                '✓ Evidence',

                style:
                TextStyle(
                  color:
                  AppColors.success,

                  fontSize:
                  10,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child:
          Column(
            children: [
              Divider(
                thickness:
                4,

                color:
                AppColors.primary,
              ),

              Text(
                'Location',

                style:
                TextStyle(
                  color:
                  AppColors.primary,

                  fontSize:
                  10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// LABEL
// ================================================================

class _FieldLabel
    extends StatelessWidget {
  final String text;

  const _FieldLabel(
      this.text,
      );

  @override
  Widget build(
      BuildContext context,
      ) {
    return Text(
      text,

      style:
      const TextStyle(
        color:
        Color(
          0xFFA9C7EF,
        ),

        fontSize:
        11,

        fontWeight:
        FontWeight.w600,
      ),
    );
  }
}

// ================================================================
// INPUT
// ================================================================

InputDecoration _inputDecoration({
  required String hint,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    hintText:
    hint,

    hintStyle:
    const TextStyle(
      color:
      AppColors
          .textSecondary,
    ),

    prefixIcon:
    prefixIcon,

    filled:
    true,

    fillColor:
    AppColors.surface,

    enabledBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.border,
      ),
    ),

    focusedBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.primary,
      ),
    ),
  );
}