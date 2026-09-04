import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/nearby_report.dart';
import '../../models/report_draft.dart';
import '../../models/report_final_ai_analysis.dart';
import '../../models/report_image_ai_analysis.dart';
import '../../services/location_service.dart';
import '../../services/nearby_report_service.dart';
import '../../services/report_draft_service.dart';
import '../../theme/app_colors.dart';
import 'map_picker_screen.dart';
import 'report_preview_screen.dart';

// ================================================================
// ADDRESS GEOCODE RESULT
// ================================================================

class AddressGeocodeResult {
  final String inputAddress;

  final String formattedAddress;

  final double latitude;

  final double longitude;

  final bool verified;

  const AddressGeocodeResult({
    required this.inputAddress,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.verified,
  });
}

// ================================================================
// CREATE REPORT LOCATION SCREEN
//
// Existing design and functionality preserved.
//
// LOCATION SOURCES:
//
// 1. Current GPS
//    → latitude / longitude
//    → reverse-geocoded address
//
// 2. Choose on Map
//    → selected latitude / longitude
//    → map address
//
// 3. Manual Address
//    → forward geocoding
//    → latitude / longitude
//    → reverse-geocoded formatted address
//
// IMPORTANT:
//
// Manually entered free text is no longer accepted as a location
// unless the geocoding provider can resolve it to map coordinates.
//
// This screen DOES NOT run Smart Assist evidence AI.
// It preserves and forwards AI information from Evidence.
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
    this.imageAnalyses = const {},
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

  final Geocoding geocoding =
  Geocoding();

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

  // Device GPS accuracy only.
  //
  // A manually geocoded address or manually selected map point
  // does not have device-GPS accuracy information.
  double? gpsAccuracy;

  bool gettingLocation =
  false;

  bool locationDetected =
  false;

  // ============================================================
  // MANUAL ADDRESS VERIFICATION
  // ============================================================

  bool validatingManualAddress =
  false;

  String? addressValidationError;

  // Prevent addressController listeners from invalidating
  // coordinates when WE update the address from GPS/map/geocoder.
  bool _updatingAddressProgrammatically =
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

  bool restoringDraft =
  true;

  bool savingDraft =
  false;

  bool draftSaveFailed =
  false;

  bool _allowPop =
  false;

  String? detectedAddress;

  // Possible values:
  //
  // manual
  // manual_unverified
  // gps
  // map
  // geocoded
  // saved_coordinates
  String locationVerificationStatus =
      'manual';

  static const Duration _draftSaveDelay =
  Duration(
    milliseconds: 500,
  );

  String? get _userId =>
      Supabase
          .instance
          .client
          .auth
          .currentUser
          ?.id;

  bool get _locationBusy =>
      restoringDraft ||
          savingDraft ||
          gettingLocation ||
          checkingNearby ||
          validatingManualAddress;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding
        .instance
        .addObserver(
      this,
    );

    // Address uses its own listener because editing a previously
    // verified address must invalidate the old coordinates.
    addressController.addListener(
      _handleAddressChanged,
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
    state ==
        AppLifecycleState.inactive ||
        state ==
            AppLifecycleState.paused ||
        state ==
            AppLifecycleState.detached
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
    final String? userId =
        _userId;

    if (userId == null) {
      if (mounted) {
        setState(() {
          restoringDraft =
          false;
        });
      }

      return;
    }

    try {
      final ReportDraft? draft =
      await ReportDraftService
          .loadDraft(
        userId: userId,
      );

      if (!mounted) {
        return;
      }

      if (draft != null) {
        latitude =
            draft.latitude;

        longitude =
            draft.longitude;

        gpsAccuracy =
            draft.locationAccuracy;

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

        _updatingAddressProgrammatically =
        true;

        addressController.text =
            restoredAddress;

        _updatingAddressProgrammatically =
        false;

        landmarkController.text =
            (
                draft.landmark ??
                    ''
            ).trim();

        locationDetected =
            restoredAddress.isNotEmpty &&
                latitude != null &&
                longitude != null;
      }

      setState(() {
        restoringDraft =
        false;

        draftSaveFailed =
        false;
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
        restoringDraft =
        false;

        draftSaveFailed =
        true;
      });
    }
  }

  // ============================================================
  // BUILD LOCATION DRAFT
  // ============================================================

  Future<ReportDraft>
  _buildCurrentDraft({
    required int currentStep,
  }) async {
    final String? userId =
        _userId;

    ReportDraft base =
    ReportDraft.empty();

    if (userId != null) {
      final ReportDraft? existing =
      await ReportDraftService
          .loadDraft(
        userId: userId,
      );

      if (existing != null) {
        base =
            existing;
      }
    }

    final String currentAddress =
    addressController
        .text
        .trim();

    return base.copyWith(
      category:
      widget.category,

      priority:
      widget.priority,

      title:
      widget.title,

      description:
      widget.description,

      landmark:
      landmarkController
          .text
          .trim()
          .isEmpty
          ? null
          : landmarkController
          .text
          .trim(),

      manualAddress:
      currentAddress.isEmpty
          ? null
          : currentAddress,

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

      currentStep:
      currentStep,

      evidenceImagePaths:
      widget
          .evidenceImages
          .map(
            (
            File file,
            ) =>
        file.path,
      )
          .toList(),

      evidenceVideoPaths:
      widget
          .evidenceVideos
          .map(
            (
            File file,
            ) =>
        file.path,
      )
          .toList(),

      updatedAt:
      DateTime.now(),
    );
  }

  // ============================================================
  // SAVE LOCATION DRAFT
  // ============================================================

  Future<bool> _saveDraft({
    required int currentStep,
  }) {
    final Completer<bool>
    completer =
    Completer<bool>();

    _draftSaveQueue =
        _draftSaveQueue.then(
              (_) async {
            final String? userId =
                _userId;

            if (userId == null) {
              if (
              !completer
                  .isCompleted
              ) {
                completer.complete(
                  false,
                );
              }

              return;
            }

            if (mounted) {
              setState(() {
                savingDraft =
                true;

                draftSaveFailed =
                false;
              });
            }

            try {
              final ReportDraft draft =
              await _buildCurrentDraft(
                currentStep:
                currentStep,
              );

              await ReportDraftService
                  .saveDraft(
                userId:
                userId,

                draft:
                draft,
              );

              if (mounted) {
                setState(() {
                  savingDraft =
                  false;

                  draftSaveFailed =
                  false;
                });
              }

              if (
              !completer
                  .isCompleted
              ) {
                completer.complete(
                  true,
                );
              }
            } catch (_) {
              if (mounted) {
                setState(() {
                  savingDraft =
                  false;

                  draftSaveFailed =
                  true;
                });
              }

              if (
              !completer
                  .isCompleted
              ) {
                completer.complete(
                  false,
                );
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
    if (
    restoringDraft
    ) {
      return;
    }

    _draftDebounce
        ?.cancel();

    _draftDebounce =
        Timer(
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
  // ADDRESS CHANGE HANDLER
  //
  // This is important:
  //
  // GPS:
  // "Jalan A"
  // coordinates A
  //
  // Citizen changes text to:
  // "Jalan B"
  //
  // We must NOT keep coordinates A attached to Jalan B.
  // ============================================================

  void _handleAddressChanged() {
    if (
    restoringDraft ||
        _updatingAddressProgrammatically
    ) {
      return;
    }

    final String currentAddress =
    addressController
        .text
        .trim();

    final String previousVerifiedAddress =
    (
        detectedAddress ??
            ''
    ).trim();

    final bool hadVerifiedCoordinates =
        latitude != null &&
            longitude != null &&
            (
                locationVerificationStatus ==
                    'gps' ||
                    locationVerificationStatus ==
                        'map' ||
                    locationVerificationStatus ==
                        'geocoded' ||
                    locationVerificationStatus ==
                        'saved_coordinates'
            );

    if (
    hadVerifiedCoordinates &&
        currentAddress !=
            previousVerifiedAddress
    ) {
      setState(() {
        // User has changed the text manually.
        //
        // Existing coordinates no longer safely describe
        // the newly typed address.
        latitude =
        null;

        longitude =
        null;

        gpsAccuracy =
        null;

        locationDetected =
        false;

        locationVerificationStatus =
        'manual_unverified';

        addressValidationError =
        null;
      });
    }

    _scheduleDraftSave();
  }

  // ============================================================
  // SAFE BACK
  // ============================================================

  Future<void>
  _goBackSafely() async {
    if (_locationBusy) {
      return;
    }

    _draftDebounce
        ?.cancel();

    final bool saved =
    await _saveDraft(
      currentStep: 3,
    );

    if (
    !saved ||
        !mounted
    ) {
      showMessage(
        'Your location draft could not be saved. '
            'Please try again.',
      );

      return;
    }

    _allowPop =
    true;

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
  // ============================================================

  ReportImageAiAnalysis?
  get legacyAiAnalysis {
    if (
    widget.aiAnalysis != null
    ) {
      return widget.aiAnalysis;
    }

    if (
    widget
        .imageAnalyses
        .isNotEmpty
    ) {
      return widget
          .imageAnalyses
          .values
          .first;
    }

    return null;
  }

  // ============================================================
  // FORMAT GEOCODED ADDRESS
  // ============================================================

  String _formatPlacemarkAddress(
      Placemark placemark,
      String fallback,
      ) {
    final List<String> possibleParts =
    <String>[
      placemark.name ?? '',
      placemark.street ?? '',
      placemark.subLocality ?? '',
      placemark.locality ?? '',
      placemark.subAdministrativeArea ?? '',
      placemark.administrativeArea ?? '',
      placemark.postalCode ?? '',
      placemark.country ?? '',
    ];

    final List<String> result =
    <String>[];

    final Set<String> used =
    <String>{};

    for (
    final String raw
    in possibleParts
    ) {
      final String clean =
      raw.trim();

      if (clean.isEmpty) {
        continue;
      }

      final String comparison =
      clean.toLowerCase();

      if (
      used.add(
        comparison,
      )
      ) {
        result.add(
          clean,
        );
      }
    }

    if (result.isEmpty) {
      return fallback;
    }

    return result.join(
      ', ',
    );
  }

  // ============================================================
  // VALIDATE + GEOCODE MANUALLY TYPED ADDRESS
  //
  // Forward geocoding:
  //
  // typed address
  //      ↓
  // latitude / longitude
  //
  // Reverse geocoding:
  //
  // latitude / longitude
  //      ↓
  // normalized address
  //
  // Note:
  //
  // "verified" here means the geocoding provider successfully
  // resolved the user's input to a geographic coordinate.
  // ============================================================

  Future<AddressGeocodeResult?>
  _validateAndGeocodeAddress(
      String rawAddress,
      ) async {
    final String inputAddress =
    rawAddress.trim();

    if (
    inputAddress.isEmpty
    ) {
      return null;
    }

    if (
    inputAddress.length <
        3
    ) {
      return null;
    }

    try {
      // ========================================================
      // FORWARD GEOCODING
      // ========================================================

      final List<Location> locations =
      await geocoding.locationFromAddress(
        inputAddress,
      );

      if (locations.isEmpty) {
        return null;
      }

      final Location resolved =
          locations.first;

      final double resolvedLatitude =
          resolved.latitude;

      final double resolvedLongitude =
          resolved.longitude;

      // ========================================================
      // COORDINATE SAFETY
      // ========================================================

      if (
      resolvedLatitude <
          -90 ||
          resolvedLatitude >
              90 ||
          resolvedLongitude <
              -180 ||
          resolvedLongitude >
              180
      ) {
        return null;
      }

      // ========================================================
      // REVERSE GEOCODING
      //
      // Prefer a normalized real-world display address.
      // ========================================================

      String formattedAddress =
          inputAddress;

      try {
        final List<Placemark> placemarks =
        await geocoding.placemarkFromCoordinates(
          resolvedLatitude,
          resolvedLongitude,
        );

        if (
        placemarks.isNotEmpty
        ) {
          formattedAddress =
              _formatPlacemarkAddress(
                placemarks.first,
                inputAddress,
              );
        }
      } catch (_) {
        // The address already successfully resolved to
        // latitude / longitude.
        //
        // If reverse geocoding temporarily fails, keep the
        // citizen's original address as the display value.
      }

      return AddressGeocodeResult(
        inputAddress:
        inputAddress,

        formattedAddress:
        formattedAddress,

        latitude:
        resolvedLatitude,

        longitude:
        resolvedLongitude,

        verified:
        true,
      );
    } catch (
    error
    ) {
      debugPrint(
        'Address geocoding failed: $error',
      );

      return null;
    }
  }

  // ============================================================
  // VERIFY MANUAL ADDRESS
  // ============================================================

  Future<bool>
  _verifyTypedAddress() async {
    if (
    validatingManualAddress
    ) {
      return false;
    }

    final String rawAddress =
    addressController
        .text
        .trim();

    // ==========================================================
    // EMPTY
    // ==========================================================

    if (
    rawAddress.isEmpty
    ) {
      setState(() {
        addressValidationError =
        'Please enter an address.';
      });

      return false;
    }

    setState(() {
      validatingManualAddress =
      true;

      addressValidationError =
      null;
    });

    try {
      final AddressGeocodeResult? result =
      await _validateAndGeocodeAddress(
        rawAddress,
      );

      if (!mounted) {
        return false;
      }

      // ========================================================
      // ADDRESS NOT FOUND
      // ========================================================

      if (
      result == null ||
          !result.verified
      ) {
        setState(() {
          latitude =
          null;

          longitude =
          null;

          gpsAccuracy =
          null;

          locationDetected =
          false;

          detectedAddress =
          null;

          locationVerificationStatus =
          'manual_unverified';

          addressValidationError =
          'This address could not be found on the map. '
              'Please enter a valid real-world address '
              'or choose the location on the map.';
        });

        return false;
      }

      // ========================================================
      // ADDRESS RESOLVED SUCCESSFULLY
      // ========================================================

      setState(() {
        latitude =
            result.latitude;

        longitude =
            result.longitude;

        // This coordinate came from geocoding,
        // NOT the phone's GPS sensor.
        gpsAccuracy =
        null;

        // Prevent the address listener from clearing the new
        // coordinates while this code updates the controller.
        _updatingAddressProgrammatically =
        true;

        addressController.text =
            result.formattedAddress;

        _updatingAddressProgrammatically =
        false;

        detectedAddress =
            result.formattedAddress;

        locationVerificationStatus =
        'geocoded';

        locationDetected =
        true;

        addressValidationError =
        null;
      });

      // ========================================================
      // SAVE
      // ========================================================

      await _saveDraft(
        currentStep: 3,
      );

      // ========================================================
      // DUPLICATE CHECK NOW HAS REAL COORDINATES
      // ========================================================

      await checkNearbyReports();

      if (!mounted) {
        return true;
      }

      showMessage(
        'Address matched successfully to a real map location.',
      );

      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      setState(() {
        addressValidationError =
        'Unable to verify this address right now. '
            'Please try again or choose the location on the map.';
      });

      return false;
    } finally {
      if (mounted) {
        setState(() {
          validatingManualAddress =
          false;
        });
      }
    }
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

      addressValidationError =
      null;
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

        _updatingAddressProgrammatically =
        true;

        addressController.text =
            result.address;

        _updatingAddressProgrammatically =
        false;

        detectedAddress =
            result.address;

        locationVerificationStatus =
        'gps';

        locationDetected =
        true;

        addressValidationError =
        null;
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

      if (
      result.accuracy >
          50
      ) {
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
    } catch (
    e
    ) {
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

      // Manually selected map point does not have
      // device GPS accuracy metadata.
      gpsAccuracy =
      null;

      _updatingAddressProgrammatically =
      true;

      addressController.text =
          result.address;

      _updatingAddressProgrammatically =
      false;

      detectedAddress =
          result.address;

      locationVerificationStatus =
      'map';

      locationDetected =
      true;

      addressValidationError =
      null;
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
              onPressed:
                  () {
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
    String address =
    addressController
        .text
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
    // MANUALLY TYPED ADDRESS MUST BE GEOCODED
    //
    // GPS and Map already provide coordinates.
    //
    // If coordinates are absent, treat the field as manual input
    // and require it to resolve to a real-world map location.
    // ==========================================================

    if (
    latitude == null ||
        longitude == null
    ) {
      final bool verified =
      await _verifyTypedAddress();

      if (
      !verified ||
          !mounted
      ) {
        return;
      }

      // Address may have been normalized by reverse geocoding.
      address =
          addressController
              .text
              .trim();
    }

    // ==========================================================
    // FINAL LOCATION SAFETY CHECK
    // ==========================================================

    if (
    latitude == null ||
        longitude == null
    ) {
      showMessage(
        'A valid map location is required before preview.',
      );

      return;
    }

    if (address.isEmpty) {
      showMessage(
        'A valid address is required before preview.',
      );

      return;
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

    _draftDebounce
        ?.cancel();

    final bool draftSaved =
    await _saveDraft(
      currentStep: 4,
    );

    if (
    !draftSaved ||
        !mounted
    ) {
      showMessage(
        'Your report draft could not be saved before preview.',
      );

      return;
    }

    // ==========================================================
    // PREVIEW
    //
    // Existing report data, evidence, AI data and location
    // forwarding are preserved.
    // ==========================================================

    final bool? submitted =
    await Navigator.push<bool>(
      context,

      MaterialPageRoute(
        builder: (_) =>
            ReportPreviewScreen(
              // ==================================================
              // REPORT
              // ==================================================

              category:
              widget.category,

              priority:
              widget.priority,

              title:
              widget.title,

              description:
              widget.description,

              // ==================================================
              // EVIDENCE
              // ==================================================

              evidenceImages:
              List<File>.from(
                widget.evidenceImages,
              ),

              evidenceVideos:
              List<File>.from(
                widget.evidenceVideos,
              ),

              imageAnalyses:
              Map<
                  String,
                  ReportImageAiAnalysis
              >.from(
                widget.imageAnalyses,
              ),

              finalAiAnalysis:
              widget.finalAiAnalysis,

              // ==================================================
              // LOCATION
              // ==================================================

              address:
              addressController
                  .text
                  .trim(),

              landmark:
              landmarkController
                  .text
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

              // ==================================================
              // LEGACY AI
              // ==================================================

              aiAnalysis:
              legacyAiAnalysis,
            ),
      ),
    );

    // ==========================================================
    // PREVIEW REPORTED SUCCESS
    //
    // Forward TRUE back to Evidence.
    // Do NOT save the Location draft again.
    // ==========================================================

    if (
    submitted ==
        true
    ) {
      if (!mounted) {
        return;
      }

      _allowPop =
      true;

      Navigator.pop(
        context,
        true,
      );

      return;
    }
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
              onPressed:
                  () {
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
              onPressed:
                  () {
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

    if (accuracy <=
        10) {
      return 'Excellent • ±${accuracy.toStringAsFixed(0)} m';
    }

    if (accuracy <=
        25) {
      return 'Good • ±${accuracy.toStringAsFixed(0)} m';
    }

    if (accuracy <=
        50) {
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
      return AppColors
          .textSecondary;
    }

    if (accuracy <=
        25) {
      return AppColors
          .success;
    }

    if (accuracy <=
        50) {
      return AppColors
          .warning;
    }

    return AppColors
        .danger;
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

    ScaffoldMessenger
        .of(
      context,
    )
        .hideCurrentSnackBar();

    ScaffoldMessenger
        .of(
      context,
    )
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
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding
        .instance
        .removeObserver(
      this,
    );

    _draftDebounce
        ?.cancel();

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
                      // ===========================================
                      // HEADER
                      // ===========================================

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

                      // ===========================================
                      // PROGRESS
                      // ===========================================

                      const _LocationProgress(),

                      const SizedBox(
                        height:
                        24,
                      ),

                      // ===========================================
                      // GPS / MAP CARD
                      // ===========================================

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

                            // =====================================
                            // CURRENT GPS
                            // =====================================

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
                                gettingLocation ||
                                    validatingManualAddress
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

                            // =====================================
                            // MAP
                            // =====================================

                            SizedBox(
                              width:
                              double.infinity,

                              child:
                              OutlinedButton.icon(
                                onPressed:
                                gettingLocation ||
                                    validatingManualAddress
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

                      // ===========================================
                      // COORDINATE / ACCURACY
                      // ===========================================

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

                      // ===========================================
                      // NEARBY CHECKING
                      // ===========================================

                      if (checkingNearby) ...[
                        const SizedBox(
                          height:
                          12,
                        ),

                        const LinearProgressIndicator(),
                      ],

                      // ===========================================
                      // NEARBY RESULTS
                      // ===========================================

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

                      // ===========================================
                      // DRAFT STATUS
                      // ===========================================

                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets.symmetric(
                          horizontal:
                          12,

                          vertical:
                          10,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          _draftStatusColor
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
                            _draftStatusColor
                                .withOpacity(
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
                                  ? Icons
                                  .cloud_off_outlined
                                  : Icons
                                  .cloud_done_outlined,

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

                      // ===========================================
                      // ADDRESS
                      // ===========================================

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

                        textInputAction:
                        TextInputAction.search,

                        onSubmitted:
                            (_) async {
                          await _verifyTypedAddress();
                        },

                        style:
                        const TextStyle(
                          color:
                          Colors.white,
                        ),

                        decoration:
                        _inputDecoration(
                          hint:
                          'Detect GPS, choose map or enter a real address',

                          prefixIcon:
                          const Icon(
                            Icons
                                .location_on_outlined,

                            color:
                            AppColors.primary,
                          ),
                        ).copyWith(
                          errorText:
                          addressValidationError,

                          errorMaxLines:
                          3,
                        ),
                      ),

                      const SizedBox(
                        height:
                        10,
                      ),

                      // ===========================================
                      // MANUAL ADDRESS LOOKUP
                      // ===========================================

                      SizedBox(
                        width:
                        double.infinity,

                        child:
                        OutlinedButton.icon(
                          onPressed:
                          validatingManualAddress ||
                              gettingLocation
                              ? null
                              : _verifyTypedAddress,

                          icon:
                          validatingManualAddress
                              ? const SizedBox(
                            width:
                            16,

                            height:
                            16,

                            child:
                            CircularProgressIndicator(
                              strokeWidth:
                              2,
                            ),
                          )
                              : const Icon(
                            Icons.search_rounded,
                          ),

                          label:
                          Text(
                            validatingManualAddress
                                ? 'Checking Address...'
                                : 'Find Address on Map',
                          ),
                        ),
                      ),

                      // ===========================================
                      // GEOCODED ADDRESS CONFIRMATION
                      // ===========================================

                      if (
                      locationVerificationStatus ==
                          'geocoded' &&
                          latitude != null &&
                          longitude != null
                      ) ...[
                        const SizedBox(
                          height:
                          10,
                        ),

                        Container(
                          width:
                          double.infinity,

                          padding:
                          const EdgeInsets.all(
                            11,
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
                              11,
                            ),

                            border:
                            Border.all(
                              color:
                              AppColors.success
                                  .withOpacity(
                                0.45,
                              ),
                            ),
                          ),

                          child:
                          const Row(
                            children: [
                              Icon(
                                Icons
                                    .verified_outlined,

                                size:
                                17,

                                color:
                                AppColors.success,
                              ),

                              SizedBox(
                                width:
                                8,
                              ),

                              Expanded(
                                child:
                                Text(
                                  'Address matched to map coordinates.',

                                  style:
                                  TextStyle(
                                    color:
                                    AppColors.success,

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
                      ],

                      const SizedBox(
                        height:
                        20,
                      ),

                      // ===========================================
                      // LANDMARK
                      // ===========================================

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

                      // ===========================================
                      // INFO
                      // ===========================================

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
                                    'as possible duplicates. A manually '
                                    'entered address must first match a real '
                                    'map location. For best GPS results, '
                                    'accuracy should normally be within '
                                    '±50 metres.',

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

                      // ===========================================
                      // SMART ASSIST TRANSFER STATUS
                      //
                      // Existing design/function preserved.
                      // ===========================================

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

              // ===============================================
              // BOTTOM
              // ===============================================

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

    errorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.danger,
      ),
    ),

    focusedErrorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.danger,
      ),
    ),
  );
}