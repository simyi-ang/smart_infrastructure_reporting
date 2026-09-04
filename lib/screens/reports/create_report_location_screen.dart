import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';

import '../../models/nearby_report.dart';
import '../../models/report_final_ai_analysis.dart';
import '../../models/report_image_ai_analysis.dart';
import '../../models/report_draft.dart';
import '../../services/location_service.dart';
import '../../services/nearby_report_service.dart';
import '../../services/report_draft_service.dart';
import '../../theme/app_colors.dart';

import 'map_picker_screen.dart';
import 'report_preview_screen.dart';

// ================================================================
// CREATE REPORT LOCATION SCREEN
//
// Existing design and functionality preserved.
//
// Added multi-image Smart Assist support:
//
// evidenceImages
//      ↓
// imageAnalyses
//      ↓
// finalAiAnalysis
//
// This screen DOES NOT run AI.
// It only preserves and forwards AI information from Evidence.
//
// ================================================================

class CreateReportLocationScreen
    extends StatefulWidget {
  // ============================================================
  // FINAL EFFECTIVE REPORT INFORMATION
  // ============================================================

  final String category;

  final String priority;

  final String title;

  final String description;

  // ============================================================
  // EVIDENCE
  // ============================================================

  final List<File> evidenceImages;

  final List<File> evidenceVideos;

  // ============================================================
  // INDIVIDUAL IMAGE AI RESULTS
  //
  // KEY:
  // local evidence image path
  //
  // VALUE:
  // analysis belonging to that image
  // ============================================================

  final Map<
      String,
      ReportImageAiAnalysis
  > imageAnalyses;

  // ============================================================
  // FINAL COMBINED SMART ASSIST RESULT
  // ============================================================

  final ReportFinalAiAnalysis?
  finalAiAnalysis;

  // ============================================================
  // LEGACY SINGLE IMAGE ANALYSIS
  //
  // Kept temporarily so older report flows remain compatible.
  //
  // Later ReportPreviewScreen can be fully migrated to the new
  // multi-image structures.
  // ============================================================

  final ReportImageAiAnalysis?
  aiAnalysis;

  const CreateReportLocationScreen({
    super.key,

    required this.category,

    required this.priority,

    required this.title,

    required this.description,

    required this.evidenceImages,

    this.evidenceVideos = const <File>[],

    this.imageAnalyses =
    const {},

    this.finalAiAnalysis,

    this.aiAnalysis,
  });

  @override
  State<CreateReportLocationScreen>
  createState() =>
      _CreateReportLocationScreenState();
}

// ================================================================
// STATE
// ================================================================

