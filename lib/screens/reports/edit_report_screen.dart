import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/infrastructure_report.dart';
import '../../models/report_final_ai_analysis.dart';
import '../../models/report_image_ai_analysis.dart';
import '../../models/report_video_ai_analysis.dart';

import '../../services/ai_evidence_service.dart';
import '../../services/location_service.dart';
import '../../services/report_edit_evidence_service.dart';
import '../../services/report_service.dart';
import '../../services/video_evidence_ai_service.dart';

import '../../theme/app_colors.dart';

import 'map_picker_screen.dart';

// ================================================================
// EDIT REPORT SCREEN
//
// FULL EDIT SMART ASSIST FLOW
//
// Citizen edits report
//      ↓
// Meaningful text validation
//      ↓
// GPS / Map / Typed-address geocoding
//      ↓
// Multiple photos
//      └── Individual Photo AI
//
// Multiple short videos
//      └── Sampled-frame Video AI
//
// All successful evidence AI results
//      ↓
// FINAL COMBINED IMAGE + VIDEO ANALYSIS
//      ↓
// Citizen review
//      ↓
// Keep Mine / Apply Final AI
//      ↓
// Save current edited report
//
// IMPORTANT:
//
// 1. Individual evidence AI never overwrites citizen data.
// 2. Only FINAL COMBINED AI can suggest report-level changes.
// 3. AI suggestions require explicit citizen approval.
// 4. Video AI reviews sampled frames, not every frame continuously.
// 5. AI does not visually verify GPS/location.
// ================================================================

enum AiTextReviewChoice {
  unresolved,
  original,
  reedit,
  ai,
}

class EditReportScreen extends StatefulWidget {
  final InfrastructureReport report;

  const EditReportScreen({
    super.key,
    required this.report,
  });

  @override
  State<EditReportScreen> createState() =>
      _EditReportScreenState();
}