class _CreateReportLocationScreenState
    extends State<CreateReportLocationScreen>
    with WidgetsBindingObserver {
  // ============================================================
  // SERVICES
  // ============================================================

  final LocationService locationService =
  LocationService();

  final NearbyReportService
  nearbyReportService =
  NearbyReportService();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController
  addressController =
  TextEditingController();

  final TextEditingController
  landmarkController =
  TextEditingController();

  // ============================================================
  // LOCATION STATE
  // ============================================================

  double? latitude;

  double? longitude;

  // GPS accuracy in metres.
  //
  // Available only when location comes from GPS.
  double? gpsAccuracy;

  bool gettingLocation =
  false;

  bool locationDetected =
  false;

  // ============================================================
  // NEARBY REPORT CHECK
  // ============================================================

  bool checkingNearby =
  false;

  List<NearbyReport> nearbyReports =
  [];

  NearbyReport?
  possibleDuplicate;

  // ============================================================
  // SMART DRAFT RECOVERY
  // ============================================================

  Timer? _draftDebounce;

  Future<void> _draftSaveQueue =
  Future<void>.value();

  bool restoringDraft = true;

  bool savingDraft = false;

  bool draftSaveFailed = false;

  bool _allowPop = false;

  String? detectedAddress;

  String locationVerificationStatus =
      'manual';

  static const Duration _draftSaveDelay =
  Duration(milliseconds: 500);

  String? get _userId =>
      Supabase.instance.client.auth.currentUser?.id;

  bool get _locationBusy =>
      restoringDraft ||
          savingDraft ||
          gettingLocation ||
          checkingNearby;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    addressController.addListener(
      _scheduleDraftSave,
    );

    landmarkController.addListener(
      _scheduleDraftSave,
    );

    unawaited(
      _restoreDraft(),
    );
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (
    state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached
    ) {
      unawaited(
        _saveDraft(
          currentStep: 3,
        ),
      );
    }
  }

  // ============================================================
  // RESTORE LOCATION DRAFT
  // ============================================================

  Future<void> _restoreDraft() async {
    final String? userId = _userId;

    if (userId == null) {
      if (mounted) {
        setState(() {
          restoringDraft = false;
        });
      }

      return;
    }

    try {
      final ReportDraft? draft =
      await ReportDraftService.loadDraft(
        userId: userId,
      );

      if (!mounted) {
        return;
      }

      if (draft != null) {
        latitude = draft.latitude;
        longitude = draft.longitude;
        gpsAccuracy = draft.locationAccuracy;

        detectedAddress =
            draft.detectedAddress;

        locationVerificationStatus =
            draft.locationVerificationStatus ??
                (
                    draft.latitude != null &&
                        draft.longitude != null
                        ? 'saved_coordinates'
                        : 'manual'
                );

        final String restoredAddress =
        (
            draft.manualAddress ??
                draft.detectedAddress ??
                ''
        ).trim();

        addressController.text =
            restoredAddress;

        landmarkController.text =
            (draft.landmark ?? '').trim();

        locationDetected =
            restoredAddress.isNotEmpty ||
                (
                    latitude != null &&
                        longitude != null
                );
      }

      setState(() {
        restoringDraft = false;
        draftSaveFailed = false;
      });

      if (
      latitude != null &&
          longitude != null
      ) {
        unawaited(
          checkNearbyReports(),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        restoringDraft = false;
        draftSaveFailed = true;
      });
    }
  }

  // ============================================================
  // BUILD LOCATION DRAFT
  // ============================================================

  Future<ReportDraft> _buildCurrentDraft({
    required int currentStep,
  }) async {
    final String? userId = _userId;

    ReportDraft base =
    ReportDraft.empty();

    if (userId != null) {
      final ReportDraft? existing =
      await ReportDraftService.loadDraft(
        userId: userId,
      );

      if (existing != null) {
        base = existing;
      }
    }

    final String currentAddress =
    addressController.text.trim();

    return base.copyWith(
      category: widget.category,
      priority: widget.priority,
      title: widget.title,
      description: widget.description,

      landmark:
      landmarkController.text.trim().isEmpty
          ? null
          : landmarkController.text.trim(),

      manualAddress:
      currentAddress.isEmpty
          ? null
          : currentAddress,

      latitude: latitude,
      longitude: longitude,
      locationAccuracy: gpsAccuracy,

      detectedAddress:
      detectedAddress,

      locationVerificationStatus:
      locationVerificationStatus,

      currentStep: currentStep,

      evidenceImagePaths:
      widget.evidenceImages
          .map(
            (File file) => file.path,
      )
          .toList(),

      evidenceVideoPaths:
      widget.evidenceVideos
          .map(
            (File file) => file.path,
      )
          .toList(),

      updatedAt: DateTime.now(),
    );
  }

  // ============================================================
  // SAVE LOCATION DRAFT
  // ============================================================

  Future<bool> _saveDraft({
    required int currentStep,
  }) {
    final Completer<bool> completer =
    Completer<bool>();

    _draftSaveQueue =
        _draftSaveQueue.then(
              (_) async {
            final String? userId = _userId;

            if (userId == null) {
              if (!completer.isCompleted) {
                completer.complete(false);
              }

              return;
            }

            if (mounted) {
              setState(() {
                savingDraft = true;
                draftSaveFailed = false;
              });
            }

            try {
              final ReportDraft draft =
              await _buildCurrentDraft(
                currentStep: currentStep,
              );

              await ReportDraftService.saveDraft(
                userId: userId,
                draft: draft,
              );

              if (mounted) {
                setState(() {
                  savingDraft = false;
                  draftSaveFailed = false;
                });
              }

              if (!completer.isCompleted) {
                completer.complete(true);
              }
            } catch (_) {
              if (mounted) {
                setState(() {
                  savingDraft = false;
                  draftSaveFailed = true;
                });
              }

              if (!completer.isCompleted) {
                completer.complete(false);
              }
            }
          },
        );

    return completer.future;
  }

  // ============================================================
  // DEBOUNCED AUTOSAVE
  // ============================================================

  void _scheduleDraftSave() {
    if (restoringDraft) {
      return;
    }

    _draftDebounce?.cancel();

    _draftDebounce = Timer(
      _draftSaveDelay,
          () {
        unawaited(
          _saveDraft(
            currentStep: 3,
          ),
        );
      },
    );
  }

  // ============================================================
  // SAFE BACK
  // ============================================================

  Future<void> _goBackSafely() async {
    if (_locationBusy) {
      return;
    }

    _draftDebounce?.cancel();

    final bool saved =
    await _saveDraft(
      currentStep: 3,
    );

    if (!saved || !mounted) {
      showMessage(
        'Your location draft could not be saved. '
            'Please try again.',
      );

      return;
    }

    _allowPop = true;

    if (mounted) {
      Navigator.pop(
        context,
      );
    }
  }

  // ============================================================
  // DRAFT STATUS
  // ============================================================

  String get _draftStatusText {
    if (restoringDraft) {
      return 'Restoring location draft...';
    }

    if (savingDraft) {
      return 'Saving location draft...';
    }

    if (draftSaveFailed) {
      return 'Location draft could not be saved';
    }

    return 'Location saved in draft';
  }

  Color get _draftStatusColor {
    return draftSaveFailed
        ? AppColors.warning
        : AppColors.success;
  }

  // ============================================================
  // LEGACY ANALYSIS FALLBACK
  //
  // Current Preview screen may still expect one
  // ReportImageAiAnalysis.
  //
  // Prefer explicitly supplied aiAnalysis.
  //
  // Otherwise use the first individual image analysis.
  // ============================================================

  ReportImageAiAnalysis?
  get legacyAiAnalysis {
    if (widget.aiAnalysis != null) {
      return widget.aiAnalysis;
    }

    if (widget.imageAnalyses.isNotEmpty) {
      return widget
          .imageAnalyses
          .values
          .first;
    }

    return null;
  }

  // ============================================================
  // GET CURRENT LOCATION
  // ============================================================

  Future<void>
  detectCurrentLocation() async {
    if (gettingLocation) {
      return;
    }

    setState(() {
      gettingLocation =
      true;
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

        detectedAddress =
            result.address;

        locationVerificationStatus =
        'gps';

        locationDetected =
        true;
      });

      await _saveDraft(
        currentStep: 3,
      );

      // ========================================================
      // NEARBY DUPLICATE CHECK
      // ========================================================

      await checkNearbyReports();

      if (!mounted) {
        return;
      }

      // ========================================================
      // GPS QUALITY MESSAGE
      // ========================================================

      if (result.accuracy >
          50) {
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
      e
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      );

      await showLocationErrorDialog(
        message,
      );
    } finally {
      if (mounted) {
        setState(() {
          gettingLocation =
          false;
        });
      }
    }
  }

  // ============================================================
  // MAP PICKER
  // ============================================================

  Future<void>
  openMapPicker() async {
    double startingLatitude =
        latitude ??
            3.1390;

    double startingLongitude =
        longitude ??
            101.6869;

    // ==========================================================
    // TRY CURRENT LOCATION FOR INITIAL MAP POSITION
    // ==========================================================

    if (
    latitude == null ||
        longitude == null
    ) {
      try {
        final result =
        await locationService
            .getCurrentLocationWithAddress();

        startingLatitude =
            result.latitude;

        startingLongitude =
            result.longitude;
      } catch (_) {
        // Kuala Lumpur fallback is used only to initialise map.
      }
    }

    if (!mounted) {
      return;
    }

    // ==========================================================
    // OPEN MAP
    // ==========================================================

    final MapPickerResult? result =
    await Navigator
        .push<MapPickerResult>(
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

    // ==========================================================
    // SAVE MAP RESULT
    // ==========================================================

    setState(() {
      latitude =
          result.latitude;

      longitude =
          result.longitude;

      // Manually selected map point does not have device GPS
      // accuracy metadata.
      gpsAccuracy =
      null;

      addressController.text =
          result.address;

      detectedAddress =
          result.address;

      locationVerificationStatus =
      'map';

      locationDetected =
      true;
    });

    await _saveDraft(
      currentStep: 3,
    );

    await checkNearbyReports();
  }

  // ============================================================
  // CHECK NEARBY REPORTS
  // ============================================================

  Future<void>
  checkNearbyReports() async {
    final double?
    currentLatitude =
        latitude;

    final double?
    currentLongitude =
        longitude;

    if (
    currentLatitude == null ||
        currentLongitude == null
    ) {
      return;
    }

    setState(() {
      checkingNearby =
      true;
    });

    try {
      // ========================================================
      // IMPORTANT
      //
      // widget.category is already the EFFECTIVE category.
      //
      // Therefore:
      //
      // Keep Mine
      //     → citizen category
      //
      // Apply AI
      //     → final combined AI category
      // ========================================================

      final List<NearbyReport>
      reports =
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

      // ========================================================
      // DUPLICATE WITHIN 100 METRES
      // ========================================================

      NearbyReport?
      duplicate;

      for (
      final NearbyReport report
      in reports
      ) {
        if (
        report.distanceMeters <=
            100
        ) {
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

      // Nearby checking must not prevent citizen reporting.
      setState(() {
        nearbyReports =
        [];

        possibleDuplicate =
        null;

        checkingNearby =
        false;
      });
    }
  }

  // ============================================================
  // LOCATION ERROR DIALOG
  // ============================================================

  Future<void>
  showLocationErrorDialog(
      String message,
      ) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context:
      context,

      builder:
          (
          dialogContext,
          ) {
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
  // PREVIEW REPORT
  // ============================================================

  Future<void>
  previewReport() async {
    final String address =
    addressController.text
        .trim();

    // ==========================================================
    // ADDRESS REQUIRED
    // ==========================================================

    if (address.isEmpty) {
      showMessage(
        'Please detect, select or enter the issue location.',
      );

      return;
    }

    // ==========================================================
    // MANUAL ADDRESS WITHOUT COORDINATES
    // ==========================================================

    if (
    latitude == null ||
        longitude == null
    ) {
      final bool?
      continueWithoutGps =
      await showDialog<bool>(
        context:
        context,

        builder:
            (
            dialogContext,
            ) {
          return AlertDialog(
            backgroundColor:
            AppColors.surface,

            title:
            const Text(
              'No GPS Coordinates',
            ),

            content:
            const Text(
              'You entered an address manually, but no GPS '
                  'coordinates are attached. Using the map or GPS '
                  'is recommended for accurate issue tracking.',
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

      if (
      continueWithoutGps !=
          true
      ) {
        return;
      }
    }

    // ==========================================================
    // DUPLICATE WARNING
    // ==========================================================

    if (
    possibleDuplicate !=
        null
    ) {
      final bool?
      continueDuplicate =
      await _showDuplicateWarning();

      if (
      continueDuplicate !=
          true
      ) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    _draftDebounce?.cancel();

    final bool draftSaved =
    await _saveDraft(
      currentStep: 4,
    );

    if (!draftSaved || !mounted) {
      showMessage(
        'Your report draft could not be saved before preview.',
      );

      return;
    }

    // ==========================================================
    // PREVIEW
    //
    // IMPORTANT:
    //
    // ReportPreviewScreen currently still supports the legacy
    // single aiAnalysis field.
    //
    // We retain all multi-image data here so this Location screen
    // is already compatible with the upgraded Evidence screen.
    //
    // The next update will migrate ReportPreviewScreen itself.
    // ==========================================================

    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
            ReportPreviewScreen(
              // ====================================================
              // FINAL EFFECTIVE REPORT INFORMATION
              // ====================================================

              category:
              widget.category,

              priority:
              widget.priority,

              title:
              widget.title,

              description:
              widget.description,

              // ====================================================
              // EVIDENCE
              // ====================================================

              evidenceImages:
              List<File>.from(
                widget.evidenceImages,
              ),

              evidenceVideos:
              List<File>.from(
                widget.evidenceVideos,
              ),

              imageAnalyses:
              Map<String, ReportImageAiAnalysis>.from(
                widget.imageAnalyses,
              ),

              finalAiAnalysis:
              widget.finalAiAnalysis,

              // ====================================================
              // LOCATION
              // ====================================================

              address:
              address,

              landmark:
              landmarkController.text
                  .trim(),

              latitude:
              latitude,

              longitude:
              longitude,

              locationAccuracy:
              gpsAccuracy,

              detectedAddress:
              detectedAddress,

              locationVerificationStatus:
              locationVerificationStatus,

              // ====================================================
              // LEGACY AI
              //
              // This keeps current Preview compiling until the next
              // screen is upgraded.
              // ====================================================

              aiAnalysis:
              legacyAiAnalysis,
            ),
      ),
    );
  }

  // ============================================================
  // DUPLICATE WARNING
  // ============================================================

  Future<bool?>
  _showDuplicateWarning() {
    final NearbyReport?
    report =
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
          (
          dialogContext,
          ) {
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
                'A similar infrastructure issue has already '
                    'been reported very close to this location.',
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
                  AppColors.textSecondary,
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
  // GPS ACCURACY TEXT
  // ============================================================

  String get _gpsAccuracyText {
    final double?
    accuracy =
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

  // ============================================================
  // GPS ACCURACY COLOR
  // ============================================================

  Color get _gpsAccuracyColor {
    final double?
    accuracy =
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );

    _draftDebounce?.cancel();

    addressController
        .dispose();

    landmarkController
        .dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return PopScope(
      canPop:
      _allowPop,

      onPopInvokedWithResult:
          (
          didPop,
          result,
          ) async {
        if (didPop) {
          return;
        }

        await _goBackSafely();
      },

      child:
      Scaffold(
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
                    CrossAxisAlignment.start,

                    children: [
                      // =================================================
                      // HEADER
                      // =================================================

                      Row(
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
                              onPressed:
                              _locationBusy
                                  ? null
                                  : _goBackSafely,

                              icon:
                              const Icon(
                                Icons.arrow_back,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width:
                            14,
                          ),

                          const Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [
                              Text(
                                'Report Issue',

                                style:
                                TextStyle(
                                  fontSize:
                                  22,

                                  fontWeight:
                                  FontWeight.bold,
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
                                  AppColors.textSecondary,

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

                      // =================================================
                      // PROGRESS
                      // =================================================

                      const _LocationProgress(),

                      const SizedBox(
                        height:
                        24,
                      ),

                      // =================================================
                      // GPS / MAP CARD
                      // =================================================

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
                          BorderRadius.circular(
                            18,
                          ),

                          border:
                          Border.all(
                            color:
                            locationDetected
                                ? AppColors.success
                                : AppColors.primaryDark,
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
                                AppColors.primary
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
                                AppColors.primary,
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
                                FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                              height:
                              6,
                            ),

                            const Text(
                              'Use GPS or choose the exact issue '
                                  'location from the map.',

                              textAlign:
                              TextAlign.center,

                              style:
                              TextStyle(
                                color:
                                AppColors.textSecondary,

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

                            // ===========================================
                            // CURRENT GPS
                            // ===========================================

                            SizedBox(
                              width:
                              double.infinity,

                              child:
                              ElevatedButton.icon(
                                style:
                                ElevatedButton.styleFrom(
                                  backgroundColor:
                                  AppColors.primaryDark,

                                  minimumSize:
                                  const Size.fromHeight(
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
                                  Icons.gps_fixed,
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

                            // ===========================================
                            // MAP
                            // ===========================================

                            SizedBox(
                              width:
                              double.infinity,

                              child:
                              OutlinedButton.icon(
                                onPressed:
                                gettingLocation
                                    ? null
                                    : openMapPicker,

                                icon:
                                const Icon(
                                  Icons.map_outlined,
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

                      // =================================================
                      // COORDINATE / ACCURACY
                      // =================================================

                      if (
                      latitude != null &&
                          longitude != null
                      ) ...[
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
                            BorderRadius.circular(
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
                                    AppColors.success,

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
                                        AppColors.textSecondary,

                                        fontSize:
                                        10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (
                              gpsAccuracy != null
                              ) ...[
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
                                        'GPS Accuracy: '
                                            '$_gpsAccuracyText',

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

                      // =================================================
                      // NEARBY CHECKING
                      // =================================================

                      if (checkingNearby) ...[
                        const SizedBox(
                          height:
                          12,
                        ),

                        const LinearProgressIndicator(),
                      ],

                      // =================================================
                      // NEARBY RESULTS
                      // =================================================

                      if (
                      !checkingNearby &&
                          nearbyReports.isNotEmpty
                      ) ...[
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
                                ? AppColors.warning
                                .withOpacity(
                              0.07,
                            )
                                : AppColors.primary
                                .withOpacity(
                              0.05,
                            ),

                            borderRadius:
                            BorderRadius.circular(
                              13,
                            ),

                            border:
                            Border.all(
                              color:
                              possibleDuplicate !=
                                  null
                                  ? AppColors.warning
                                  : AppColors.primaryDark,
                            ),
                          ),

                          child:
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [
                              Icon(
                                possibleDuplicate !=
                                    null
                                    ? Icons
                                    .warning_amber_rounded
                                    : Icons.info_outline,

                                color:
                                possibleDuplicate !=
                                    null
                                    ? AppColors.warning
                                    : AppColors.primary,
                              ),

                              const SizedBox(
                                width:
                                9,
                              ),

                              Expanded(
                                child:
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      possibleDuplicate !=
                                          null
                                          ? 'Possible Duplicate Detected'
                                          : '${nearbyReports.length} '
                                          'similar issue(s) nearby',

                                      style:
                                      const TextStyle(
                                        fontWeight:
                                        FontWeight.bold,

                                        fontSize:
                                        11,
                                      ),
                                    ),

                                    if (
                                    nearbyReports.isNotEmpty
                                    ) ...[
                                      const SizedBox(
                                        height:
                                        4,
                                      ),

                                      Text(
                                        'Closest: '
                                            '${nearbyReports.first.title} • '
                                            '${nearbyReports.first.distanceText}',

                                        style:
                                        const TextStyle(
                                          color:
                                          AppColors.textSecondary,

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

                      // =================================================
                      // DRAFT STATUS
                      // =================================================

                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          _draftStatusColor.withOpacity(
                            0.07,
                          ),

                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),

                          border:
                          Border.all(
                            color:
                            _draftStatusColor.withOpacity(
                              0.45,
                            ),
                          ),
                        ),

                        child:
                        Row(
                          children: [
                            Icon(
                              savingDraft ||
                                  restoringDraft
                                  ? Icons.sync_rounded
                                  : draftSaveFailed
                                  ? Icons.cloud_off_outlined
                                  : Icons.cloud_done_outlined,

                              color:
                              _draftStatusColor,

                              size:
                              17,
                            ),

                            const SizedBox(
                              width:
                              8,
                            ),

                            Expanded(
                              child:
                              Text(
                                _draftStatusText,

                                style:
                                TextStyle(
                                  color:
                                  _draftStatusColor,

                                  fontSize:
                                  10,

                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height:
                        14,
                      ),

                      // =================================================
                      // ADDRESS
                      // =================================================

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
                            AppColors.primary,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      // =================================================
                      // LANDMARK
                      // =================================================

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
                            Icons.place_outlined,

                            color:
                            AppColors.textSecondary,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      // =================================================
                      // INFO
                      // =================================================

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
                          BorderRadius.circular(
                            13,
                          ),

                          border:
                          Border.all(
                            color:
                            AppColors.primaryDark,
                          ),
                        ),

                        child:
                        const Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [
                            Icon(
                              Icons.info_outline,

                              color:
                              AppColors.primary,

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
                                'SmartCity automatically checks for '
                                    'similar reports within 500 metres. '
                                    'Issues within 100 metres are flagged '
                                    'as possible duplicates. For best '
                                    'results, GPS accuracy should normally '
                                    'be within ±50 metres.',

                                style:
                                TextStyle(
                                  color:
                                  AppColors.textSecondary,

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

                      // =================================================
                      // SMART ASSIST TRANSFER STATUS
                      //
                      // Small information box only.
                      //
                      // Does not change the existing flow.
                      // =================================================

                      if (
                      widget.imageAnalyses.isNotEmpty ||
                          widget.finalAiAnalysis !=
                              null
                      ) ...[
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
                            const Color(
                              0xFF8F80FF,
                            ).withOpacity(
                              0.06,
                            ),

                            borderRadius:
                            BorderRadius.circular(
                              13,
                            ),

                            border:
                            Border.all(
                              color:
                              const Color(
                                0xFF8F80FF,
                              ).withOpacity(
                                0.35,
                              ),
                            ),
                          ),

                          child:
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [
                              const Icon(
                                Icons.auto_awesome,

                                color:
                                Color(
                                  0xFF8F80FF,
                                ),

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
                                  widget.finalAiAnalysis !=
                                      null
                                      ? 'Smart Assist completed '
                                      '${widget.finalAiAnalysis!.analyzedImageCount} '
                                      'evidence image analysis'
                                      '${widget.finalAiAnalysis!.analyzedImageCount == 1 ? '' : 'es'} '
                                      'and created a final combined assessment.'
                                      : '${widget.imageAnalyses.length} '
                                      'individual evidence analysis'
                                      '${widget.imageAnalyses.length == 1 ? '' : 'es'} '
                                      'are attached to this report.',

                                  style:
                                  const TextStyle(
                                    color:
                                    AppColors.textSecondary,

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
                    ],
                  ),
                ),
              ),

              // =====================================================
              // BOTTOM
              // =====================================================

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
                      AppColors.border,
                    ),
                  ),
                ),

                child:
                Row(
                  children: [
                    OutlinedButton(
                      onPressed:
                      _locationBusy
                          ? null
                          : _goBackSafely,

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
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          AppColors.primaryDark,

                          minimumSize:
                          const Size.fromHeight(
                            54,
                          ),
                        ),

                        onPressed:
                        _locationBusy
                            ? null
                            : previewReport,

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
      ),
    );
  }
}

// ================================================================
// LOCATION PROGRESS
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
// FIELD LABEL
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
// INPUT DECORATION
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
      AppColors.textSecondary,
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