class _EditReportScreenState
    extends State<EditReportScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final ReportService reportService =
  ReportService();

  final ReportEditEvidenceService evidenceService =
  ReportEditEvidenceService();

  final AiEvidenceService aiService =
  AiEvidenceService();

  final VideoEvidenceAiService videoAiService =
      VideoEvidenceAiService.instance;

  final LocationService locationService =
  LocationService();

  final Geocoding geocoding =
  Geocoding();

  final ImagePicker picker =
  ImagePicker();

  final SupabaseClient supabase =
      Supabase.instance.client;

  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> formKey =
  GlobalKey<FormState>();

  late TextEditingController titleController;

  late TextEditingController descriptionController;

  late TextEditingController addressController;

  late TextEditingController landmarkController;

  late String selectedCategory;

  late String selectedPriority;

  // ============================================================
  // GENERAL STATE
  // ============================================================

  bool saving =
  false;

  bool loadingEvidence =
  true;

  bool editingEvidence =
  false;

  bool analyzingAi =
  false;

  bool combiningAnalyses =
  false;

  bool gettingLocation =
  false;

  bool validatingAddress =
  false;

  bool aiSuggestionsApplied =
  false;

  String? evidenceError;

  String? finalAnalysisError;

  String? addressValidationError;

  String? analyzingEvidenceKey;

  // ============================================================
  // LOCATION
  // ============================================================

  double? latitude;

  double? longitude;

  double? gpsAccuracy;

  String? verifiedAddress;

  String locationVerificationStatus =
      'saved';

  bool updatingAddressProgrammatically =
  false;

  // ============================================================
  // EVIDENCE
  // ============================================================

  List<EditableReportEvidence> evidence =
  <EditableReportEvidence>[];

  // ============================================================
  // INDIVIDUAL PHOTO ANALYSES
  //
  // KEY:
  // sourceTable:id
  // ============================================================

  final Map<String, ReportImageAiAnalysis>
  imageAnalyses =
  <String, ReportImageAiAnalysis>{};

  final Map<String, String>
  imageAnalysisErrors =
  <String, String>{};

  // ============================================================
  // INDIVIDUAL VIDEO ANALYSES
  // ============================================================

  final Map<String, ReportVideoAiAnalysis>
  videoAnalyses =
  <String, ReportVideoAiAnalysis>{};

  final Map<String, String>
  videoAnalysisErrors =
  <String, String>{};

  // ============================================================
  // FINAL COMBINED ANALYSIS
  // ============================================================

  ReportFinalAiAnalysis?
  finalAiAnalysis;

  // ============================================================
  // MANDATORY SEMANTIC TEXT REVIEW
  //
  // Local validators catch obvious invalid text. They cannot
  // reliably detect a grammatically valid but irrelevant sentence
  // such as "good by to you all".
  //
  // Therefore, when Title or Description is changed, Save requires
  // a fresh final Smart Assist assessment. If AI reports the text
  // as not meaningful, insufficient, or suggests substantially
  // different wording, the citizen must choose:
  //
  // 1. Use AI Version
  // 2. Re-edit
  //
  // Re-edit blocks Save until the changed wording is reviewed again.
  // ============================================================

  AiTextReviewChoice textReviewChoice =
      AiTextReviewChoice.unresolved;

  bool semanticTextReviewResolved =
  false;

  String? lastAiReviewedTitle;

  String? lastAiReviewedDescription;

  // ============================================================
  // OPTIONS
  // ============================================================

  final List<String> categories =
  <String>[
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  final List<String> priorities =
  <String>[
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  // ============================================================
  // LIMITS
  // ============================================================

  static const int maxEvidenceItems =
  5;

  static const int maxAiImages =
  5;

  static const int maxAiVideos =
  3;

  static const Duration maxVideoDuration =
  Duration(
    seconds: 30,
  );

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isBusy =>
      saving ||
          loadingEvidence ||
          editingEvidence ||
          analyzingAi ||
          combiningAnalyses ||
          gettingLocation ||
          validatingAddress;

  int get photoCount =>
      evidence
          .where(
            (item) =>
        item.isImage,
      )
          .length;

  int get videoCount =>
      evidence
          .where(
            (item) =>
        item.isVideo,
      )
          .length;

  int get successfulAiCount =>
      imageAnalyses.length +
          videoAnalyses.length;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    selectedCategory =
        widget.report.category;

    selectedPriority =
        widget.report.priority;

    titleController =
        TextEditingController(
          text:
          widget.report.title,
        );

    descriptionController =
        TextEditingController(
          text:
          widget.report.description,
        );

    addressController =
        TextEditingController(
          text:
          widget.report.address,
        );

    landmarkController =
        TextEditingController(
          text:
          widget.report.landmark ??
              '',
        );

    latitude =
        widget.report.latitude;

    longitude =
        widget.report.longitude;

    verifiedAddress =
        widget.report.address.trim();

    addressController.addListener(
      handleAddressChanged,
    );

    loadEvidence();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    addressController.removeListener(
      handleAddressChanged,
    );

    titleController.dispose();

    descriptionController.dispose();

    addressController.dispose();

    landmarkController.dispose();

    super.dispose();
  }

  // ============================================================
  // EVIDENCE KEY
  // ============================================================

  String evidenceKey(
      EditableReportEvidence item,
      ) {
    return '${item.sourceTable}:${item.id}';
  }

  // ============================================================
  // CLEAN ERROR
  // ============================================================

  String cleanError(
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

  // ============================================================
  // LOAD EVIDENCE
  // ============================================================

  Future<void> loadEvidence() async {
    if (mounted) {
      setState(() {
        loadingEvidence =
        true;

        evidenceError =
        null;
      });
    }

    try {
      final List<EditableReportEvidence> result =
      await evidenceService.loadEvidence(
        reportId:
        widget.report.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        evidence =
            result;

        loadingEvidence =
        false;

        imageAnalyses.clear();

        imageAnalysisErrors.clear();

        videoAnalyses.clear();

        videoAnalysisErrors.clear();

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingEvidence =
        false;

        evidenceError =
            cleanError(
              e,
            );
      });
    }
  }

  // ============================================================
  // MEANINGFUL MULTILINGUAL-FRIENDLY VALIDATION
  //
  // Supports:
  // - English
  // - Malay
  // - accented Latin
  // - Chinese
  // - Japanese
  // - Korean
  // - mixed text
  // ============================================================

  bool containsMeaningfulCharacter(
      String text,
      ) {
    return RegExp(
      r'[A-Za-zÀ-ÖØ-öø-ÿĀ-ž'
      r'\u0100-\u024F'
      r'\u3040-\u30FF'
      r'\u3400-\u4DBF'
      r'\u4E00-\u9FFF'
      r'\uAC00-\uD7AF]',
      unicode:
      true,
    ).hasMatch(
      text,
    );
  }

  String? validateMeaningfulText(
      String value, {
        required String fieldName,
        required int minimumLength,
        required int minimumWords,
        bool optional = false,
      }) {
    final String text =
    value.trim();

    if (optional &&
        text.isEmpty) {
      return null;
    }

    if (text.isEmpty) {
      return 'Please enter a $fieldName.';
    }

    if (text.length <
        minimumLength) {
      return 'The $fieldName is too short to be useful.';
    }

    if (!containsMeaningfulCharacter(
      text,
    )) {
      return 'The $fieldName must contain meaningful text.';
    }

    if (RegExp(
      r'^[0-9\s.,/#\-]+$',
      unicode:
      true,
    ).hasMatch(
      text,
    )) {
      return 'The $fieldName cannot contain only numbers or symbols.';
    }

    final String compact =
    text.replaceAll(
      RegExp(
        r'\s+',
        unicode:
        true,
      ),
      '',
    );

    if (compact.length >=
        4 &&
        RegExp(
          r'^(.)\1+$',
          caseSensitive:
          false,
          unicode:
          true,
        ).hasMatch(
          compact,
        )) {
      return 'The $fieldName contains repeated characters '
          'and does not appear meaningful.';
    }

    if (RegExp(
      r'(.)\1{4,}',
      caseSensitive:
      false,
      unicode:
      true,
    ).hasMatch(
      text,
    )) {
      return 'The $fieldName contains too many repeated characters.';
    }

    final bool containsCjk =
    RegExp(
      r'[\u3040-\u30FF'
      r'\u3400-\u4DBF'
      r'\u4E00-\u9FFF'
      r'\uAC00-\uD7AF]',
      unicode:
      true,
    ).hasMatch(
      text,
    );

    if (!containsCjk) {
      final List<String> words =
      text
          .split(
        RegExp(
          r'\s+',
          unicode:
          true,
        ),
      )
          .where(
            (word) =>
        word
            .trim()
            .isNotEmpty,
      )
          .toList();

      if (words.length <
          minimumWords) {
        return 'Please provide a meaningful $fieldName '
            'using at least $minimumWords useful words.';
      }
    }

    return null;
  }

  String? validateTitle(
      String? value,
      ) {
    return validateMeaningfulText(
      value ??
          '',
      fieldName:
      'report title',
      minimumLength:
      5,
      minimumWords:
      2,
    );
  }

  String? validateDescription(
      String? value,
      ) {
    return validateMeaningfulText(
      value ??
          '',
      fieldName:
      'description',
      minimumLength:
      10,
      minimumWords:
      3,
    );
  }

  String? validateAddress(
      String? value,
      ) {
    return validateMeaningfulText(
      value ??
          '',
      fieldName:
      'address',
      minimumLength:
      5,
      minimumWords:
      2,
    );
  }

  String? validateLandmark(
      String? value,
      ) {
    return validateMeaningfulText(
      value ??
          '',
      fieldName:
      'landmark',
      minimumLength:
      3,
      minimumWords:
      1,
      optional:
      true,
    );
  }

  // ============================================================
  // INVALIDATE FINAL AI
  //
  // Evidence-level visual observations can remain available.
  // Final report-level result becomes stale if citizen changes
  // report information or location.
  // ============================================================

  void invalidateFinalAi() {
    if (!mounted) {
      return;
    }

    setState(() {
      finalAiAnalysis =
      null;

      finalAnalysisError =
      null;

      aiSuggestionsApplied =
      false;

      semanticTextReviewResolved =
      false;

      textReviewChoice =
          AiTextReviewChoice.unresolved;

      lastAiReviewedTitle =
      null;

      lastAiReviewedDescription =
      null;
    });
  }

  // ============================================================
  // ADDRESS CHANGE
  //
  // IMPORTANT:
  // If citizen manually changes an address, old coordinates
  // must not remain attached to the new address.
  // ============================================================

  void handleAddressChanged() {
    if (updatingAddressProgrammatically) {
      return;
    }

    final String currentAddress =
    addressController.text
        .trim();

    final String previousAddress =
    (verifiedAddress ??
        '')
        .trim();

    if (previousAddress.isNotEmpty &&
        currentAddress !=
            previousAddress &&
        latitude !=
            null &&
        longitude !=
            null) {
      setState(() {
        latitude =
        null;

        longitude =
        null;

        gpsAccuracy =
        null;

        locationVerificationStatus =
        'manual_unverified';

        addressValidationError =
        null;

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });

      return;
    }

    if (finalAiAnalysis !=
        null) {
      invalidateFinalAi();
    }
  }

  // ============================================================
  // PROGRAMMATIC ADDRESS
  // ============================================================

  void setAddressProgrammatically(
      String value,
      ) {
    updatingAddressProgrammatically =
    true;

    addressController.text =
        value;

    updatingAddressProgrammatically =
    false;
  }

  // ============================================================
  // FORMAT PLACEMARK
  // ============================================================

  String formatPlacemarkAddress(
      Placemark placemark,
      String fallback,
      ) {
    final List<String> values =
    <String>[
      placemark.name ??
          '',
      placemark.street ??
          '',
      placemark.subLocality ??
          '',
      placemark.locality ??
          '',
      placemark.subAdministrativeArea ??
          '',
      placemark.administrativeArea ??
          '',
      placemark.postalCode ??
          '',
      placemark.country ??
          '',
    ];

    final Set<String> seen =
    <String>{};

    final List<String> parts =
    <String>[];

    for (final String value
    in values) {
      final String clean =
      value.trim();

      if (clean.isEmpty) {
        continue;
      }

      if (seen.add(
        clean.toLowerCase(),
      )) {
        parts.add(
          clean,
        );
      }
    }

    if (parts.isEmpty) {
      return fallback;
    }

    return parts.join(
      ', ',
    );
  }

  // ============================================================
  // VERIFY TYPED ADDRESS
  // ============================================================

  Future<bool> verifyTypedAddress() async {
    if (validatingAddress ||
        saving ||
        editingEvidence ||
        analyzingAi ||
        combiningAnalyses) {
      return false;
    }

    final String inputAddress =
    addressController.text
        .trim();

    if (inputAddress.isEmpty) {
      setState(() {
        addressValidationError =
        'Please enter an address.';
      });

      return false;
    }

    setState(() {
      validatingAddress =
      true;

      addressValidationError =
      null;
    });

    try {
      // ========================================================
      // FORWARD GEOCODING
      // ========================================================

      final List<Location> locations =
      await geocoding
          .locationFromAddress(
        inputAddress,
      );

      if (locations.isEmpty) {
        throw Exception(
          'Address not found.',
        );
      }

      final Location resolved =
          locations.first;

      final double newLatitude =
          resolved.latitude;

      final double newLongitude =
          resolved.longitude;

      if (newLatitude <
          -90 ||
          newLatitude >
              90 ||
          newLongitude <
              -180 ||
          newLongitude >
              180) {
        throw Exception(
          'Invalid coordinates.',
        );
      }

      String formattedAddress =
          inputAddress;

      // ========================================================
      // REVERSE GEOCODING
      // ========================================================

      try {
        final List<Placemark> placemarks =
        await geocoding
            .placemarkFromCoordinates(
          newLatitude,
          newLongitude,
        );

        if (placemarks.isNotEmpty) {
          formattedAddress =
              formatPlacemarkAddress(
                placemarks.first,
                inputAddress,
              );
        }
      } catch (_) {
        // Forward geocoding already resolved the input.
      }

      if (!mounted) {
        return false;
      }

      setState(() {
        latitude =
            newLatitude;

        longitude =
            newLongitude;

        gpsAccuracy =
        null;

        verifiedAddress =
            formattedAddress;

        locationVerificationStatus =
        'geocoded';

        addressValidationError =
        null;

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });

      setAddressProgrammatically(
        formattedAddress,
      );

      showMessage(
        'Address matched to map coordinates successfully.',
      );

      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      setState(() {
        latitude =
        null;

        longitude =
        null;

        gpsAccuracy =
        null;

        locationVerificationStatus =
        'manual_unverified';

        addressValidationError =
        'This address could not be matched to map coordinates. '
            'Please enter a clearer address, use Current GPS, '
            'or choose the point on the map.';

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });

      return false;
    } finally {
      if (mounted) {
        setState(() {
          validatingAddress =
          false;
        });
      }
    }
  }

  // ============================================================
  // CURRENT GPS
  // ============================================================

  Future<void> detectCurrentLocation() async {
    if (isBusy) {
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

        verifiedAddress =
            result.address;

        locationVerificationStatus =
        'gps';

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });

      setAddressProgrammatically(
        result.address,
      );

      if (result.accuracy >
          50) {
        showMessage(
          'Location detected, but GPS accuracy is low '
              '(±${result.accuracy.toStringAsFixed(0)} m). '
              'You can adjust the exact point on the map.',
        );
      } else {
        showMessage(
          'Current location detected successfully.',
        );
      }
    } catch (e) {
      showMessage(
        cleanError(
          e,
        ),
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
  // OPEN MAP PICKER
  // ============================================================

  Future<void> openMapPicker() async {
    if (isBusy) {
      return;
    }

    double initialLatitude =
        latitude ??
            3.1390;

    double initialLongitude =
        longitude ??
            101.6869;

    if (latitude ==
        null ||
        longitude ==
            null) {
      try {
        final result =
        await locationService
            .getCurrentLocationWithAddress();

        initialLatitude =
            result.latitude;

        initialLongitude =
            result.longitude;
      } catch (_) {
        // KL coordinate is only map start fallback.
      }
    }

    if (!mounted) {
      return;
    }

    final MapPickerResult? result =
    await Navigator.push<
        MapPickerResult>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
            MapPickerScreen(
              initialLatitude:
              initialLatitude,
              initialLongitude:
              initialLongitude,
            ),
      ),
    );

    if (result ==
        null ||
        !mounted) {
      return;
    }

    setState(() {
      latitude =
          result.latitude;

      longitude =
          result.longitude;

      gpsAccuracy =
      null;

      verifiedAddress =
          result.address;

      locationVerificationStatus =
      'map';

      addressValidationError =
      null;

      finalAiAnalysis =
      null;

      finalAnalysisError =
      null;

      aiSuggestionsApplied =
      false;
    });

    setAddressProgrammatically(
      result.address,
    );
  }

  // ============================================================
  // ENSURE VALID LOCATION
  // ============================================================

  Future<bool> ensureValidLocation() async {
    if (latitude !=
        null &&
        longitude !=
            null &&
        addressController.text
            .trim()
            .isNotEmpty) {
      return true;
    }

    return verifyTypedAddress();
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> pickImage(
      ImageSource source,
      ) async {
    if (isBusy) {
      return;
    }

    if (evidence.length >=
        maxEvidenceItems) {
      showMessage(
        'A maximum of $maxEvidenceItems evidence items is allowed.',
      );

      return;
    }

    try {
      final XFile? picked =
      await picker.pickImage(
        source:
        source,
        imageQuality:
        88,
        maxWidth:
        2048,
      );

      if (picked ==
          null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        editingEvidence =
        true;
      });

      final EditableReportEvidence added =
      await evidenceService.addImage(
        reportId:
        widget.report.id,
        file:
        File(
          picked.path,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        evidence.add(
          added,
        );

        editingEvidence =
        false;

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });

      showMessage(
        'Evidence photo added. Smart Assist is analysing it.',
      );

      await analyzeSingleImage(
        added,
        rebuildFinal:
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        editingEvidence =
        false;
      });

      showMessage(
        cleanError(
          e,
        ),
      );
    }
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> pickVideo(
      ImageSource source,
      ) async {
    if (isBusy) {
      return;
    }

    if (evidence.length >=
        maxEvidenceItems) {
      showMessage(
        'A maximum of $maxEvidenceItems evidence items is allowed.',
      );

      return;
    }

    if (videoCount >=
        maxAiVideos) {
      showMessage(
        'A maximum of $maxAiVideos short videos is supported.',
      );

      return;
    }

    try {
      final XFile? picked =
      await picker.pickVideo(
        source:
        source,
        maxDuration:
        maxVideoDuration,
      );

      if (picked ==
          null) {
        return;
      }

      final File localVideo =
      File(
        picked.path,
      );

      if (!await localVideo.exists() ||
          await localVideo.length() <=
              0) {
        throw Exception(
          'The selected video is unavailable or empty.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        editingEvidence =
        true;
      });

      final EditableReportEvidence added =
      await evidenceService.addVideo(
        reportId:
        widget.report.id,
        file:
        localVideo,

        // IMPORTANT:
        // use EDITED current coordinates.
        latitude:
        latitude,

        longitude:
        longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        evidence.add(
          added,
        );

        editingEvidence =
        false;

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });

      showMessage(
        'Evidence video added. Smart Assist is reviewing representative frames.',
      );

      await analyzeSingleVideo(
        added,
        localFile:
        localVideo,
        rebuildFinal:
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        editingEvidence =
        false;
      });

      showMessage(
        cleanError(
          e,
        ),
      );
    }
  }

  // ============================================================
  // ADD EVIDENCE MENU
  // ============================================================

  Future<void> showAddEvidenceMenu() async {
    if (isBusy) {
      return;
    }

    if (evidence.length >=
        maxEvidenceItems) {
      showMessage(
        'A maximum of $maxEvidenceItems evidence items is allowed.',
      );

      return;
    }

    final String? option =
    await showModalBottomSheet<String>(
      context:
      context,
      backgroundColor:
      AppColors.surface,
      showDragHandle:
      true,
      builder:
          (
          bottomContext,
          ) {
        return SafeArea(
          child:
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              18,
            ),
            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const Text(
                  'Add Evidence',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                    fontWeight:
                    FontWeight.bold,
                    fontSize:
                    16,
                  ),
                ),

                const SizedBox(
                  height:
                  12,
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.camera_alt_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Take Photo',
                  ),
                  onTap:
                      () {
                    Navigator.pop(
                      bottomContext,
                      'camera_image',
                    );
                  },
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.photo_library_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Choose Photo',
                  ),
                  onTap:
                      () {
                    Navigator.pop(
                      bottomContext,
                      'gallery_image',
                    );
                  },
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.videocam_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Record Video',
                  ),
                  onTap:
                      () {
                    Navigator.pop(
                      bottomContext,
                      'camera_video',
                    );
                  },
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.video_library_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Choose Video',
                  ),
                  onTap:
                      () {
                    Navigator.pop(
                      bottomContext,
                      'gallery_video',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    switch (option) {
      case 'camera_image':
        await pickImage(
          ImageSource.camera,
        );
        break;

      case 'gallery_image':
        await pickImage(
          ImageSource.gallery,
        );
        break;

      case 'camera_video':
        await pickVideo(
          ImageSource.camera,
        );
        break;

      case 'gallery_video':
        await pickVideo(
          ImageSource.gallery,
        );
        break;
    }
  }

  // ============================================================
// REMOVE EVIDENCE
//
// EVIDENCE IS MANDATORY
//
// Create Report AND Edit Report must always retain at least ONE
// evidence item:
//
// - one photo, OR
// - one short video.
//
// The final evidence item cannot be removed directly. The citizen
// can choose Add Replacement, then remove the old item.
//
// For non-final evidence deletion:
// - delete in Supabase first,
// - verify by reloading from the server,
// - invalidate stale individual/final AI.
// ============================================================

  Future<void> removeEvidence(
      EditableReportEvidence item,
      ) async {
    if (isBusy) {
      return;
    }

    // ==========================================================
    // PROTECT LAST EVIDENCE
    // ==========================================================

    if (evidence.length <= 1) {
      final bool? addReplacement =
      await showDialog<bool>(
        context:
        context,

        barrierDismissible:
        false,

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
                  Icons.verified_user_outlined,

                  color:
                  AppColors.primary,
                ),

                SizedBox(
                  width:
                  10,
                ),

                Expanded(
                  child:
                  Text(
                    'Evidence Required',
                  ),
                ),
              ],
            ),

            content:
            const Text(
              'Every report must keep at least one evidence photo or '
                  'short video. This is currently the only evidence item, '
                  'so it cannot be removed.\n\n'
                  'To replace it, add a new photo or video first. '
                  'After the replacement is saved, you can remove this item.',

              style:
              TextStyle(
                color:
                AppColors.textSecondary,

                height:
                1.45,
              ),
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
                  'Keep Evidence',
                ),
              ),

              ElevatedButton.icon(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },

                icon:
                const Icon(
                  Icons.add_photo_alternate_outlined,

                  size:
                  17,
                ),

                label:
                const Text(
                  'Add Replacement',
                ),
              ),
            ],
          );
        },
      );

      if (addReplacement == true &&
          mounted) {
        await showAddEvidenceMenu();
      }

      return;
    }

    // ==========================================================
    // CONFIRM NORMAL DELETE
    // ==========================================================

    final bool? confirmed =
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
            'Remove Evidence?',
          ),

          content:
          const Text(
            'This evidence will be permanently removed. '
                'Its individual AI result and the old final combined '
                'assessment will no longer be valid.',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              height:
              1.4,
            ),
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
                'Keep',
              ),
            ),

            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
              const Text(
                'Remove',

                style:
                TextStyle(
                  color:
                  Colors.orangeAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      editingEvidence =
      true;
    });

    final String removedKey =
    evidenceKey(
      item,
    );

    try {
      // ========================================================
      // 1. DELETE FROM DATABASE + STORAGE
      //
      // The service now verifies that the database row was
      // actually deleted. RLS "0 rows deleted" is treated as an
      // error instead of pretending deletion succeeded.
      // ========================================================

      await evidenceService.removeEvidence(
        evidence:
        item,
      );

      // ========================================================
      // 2. REMOVE STALE FINAL AI DATABASE ROW
      // ========================================================

      try {
        await supabase
            .from(
          'report_final_ai_analysis',
        )
            .delete()
            .eq(
          'report_id',
          widget.report.id,
        );
      } catch (e) {
        debugPrint(
          'Unable to clear stale final AI analysis: $e',
        );
      }

      if (!mounted) {
        return;
      }

      // ========================================================
      // 3. CLEAR LOCAL AI STATE
      // ========================================================

      setState(() {
        imageAnalyses.remove(
          removedKey,
        );

        imageAnalysisErrors.remove(
          removedKey,
        );

        videoAnalyses.remove(
          removedKey,
        );

        videoAnalysisErrors.remove(
          removedKey,
        );

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        analyzingEvidenceKey =
        null;

        aiSuggestionsApplied =
        false;

        semanticTextReviewResolved =
        false;

        textReviewChoice =
            AiTextReviewChoice.unresolved;

        lastAiReviewedTitle =
        null;

        lastAiReviewedDescription =
        null;
      });

      // ========================================================
      // 4. RELOAD FROM SUPABASE
      //
      // This is the important persistence fix.
      //
      // We do NOT trust only evidence.removeWhere(...).
      // The list shown after deletion is loaded again from the
      // database, so reopening Edit Report shows the same result.
      // ========================================================

      final List<EditableReportEvidence> serverEvidence =
      await evidenceService.loadEvidence(
        reportId:
        widget.report.id,
      );

      // The deleted exact row must no longer exist.
      final bool stillExists =
      serverEvidence.any(
            (
            current,
            ) =>
        current.id ==
            item.id &&
            current.sourceTable ==
                item.sourceTable,
      );

      if (stillExists) {
        throw Exception(
          'The evidence was not removed from the database. '
              'Please check the Supabase DELETE/RLS policy and try again.',
        );
      }

      // Defensive invariant: edit must still retain one item.
      if (serverEvidence.isEmpty) {
        throw Exception(
          'Evidence cannot be left empty. Add replacement evidence '
              'before removing the final item.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        evidence =
            serverEvidence;

        editingEvidence =
        false;
      });

      showMessage(
        'Evidence removed permanently. '
            '${serverEvidence.length} evidence item(s) remain.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      // Reload server truth even after failure. This prevents a
      // local UI-only delete from making the screen look correct
      // when the database row still exists.
      try {
        final List<EditableReportEvidence> serverEvidence =
        await evidenceService.loadEvidence(
          reportId:
          widget.report.id,
        );

        if (mounted) {
          setState(() {
            evidence =
                serverEvidence;

            editingEvidence =
            false;
          });
        }
      } catch (_) {
        setState(() {
          editingEvidence =
          false;
        });
      }

      showMessage(
        cleanError(
          e,
        ),
      );
    }
  }

  // ============================================================
  // DOWNLOAD STORED VIDEO TO TEMP FILE
  //
  // Existing videos are in private Supabase Storage.
  //
  // VideoEvidenceAiService expects a File.
  //
  // signed URL
  //      ↓
  // temporary local video
  //      ↓
  // video AI
  //      ↓
  // delete temporary file
  // ============================================================

  Future<File> downloadVideoToTemp(
      EditableReportEvidence item,
      ) async {
    final String signedUrl =
        item.signedUrl
            ?.trim() ??
            '';

    if (signedUrl.isEmpty) {
      throw Exception(
        'Unable to access this stored video for AI analysis.',
      );
    }

    final HttpClient client =
    HttpClient();

    try {
      final HttpClientRequest request =
      await client.getUrl(
        Uri.parse(
          signedUrl,
        ),
      );

      final HttpClientResponse response =
      await request.close();

      if (response.statusCode <
          200 ||
          response.statusCode >=
              300) {
        throw Exception(
          'Unable to download stored video '
              '(HTTP ${response.statusCode}).',
        );
      }

      final String lowerPath =
      item.storagePath
          .toLowerCase();

      String extension =
          '.mp4';

      if (lowerPath.endsWith(
        '.mov',
      )) {
        extension =
        '.mov';
      } else if (lowerPath.endsWith(
        '.m4v',
      )) {
        extension =
        '.m4v';
      }

      final File temporaryVideo =
      File(
        '${Directory.systemTemp.path}'
            '${Platform.pathSeparator}'
            'smartcity_edit_video_'
            '${item.id}_'
            '${DateTime.now().millisecondsSinceEpoch}'
            '$extension',
      );

      final IOSink sink =
      temporaryVideo.openWrite();

      await response.pipe(
        sink,
      );

      if (!await temporaryVideo.exists() ||
          await temporaryVideo.length() <=
              0) {
        throw Exception(
          'Downloaded video is empty.',
        );
      }

      return temporaryVideo;
    } finally {
      client.close(
        force:
        true,
      );
    }
  }

  // ============================================================
  // ANALYSE ONE IMAGE
  // ============================================================

  Future<bool> analyzeSingleImage(
      EditableReportEvidence item, {
        bool rebuildFinal = false,
      }) async {
    if (!item.isImage) {
      return false;
    }

    final String key =
    evidenceKey(
      item,
    );

    // Saved-image AI uses report_images.id.
    if (item.sourceTable !=
        ReportEditEvidenceService
            .reportImagesTable) {
      if (mounted) {
        setState(() {
          imageAnalysisErrors[key] =
          'This image is not stored in report_images and '
              'cannot use the current saved-image AI pipeline.';
        });
      }

      return false;
    }

    if (mounted) {
      setState(() {
        analyzingEvidenceKey =
            key;

        imageAnalysisErrors.remove(
          key,
        );

        imageAnalyses.remove(
          key,
        );

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });
    }

    try {
      final ReportImageAiAnalysis result =
      await aiService.analyzeImage(
        reportImageId:
        item.id,
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        imageAnalyses[key] =
            result;
      });

      if (rebuildFinal) {
        await combineAllAnalyses();
      }

      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          imageAnalysisErrors[key] =
              cleanError(
                e,
              );
        });
      }

      return false;
    } finally {
      if (mounted &&
          analyzingEvidenceKey ==
              key) {
        setState(() {
          analyzingEvidenceKey =
          null;
        });
      }
    }
  }

  // ============================================================
  // ANALYSE ONE VIDEO
  // ============================================================

  Future<bool> analyzeSingleVideo(
      EditableReportEvidence item, {
        File? localFile,
        bool rebuildFinal = false,
      }) async {
    if (!item.isVideo) {
      return false;
    }

    final String key =
    evidenceKey(
      item,
    );

    if (mounted) {
      setState(() {
        analyzingEvidenceKey =
            key;

        videoAnalysisErrors.remove(
          key,
        );

        videoAnalyses.remove(
          key,
        );

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });
    }

    File? temporaryFile;

    try {
      final File videoFile;

      if (localFile !=
          null &&
          await localFile.exists()) {
        videoFile =
            localFile;
      } else {
        temporaryFile =
        await downloadVideoToTemp(
          item,
        );

        videoFile =
            temporaryFile;
      }

      final ReportVideoAiAnalysis result =
      await videoAiService.analyzeLocalVideo(
        videoFile:
        videoFile,
        userCategory:
        selectedCategory,
        userPriority:
        selectedPriority,
        userTitle:
        titleController.text
            .trim(),
        userDescription:
        descriptionController.text
            .trim(),
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        videoAnalyses[key] =
            result;
      });

      if (rebuildFinal) {
        await combineAllAnalyses();
      }

      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          videoAnalysisErrors[key] =
              cleanError(
                e,
              );
        });
      }

      return false;
    } finally {
      if (temporaryFile !=
          null) {
        try {
          if (await temporaryFile.exists()) {
            await temporaryFile.delete();
          }
        } catch (_) {
          // Temp-file cleanup should never block report flow.
        }
      }

      if (mounted &&
          analyzingEvidenceKey ==
              key) {
        setState(() {
          analyzingEvidenceKey =
          null;
        });
      }
    }
  }

  // ============================================================
  // IMAGE ANALYSIS PAYLOAD
  // ============================================================

  Map<String, dynamic> imageAnalysisPayload(
      EditableReportEvidence item,
      ReportImageAiAnalysis analysis,
      ) {
    return <String, dynamic>{
      ...analysis.toJson(),

      'source_evidence_id':
      item.id,

      'evidence_type':
      'image',
    };
  }

  // ============================================================
  // VIDEO ANALYSIS PAYLOAD
  // ============================================================

  Map<String, dynamic> videoAnalysisPayload(
      EditableReportEvidence item,
      ReportVideoAiAnalysis analysis,
      ) {
    return <String, dynamic>{
      'source_evidence_id':
      item.id,

      'evidence_type':
      'video',

      'ai_status':
      analysis.aiStatus,

      'issue_detected':
      analysis.issueDetected,

      'category':
      analysis.category,

      'subcategory':
      analysis.subcategory,

      'severity':
      analysis.severity,

      'confidence':
      analysis.confidence,

      'description':
      analysis.description,

      'evidence_quality':
      analysis.evidenceQuality,

      'temporal_consistency':
      analysis.temporalConsistency,

      'useful_frame_count':
      analysis.usefulFrameCount,

      'analyzed_frame_count':
      analysis.analyzedFrameCount,

      'category_matches_user':
      analysis.categoryMatchesUser,

      'priority_change_recommended':
      analysis.priorityChangeRecommended,

      'recommended_priority':
      analysis.recommendedPriority,

      'suggested_title':
      analysis.suggestedTitle,

      'suggested_description':
      analysis.suggestedDescription,

      'report_quality':
      analysis.reportQuality,

      'report_sufficient':
      analysis.reportSufficient,

      'safety_concern':
      analysis.safetyConcern,

      'missing_information':
      analysis.missingInformation,

      'summary':
      analysis.summary,

      'limitation_notice':
      analysis.limitationNotice,

      'analyzed_at':
      analysis.analyzedAt
          ?.toUtc()
          .toIso8601String(),
    };
  }

  // ============================================================
  // FINAL COMBINED IMAGE + VIDEO ANALYSIS
  // ============================================================

  Future<void> combineAllAnalyses() async {
    if (combiningAnalyses) {
      return;
    }

    final List<Map<String, dynamic>>
    imagePayloads =
    <Map<String, dynamic>>[];

    final List<Map<String, dynamic>>
    videoPayloads =
    <Map<String, dynamic>>[];

    final List<String>
    sourceEvidenceIds =
    <String>[];

    // ==========================================================
    // ONLY CURRENT EVIDENCE
    //
    // Deleted evidence must never remain in final AI input.
    // ==========================================================

    for (final EditableReportEvidence item
    in evidence) {
      final String key =
      evidenceKey(
        item,
      );

      if (item.isImage) {
        final ReportImageAiAnalysis? analysis =
        imageAnalyses[key];

        if (analysis !=
            null) {
          imagePayloads.add(
            imageAnalysisPayload(
              item,
              analysis,
            ),
          );

          sourceEvidenceIds.add(
            item.id,
          );
        }
      }

      if (item.isVideo) {
        final ReportVideoAiAnalysis? analysis =
        videoAnalyses[key];

        if (analysis !=
            null) {
          videoPayloads.add(
            videoAnalysisPayload(
              item,
              analysis,
            ),
          );

          sourceEvidenceIds.add(
            item.id,
          );
        }
      }
    }

    if (imagePayloads.isEmpty &&
        videoPayloads.isEmpty) {
      if (mounted) {
        setState(() {
          finalAiAnalysis =
          null;

          finalAnalysisError =
          'No successful evidence AI result is available to combine.';
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        combiningAnalyses =
        true;

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });
    }

    try {
      // ========================================================
      // EDGE FUNCTION
      //
      // Latest function supports:
      //
      // image-only
      // video-only
      // mixed evidence
      // ========================================================

      final FunctionResponse response =
      await supabase.functions.invoke(
        'combine-report-ai-analysis',

        body:
        <String, dynamic>{
          'analysis_mode':
          'combine_analysis',

          // ====================================================
          // CURRENT EDITED REPORT
          // ====================================================

          'report_context':
          <String, dynamic>{
            'category':
            selectedCategory,

            'priority':
            selectedPriority,

            'title':
            titleController.text
                .trim(),

            'description':
            descriptionController.text
                .trim(),

            'address':
            addressController.text
                .trim(),

            'landmark':
            landmarkController.text
                .trim(),

            'latitude':
            latitude,

            'longitude':
            longitude,
          },

          // ====================================================
          // MULTI-PHOTO AI
          // ====================================================

          'image_analyses':
          imagePayloads,

          // ====================================================
          // MULTI-VIDEO AI
          // ====================================================

          'video_analyses':
          videoPayloads,
        },
      );

      final dynamic rawData =
          response.data;

      if (rawData is! Map) {
        throw Exception(
          'Final Smart Assist returned an invalid response.',
        );
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(
        rawData,
      );

      final String error =
          data['error']
              ?.toString()
              .trim() ??
              '';

      if (error.isNotEmpty) {
        throw Exception(
          error,
        );
      }

      final ReportFinalAiAnalysis result =
      ReportFinalAiAnalysis.fromAiResult(
        data,

        // Current model stores image count.
        analyzedImageCount:
        imagePayloads.length,

        // Includes both image + video evidence IDs.
        sourceEvidenceIds:
        sourceEvidenceIds
            .toSet()
            .toList(),
      ).copyWith(
        suggestionsApplied:
        false,

        reviewedByUser:
        false,

        originalUserCategory:
        widget.report.category,

        originalUserPriority:
        widget.report.priority,

        originalUserTitle:
        widget.report.title,

        originalUserDescription:
        widget.report.description,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        finalAiAnalysis =
            result;

        finalAnalysisError =
        null;

        // This exact Title + Description pair is what the final
        // combined AI has reviewed.
        lastAiReviewedTitle =
            titleController.text.trim();

        lastAiReviewedDescription =
            descriptionController.text.trim();

        semanticTextReviewResolved =
        false;

        textReviewChoice =
            AiTextReviewChoice.unresolved;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        finalAiAnalysis =
        null;

        finalAnalysisError =
            cleanError(
              e,
            );
      });
    } finally {
      if (mounted) {
        setState(() {
          combiningAnalyses =
          false;
        });
      }
    }
  }

  // ============================================================
  // ANALYSE ALL EVIDENCE
  //
  // IMAGE 1 → AI
  // IMAGE 2 → AI
  // IMAGE 3 → AI
  //
  // VIDEO 1 → VIDEO AI
  // VIDEO 2 → VIDEO AI
  //
  // Successful results
  //      ↓
  // Final Combined Analysis
  //
  // Failure of one evidence item does not stop others.
  // ============================================================

  Future<void> runAiAssist() async {
    if (isBusy) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    // ==========================================================
    // REPORT TEXT VALIDATION
    // ==========================================================

    if (!formKey.currentState!
        .validate()) {
      showMessage(
        'Please correct the highlighted report information '
            'before using Smart Assist.',
      );

      return;
    }

    // ==========================================================
    // CATEGORY
    // ==========================================================

    if (!categories.contains(
      selectedCategory,
    )) {
      showMessage(
        'Please select a valid issue category.',
      );

      return;
    }

    // ==========================================================
    // PRIORITY
    // ==========================================================

    if (!priorities.contains(
      selectedPriority,
    )) {
      showMessage(
        'Please select a valid priority level.',
      );

      return;
    }

    // ==========================================================
    // LOCATION
    // ==========================================================

    final bool locationReady =
    await ensureValidLocation();

    if (!locationReady ||
        !mounted) {
      showMessage(
        'Please confirm a valid map location before using Smart Assist.',
      );

      return;
    }

    // ==========================================================
    // EVIDENCE
    // ==========================================================

    if (evidence.isEmpty) {
      showMessage(
        'Evidence is required. Add at least one photo or short video '
            'before running Smart Assist.',
      );

      return;
    }

    final List<EditableReportEvidence> images =
    evidence
        .where(
          (item) =>
      item.isImage,
    )
        .take(
      maxAiImages,
    )
        .toList();

    final List<EditableReportEvidence> videos =
    evidence
        .where(
          (item) =>
      item.isVideo,
    )
        .take(
      maxAiVideos,
    )
        .toList();

    setState(() {
      analyzingAi =
      true;

      imageAnalyses.clear();

      imageAnalysisErrors.clear();

      videoAnalyses.clear();

      videoAnalysisErrors.clear();

      finalAiAnalysis =
      null;

      finalAnalysisError =
      null;

      aiSuggestionsApplied =
      false;
    });

    int successCount =
    0;

    try {
      // ========================================================
      // MULTIPLE PHOTO ANALYSIS
      // ========================================================

      for (final EditableReportEvidence image
      in images) {
        if (!mounted) {
          return;
        }

        final bool successful =
        await analyzeSingleImage(
          image,
          rebuildFinal:
          false,
        );

        if (successful) {
          successCount++;
        }

        // Reduce burst requests.
        await Future<void>.delayed(
          const Duration(
            milliseconds:
            300,
          ),
        );
      }

      // ========================================================
      // MULTIPLE VIDEO ANALYSIS
      // ========================================================

      for (final EditableReportEvidence video
      in videos) {
        if (!mounted) {
          return;
        }

        final bool successful =
        await analyzeSingleVideo(
          video,
          rebuildFinal:
          false,
        );

        if (successful) {
          successCount++;
        }

        await Future<void>.delayed(
          const Duration(
            milliseconds:
            300,
          ),
        );
      }

      // ========================================================
      // FINAL COMBINE
      // ========================================================

      if (successCount >
          0) {
        await combineAllAnalyses();
      }

      if (!mounted) {
        return;
      }

      if (successCount ==
          0) {
        showMessage(
          'Smart Assist could not analyse the current evidence. '
              'Your report and evidence remain safe and editable.',
        );
      } else if (finalAiAnalysis ==
          null) {
        showMessage(
          '$successCount evidence item(s) were analysed, '
              'but the final combined assessment is unavailable. '
              'You can retry the combine step.',
        );
      } else {
        showMessage(
          '$successCount evidence item(s) analysed. '
              'Review the final combined Smart Assist result.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          analyzingAi =
          false;

          analyzingEvidenceKey =
          null;
        });
      }
    }
  }

  // ============================================================
  // TEXT COMPARISON HELPERS
  //
  // This client-side similarity check is only a conservative
  // "large rewrite" trigger. Semantic meaning is decided by the
  // final AI fields such as titleMeaningful/descriptionMeaningful.
  // ============================================================

  String normalizeTextForComparison(
      String value,
      ) {
    return value
        .toLowerCase()
        .replaceAll(
      RegExp(
        r'[^\p{L}\p{N}\s]',
        unicode:
        true,
      ),
      ' ',
    )
        .replaceAll(
      RegExp(
        r'\s+',
        unicode:
        true,
      ),
      ' ',
    )
        .trim();
  }

  Set<String> comparisonTokens(
      String value,
      ) {
    final String normalized =
    normalizeTextForComparison(
      value,
    );

    if (normalized.isEmpty) {
      return <String>{};
    }

    final bool containsCjk =
    RegExp(
      r'[\u3040-\u30FF'
      r'\u3400-\u4DBF'
      r'\u4E00-\u9FFF'
      r'\uAC00-\uD7AF]',
      unicode:
      true,
    ).hasMatch(
      normalized,
    );

    if (containsCjk) {
      return normalized
          .replaceAll(
        ' ',
        '',
      )
          .split(
        '',
      )
          .where(
            (
            character,
            ) =>
        character.trim().isNotEmpty,
      )
          .toSet();
    }

    return normalized
        .split(
      ' ',
    )
        .where(
          (
          word,
          ) =>
      word.trim().isNotEmpty,
    )
        .toSet();
  }

  double textSimilarity(
      String first,
      String second,
      ) {
    final Set<String> a =
    comparisonTokens(
      first,
    );

    final Set<String> b =
    comparisonTokens(
      second,
    );

    if (a.isEmpty &&
        b.isEmpty) {
      return 1.0;
    }

    if (a.isEmpty ||
        b.isEmpty) {
      return 0.0;
    }

    final Set<String> union =
    a.union(
      b,
    );

    if (union.isEmpty) {
      return 1.0;
    }

    return a
        .intersection(
      b,
    )
        .length /
        union.length;
  }

  bool isSubstantiallyDifferent(
      String current,
      String suggestion, {
        required bool isTitle,
      }) {
    final String currentClean =
    current.trim();

    final String suggestionClean =
    suggestion.trim();

    if (currentClean.isEmpty ||
        suggestionClean.isEmpty) {
      return false;
    }

    if (normalizeTextForComparison(
      currentClean,
    ) ==
        normalizeTextForComparison(
          suggestionClean,
        )) {
      return false;
    }

    final double similarity =
    textSimilarity(
      currentClean,
      suggestionClean,
    );

    final int longer =
    currentClean.length >
        suggestionClean.length
        ? currentClean.length
        : suggestionClean.length;

    final int shorter =
    currentClean.length <
        suggestionClean.length
        ? currentClean.length
        : suggestionClean.length;

    final double lengthRatio =
    longer == 0
        ? 1
        : shorter / longer;

    if (isTitle) {
      return similarity < 0.40 ||
          lengthRatio < 0.45;
    }

    return similarity < 0.30 ||
        lengthRatio < 0.40;
  }

  bool get reportTextChanged {
    return titleController.text.trim() !=
        widget.report.title.trim() ||
        descriptionController.text.trim() !=
            widget.report.description.trim();
  }

  bool get currentTextHasFreshAiReview {
    return finalAiAnalysis != null &&
        lastAiReviewedTitle ==
            titleController.text.trim() &&
        lastAiReviewedDescription ==
            descriptionController.text.trim();
  }

  bool finalAiReportsTextConcern(
      ReportFinalAiAnalysis result,
      ) {
    final String currentTitle =
    titleController.text.trim();

    final String currentDescription =
    descriptionController.text.trim();

    final String aiTitle =
        result.suggestedTitle?.trim() ??
            '';

    final String aiDescription =
        result.suggestedDescription?.trim() ??
            '';

    final String reportIssue =
        result.reportIssue?.trim().toLowerCase() ??
            '';

    final bool explicitMeaningProblem =
        result.titleMeaningful == false ||
            result.descriptionMeaningful == false ||
            result.reportSufficient == false;

    final bool explicitReportIssue =
        reportIssue.isNotEmpty &&
            reportIssue != 'none' &&
            reportIssue != 'no issue' &&
            reportIssue != 'not applicable' &&
            reportIssue != 'n/a';

    final bool largeTitleRewrite =
        aiTitle.isNotEmpty &&
            isSubstantiallyDifferent(
              currentTitle,
              aiTitle,
              isTitle:
              true,
            );

    final bool largeDescriptionRewrite =
        aiDescription.isNotEmpty &&
            isSubstantiallyDifferent(
              currentDescription,
              aiDescription,
              isTitle:
              false,
            );

    return explicitMeaningProblem ||
        explicitReportIssue ||
        largeTitleRewrite ||
        largeDescriptionRewrite;
  }

  // ============================================================
  // REQUIRE FRESH AI REVIEW FOR CHANGED TITLE / DESCRIPTION
  //
  // This closes the gap where text such as:
  // "good by to you all"
  //
  // can pass simple length/word-count validation even though it
  // does not meaningfully describe the infrastructure issue.
  // ============================================================

  Future<bool> ensureSemanticTextReviewBeforeSave() async {
    if (!reportTextChanged) {
      return true;
    }

    // If the user already explicitly accepted the AI version,
    // and did not change the text afterward, allow Save.
    if (semanticTextReviewResolved &&
        textReviewChoice ==
            AiTextReviewChoice.ai) {
      return true;
    }

    // Changed report text must have a final AI assessment for the
    // exact current text.
    if (!currentTextHasFreshAiReview) {
      final bool? runReview =
      await showDialog<bool>(
        context:
        context,

        barrierDismissible:
        false,

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
                  Icons.fact_check_outlined,

                  color:
                  AppColors.primary,
                ),

                SizedBox(
                  width:
                  10,
                ),

                Expanded(
                  child:
                  Text(
                    'AI Text Review Required',
                  ),
                ),
              ],
            ),

            content:
            const Text(
              'You changed the report title or description. '
                  'Before the edited report can be saved, Smart Assist '
                  'must check that the new wording still meaningfully '
                  'describes the evidence.\n\n'
                  'This prevents unrelated or meaningless text from being '
                  'saved even when it passes basic word-count validation.',

              style:
              TextStyle(
                color:
                AppColors.textSecondary,

                height:
                1.45,
              ),
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
                  'Re-edit',
                ),
              ),

              ElevatedButton.icon(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },

                icon:
                const Icon(
                  Icons.auto_awesome,

                  size:
                  17,
                ),

                label:
                const Text(
                  'Run AI Review',
                ),
              ),
            ],
          );
        },
      );

      if (runReview != true) {
        textReviewChoice =
            AiTextReviewChoice.reedit;

        semanticTextReviewResolved =
        false;

        return false;
      }

      await runAiAssist();

      if (!mounted) {
        return false;
      }

      if (!currentTextHasFreshAiReview) {
        showMessage(
          'AI review could not be completed for the current wording. '
              'Please re-edit or try Smart Assist again.',
        );

        return false;
      }
    }

    final ReportFinalAiAnalysis result =
    finalAiAnalysis!;

    // If AI finds no semantic concern and the final evidence
    // assessment says the report is sufficient, the changed text
    // is accepted as reviewed.
    if (!finalAiReportsTextConcern(
      result,
    )) {
      semanticTextReviewResolved =
      true;

      textReviewChoice =
          AiTextReviewChoice.original;

      return true;
    }

    final String currentTitle =
    titleController.text.trim();

    final String currentDescription =
    descriptionController.text.trim();

    final String aiTitle =
        result.suggestedTitle?.trim() ??
            '';

    final String aiDescription =
        result.suggestedDescription?.trim() ??
            '';

    // If AI says a field is not meaningful, AI must actually
    // provide a usable replacement before "Use AI Version" can
    // be selected.
    final bool aiCanRepairTitle =
        result.titleMeaningful != false ||
            aiTitle.isNotEmpty;

    final bool aiCanRepairDescription =
        result.descriptionMeaningful != false ||
            aiDescription.isNotEmpty;

    final bool canUseAiVersion =
        aiCanRepairTitle &&
            aiCanRepairDescription &&
            (aiTitle.isNotEmpty ||
                aiDescription.isNotEmpty);

    final bool? useAiVersion =
    await showDialog<bool>(
      context:
      context,

      barrierDismissible:
      false,

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
                Icons.warning_amber_rounded,

                color:
                Colors.orangeAccent,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Text(
                  'Report Wording Needs Review',
                ),
              ),
            ],
          ),

          content:
          SingleChildScrollView(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                const Text(
                  'Smart Assist found that the edited title/description '
                      'may be unclear, insufficient, unrelated to the '
                      'evidence, or substantially different from the '
                      'recommended wording.\n\n'
                      'The report cannot be saved until you choose how '
                      'to correct the wording.',

                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,

                    height:
                    1.45,
                  ),
                ),

                const SizedBox(
                  height:
                  14,
                ),

                _TextReviewPanel(
                  label:
                  'CURRENT EDITED VERSION',

                  title:
                  currentTitle,

                  description:
                  currentDescription,
                ),

                const SizedBox(
                  height:
                  10,
                ),

                _TextReviewPanel(
                  label:
                  'AI RECOMMENDED VERSION',

                  title:
                  aiTitle.isEmpty
                      ? 'No replacement title suggested'
                      : aiTitle,

                  description:
                  aiDescription.isEmpty
                      ? 'No replacement description suggested'
                      : aiDescription,
                ),

                if ((result.reportIssue ?? '')
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                    10,
                  ),

                  Text(
                    'AI review: ${result.reportIssue}',

                    style:
                    const TextStyle(
                      color:
                      Colors.orangeAccent,

                      fontSize:
                      10,

                      height:
                      1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),

          actions: [
            TextButton.icon(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              icon:
              const Icon(
                Icons.edit_outlined,

                size:
                17,
              ),

              label:
              const Text(
                'Re-edit',
              ),
            ),

            ElevatedButton.icon(
              onPressed:
              canUseAiVersion
                  ? () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              }
                  : null,

              icon:
              const Icon(
                Icons.auto_fix_high,

                size:
                17,
              ),

              label:
              const Text(
                'Use AI Version',
              ),
            ),
          ],
        );
      },
    );

    if (useAiVersion != true) {
      semanticTextReviewResolved =
      false;

      textReviewChoice =
          AiTextReviewChoice.reedit;

      showMessage(
        'Please re-edit the title or description. '
            'Save remains blocked until the updated wording passes review.',
      );

      return false;
    }

    // ==========================================================
    // APPLY AI TEXT VERSION
    // ==========================================================

    setState(() {
      if (aiTitle.isNotEmpty) {
        titleController.text =
            aiTitle;
      }

      if (aiDescription.isNotEmpty) {
        descriptionController.text =
            aiDescription;
      }

      final String suggestedCategory =
          result.category?.trim() ??
              '';

      if (result.categoryMatchesUser == false &&
          categories.contains(
            suggestedCategory,
          )) {
        selectedCategory =
            suggestedCategory;
      }

      final String recommendedPriority =
          result.recommendedPriority?.trim() ??
              '';

      if (result.priorityChangeRecommended == true &&
          priorities.contains(
            recommendedPriority,
          )) {
        selectedPriority =
            recommendedPriority;
      }

      aiSuggestionsApplied =
      true;

      semanticTextReviewResolved =
      true;

      textReviewChoice =
          AiTextReviewChoice.ai;

      // The user explicitly accepted this AI version.
      lastAiReviewedTitle =
          titleController.text.trim();

      lastAiReviewedDescription =
          descriptionController.text.trim();

      finalAiAnalysis =
          result.copyWith(
            reviewedByUser:
            true,

            suggestionsApplied:
            true,
          );

      semanticTextReviewResolved =
      true;

      textReviewChoice =
          AiTextReviewChoice.ai;

      lastAiReviewedTitle =
          titleController.text.trim();

      lastAiReviewedDescription =
          descriptionController.text.trim();
    });

    // AI text must still pass deterministic local validation.
    if (!formKey.currentState!
        .validate()) {
      semanticTextReviewResolved =
      false;

      textReviewChoice =
          AiTextReviewChoice.reedit;

      showMessage(
        'The AI wording still needs editing before it can be saved.',
      );

      return false;
    }

    return true;
  }

  // ============================================================
  // APPLY FINAL AI
  //
  // Only FINAL COMBINED result can modify citizen fields.
  // ============================================================

  Future<void> applyFinalAiSuggestions() async {
    final ReportFinalAiAnalysis? result =
        finalAiAnalysis;

    if (result ==
        null) {
      return;
    }

    final bool? approved =
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
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color:
                AppColors.primary,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Text(
                  'Apply Final AI Suggestions?',
                ),
              ),
            ],
          ),

          content:
          const Text(
            'Only the final combined image/video assessment will be used. '
                'Smart Assist will update only fields with a usable recommendation. '
                'Nothing is changed until you approve, and you can continue editing afterward.',
            style:
            TextStyle(
              color:
              AppColors.textSecondary,
              height:
              1.45,
            ),
          ),

          actions: [
            TextButton(
              onPressed:
                  () =>
                  Navigator.pop(
                    dialogContext,
                    false,
                  ),
              child:
              const Text(
                'Keep Mine',
              ),
            ),

            ElevatedButton(
              onPressed:
                  () =>
                  Navigator.pop(
                    dialogContext,
                    true,
                  ),
              child:
              const Text(
                'Apply Final AI',
              ),
            ),
          ],
        );
      },
    );

    // ==========================================================
    // KEEP CITIZEN DATA
    // ==========================================================

    if (approved !=
        true) {
      if (mounted &&
          finalAiAnalysis !=
              null) {
        setState(() {
          finalAiAnalysis =
              finalAiAnalysis!
                  .copyWith(
                reviewedByUser:
                true,

                suggestionsApplied:
                false,
              );
        });
      }

      return;
    }

    if (!mounted) {
      return;
    }

    final String suggestedTitle =
        result.suggestedTitle
            ?.trim() ??
            '';

    final String suggestedDescription =
        result.suggestedDescription
            ?.trim() ??
            '';

    final String suggestedCategory =
        result.category
            ?.trim() ??
            '';

    final String recommendedPriority =
        result.recommendedPriority
            ?.trim() ??
            '';

    setState(() {
      // ========================================================
      // TITLE
      // ========================================================

      if (suggestedTitle.isNotEmpty) {
        titleController.text =
            suggestedTitle;
      }

      // ========================================================
      // DESCRIPTION
      // ========================================================

      if (suggestedDescription.isNotEmpty) {
        descriptionController.text =
            suggestedDescription;
      }

      // ========================================================
      // CATEGORY
      // ========================================================

      if (result.categoryMatchesUser ==
          false &&
          categories.contains(
            suggestedCategory,
          )) {
        selectedCategory =
            suggestedCategory;
      }

      // ========================================================
      // PRIORITY
      // ========================================================

      if (result.priorityChangeRecommended ==
          true &&
          priorities.contains(
            recommendedPriority,
          )) {
        selectedPriority =
            recommendedPriority;
      }

      aiSuggestionsApplied =
      true;

      finalAiAnalysis =
          result.copyWith(
            reviewedByUser:
            true,

            suggestionsApplied:
            true,
          );
    });

    // ==========================================================
    // AI OUTPUT IS VALIDATED AGAIN
    // ==========================================================

    final bool valid =
    formKey.currentState!
        .validate();

    if (!valid) {
      showMessage(
        'Some AI suggestions still need manual editing before they can be saved.',
      );
    } else {
      showMessage(
        'Final AI suggestions applied. Review or edit them before saving.',
      );
    }
  }

  // ============================================================
  // KEEP CURRENT CITIZEN INFORMATION
  // ============================================================

  void keepCitizenValues() {
    if (finalAiAnalysis ==
        null) {
      return;
    }

    setState(() {
      aiSuggestionsApplied =
      false;

      semanticTextReviewResolved =
      !reportTextChanged;

      textReviewChoice =
      reportTextChanged
          ? AiTextReviewChoice.unresolved
          : AiTextReviewChoice.original;

      finalAiAnalysis =
          finalAiAnalysis!
              .copyWith(
            reviewedByUser:
            true,

            suggestionsApplied:
            false,
          );
    });

    showMessage(
      'Your current report information remains selected.',
    );
  }

  // ============================================================
  // SAVE FINAL COMBINED AI
  //
  // Uses same report_final_ai_analysis structure as Create Report.
  // ============================================================

  Future<void> saveFinalAiAnalysis() async {
    final ReportFinalAiAnalysis? result =
        finalAiAnalysis;

    if (result ==
        null) {
      return;
    }

    final Map<String, dynamic> data =
    result.toDatabaseJson(
      reportId:
      widget.report.id,
    );

    data['report_id'] =
        widget.report.id;

    data['ai_status'] =
    result.aiStatus ==
        'failed'
        ? 'failed'
        : 'completed';

    data['analyzed_image_count'] =
        imageAnalyses.length;

    // Contains image AND video evidence IDs.
    data['source_evidence_ids'] =
        result.sourceEvidenceIds;

    data['analyzed_at'] ??=
        DateTime.now()
            .toUtc()
            .toIso8601String();

    data['updated_at'] =
        DateTime.now()
            .toUtc()
            .toIso8601String();

    await supabase
        .from(
      'report_final_ai_analysis',
    )
        .upsert(
      data,
      onConflict:
      'report_id',
    );
  }

  // ============================================================
  // SAVE REPORT
  // ============================================================

  Future<void> saveReport() async {
    if (isBusy) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    // ==========================================================
    // MEANINGFUL TEXT
    // ==========================================================

    if (!formKey.currentState!
        .validate()) {
      showMessage(
        'Please correct the highlighted information before saving.',
      );

      return;
    }

    // ==========================================================
    // EVIDENCE
    // ==========================================================

    if (evidence.isEmpty) {
      showMessage(
        'Evidence is required. Keep at least one photo or short video '
            'before saving the report.',
      );

      return;
    }

    // ==========================================================
    // CATEGORY
    // ==========================================================

    if (!categories.contains(
      selectedCategory,
    )) {
      showMessage(
        'Please select a valid issue category.',
      );

      return;
    }

    // ==========================================================
    // PRIORITY
    // ==========================================================

    if (!priorities.contains(
      selectedPriority,
    )) {
      showMessage(
        'Please select a valid priority level.',
      );

      return;
    }

    // ==========================================================
    // LOCATION
    // ==========================================================

    final bool locationReady =
    await ensureValidLocation();

    if (!locationReady ||
        !mounted) {
      showMessage(
        'Please confirm a valid map location before saving.',
      );

      return;
    }

    // ==========================================================
    // MANDATORY AI SEMANTIC REVIEW FOR CHANGED TEXT
    //
    // Basic validators alone are not enough to detect a sentence
    // that has valid words but is unrelated to the report issue.
    // ==========================================================

    final bool semanticTextReady =
    await ensureSemanticTextReviewBeforeSave();

    if (!semanticTextReady ||
        !mounted) {
      return;
    }

    setState(() {
      saving =
      true;
    });

    try {
      // ========================================================
      // SAVE CURRENT EDITED REPORT
      // ========================================================

      await reportService.updateReport(
        reportId:
        widget.report.id,

        title:
        titleController.text
            .trim(),

        category:
        selectedCategory,

        priority:
        selectedPriority,

        description:
        descriptionController.text
            .trim(),

        address:
        addressController.text
            .trim(),

        landmark:
        landmarkController.text
            .trim(),

        // ======================================================
        // IMPORTANT:
        //
        // Use CURRENT edited coordinates, not widget.report.
        // ======================================================

        latitude:
        latitude,

        longitude:
        longitude,
      );

      // ========================================================
      // SAVE FINAL AI ASSESSMENT
      // ========================================================

      if (finalAiAnalysis !=
          null) {
        await saveFinalAiAnalysis();
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color:
                Colors.white,
              ),

              const SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Text(
                  aiSuggestionsApplied
                      ? 'Report updated successfully with reviewed combined AI assistance.'
                      : finalAiAnalysis != null
                      ? 'Report updated successfully with reviewed AI assessment.'
                      : 'Report updated successfully.',
                ),
              ),
            ],
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      showMessage(
        cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving =
          false;
        });
      }
    }
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
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool busy =
        isBusy;

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
                Form(
                  key:
                  formKey,

                  autovalidateMode:
                  AutovalidateMode
                      .onUserInteraction,

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
                              busy
                                  ? null
                                  : () {
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
                            width:
                            12,
                          ),

                          Expanded(
                            child:
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,

                              children: [
                                const Text(
                                  'Edit Report',
                                  style:
                                  TextStyle(
                                    fontSize:
                                    22,

                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                Text(
                                  widget.report.referenceNumber,

                                  style:
                                  const TextStyle(
                                    color:
                                    AppColors.textSecondary,

                                    fontSize:
                                    11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal:
                              10,

                              vertical:
                              6,
                            ),

                            decoration:
                            BoxDecoration(
                              color:
                              const Color(
                                0xFFFFC62E,
                              ).withOpacity(
                                0.10,
                              ),

                              borderRadius:
                              BorderRadius.circular(
                                30,
                              ),
                            ),

                            child:
                            const Text(
                              'PENDING',

                              style:
                              TextStyle(
                                color:
                                Color(
                                  0xFFFFC62E,
                                ),

                                fontSize:
                                9,

                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      _InfoCard(
                        icon:
                        Icons.edit_note_outlined,

                        text:
                        'You can update this report while it is pending review. '
                            'Text must remain meaningful, location must resolve to map coordinates, '
                            'and Smart Assist can review multiple photos and videos.',
                      ),

                      const SizedBox(
                        height:
                        18,
                      ),

                      // =================================================
                      // FINAL COMBINED SMART ASSIST
                      // =================================================

                      _CombinedAiCard(
                        analyzing:
                        analyzingAi,

                        combining:
                        combiningAnalyses,

                        imageCount:
                        imageAnalyses.length,

                        videoCount:
                        videoAnalyses.length,

                        result:
                        finalAiAnalysis,

                        error:
                        finalAnalysisError,

                        suggestionsApplied:
                        aiSuggestionsApplied,

                        onAnalyze:
                        busy
                            ? null
                            : runAiAssist,

                        onCombine:
                        busy ||
                            successfulAiCount ==
                                0
                            ? null
                            : combineAllAnalyses,

                        onApply:
                        busy ||
                            finalAiAnalysis ==
                                null
                            ? null
                            : applyFinalAiSuggestions,

                        onKeepMine:
                        busy ||
                            finalAiAnalysis ==
                                null
                            ? null
                            : keepCitizenValues,
                      ),

                      const SizedBox(
                        height:
                        24,
                      ),

                      // =================================================
                      // CATEGORY
                      // =================================================

                      const _Label(
                        'ISSUE CATEGORY',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      DropdownButtonFormField<String>(
                        value:
                        selectedCategory,

                        dropdownColor:
                        AppColors.surface,

                        decoration:
                        _decoration(),

                        items:
                        categories
                            .map(
                              (
                              category,
                              ) {
                            return DropdownMenuItem<String>(
                              value:
                              category,

                              child:
                              Text(
                                category,
                              ),
                            );
                          },
                        )
                            .toList(),

                        onChanged:
                        busy
                            ? null
                            : (
                            value,
                            ) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            selectedCategory =
                                value;

                            finalAiAnalysis =
                            null;

                            finalAnalysisError =
                            null;

                            aiSuggestionsApplied =
                            false;
                          });
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      // =================================================
                      // PRIORITY
                      // =================================================

                      const _Label(
                        'PRIORITY',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      DropdownButtonFormField<String>(
                        value:
                        selectedPriority,

                        dropdownColor:
                        AppColors.surface,

                        decoration:
                        _decoration(),

                        items:
                        priorities
                            .map(
                              (
                              priority,
                              ) {
                            return DropdownMenuItem<String>(
                              value:
                              priority,

                              child:
                              Text(
                                priority,
                              ),
                            );
                          },
                        )
                            .toList(),

                        onChanged:
                        busy
                            ? null
                            : (
                            value,
                            ) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            selectedPriority =
                                value;

                            finalAiAnalysis =
                            null;

                            finalAnalysisError =
                            null;

                            aiSuggestionsApplied =
                            false;
                          });
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      // =================================================
                      // TITLE
                      // =================================================

                      const _Label(
                        'REPORT TITLE',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      TextFormField(
                        controller:
                        titleController,

                        enabled:
                        !busy,

                        maxLength:
                        100,

                        textCapitalization:
                        TextCapitalization.sentences,

                        decoration:
                        _decoration(
                          hint:
                          'e.g., Large pothole on Jalan Ampang',
                        ),

                        validator:
                        validateTitle,

                        onChanged:
                            (_) {
                          if (finalAiAnalysis !=
                              null ||
                              aiSuggestionsApplied) {
                            invalidateFinalAi();
                          }
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      // =================================================
                      // DESCRIPTION
                      // =================================================

                      const _Label(
                        'DESCRIPTION',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      TextFormField(
                        controller:
                        descriptionController,

                        enabled:
                        !busy,

                        minLines:
                        5,

                        maxLines:
                        8,

                        maxLength:
                        500,

                        textCapitalization:
                        TextCapitalization.sentences,

                        decoration:
                        _decoration(
                          hint:
                          'Describe the infrastructure issue clearly, '
                              'including severity and any safety concern.',
                        ),

                        validator:
                        validateDescription,

                        onChanged:
                            (_) {
                          if (finalAiAnalysis !=
                              null ||
                              aiSuggestionsApplied) {
                            invalidateFinalAi();
                          }
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      // =================================================
                      // ADDRESS
                      // =================================================

                      const _Label(
                        'ADDRESS & LOCATION',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      TextFormField(
                        controller:
                        addressController,

                        enabled:
                        !busy,

                        maxLength:
                        250,

                        textInputAction:
                        TextInputAction.search,

                        onFieldSubmitted:
                            (_) async {
                          await verifyTypedAddress();
                        },

                        decoration:
                        _decoration(
                          hint:
                          'Issue location',
                        ).copyWith(
                          errorText:
                          addressValidationError,

                          errorMaxLines:
                          3,
                        ),

                        validator:
                        validateAddress,
                      ),

                      const SizedBox(
                        height:
                        10,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                            OutlinedButton.icon(
                              onPressed:
                              busy
                                  ? null
                                  : detectCurrentLocation,

                              icon:
                              gettingLocation
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
                                Icons.gps_fixed,
                              ),

                              label:
                              Text(
                                gettingLocation
                                    ? 'Detecting...'
                                    : 'Current GPS',
                              ),
                            ),
                          ),

                          const SizedBox(
                            width:
                            10,
                          ),

                          Expanded(
                            child:
                            OutlinedButton.icon(
                              onPressed:
                              busy
                                  ? null
                                  : openMapPicker,

                              icon:
                              const Icon(
                                Icons.map_outlined,
                              ),

                              label:
                              const Text(
                                'Choose Map',
                              ),
                            ),
                          ),
                        ],
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
                          busy
                              ? null
                              : verifyTypedAddress,

                          icon:
                          validatingAddress
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
                            validatingAddress
                                ? 'Checking Address...'
                                : 'Find Typed Address on Map',
                          ),
                        ),
                      ),

                      if (latitude !=
                          null &&
                          longitude !=
                              null) ...[
                        const SizedBox(
                          height:
                          10,
                        ),

                        _LocationStatusCard(
                          latitude:
                          latitude!,

                          longitude:
                          longitude!,

                          accuracy:
                          gpsAccuracy,

                          source:
                          locationVerificationStatus,
                        ),
                      ],

                      const SizedBox(
                        height:
                        20,
                      ),

                      // =================================================
                      // LANDMARK
                      // =================================================

                      const _Label(
                        'ADDITIONAL LANDMARK',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      TextFormField(
                        controller:
                        landmarkController,

                        enabled:
                        !busy,

                        maxLength:
                        150,

                        decoration:
                        _decoration(
                          hint:
                          'Optional landmark',
                        ),

                        validator:
                        validateLandmark,

                        onChanged:
                            (_) {
                          if (finalAiAnalysis !=
                              null ||
                              aiSuggestionsApplied) {
                            invalidateFinalAi();
                          }
                        },
                      ),

                      const SizedBox(
                        height:
                        26,
                      ),

                      // =================================================
                      // EVIDENCE
                      // =================================================

                      _EvidenceEditor(
                        evidence:
                        evidence,

                        loading:
                        loadingEvidence,

                        busy:
                        editingEvidence,

                        error:
                        evidenceError,

                        maxEvidenceItems:
                        maxEvidenceItems,

                        onRetry:
                        loadEvidence,

                        onAdd:
                        showAddEvidenceMenu,

                        onRemove:
                        removeEvidence,

                        imageAnalyses:
                        imageAnalyses,

                        imageErrors:
                        imageAnalysisErrors,

                        videoAnalyses:
                        videoAnalyses,

                        videoErrors:
                        videoAnalysisErrors,

                        analyzingEvidenceKey:
                        analyzingEvidenceKey,

                        evidenceKey:
                        evidenceKey,

                        onAnalyzeImage:
                            (
                            item,
                            ) {
                          return analyzeSingleImage(
                            item,
                            rebuildFinal:
                            true,
                          );
                        },

                        onAnalyzeVideo:
                            (
                            item,
                            ) {
                          return analyzeSingleVideo(
                            item,
                            rebuildFinal:
                            true,
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                        18,
                      ),

                      _InfoCard(
                        icon:
                        Icons.verified_user_outlined,

                        text:
                        'Each photo is analysed independently. '
                            'Each short video is assessed using representative sampled frames. '
                            'All successful results are then combined with the current report details. '
                            'AI recommendations never overwrite citizen information without approval.',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // =====================================================
            // SAVE
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
              SizedBox(
                width:
                double.infinity,

                height:
                54,

                child:
                ElevatedButton.icon(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.primaryDark,

                    foregroundColor:
                    Colors.white,

                    disabledBackgroundColor:
                    AppColors.primaryDark.withOpacity(
                      0.40,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),

                  onPressed:
                  busy
                      ? null
                      : saveReport,

                  icon:
                  saving
                      ? const SizedBox(
                    width:
                    19,

                    height:
                    19,

                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,

                      color:
                      Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons.save_outlined,
                  ),

                  label:
                  Text(
                    saving
                        ? 'Saving...'
                        : 'Save Reviewed Changes',

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
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

// =================================================================
// LOCATION STATUS
// =================================================================

class _LocationStatusCard
    extends StatelessWidget {
  final double latitude;

  final double longitude;

  final double? accuracy;

  final String source;

  const _LocationStatusCard({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.source,
  });

  String get sourceLabel {
    switch (source) {
      case 'gps':
        return 'Location verified from Current GPS';

      case 'map':
        return 'Location selected from map';

      case 'geocoded':
        return 'Typed address matched to map coordinates';

      default:
        return 'Saved report coordinates';
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        11,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.greenAccent.withOpacity(
          0.05,
        ),

        borderRadius:
        BorderRadius.circular(
          11,
        ),

        border:
        Border.all(
          color:
          Colors.greenAccent.withOpacity(
            0.28,
          ),
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,

                size:
                17,

                color:
                Colors.greenAccent,
              ),

              const SizedBox(
                width:
                8,
              ),

              Expanded(
                child:
                Text(
                  sourceLabel,

                  style:
                  const TextStyle(
                    color:
                    Colors.greenAccent,

                    fontSize:
                    10,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            6,
          ),

          Text(
            '${latitude.toStringAsFixed(6)}, '
                '${longitude.toStringAsFixed(6)}',

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              9,
            ),
          ),

          if (accuracy !=
              null) ...[
            const SizedBox(
              height:
              4,
            ),

            Text(
              'GPS accuracy: '
                  '±${accuracy!.toStringAsFixed(0)} m',

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
    );
  }
}

// =================================================================
// FINAL COMBINED AI CARD
// =================================================================

class _CombinedAiCard
    extends StatelessWidget {
  final bool analyzing;

  final bool combining;

  final int imageCount;

  final int videoCount;

  final ReportFinalAiAnalysis?
  result;

  final String? error;

  final bool suggestionsApplied;

  final Future<void> Function()?
  onAnalyze;

  final Future<void> Function()?
  onCombine;

  final Future<void> Function()?
  onApply;

  final VoidCallback?
  onKeepMine;

  const _CombinedAiCard({
    required this.analyzing,
    required this.combining,
    required this.imageCount,
    required this.videoCount,
    required this.result,
    required this.error,
    required this.suggestionsApplied,
    required this.onAnalyze,
    required this.onCombine,
    required this.onApply,
    required this.onKeepMine,
  });

  String safeValue(
      String? value,
      ) {
    final String clean =
        value?.trim() ??
            '';

    if (clean.isEmpty) {
      return 'Not available';
    }

    return clean;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        15,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.primary.withOpacity(
          0.055,
        ),

        borderRadius:
        BorderRadius.circular(
          15,
        ),

        border:
        Border.all(
          color:
          AppColors.primary.withOpacity(
            0.28,
          ),
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,

                color:
                AppColors.primary,
              ),

              const SizedBox(
                width:
                9,
              ),

              const Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      'AI Smart Assist',

                      style:
                      TextStyle(
                        color:
                        Colors.white,

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    Text(
                      'Multi-photo + video + final combined analysis',

                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,

                        fontSize:
                        9,
                      ),
                    ),
                  ],
                ),
              ),

              OutlinedButton(
                onPressed:
                analyzing ||
                    combining
                    ? null
                    : onAnalyze,

                child:
                analyzing
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
                    : const Text(
                  'Analyse All',
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            12,
          ),

          Wrap(
            spacing:
            8,

            runSpacing:
            8,

            children: [
              _AiCountChip(
                icon:
                Icons.image_outlined,

                text:
                '$imageCount photo AI',
              ),

              _AiCountChip(
                icon:
                Icons.movie_outlined,

                text:
                '$videoCount video AI',
              ),
            ],
          ),

          if (combining) ...[
            const SizedBox(
              height:
              12,
            ),

            const LinearProgressIndicator(),

            const SizedBox(
              height:
              7,
            ),

            const Text(
              'Combining image and video evidence analyses...',

              style:
              TextStyle(
                color:
                AppColors.textSecondary,

                fontSize:
                9,
              ),
            ),
          ],

          if (error !=
              null &&
              error!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(
              height:
              12,
            ),

            Container(
              width:
              double.infinity,

              padding:
              const EdgeInsets.all(
                10,
              ),

              decoration:
              BoxDecoration(
                color:
                Colors.orangeAccent.withOpacity(
                  0.06,
                ),

                borderRadius:
                BorderRadius.circular(
                  10,
                ),

                border:
                Border.all(
                  color:
                  Colors.orangeAccent.withOpacity(
                    0.25,
                  ),
                ),
              ),

              child:
              Text(
                error!,

                style:
                const TextStyle(
                  color:
                  Colors.orangeAccent,

                  fontSize:
                  9,

                  height:
                  1.4,
                ),
              ),
            ),

            const SizedBox(
              height:
              9,
            ),

            SizedBox(
              width:
              double.infinity,

              child:
              OutlinedButton.icon(
                onPressed:
                onCombine,

                icon:
                const Icon(
                  Icons.refresh_rounded,

                  size:
                  17,
                ),

                label:
                const Text(
                  'Retry Final Combine',
                ),
              ),
            ),
          ],

          if (result !=
              null) ...[
            const SizedBox(
              height:
              14,
            ),

            const Divider(
              color:
              AppColors.border,
            ),

            const SizedBox(
              height:
              8,
            ),

            const Row(
              children: [
                Icon(
                  Icons.hub_outlined,

                  size:
                  18,

                  color:
                  AppColors.primary,
                ),

                SizedBox(
                  width:
                  8,
                ),

                Text(
                  'Final Combined Analysis',

                  style:
                  TextStyle(
                    color:
                    Colors.white,

                    fontSize:
                    12,

                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
              11,
            ),

            _AiResultLine(
              label:
              'Issue detected',

              value:
              result!.issueDetected ==
                  true
                  ? 'Yes'
                  : 'Not confirmed',
            ),

            _AiResultLine(
              label:
              'Final category',

              value:
              safeValue(
                result!.category,
              ),
            ),

            _AiResultLine(
              label:
              'Severity',

              value:
              safeValue(
                result!.severity,
              ),
            ),

            _AiResultLine(
              label:
              'Confidence',

              value:
              safeValue(
                result!.confidence,
              ),
            ),

            _AiResultLine(
              label:
              'Evidence quality',

              value:
              safeValue(
                result!.evidenceQuality,
              ),
            ),

            _AiResultLine(
              label:
              'Consistency',

              value:
              safeValue(
                result!.evidenceConsistency,
              ),
            ),

            _AiResultLine(
              label:
              'Report quality',

              value:
              safeValue(
                result!.reportQuality,
              ),
            ),

            _AiResultLine(
              label:
              'Report sufficient',

              value:
              result!.reportSufficient ==
                  false
                  ? 'Needs improvement'
                  : 'Yes',
            ),

            if ((result!.safetyConcern ??
                '')
                .trim()
                .isNotEmpty)
              _AiResultLine(
                label:
                'Safety concern',

                value:
                result!.safetyConcern!,
              ),

            if (result!
                .missingInformation
                .isNotEmpty)
              _AiResultLine(
                label:
                'Missing information',

                value:
                result!
                    .missingInformation
                    .join(
                  ', ',
                ),
              ),

            if (result!
                .conflictingEvidence)
              _AiResultLine(
                label:
                'Evidence conflict',

                value:
                safeValue(
                  result!.conflictingEvidenceReason,
                ),
              ),

            const SizedBox(
              height:
              12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                  OutlinedButton(
                    onPressed:
                    onKeepMine,

                    child:
                    const Text(
                      'Keep Mine',
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  9,
                ),

                Expanded(
                  child:
                  ElevatedButton.icon(
                    onPressed:
                    onApply,

                    icon:
                    Icon(
                      suggestionsApplied
                          ? Icons.check_circle_outline
                          : Icons.auto_fix_high,

                      size:
                      18,
                    ),

                    label:
                    Text(
                      suggestionsApplied
                          ? 'Applied'
                          : 'Review & Apply',
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(
            height:
            9,
          ),

          const Text(
            'AI recommendations are assistance only. '
                'Individual image/video results never overwrite the report. '
                'Only the final combined result can be applied after approval.',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              9,

              height:
              1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// AI COUNT CHIP
// =================================================================

class _AiCountChip
    extends StatelessWidget {
  final IconData icon;

  final String text;

  const _AiCountChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        9,

        vertical:
        6,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.background.withOpacity(
          0.45,
        ),

        borderRadius:
        BorderRadius.circular(
          20,
        ),

        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),

      child:
      Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          Icon(
            icon,

            size:
            14,

            color:
            AppColors.primary,
          ),

          const SizedBox(
            width:
            5,
          ),

          Text(
            text,

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              9,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// EVIDENCE EDITOR
// =================================================================

class _EvidenceEditor
    extends StatelessWidget {
  final List<EditableReportEvidence>
  evidence;

  final bool loading;

  final bool busy;

  final String? error;

  final int maxEvidenceItems;

  final Future<void> Function()
  onRetry;

  final Future<void> Function()
  onAdd;

  final Future<void> Function(
      EditableReportEvidence item,
      ) onRemove;

  final Map<String, ReportImageAiAnalysis>
  imageAnalyses;

  final Map<String, String>
  imageErrors;

  final Map<String, ReportVideoAiAnalysis>
  videoAnalyses;

  final Map<String, String>
  videoErrors;

  final String?
  analyzingEvidenceKey;

  final String Function(
      EditableReportEvidence item,
      ) evidenceKey;

  final Future<bool> Function(
      EditableReportEvidence item,
      ) onAnalyzeImage;

  final Future<bool> Function(
      EditableReportEvidence item,
      ) onAnalyzeVideo;

  const _EvidenceEditor({
    required this.evidence,
    required this.loading,
    required this.busy,
    required this.error,
    required this.maxEvidenceItems,
    required this.onRetry,
    required this.onAdd,
    required this.onRemove,
    required this.imageAnalyses,
    required this.imageErrors,
    required this.videoAnalyses,
    required this.videoErrors,
    required this.analyzingEvidenceKey,
    required this.evidenceKey,
    required this.onAnalyzeImage,
    required this.onAnalyzeVideo,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,

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
          15,
        ),

        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,

                color:
                AppColors.primary,
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
                    const Text(
                      'Evidence',

                      style:
                      TextStyle(
                        color:
                        Colors.white,

                        fontSize:
                        14,

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    Text(
                      '${evidence.length} / $maxEvidenceItems items · '
                          'minimum 1 required',

                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,

                        fontSize:
                        9,
                      ),
                    ),
                  ],
                ),
              ),

              TextButton.icon(
                onPressed:
                busy ||
                    evidence.length >=
                        maxEvidenceItems
                    ? null
                    : onAdd,

                icon:
                const Icon(
                  Icons.add,

                  size:
                  17,
                ),

                label:
                const Text(
                  'Add',
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            12,
          ),

          if (loading)
            const Center(
              child:
              Padding(
                padding:
                EdgeInsets.all(
                  18,
                ),

                child:
                CircularProgressIndicator(),
              ),
            )
          else if (error !=
              null)
            Column(
              children: [
                Text(
                  error!,

                  style:
                  const TextStyle(
                    color:
                    Colors.orangeAccent,
                  ),
                ),

                TextButton(
                  onPressed:
                  onRetry,

                  child:
                  const Text(
                    'Retry',
                  ),
                ),
              ],
            )
          else if (evidence.isEmpty)
              const Padding(
                padding:
                EdgeInsets.symmetric(
                  vertical:
                  18,
                ),

                child:
                Center(
                  child:
                  Text(
                    'No evidence available.',

                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap:
                true,

                physics:
                const NeverScrollableScrollPhysics(),

                itemCount:
                evidence.length,

                separatorBuilder:
                    (
                    context,
                    index,
                    ) {
                  return const SizedBox(
                    height:
                    12,
                  );
                },

                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final EditableReportEvidence item =
                  evidence[index];

                  final String key =
                  evidenceKey(
                    item,
                  );

                  return _EvidenceAnalysisCard(
                    item:
                    item,

                    index:
                    index,

                    analyzing:
                    analyzingEvidenceKey ==
                        key,

                    onRemove:
                    busy
                        ? null
                        : () {
                      onRemove(
                        item,
                      );
                    },

                    imageAnalysis:
                    imageAnalyses[key],

                    imageError:
                    imageErrors[key],

                    videoAnalysis:
                    videoAnalyses[key],

                    videoError:
                    videoErrors[key],

                    onAnalyze:
                    busy
                        ? null
                        : () async {
                      if (item.isImage) {
                        await onAnalyzeImage(
                          item,
                        );
                      } else {
                        await onAnalyzeVideo(
                          item,
                        );
                      }
                    },
                  );
                },
              ),

          if (busy) ...[
            const SizedBox(
              height:
              12,
            ),

            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

// =================================================================
// EVIDENCE ANALYSIS CARD
// =================================================================

class _EvidenceAnalysisCard
    extends StatelessWidget {
  final EditableReportEvidence item;

  final int index;

  final bool analyzing;

  final VoidCallback?
  onRemove;

  final ReportImageAiAnalysis?
  imageAnalysis;

  final String?
  imageError;

  final ReportVideoAiAnalysis?
  videoAnalysis;

  final String?
  videoError;

  final Future<void> Function()?
  onAnalyze;

  const _EvidenceAnalysisCard({
    required this.item,
    required this.index,
    required this.analyzing,
    required this.onRemove,
    required this.imageAnalysis,
    required this.imageError,
    required this.videoAnalysis,
    required this.videoError,
    required this.onAnalyze,
  });

  String safeValue(
      String? value,
      ) {
    final String clean =
        value?.trim() ??
            '';

    return clean.isEmpty
        ? 'Not available'
        : clean;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      decoration:
      BoxDecoration(
        color:
        AppColors.background.withOpacity(
          0.55,
        ),

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
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          SizedBox(
            height:
            150,

            child:
            Stack(
              children: [
                Positioned.fill(
                  child:
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(
                      top:
                      Radius.circular(
                        12,
                      ),
                    ),

                    child:
                    Container(
                      color:
                      AppColors.background,

                      child:
                      item.isImage &&
                          item.signedUrl !=
                              null
                          ? Image.network(
                        item.signedUrl!,

                        fit:
                        BoxFit.cover,

                        errorBuilder:
                            (
                            context,
                            error,
                            stack,
                            ) {
                          return const Center(
                            child:
                            Icon(
                              Icons.broken_image_outlined,

                              color:
                              AppColors.textSecondary,
                            ),
                          );
                        },
                      )
                          : const Center(
                        child:
                        Icon(
                          Icons.videocam_outlined,

                          color:
                          AppColors.primary,

                          size:
                          44,
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left:
                  8,

                  bottom:
                  8,

                  child:
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal:
                      8,

                      vertical:
                      4,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      Colors.black.withOpacity(
                        0.72,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),

                    child:
                    Text(
                      '${item.isImage ? 'PHOTO' : 'VIDEO'} '
                          '${index + 1}',

                      style:
                      const TextStyle(
                        color:
                        Colors.white,

                        fontSize:
                        8,

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  right:
                  5,

                  top:
                  5,

                  child:
                  Material(
                    color:
                    Colors.black.withOpacity(
                      0.65,
                    ),

                    shape:
                    const CircleBorder(),

                    child:
                    IconButton(
                      visualDensity:
                      VisualDensity.compact,

                      onPressed:
                      onRemove,

                      icon:
                      const Icon(
                        Icons.close,

                        size:
                        17,

                        color:
                        Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding:
            const EdgeInsets.all(
              12,
            ),

            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                      Text(
                        item.isImage
                            ? 'Photo Evidence Intelligence'
                            : 'Video Evidence Intelligence',

                        style:
                        const TextStyle(
                          color:
                          Colors.white,

                          fontSize:
                          11,

                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ),

                    OutlinedButton.icon(
                      onPressed:
                      analyzing
                          ? null
                          : onAnalyze,

                      icon:
                      analyzing
                          ? const SizedBox(
                        width:
                        14,

                        height:
                        14,

                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                        ),
                      )
                          : const Icon(
                        Icons.auto_awesome,

                        size:
                        15,
                      ),

                      label:
                      Text(
                        analyzing
                            ? 'Analysing'
                            : 'Analyse',
                      ),
                    ),
                  ],
                ),

                // ===================================================
                // IMAGE AI RESULT
                // ===================================================

                if (imageAnalysis !=
                    null) ...[
                  const SizedBox(
                    height:
                    9,
                  ),

                  _AiResultLine(
                    label:
                    'Issue',

                    value:
                    imageAnalysis!.issueDetected ==
                        true
                        ? 'Detected'
                        : 'Not confirmed',
                  ),

                  _AiResultLine(
                    label:
                    'Category',

                    value:
                    safeValue(
                      imageAnalysis!.category,
                    ),
                  ),

                  _AiResultLine(
                    label:
                    'Severity',

                    value:
                    safeValue(
                      imageAnalysis!.severity,
                    ),
                  ),

                  _AiResultLine(
                    label:
                    'Confidence',

                    value:
                    safeValue(
                      imageAnalysis!.confidence,
                    ),
                  ),

                  _AiResultLine(
                    label:
                    'Quality',

                    value:
                    safeValue(
                      imageAnalysis!.evidenceQuality,
                    ),
                  ),

                  if ((imageAnalysis!.safetyConcern ??
                      '')
                      .trim()
                      .isNotEmpty)
                    _AiResultLine(
                      label:
                      'Safety',

                      value:
                      imageAnalysis!.safetyConcern!,
                    ),
                ],

                // ===================================================
                // VIDEO AI RESULT
                // ===================================================

                if (videoAnalysis !=
                    null) ...[
                  const SizedBox(
                    height:
                    9,
                  ),

                  _AiResultLine(
                    label:
                    'Issue',

                    value:
                    videoAnalysis!.issueDetected
                        ? 'Detected'
                        : 'Not confirmed',
                  ),

                  _AiResultLine(
                    label:
                    'Category',

                    value:
                    safeValue(
                      videoAnalysis!.category,
                    ),
                  ),

                  _AiResultLine(
                    label:
                    'Severity',

                    value:
                    safeValue(
                      videoAnalysis!.severity,
                    ),
                  ),

                  _AiResultLine(
                    label:
                    'Confidence',

                    value:
                    safeValue(
                      videoAnalysis!.confidence,
                    ),
                  ),

                  _AiResultLine(
                    label:
                    'Quality',

                    value:
                    safeValue(
                      videoAnalysis!.evidenceQuality,
                    ),
                  ),

                  _AiResultLine(
                    label:
                    'Across frames',

                    value:
                    safeValue(
                      videoAnalysis!.temporalConsistency,
                    ),
                  ),

                  _AiResultLine(
                    label:
                    'Useful frames',

                    value:
                    '${videoAnalysis!.usefulFrameCount} / '
                        '${videoAnalysis!.analyzedFrameCount}',
                  ),

                  if ((videoAnalysis!.safetyConcern ??
                      '')
                      .trim()
                      .isNotEmpty)
                    _AiResultLine(
                      label:
                      'Safety',

                      value:
                      videoAnalysis!.safetyConcern!,
                    ),

                  const SizedBox(
                    height:
                    4,
                  ),

                  const Text(
                    'Video AI reviews representative sampled frames, '
                        'not every frame continuously.',

                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,

                      fontSize:
                      8,

                      height:
                      1.35,
                    ),
                  ),
                ],

                // ===================================================
                // PER-EVIDENCE ERROR
                // ===================================================

                if ((imageError ??
                    videoError) !=
                    null &&
                    (imageError ??
                        videoError)!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(
                    height:
                    8,
                  ),

                  Text(
                    imageError ??
                        videoError!,

                    style:
                    const TextStyle(
                      color:
                      Colors.orangeAccent,

                      fontSize:
                      9,

                      height:
                      1.35,
                    ),
                  ),
                ],

                if (!analyzing &&
                    imageAnalysis ==
                        null &&
                    videoAnalysis ==
                        null &&
                    (imageError ??
                        videoError) ==
                        null) ...[
                  const SizedBox(
                    height:
                    7,
                  ),

                  const Text(
                    'Not analysed yet.',

                    style:
                    TextStyle(
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
    );
  }
}

// =================================================================
// AI RESULT LINE
// =================================================================

class _AiResultLine
    extends StatelessWidget {
  final String label;

  final String value;

  const _AiResultLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom:
        7,
      ),

      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          SizedBox(
            width:
            118,

            child:
            Text(
              label,

              style:
              const TextStyle(
                color:
                AppColors.textSecondary,

                fontSize:
                9,
              ),
            ),
          ),

          Expanded(
            child:
            Text(
              value,

              style:
              const TextStyle(
                color:
                Colors.white,

                fontSize:
                10,

                height:
                1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// TEXT REVIEW PANEL
// =================================================================

class _TextReviewPanel
    extends StatelessWidget {
  final String label;

  final String title;

  final String description;

  const _TextReviewPanel({
    required this.label,
    required this.title,
    required this.description,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        11,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.background.withOpacity(
          0.55,
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

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            label,

            style:
            const TextStyle(
              color:
              AppColors.primary,

              fontSize:
              9,

              fontWeight:
              FontWeight.w700,
            ),
          ),

          const SizedBox(
            height:
            8,
          ),

          const Text(
            'Title',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              8,
            ),
          ),

          const SizedBox(
            height:
            3,
          ),

          Text(
            title,

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize:
              10,

              height:
              1.35,
            ),
          ),

          const SizedBox(
            height:
            8,
          ),

          const Text(
            'Description',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              8,
            ),
          ),

          const SizedBox(
            height:
            3,
          ),

          Text(
            description,

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize:
              10,

              height:
              1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// INFO CARD
// =================================================================

class _InfoCard
    extends StatelessWidget {
  final IconData icon;

  final String text;

  const _InfoCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        13,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.primary.withOpacity(
          0.07,
        ),

        borderRadius:
        BorderRadius.circular(
          13,
        ),

        border:
        Border.all(
          color:
          AppColors.primary.withOpacity(
            0.25,
          ),
        ),
      ),

      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Icon(
            icon,

            color:
            AppColors.primary,

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
              text,

              style:
              const TextStyle(
                color:
                AppColors.textSecondary,

                fontSize:
                10,

                height:
                1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// LABEL
// =================================================================

class _Label
    extends StatelessWidget {
  final String text;

  const _Label(
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

        letterSpacing:
        0.4,
      ),
    );
  }
}

// =================================================================
// INPUT DECORATION
// =================================================================

InputDecoration _decoration({
  String? hint,
}) {
  return InputDecoration(
    hintText:
    hint,

    hintStyle:
    const TextStyle(
      color:
      AppColors.textSecondary,
    ),

    filled:
    true,

    fillColor:
    AppColors.surface,

    counterStyle:
    const TextStyle(
      color:
      AppColors.textSecondary,
    ),

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

        width:
        1.4,
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

        width:
        1.4,
      ),
    ),
  );
}
