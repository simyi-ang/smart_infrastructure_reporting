import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../models/report_draft.dart';
import '../../models/report_final_ai_analysis.dart';
import '../../models/report_image_ai_analysis.dart';

import '../../services/ai_evidence_service.dart';
import '../../services/image_compression_service.dart';
import '../../services/report_draft_service.dart';

import '../../theme/app_colors.dart';

import 'create_report_location_screen.dart';

// ================================================================
// CREATE REPORT EVIDENCE SCREEN
//
// MULTI-IMAGE SMART ASSIST
//
// Flow:
//
// Image 1
//    ↓
// Analysis 1
//
// Image 2
//    ↓
// Analysis 2
//
// Image 3
//    ↓
// Analysis 3
//
// Analysis 1 + Analysis 2 + Analysis 3
// + Citizen report details
//    ↓
// FINAL COMBINED ANALYSIS
//
// Individual results are expandable / collapsible.
//
// Existing:
// - compression
// - camera
// - gallery
// - report validation
// - Keep Mine
// - Apply AI
// - Edit Report
// - location navigation
//
// are preserved.
// ================================================================

class CreateReportEvidenceScreen extends StatefulWidget {
  final String category;
  final String priority;
  final String title;
  final String description;

  const CreateReportEvidenceScreen({
    super.key,
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
  });

  @override
  State<CreateReportEvidenceScreen> createState() =>
      _CreateReportEvidenceScreenState();
}

class _CreateReportEvidenceScreenState
    extends State<CreateReportEvidenceScreen>
    with WidgetsBindingObserver {
  // ============================================================
  // SERVICES
  // ============================================================

  final ImagePicker picker = ImagePicker();

  final ImageCompressionService compressionService =
  const ImageCompressionService();

  final AiEvidenceService aiEvidenceService =
  AiEvidenceService();

  // ============================================================
  // LIMITS
  // ============================================================

  /// Maximum number of PHOTO + VIDEO evidence items combined.
  static const int maxEvidenceItems = 5;

  /// Image Smart Assist can still process up to 5 photos.
  static const int maxAiImages = 5;

  /// Videos are intentionally kept short so that:
  /// - upload size stays reasonable
  /// - future frame extraction is practical
  /// - citizens do not accidentally attach long recordings
  static const Duration maxVideoDuration =
  Duration(seconds: 30);

  // ============================================================
  // EVIDENCE
  // ============================================================

  final List<File> evidenceImages = <File>[];

  final List<File> evidenceVideos = <File>[];

  /// Duration is cached by persistent local video path.
  final Map<String, Duration> videoDurations =
  <String, Duration>{};

  // ============================================================
  // INDIVIDUAL IMAGE ANALYSES
  // ============================================================

  final Map<String, ReportImageAiAnalysis>
  imageAnalyses =
  <String, ReportImageAiAnalysis>{};

  // ============================================================
  // EXPANDED IMAGE CARDS
  // ============================================================

  final Set<String> expandedImageAnalyses =
  <String>{};

  // ============================================================
  // IMAGE-SPECIFIC ERRORS
  // ============================================================

  final Map<String, String>
  imageAnalysisErrors =
  <String, String>{};

  // ============================================================
  // IMAGE CURRENTLY BEING ANALYZED
  // ============================================================

  String? analyzingImagePath;

  // ============================================================
  // FINAL COMBINED IMAGE RESULT
  // ============================================================

  ReportFinalAiAnalysis? finalAiAnalysis;

  bool combiningAnalyses = false;

  String? finalAnalysisError;

  // ============================================================
  // GENERAL STATE
  // ============================================================

  bool loadingImage = false;

  bool loadingVideo = false;

  bool analyzingEvidence = false;

  bool aiSuggestionsApplied = false;

  bool restoringDraft = true;

  bool savingDraft = false;

  bool draftSaveFailed = false;

  bool isNavigating = false;

  bool _allowPop = false;

  // ============================================================
  // IMAGE COMPRESSION
  // ============================================================

  int totalCompressedBytes = 0;

  int compressedImageCount = 0;

  String compressionMessage =
      'Evidence photos are optimized before upload.';

  // ============================================================
  // EFFECTIVE REPORT VALUES
  // ============================================================

  late String selectedCategory;

  late String selectedPriority;

  late String selectedTitle;

  late String selectedDescription;

  // ============================================================
  // SAVE QUEUE
  //
  // Prevents two draft writes racing each other when the citizen
  // quickly adds/removes evidence or navigates away.
  // ============================================================

  Future<void> _saveQueue =
  Future<void>.value();

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get _userId {
    return Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.id;
  }

  // ============================================================
  // EVIDENCE HELPERS
  // ============================================================

  int get totalEvidenceCount =>
      evidenceImages.length +
          evidenceVideos.length;

  int get remainingEvidenceSlots =>
      maxEvidenceItems -
          totalEvidenceCount;

  bool get hasEvidence =>
      evidenceImages.isNotEmpty ||
          evidenceVideos.isNotEmpty;

  bool get evidenceLimitReached =>
      totalEvidenceCount >=
          maxEvidenceItems;

  // ============================================================
  // BUSY?
  // ============================================================

  bool get isBusy =>
      restoringDraft ||
          savingDraft ||
          loadingImage ||
          loadingVideo ||
          analyzingEvidence ||
          combiningAnalyses ||
          isNavigating;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    selectedCategory =
        widget.category;

    selectedPriority =
        widget.priority;

    selectedTitle =
        widget.title;

    selectedDescription =
        widget.description;

    unawaited(
      _restoreDraft(),
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

    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE
  //
  // Save when app goes background/inactive.
  // ============================================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state ==
        AppLifecycleState.inactive ||
        state ==
            AppLifecycleState.paused ||
        state ==
            AppLifecycleState.detached) {
      unawaited(
        _saveDraft(
          currentStep: 2,
        ),
      );
    }
  }

  // ============================================================
  // RESTORE DRAFT
  // ============================================================

  Future<void> _restoreDraft() async {
    final String? userId =
        _userId;

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
      await ReportDraftService
          .loadDraft(
        userId: userId,
      );

      if (!mounted) {
        return;
      }

      if (draft == null) {
        setState(() {
          restoringDraft = false;
        });

        await _saveDraft(
          currentStep: 2,
        );

        return;
      }

      final List<File> restoredImages =
      <File>[];

      for (final String path
      in draft.evidenceImagePaths) {
        final File file =
        File(path);

        if (await file.exists()) {
          restoredImages.add(
            file,
          );
        }
      }

      final List<File> restoredVideos =
      <File>[];

      for (final String path
      in draft.evidenceVideoPaths) {
        final File file =
        File(path);

        if (await file.exists()) {
          restoredVideos.add(
            file,
          );
        }
      }

      int restoredBytes = 0;

      for (final File file
      in restoredImages) {
        try {
          restoredBytes +=
          await file.length();
        } catch (_) {
          // Ignore file-size failure.
        }
      }

      if (draft.category.trim().isNotEmpty) {
        selectedCategory =
            draft.category;
      }

      if (draft.priority.trim().isNotEmpty) {
        selectedPriority =
            draft.priority;
      }

      if (draft.title.trim().isNotEmpty) {
        selectedTitle =
            draft.title;
      }

      if (draft.description
          .trim()
          .isNotEmpty) {
        selectedDescription =
            draft.description;
      }

      setState(() {
        evidenceImages
          ..clear()
          ..addAll(
            restoredImages,
          );

        evidenceVideos
          ..clear()
          ..addAll(
            restoredVideos,
          );

        totalCompressedBytes =
            restoredBytes;

        compressionMessage =
        restoredImages.isEmpty
            ? 'Evidence photos are optimized before upload.'
            : '${restoredImages.length} saved photo(s) restored from draft.';

        restoringDraft =
        false;
      });

      // Load video durations after restoring.
      for (final File video
      in restoredVideos) {
        await _loadVideoDuration(
          video,
        );
      }

      if (!mounted) {
        return;
      }

      await _saveDraft(
        currentStep: 2,
      );
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
  // BUILD CURRENT DRAFT
  // ============================================================

  Future<ReportDraft> _buildCurrentDraft({
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
        base = existing;
      }
    }

    return base.copyWith(
      category:
      selectedCategory,

      priority:
      selectedPriority,

      title:
      selectedTitle,

      description:
      selectedDescription,

      currentStep:
      currentStep,

      evidenceImagePaths:
      evidenceImages
          .map(
            (file) => file.path,
      )
          .toList(),

      evidenceVideoPaths:
      evidenceVideos
          .map(
            (file) => file.path,
      )
          .toList(),

      updatedAt:
      DateTime.now(),
    );
  }

  // ============================================================
  // SAVE DRAFT
  // ============================================================

  Future<bool> _saveDraft({
    required int currentStep,
  }) {
    final Completer<bool> completer =
    Completer<bool>();

    _saveQueue =
        _saveQueue.then(
              (_) async {
            final String? userId =
                _userId;

            if (userId == null) {
              completer.complete(
                false,
              );

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

              completer.complete(
                true,
              );
            } catch (_) {
              if (mounted) {
                setState(() {
                  savingDraft =
                  false;

                  draftSaveFailed =
                  true;
                });
              }

              completer.complete(
                false,
              );
            }
          },
        );

    return completer.future;
  }

  // ============================================================
  // SAVE EFFECTIVE AI VALUES
  // ============================================================

  Future<void> _saveEffectiveReportValues() async {
    await _saveDraft(
      currentStep: 2,
    );
  }

  // ============================================================
  // VIDEO DURATION
  // ============================================================

  Future<Duration?> _loadVideoDuration(
      File videoFile,
      ) async {
    VideoPlayerController?
    controller;

    try {
      controller =
          VideoPlayerController.file(
            videoFile,
          );

      await controller.initialize();

      final Duration duration =
          controller.value.duration;

      videoDurations[
      videoFile.path] =
          duration;

      if (mounted) {
        setState(() {});
      }

      return duration;
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  // ============================================================
  // FORMAT VIDEO DURATION
  // ============================================================

  String _formatVideoDuration(
      Duration? duration,
      ) {
    if (duration == null) {
      return '--:--';
    }

    final int minutes =
        duration.inMinutes;

    final int seconds =
        duration.inSeconds %
            60;

    return '$minutes:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // DRAFT STATUS TEXT
  // ============================================================

  String get _draftStatusText {
    if (restoringDraft) {
      return 'Restoring saved draft...';
    }

    if (savingDraft) {
      return 'Saving draft...';
    }

    if (draftSaveFailed) {
      return 'Draft could not be saved';
    }

    return 'Draft protected';
  }

  // ============================================================
  // DRAFT STATUS ICON
  // ============================================================

  IconData get _draftStatusIcon {
    if (restoringDraft ||
        savingDraft) {
      return Icons.sync_rounded;
    }

    if (draftSaveFailed) {
      return Icons
          .cloud_off_outlined;
    }

    return Icons
        .cloud_done_outlined;
  }

  // ============================================================
  // DRAFT STATUS COLOR
  // ============================================================

  Color get _draftStatusColor {
    if (draftSaveFailed) {
      return Colors.amber;
    }

    return AppColors.success;
  }

  // ============================================================
  // LOCAL REPORT VALIDATION
  // ============================================================

  String? validateReportLocally({
    required String title,
    required String description,
  }) {
    final String? titleProblem =
    validateMeaningfulText(
      title,
      fieldName:
      'title',
      minimumLength:
      4,
    );

    if (titleProblem != null) {
      return titleProblem;
    }

    final String?
    descriptionProblem =
    validateMeaningfulText(
      description,
      fieldName:
      'description',
      minimumLength:
      8,
    );

    if (descriptionProblem != null) {
      return descriptionProblem;
    }

    return null;
  }

  // ============================================================
  // MEANINGFUL TEXT VALIDATION
  // ============================================================

  String? validateMeaningfulText(
      String value, {
        required String fieldName,
        required int minimumLength,
      }) {
    final String text =
    value.trim();

    if (text.isEmpty) {
      return 'Please enter a $fieldName.';
    }

    if (
    text.length <
        minimumLength
    ) {
      return 'The $fieldName is too short to be useful.';
    }

    final int letterCount =
        RegExp(
          r'[A-Za-zÀ-ÖØ-öø-ÿ]',
        ).allMatches(
          text,
        ).length;

    if (letterCount == 0) {
      return 'The $fieldName must contain meaningful words.';
    }

    // ==========================================================
    // REPEATED CHARACTERS
    // ==========================================================

    if (
    RegExp(
      r'(.)\1{3,}',
      caseSensitive:
      false,
    ).hasMatch(
      text,
    )
    ) {
      return 'The $fieldName contains too many repeated '
          'characters and does not appear to be useful.';
    }

    // ==========================================================
    // EXCESSIVE SYMBOLS
    // ==========================================================

    final int symbolCount =
        RegExp(
          r'[^A-Za-zÀ-ÖØ-öø-ÿ0-9\s]',
        ).allMatches(
          text,
        ).length;

    final double symbolRatio =
        symbolCount /
            text.length;

    if (
    symbolRatio >
        0.30
    ) {
      return 'The $fieldName contains too many symbols.';
    }

    // ==========================================================
    // LETTER RATIO
    // ==========================================================

    final double letterRatio =
        letterCount /
            text.length;

    if (
    letterRatio <
        0.45
    ) {
      return 'The $fieldName does not contain enough '
          'meaningful text.';
    }

    // ==========================================================
    // RANDOM LONG TOKEN
    // ==========================================================

    final String lettersOnly =
    text.replaceAll(
      RegExp(
        r'[^A-Za-zÀ-ÖØ-öø-ÿ]',
      ),
      '',
    );

    if (
    lettersOnly.length >=
        18 &&
        !text.contains(
          ' ',
        )
    ) {
      return 'The $fieldName does not appear to contain '
          'a clear phrase or sentence.';
    }

    // ==========================================================
    // LONG CONSONANT RUN
    // ==========================================================

    if (
    RegExp(
      r'[bcdfghjklmnpqrstvwxyz]{7,}',
      caseSensitive:
      false,
    ).hasMatch(
      lettersOnly,
    )
    ) {
      return 'The $fieldName does not appear to contain '
          'understandable words.';
    }

    return null;
  }

  // ============================================================
  // ANALYZE ONE IMAGE
  // ============================================================

  Future<bool> analyzeSingleImage(
      File imageFile, {
        bool rebuildFinal =
        true,
      }) async {
    if (
    !await imageFile.exists()
    ) {
      imageAnalysisErrors[
      imageFile.path] =
      'Evidence image is no longer available.';

      if (mounted) {
        setState(() {});
      }

      return false;
    }

    if (mounted) {
      setState(() {
        analyzingEvidence =
        true;

        analyzingImagePath =
            imageFile.path;

        imageAnalysisErrors
            .remove(
          imageFile.path,
        );

        // Old combined result is no longer authoritative.
        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;

        aiSuggestionsApplied =
        false;
      });
    }

    try {
      final ReportImageAiAnalysis
      result =
      await aiEvidenceService
          .analyzeLocalImage(
        imageFile:
        imageFile,

        userCategory:
        selectedCategory,

        userPriority:
        selectedPriority,

        userTitle:
        selectedTitle,

        userDescription:
        selectedDescription,
      );

      if (!mounted) {
        return false;
      }

      final ReportImageAiAnalysis
      prepared =
      result.copyWith(
        reviewedByUser:
        false,

        suggestionsApplied:
        false,

        originalUserCategory:
        widget.category,

        originalUserPriority:
        widget.priority,

        originalUserTitle:
        widget.title,

        originalUserDescription:
        widget.description,
      );

      setState(() {
        imageAnalyses[
        imageFile.path] =
            prepared;

        // Newly analyzed evidence opens automatically.
        expandedImageAnalyses.add(
          imageFile.path,
        );
      });

      if (rebuildFinal) {
        await combineAllAnalyses();
      }

      return true;
    } catch (e) {
      final String message =
      _cleanException(
        e,
      );

      if (mounted) {
        setState(() {
          imageAnalysisErrors[
          imageFile.path] =
              message;
        });
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          analyzingImagePath =
          null;

          analyzingEvidence =
          false;
        });
      }
    }
  }

  // ============================================================
  // ANALYZE MULTIPLE IMAGES
  //
  // Runs sequentially.
  //
  // This avoids hitting Gemini with several simultaneous
  // requests from one user action.
  // ============================================================

  Future<void> analyzeImageBatch(
      List<File> images,
      ) async {
    if (images.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        analyzingEvidence =
        true;

        finalAiAnalysis =
        null;

        finalAnalysisError =
        null;
      });
    }

    int successCount =
    0;

    try {
      for (
      int index = 0;
      index < images.length;
      index++
      ) {
        final File file =
        images[index];

        if (!mounted) {
          return;
        }

        setState(() {
          analyzingImagePath =
              file.path;

          compressionMessage =
          'Smart Assist analyzing image '
              '${index + 1} of ${images.length}...';
        });

        final bool success =
        await analyzeSingleImage(
          file,
          rebuildFinal:
          false,
        );

        if (success) {
          successCount++;
        }

        // A small spacing between requests helps avoid burst traffic.
        if (
        index <
            images.length - 1
        ) {
          await Future<void>.delayed(
            const Duration(
              milliseconds:
              500,
            ),
          );
        }
      }

      if (
      successCount >
          0
      ) {
        await combineAllAnalyses();
      }
    } finally {
      if (mounted) {
        setState(() {
          analyzingImagePath =
          null;

          analyzingEvidence =
          false;

          compressionMessage =
          evidenceImages.isEmpty
              ? 'Evidence images are optimized before upload.'
              : '$compressedImageCount image(s) compressed '
              'before upload.';
        });
      }
    }
  }

  // ============================================================
  // COMBINE ALL COMPLETED IMAGE ANALYSES
  // ============================================================

  Future<void> combineAllAnalyses() async {
    if (imageAnalyses.isEmpty) {
      if (mounted) {
        setState(() {
          finalAiAnalysis =
          null;

          finalAnalysisError =
          null;
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
      // ONLY CURRENT EVIDENCE
      //
      // Prevent deleted evidence from remaining in the
      // combined request.
      // ========================================================

      final Map<
          String,
          ReportImageAiAnalysis
      > activeAnalyses = {};

      for (
      final File file
      in evidenceImages
      ) {
        final ReportImageAiAnalysis?
        analysis =
        imageAnalyses[
        file.path];

        if (analysis != null) {
          activeAnalyses[
          file.path] =
              analysis;
        }
      }

      if (activeAnalyses.isEmpty) {
        return;
      }

      final ReportFinalAiAnalysis
      result =
      await aiEvidenceService
          .combineImageAnalyses(
        imageAnalyses:
        activeAnalyses,

        userCategory:
        selectedCategory,

        userPriority:
        selectedPriority,

        userTitle:
        selectedTitle,

        userDescription:
        selectedDescription,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        finalAiAnalysis =
            result.copyWith(
              suggestionsApplied:
              false,

              reviewedByUser:
              false,

              originalUserCategory:
              widget.category,

              originalUserPriority:
              widget.priority,

              originalUserTitle:
              widget.title,

              originalUserDescription:
              widget.description,
            );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        finalAnalysisError =
            _cleanException(
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
  // REANALYZE ONE IMAGE
  // ============================================================

  Future<void> reanalyzeImage(
      File file,
      ) async {
    if (isBusy) {
      return;
    }

    await analyzeSingleImage(
      file,
    );
  }

  // ============================================================
  // REANALYZE ALL
  // ============================================================

  Future<void> analyzeAgain() async {
    if (evidenceImages.isEmpty) {
      showMessage(
        'Please add an evidence image first.',
      );

      return;
    }

    if (isBusy) {
      return;
    }

    // ==========================================================
    // CLEAR OLD RESULTS
    // ==========================================================

    setState(() {
      imageAnalyses.clear();

      imageAnalysisErrors.clear();

      expandedImageAnalyses.clear();

      finalAiAnalysis =
      null;

      finalAnalysisError =
      null;

      aiSuggestionsApplied =
      false;
    });

    await analyzeImageBatch(
      List<File>.from(
        evidenceImages,
      ),
    );
  }

  // ============================================================
  // KEEP ORIGINAL USER INFORMATION
  // ============================================================

  void keepOriginalInformation() {
    setState(() {
      selectedCategory =
          widget.category;

      selectedPriority =
          widget.priority;

      selectedTitle =
          widget.title;

      selectedDescription =
          widget.description;

      aiSuggestionsApplied =
      false;

      if (
      finalAiAnalysis !=
          null
      ) {
        finalAiAnalysis =
            finalAiAnalysis!
                .copyWith(
              suggestionsApplied:
              false,

              reviewedByUser:
              true,

              originalUserCategory:
              widget.category,

              originalUserPriority:
              widget.priority,

              originalUserTitle:
              widget.title,

              originalUserDescription:
              widget.description,
            );
      }
    });

    showMessage(
      'Your original report information is selected.',
    ); unawaited(
      _saveEffectiveReportValues(),
    );
  }

  // ============================================================
  // APPLY FINAL COMBINED AI SUGGESTIONS
  //
  // IMPORTANT:
  //
  // Individual image analysis is NOT allowed to overwrite
  // report information.
  //
  // Only the FINAL COMBINED RESULT can be applied.
  // ============================================================

  void applyAiSuggestions() {
    final ReportFinalAiAnalysis?
    result =
        finalAiAnalysis;

    if (result == null) {
      return;
    }

    if (
    result.issueDetected !=
        true
    ) {
      showMessage(
        'Smart Assist could not confirm an infrastructure '
            'issue from the combined evidence.',
      );

      return;
    }

    setState(() {
      // ========================================================
      // CATEGORY
      // ========================================================

      if (
      result.category !=
          null &&
          result.category!
              .trim()
              .isNotEmpty
      ) {
        selectedCategory =
            result.category!
                .trim();
      }

      // ========================================================
      // PRIORITY
      // ========================================================

      final String?
      recommendedPriority =
          result
              .recommendedPriority ??
              result.severity;

      if (
      recommendedPriority !=
          null &&
          recommendedPriority
              .trim()
              .isNotEmpty
      ) {
        selectedPriority =
            recommendedPriority
                .trim();
      }

      // ========================================================
      // TITLE
      // ========================================================

      if (
      result.suggestedTitle !=
          null &&
          result.suggestedTitle!
              .trim()
              .isNotEmpty
      ) {
        selectedTitle =
            result.suggestedTitle!
                .trim();
      }

      // ========================================================
      // DESCRIPTION
      // ========================================================

      final String?
      suggestedDescription =
          result
              .suggestedDescription ??
              result.description;

      if (
      suggestedDescription !=
          null &&
          suggestedDescription
              .trim()
              .isNotEmpty
      ) {
        selectedDescription =
            suggestedDescription
                .trim();
      }

      aiSuggestionsApplied =
      true;

      finalAiAnalysis =
          result.copyWith(
            suggestionsApplied:
            true,

            reviewedByUser:
            true,

            originalUserCategory:
            widget.category,

            originalUserPriority:
            widget.priority,

            originalUserTitle:
            widget.title,

            originalUserDescription:
            widget.description,
          );
    });

    showMessage(
      'Final Smart Assist suggestions applied.',
    ); unawaited(
      _saveEffectiveReportValues(),
    );
  }

  // ============================================================
  // EDIT REPORT
  // ============================================================

  Future<void> editReport() async {
    if (isBusy) {
      return;
    }

    await _saveDraft(
      currentStep: 1,
    );

    if (!mounted) {
      return;
    }

    _allowPop =
    true;

    Navigator.pop(
      context,
    );
  }

  // ============================================================
  // TAKE PHOTO
  // ============================================================

  Future<void> takePhoto() async {
    if (isBusy) {
      return;
    }

    if (evidenceLimitReached) {
      showMessage(
        'You can add up to '
            '$maxEvidenceItems evidence items '
            'in total.',
      );

      return;
    }

    if (evidenceImages.length >=
        maxAiImages) {
      showMessage(
        'Smart Assist supports up to '
            '$maxAiImages photos.',
      );

      return;
    }

    try {
      setState(() {
        loadingImage =
        true;

        compressionMessage =
        'Preparing photo...';
      });

      final XFile? image =
      await picker.pickImage(
        source:
        ImageSource.camera,

        imageQuality:
        95,
      );

      if (image == null) {
        return;
      }

      final File? preparedFile =
      await _addAndCompressFile(
        File(
          image.path,
        ),
      );

      if (preparedFile != null) {
        await analyzeImageBatch(
          <File>[
            preparedFile,
          ],
        );
      }
    } catch (e) {
      showMessage(
        'Unable to open camera: '
            '${_cleanException(e)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingImage =
          false;
        });
      }
    }
  }

  // ============================================================
  // PICK MULTIPLE GALLERY IMAGES
  // ============================================================

  Future<void> pickGalleryImages() async {
    if (isBusy) {
      return;
    }

    final int availableTotal =
        remainingEvidenceSlots;

    final int availableForAi =
        maxAiImages -
            evidenceImages.length;

    final int remaining =
    availableTotal <
        availableForAi
        ? availableTotal
        : availableForAi;

    if (remaining <= 0) {
      showMessage(
        evidenceLimitReached
            ? 'You can add up to '
            '$maxEvidenceItems evidence items '
            'in total.'
            : 'Smart Assist already has '
            '$maxAiImages photos.',
      );

      return;
    }

    try {
      setState(() {
        loadingImage =
        true;

        compressionMessage =
        'Preparing selected photos...';
      });

      final List<XFile> selected =
      await picker.pickMultiImage(
        imageQuality:
        95,
      );

      if (selected.isEmpty) {
        return;
      }

      final List<XFile> images =
      selected.take(
        remaining,
      ).toList();

      if (selected.length >
          remaining) {
        showMessage(
          'Only the first $remaining '
              'photo(s) were added because '
              'the report supports up to '
              '$maxEvidenceItems total '
              'evidence items.',
        );
      }

      final List<File>
      preparedFiles =
      <File>[];

      for (int index = 0;
      index < images.length;
      index++) {
        if (mounted) {
          setState(() {
            compressionMessage =
            'Optimizing photo '
                '${index + 1} of '
                '${images.length}...';
          });
        }

        final File? preparedFile =
        await _addAndCompressFile(
          File(
            images[index].path,
          ),
        );

        if (preparedFile != null) {
          preparedFiles.add(
            preparedFile,
          );
        }
      }

      if (preparedFiles.isNotEmpty) {
        await analyzeImageBatch(
          preparedFiles,
        );
      }
    } catch (e) {
      showMessage(
        'Unable to open gallery: '
            '${_cleanException(e)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingImage =
          false;

          if (evidenceImages
              .isNotEmpty) {
            compressionMessage =
            '$compressedImageCount '
                'photo(s) optimized '
                'before upload.';
          }
        });
      }
    }
  }

  // ============================================================
// RECORD VIDEO
// ============================================================

  Future<void> recordVideo() async {
    if (isBusy) {
      return;
    }

    if (evidenceLimitReached) {
      showMessage(
        'You can add up to '
            '$maxEvidenceItems evidence items '
            'in total.',
      );

      return;
    }

    try {
      setState(() {
        loadingVideo =
        true;
      });

      final XFile? video =
      await picker.pickVideo(
        source:
        ImageSource.camera,

        maxDuration:
        maxVideoDuration,
      );

      if (video == null) {
        return;
      }

      await _prepareVideo(
        File(
          video.path,
        ),
      );
    } catch (e) {
      showMessage(
        'Unable to record video: '
            '${_cleanException(e)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingVideo =
          false;
        });
      }
    }
  }

// ============================================================
// PICK VIDEO FROM GALLERY
// ============================================================

  Future<void> pickGalleryVideo() async {
    if (isBusy) {
      return;
    }

    if (evidenceLimitReached) {
      showMessage(
        'You can add up to '
            '$maxEvidenceItems evidence items '
            'in total.',
      );

      return;
    }

    try {
      setState(() {
        loadingVideo =
        true;
      });

      final XFile? video =
      await picker.pickVideo(
        source:
        ImageSource.gallery,

        maxDuration:
        maxVideoDuration,
      );

      if (video == null) {
        return;
      }

      await _prepareVideo(
        File(
          video.path,
        ),
      );
    } catch (e) {
      showMessage(
        'Unable to select video: '
            '${_cleanException(e)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingVideo =
          false;
        });
      }
    }
  }

// ============================================================
// PREPARE VIDEO
// ============================================================

  Future<void> _prepareVideo(
      File sourceFile,
      ) async {
    final String? userId =
        _userId;

    if (userId == null) {
      showMessage(
        'Your session is unavailable. '
            'Please sign in again.',
      );

      return;
    }

    if (!await sourceFile.exists()) {
      showMessage(
        'The selected video '
            'is no longer available.',
      );

      return;
    }

    VideoPlayerController?
    controller;

    try {
      controller =
          VideoPlayerController.file(
            sourceFile,
          );

      await controller.initialize();

      final Duration duration =
          controller.value.duration;

      if (duration >
          maxVideoDuration) {
        showMessage(
          'Please choose a video '
              'that is 30 seconds or shorter.',
        );

        return;
      }

      final String persistentPath =
      await ReportDraftService
          .persistEvidenceVideo(
        userId:
        userId,

        sourceFile:
        sourceFile,
      );

      final File persistentFile =
      File(
        persistentPath,
      );

      if (!await persistentFile
          .exists()) {
        throw Exception(
          'Unable to preserve video.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        evidenceVideos.add(
          persistentFile,
        );

        videoDurations[
        persistentFile.path] =
            duration;
      });

      await _saveDraft(
        currentStep:
        2,
      );

      showMessage(
        'Video added to your draft.',
      );
    } catch (e) {
      showMessage(
        'Unable to prepare video: '
            '${_cleanException(e)}',
      );
    } finally {
      await controller?.dispose();
    }
  }

  // ============================================================
// VIDEO PREVIEW
// ============================================================

  Future<void> previewVideo(
      File videoFile,
      ) async {
    if (!await videoFile.exists()) {
      showMessage(
        'This video is no longer '
            'available.',
      );

      return;
    }

    final VideoPlayerController
    controller =
    VideoPlayerController.file(
      videoFile,
    );

    try {
      await controller.initialize();

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
          return _VideoPreviewDialog(
            controller:
            controller,
          );
        },
      );
    } catch (e) {
      showMessage(
        'Unable to preview video: '
            '${_cleanException(e)}',
      );
    } finally {
      await controller.dispose();
    }
  }

  Future<File?> _addAndCompressFile(
      File originalFile,
      ) async {
    final String? userId =
        _userId;

    if (userId == null) {
      showMessage(
        'Your session is unavailable. '
            'Please sign in again.',
      );

      return null;
    }

    try {
      final ImageCompressionResult
      result =
      await compressionService
          .compressEvidenceImage(
        originalFile,
      );

      // ==========================================================
      // COPY THE COMPRESSED IMAGE TO PERMANENT DRAFT STORAGE
      // ==========================================================

      final String persistentPath =
      await ReportDraftService
          .persistEvidenceImage(
        userId:
        userId,

        sourceFile:
        result.file,
      );

      final File persistentFile =
      File(
        persistentPath,
      );

      if (!await persistentFile
          .exists()) {
        throw Exception(
          'Persistent evidence file '
              'could not be created.',
        );
      }

      if (!mounted) {
        return null;
      }

      setState(() {
        evidenceImages.add(
          persistentFile,
        );

        totalCompressedBytes +=
            result.compressedBytes;

        if (result.compressed) {
          compressedImageCount++;
        }

        compressionMessage =
        result.compressed
            ? 'Photo optimized: '
            '${compressionService.formatBytes(result.originalBytes)} → '
            '${compressionService.formatBytes(result.compressedBytes)} '
            '(${result.savedPercentage.toStringAsFixed(0)}% smaller)'
            : 'Photo ready for upload.';
      });

      // The temporary compression file is no longer needed
      // because the permanent draft copy has been created.
      if (result.file.path !=
          persistentFile.path) {
        await compressionService
            .deleteTemporaryCompressedFile(
          result.file,
        );
      }

      await _saveDraft(
        currentStep: 2,
      );

      return persistentFile;
    } catch (e) {
      showMessage(
        'Unable to prepare photo: '
            '${_cleanException(e)}',
      );

      return null;
    }
  }

  // ============================================================
  // REMOVE IMAGE
  // ============================================================

  Future<void> removeImage(
      int index,
      ) async {
    if (index < 0 ||
        index >=
            evidenceImages.length ||
        isBusy) {
      return;
    }

    final String? userId =
        _userId;

    if (userId == null) {
      return;
    }

    final File file =
    evidenceImages[index];

    final String path =
        file.path;

    int currentBytes = 0;

    try {
      currentBytes =
      await file.length();
    } catch (_) {
      currentBytes = 0;
    }

    setState(() {
      evidenceImages.removeAt(
        index,
      );

      imageAnalyses.remove(
        path,
      );

      imageAnalysisErrors.remove(
        path,
      );

      expandedImageAnalyses.remove(
        path,
      );

      finalAiAnalysis =
      null;

      finalAnalysisError =
      null;

      aiSuggestionsApplied =
      false;

      totalCompressedBytes =
          (
              totalCompressedBytes -
                  currentBytes
          ).clamp(
            0,
            1 << 62,
          );

      // Evidence changed, so an old final AI result
      // must not remain authoritative.
      selectedCategory =
          widget.category;

      selectedPriority =
          widget.priority;

      selectedTitle =
          widget.title;

      selectedDescription =
          widget.description;
    });

    await ReportDraftService
        .removeEvidenceImage(
      userId:
      userId,

      imagePath:
      path,
    );

    await _saveDraft(
      currentStep: 2,
    );

    if (imageAnalyses.isNotEmpty) {
      await combineAllAnalyses();
    }
  }

  Future<void> removeVideo(
      int index,
      ) async {
    if (index < 0 ||
        index >=
            evidenceVideos.length ||
        isBusy) {
      return;
    }

    final String? userId =
        _userId;

    if (userId == null) {
      return;
    }

    final File file =
    evidenceVideos[index];

    final String path =
        file.path;

    setState(() {
      evidenceVideos.removeAt(
        index,
      );

      videoDurations.remove(
        path,
      );
    });

    await ReportDraftService
        .removeEvidenceVideo(
      userId:
      userId,

      videoPath:
      path,
    );

    await _saveDraft(
      currentStep: 2,
    );
  }

  // ============================================================
  // TOGGLE IMAGE ANALYSIS
  // ============================================================

  void toggleImageAnalysis(
      String path,
      ) {
    setState(() {
      if (
      expandedImageAnalyses
          .contains(
        path,
      )
      ) {
        expandedImageAnalyses
            .remove(
          path,
        );
      } else {
        expandedImageAnalyses.add(
          path,
        );
      }
    });
  }

  // ============================================================
  // CONTINUE
  // ============================================================

  Future<void> continueToLocation() async {
    if (!hasEvidence) {
      showMessage(
        'Please add at least one '
            'photo or video.',
      );

      return;
    }

    if (isBusy) {
      showMessage(
        'Please wait for the current '
            'operation to finish.',
      );

      return;
    }

    final String? localProblem =
    validateReportLocally(
      title:
      selectedTitle,

      description:
      selectedDescription,
    );

    if (localProblem != null) {
      await showInvalidReportDialog(
        localProblem,
      );

      return;
    }

    final ReportFinalAiAnalysis?
    result =
        finalAiAnalysis;

    if (result != null &&
        result.reportSufficient ==
            false &&
        !aiSuggestionsApplied) {
      await showPoorReportDialog();

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isNavigating =
      true;
    });

    final bool saved =
    await _saveDraft(
      currentStep:
      3,
    );

    if (!saved) {
      if (mounted) {
        setState(() {
          isNavigating =
          false;
        });
      }

      showMessage(
        'Unable to save your draft. '
            'Please try again before continuing.',
      );

      return;
    }

    ReportImageAiAnalysis?
    legacyAnalysis;

    if (imageAnalyses.isNotEmpty) {
      legacyAnalysis =
          imageAnalyses.values.first;
    }

    try {
      if (!mounted) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CreateReportLocationScreen(
                category:
                selectedCategory,

                priority:
                selectedPriority,

                title:
                selectedTitle,

                description:
                selectedDescription,

                evidenceImages:
                List<File>.from(
                  evidenceImages,
                ),

                aiAnalysis:
                legacyAnalysis,
              ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isNavigating =
          false;
        });

        await _restoreDraft();
      }
    }
  }

  // ============================================================
  // INVALID LOCAL REPORT DIALOG
  // ============================================================

  Future<void> showInvalidReportDialog(
      String reason,
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
          title:
          const Row(
            children: [
              Icon(
                Icons
                    .warning_amber_rounded,
                color:
                Colors.orange,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Text(
                  'Report Needs Improvement',
                ),
              ),
            ],
          ),

          content:
          Text(
            '$reason\n\n'
                'Please provide useful information so the '
                'responding worker can understand the issue.',
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

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                editReport();
              },

              icon:
              const Icon(
                Icons.edit_outlined,
              ),

              label:
              const Text(
                'Edit Report',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // POOR FINAL REPORT DIALOG
  // ============================================================

  Future<void> showPoorReportDialog() async {
    final ReportFinalAiAnalysis?
    result =
        finalAiAnalysis;

    if (
    !mounted ||
        result == null
    ) {
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
          title:
          const Row(
            children: [
              Icon(
                Icons
                    .warning_amber_rounded,
                color:
                Colors.orange,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Text(
                  'Report Information Is Unclear',
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
              Text(
                result.reportIssue ??
                    'Smart Assist found that the report '
                        'does not contain enough meaningful '
                        'information.',
              ),

              if (
              result
                  .missingInformation
                  .isNotEmpty
              ) ...[
                const SizedBox(
                  height:
                  12,
                ),

                const Text(
                  'Missing or unclear:',
                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                  4,
                ),

                ...result
                    .missingInformation
                    .map(
                      (
                      item,
                      ) =>
                      Padding(
                        padding:
                        const EdgeInsets.only(
                          bottom:
                          3,
                        ),

                        child:
                        Text(
                          '• $item',
                        ),
                      ),
                ),
              ],
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                editReport();
              },

              child:
              const Text(
                'Edit Report',
              ),
            ),

            if (
            result
                .hasSuggestedReportText &&
                result
                    .issueDetected ==
                    true
            )
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );

                  applyAiSuggestions();
                },

                icon:
                const Icon(
                  Icons.auto_awesome,
                ),

                label:
                const Text(
                  'Apply AI',
                ),
              ),
          ],
        );
      },
    );
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
  // CLEAN ERROR
  // ============================================================

  String _cleanException(
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

  Widget _buildDraftStatusCard() {
    final Color color =
        _draftStatusColor;

    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.symmetric(
        horizontal:
        14,

        vertical:
        11,
      ),

      decoration:
      BoxDecoration(
        color:
        color.withOpacity(
          0.07,
        ),

        borderRadius:
        BorderRadius.circular(
          13,
        ),

        border:
        Border.all(
          color:
          color.withOpacity(
            0.30,
          ),
        ),
      ),

      child:
      Row(
        children: [
          if (savingDraft ||
              restoringDraft)
            SizedBox(
              width:
              17,
              height:
              17,
              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
                color:
                color,
              ),
            )
          else
            Icon(
              _draftStatusIcon,
              color:
              color,
              size:
              18,
            ),

          const SizedBox(
            width:
            10,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _draftStatusText,
                  style:
                  TextStyle(
                    color:
                    color,
                    fontSize:
                    11,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                  2,
                ),

                const Text(
                  'Photos and videos are kept locally '
                      'until this report is submitted or discarded.',
                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize:
                    9,
                    height:
                    1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,

      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        // Do not leave while restoring/saving/analyzing/navigating.
        if (isBusy) {
          return;
        }

        final bool saved = await _saveDraft(
          currentStep: 2,
        );

        if (!saved || !mounted) {
          return;
        }

        _allowPop = true;

        Navigator.pop(context);
      },

      child: Scaffold(
        backgroundColor: AppColors.background,

        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // =================================================
                      // HEADER
                      // =================================================

                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),

                            child: IconButton(
                              onPressed: isBusy
                                  ? null
                                  : () async {
                                final bool saved = await _saveDraft(
                                  currentStep: 2,
                                );

                                if (!saved || !mounted) {
                                  return;
                                }

                                _allowPop = true;

                                Navigator.pop(context);
                              },

                              icon: const Icon(
                                Icons.arrow_back,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Issue',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Help improve your community',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      // =================================================
                      // PROGRESS
                      // =================================================

                      const _EvidenceProgress(),

                      const SizedBox(
                        height: 14,
                      ),

                      // =================================================
                      // DRAFT STATUS
                      // =================================================

                      _buildDraftStatusCard(),

                      const SizedBox(
                        height: 22,
                      ),

                      // =================================================
                      // SMART ASSIST
                      // =================================================

                      _buildSmartAssistCard(),

                      const SizedBox(
                        height: 20,
                      ),

                      // =================================================
                      // IMAGE OPTIMIZATION
                      // =================================================

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10253E,
                          ),
                          borderRadius: BorderRadius.circular(
                            15,
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFF375B91,
                            ),
                          ),
                        ),

                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Icon(
                              Icons.compress_outlined,
                              color: AppColors.primary,
                              size: 25,
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  const Text(
                                    'Evidence Optimization',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    loadingImage
                                        ? compressionMessage
                                        : evidenceImages.isEmpty
                                        ? 'Evidence photos are optimized before upload.'
                                        : '$compressionMessage\n'
                                        'Prepared photo size: '
                                        '${compressionService.formatBytes(totalCompressedBytes)}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      height: 1.4,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 5,
                                  ),

                                  Text(
                                    'Maximum $maxEvidenceItems total evidence items. '
                                        'Smart Assist analyzes photos individually.',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                      height: 1.35,
                                    ),
                                  ),

                                  if (evidenceVideos.isNotEmpty) ...[
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      '${evidenceVideos.length} short video'
                                          '${evidenceVideos.length == 1 ? '' : 's'} '
                                          'saved as supporting evidence.',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // =================================================
                      // UPLOAD BOX
                      // =================================================

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),

                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primaryDark,
                            width: 1.5,
                          ),
                        ),

                        child: Column(
                          children: [
                            Container(
                              width: 58,
                              height: 58,

                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(
                                  0.10,
                                ),
                                shape: BoxShape.circle,
                              ),

                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 30,
                                color: AppColors.primary,
                              ),
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            const Text(
                              'Add Evidence',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            const Text(
                              'Add a clear close-up or wider context photo. '
                                  'A short video can help show movement, flickering, '
                                  'water flow or other changing conditions.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.45,
                              ),
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),

                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(
                                  0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  20,
                                ),
                              ),

                              child: Text(
                                '$totalEvidenceCount / '
                                    '$maxEvidenceItems evidence items',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // =================================================
                      // CAMERA / VIDEO BUTTONS
                      // =================================================

                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isBusy || evidenceLimitReached
                                      ? null
                                      : takePhoto,
                                  icon: const Icon(
                                    Icons.camera_alt_outlined,
                                  ),
                                  label: const Text(
                                    'Photo',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 10,
                              ),

                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isBusy || evidenceLimitReached
                                      ? null
                                      : recordVideo,
                                  icon: const Icon(
                                    Icons.videocam_outlined,
                                  ),
                                  label: const Text(
                                    'Record Video',
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
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isBusy || evidenceLimitReached
                                      ? null
                                      : pickGalleryImages,
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text(
                                    'Gallery Photos',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 10,
                              ),

                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isBusy || evidenceLimitReached
                                      ? null
                                      : pickGalleryVideo,
                                  icon: const Icon(
                                    Icons.video_library_outlined,
                                  ),
                                  label: const Text(
                                    'Gallery Video',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // =================================================
                      // VIDEO EVIDENCE
                      // =================================================

                      if (evidenceVideos.isNotEmpty) ...[
                        const SizedBox(
                          height: 18,
                        ),

                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Video Evidence',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            Text(
                              '${evidenceVideos.length} video'
                                  '${evidenceVideos.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        ...List.generate(
                          evidenceVideos.length,
                              (index) {
                            final File video = evidenceVideos[index];

                            final Duration? duration =
                            videoDurations[video.path];

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 10,
                              ),

                              child: Container(
                                padding: const EdgeInsets.all(
                                  12,
                                ),

                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    14,
                                  ),
                                  border: Border.all(
                                    color: AppColors.border,
                                  ),
                                ),

                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: isBusy
                                          ? null
                                          : () {
                                        previewVideo(
                                          video,
                                        );
                                      },

                                      child: Container(
                                        width: 70,
                                        height: 58,

                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF10253E,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),

                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            const Icon(
                                              Icons.videocam_outlined,
                                              color: AppColors.primary,
                                              size: 27,
                                            ),

                                            Positioned(
                                              right: 5,
                                              bottom: 5,

                                              child: Container(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 2,
                                                ),

                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                  BorderRadius.circular(
                                                    5,
                                                  ),
                                                ),

                                                child: Text(
                                                  _formatVideoDuration(
                                                    duration,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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
                                          Text(
                                            'Video ${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(
                                            height: 4,
                                          ),

                                          const Text(
                                            'Supporting evidence • '
                                                'Kept safely in your local draft.',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 9,
                                              height: 1.35,
                                            ),
                                          ),

                                          const SizedBox(
                                            height: 6,
                                          ),

                                          InkWell(
                                            onTap: isBusy
                                                ? null
                                                : () {
                                              previewVideo(
                                                video,
                                              );
                                            },

                                            child: const Text(
                                              'Preview video',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    IconButton(
                                      tooltip: 'Remove video',
                                      onPressed: isBusy
                                          ? null
                                          : () {
                                        removeVideo(
                                          index,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // =================================================
                      // IMAGE PREVIEW HEADER
                      // =================================================

                      if (evidenceImages.isNotEmpty) ...[
                        const SizedBox(
                          height: 18,
                        ),

                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Photo Evidence',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            Text(
                              '${evidenceImages.length} photo'
                                  '${evidenceImages.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 10,
                        ),
                      ],

                      // =================================================
                      // IMAGE PREVIEW GRID
                      // =================================================

                      if (evidenceImages.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: evidenceImages.length,

                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 9,
                            mainAxisSpacing: 9,
                          ),

                          itemBuilder: (
                              context,
                              index,
                              ) {
                            final File file = evidenceImages[index];

                            final bool complete =
                            imageAnalyses.containsKey(
                              file.path,
                            );

                            final bool hasError =
                            imageAnalysisErrors.containsKey(
                              file.path,
                            );

                            final bool analyzing =
                                analyzingImagePath == file.path;

                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      12,
                                    ),

                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),

                                // =================================================
                                // STATUS BADGE
                                // =================================================

                                Positioned(
                                  left: 4,
                                  bottom: 4,

                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),

                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(
                                        8,
                                      ),
                                    ),

                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (analyzing) ...[
                                          const SizedBox(
                                            width: 8,
                                            height: 8,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.3,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 4,
                                          ),
                                        ],

                                        Text(
                                          analyzing
                                              ? 'Analyzing'
                                              : hasError
                                              ? 'Failed'
                                              : complete
                                              ? 'Verified'
                                              : 'Ready',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // =================================================
                                // REMOVE PHOTO
                                // =================================================

                                Positioned(
                                  right: 4,
                                  top: 4,

                                  child: GestureDetector(
                                    onTap: isBusy
                                        ? null
                                        : () {
                                      removeImage(
                                        index,
                                      );
                                    },

                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        4,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                      // =================================================
                      // HELPFUL EMPTY STATE
                      // =================================================

                      if (!hasEvidence) ...[
                        const SizedBox(
                          height: 18,
                        ),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                            16,
                          ),

                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              14,
                            ),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),

                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: Text(
                                  'Add at least one photo or short video '
                                      'before continuing to the location step.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 8,
                      ),
                    ],
                  ),
                ),
              ),

              // =====================================================
              // BOTTOM BUTTONS
              // =====================================================

              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withOpacity(
                        0.6,
                      ),
                    ),
                  ),
                ),

                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    18,
                  ),

                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () async {
                          final bool saved = await _saveDraft(
                            currentStep: 2,
                          );

                          if (!saved || !mounted) {
                            return;
                          }

                          _allowPop = true;

                          Navigator.pop(context);
                        },

                        child: const Text(
                          'Back',
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            minimumSize: const Size.fromHeight(
                              54,
                            ),
                          ),

                          onPressed: isBusy
                              ? null
                              : continueToLocation,

                          child: isBusy
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                hasEvidence
                                    ? 'Continue to Location'
                                    : 'Add Evidence First',
                              ),
                              const SizedBox(
                                width: 6,
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SMART ASSIST CARD
  // ============================================================

  Widget _buildSmartAssistCard() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        16,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFF10253E,
        ),

        borderRadius:
        BorderRadius.circular(
          15,
        ),

        border:
        Border.all(
          color:
          const Color(
            0xFF375B91,
          ),
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Row(
            children: [
              const Text(
                '✨',
                style:
                TextStyle(
                  fontSize:
                  25,
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
                      'Smart Assist',
                      style:
                      TextStyle(
                        color:
                        Color(
                          0xFF8F80FF,
                        ),

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      3,
                    ),

                    Text(
                      _smartAssistMessage(),

                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize:
                        11,
                        height:
                        1.4,
                      ),
                    ),
                  ],
                ),
              ),

              if (isBusy)
                const SizedBox(
                  width:
                  20,
                  height:
                  20,

                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                    color:
                    Color(
                      0xFF8F80FF,
                    ),
                  ),
                ),
            ],
          ),

          // ======================================================
          // INDIVIDUAL IMAGE RESULTS
          // ======================================================

          if (
          evidenceImages
              .isNotEmpty
          ) ...[
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

            const Text(
              'Individual Evidence Analysis',

              style:
              TextStyle(
                color:
                Color(
                  0xFF8F80FF,
                ),

                fontSize:
                11,

                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
              8,
            ),

            ...List.generate(
              evidenceImages.length,
                  (
                  index,
                  ) {
                final File file =
                evidenceImages[
                index];

                return Padding(
                  padding:
                  const EdgeInsets.only(
                    bottom:
                    8,
                  ),

                  child:
                  _buildImageAnalysisCard(
                    file:
                    file,

                    index:
                    index,
                  ),
                );
              },
            ),
          ],

          // ======================================================
          // FINAL COMBINED RESULT
          // ======================================================

          if (
          finalAiAnalysis !=
              null
          ) ...[
            const SizedBox(
              height:
              10,
            ),

            const Divider(
              color:
              AppColors.border,
            ),

            const SizedBox(
              height:
              10,
            ),

            _buildFinalCombinedCard(
              finalAiAnalysis!,
            ),
          ],

          // ======================================================
          // FINAL ERROR
          // ======================================================

          if (
          finalAnalysisError !=
              null
          ) ...[
            const SizedBox(
              height:
              12,
            ),

            Text(
              'Final analysis unavailable: '
                  '$finalAnalysisError',

              style:
              const TextStyle(
                color:
                Colors.amber,
                fontSize:
                10,
                height:
                1.4,
              ),
            ),

            const SizedBox(
              height:
              8,
            ),

            SizedBox(
              width:
              double.infinity,

              child:
              OutlinedButton.icon(
                onPressed:
                isBusy
                    ? null
                    : combineAllAnalyses,

                icon:
                const Icon(
                  Icons.refresh,
                  size:
                  17,
                ),

                label:
                const Text(
                  'Retry Final Analysis',
                ),
              ),
            ),
          ],

          // ======================================================
          // REANALYZE ALL
          // ======================================================

          if (
          evidenceImages
              .isNotEmpty
          ) ...[
            const SizedBox(
              height:
              8,
            ),

            SizedBox(
              width:
              double.infinity,

              child:
              OutlinedButton.icon(
                onPressed:
                isBusy
                    ? null
                    : analyzeAgain,

                icon:
                const Icon(
                  Icons.refresh,
                  size:
                  17,
                ),

                label:
                const Text(
                  'Analyze All Again',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // INDIVIDUAL IMAGE ANALYSIS CARD
  // ============================================================

  Widget _buildImageAnalysisCard({
    required File file,
    required int index,
  }) {
    final String path =
        file.path;

    final ReportImageAiAnalysis?
    result =
    imageAnalyses[
    path];

    final String? error =
    imageAnalysisErrors[
    path];

    final bool expanded =
    expandedImageAnalyses
        .contains(
      path,
    );

    final bool analyzing =
        analyzingImagePath ==
            path;

    String summary =
        'Waiting for analysis';

    if (analyzing) {
      summary =
      'Analyzing evidence...';
    } else if (result != null) {
      final String issue =
      result.issueDetected ==
          true
          ? result.issueLabel
          : 'No clear issue';

      summary =
      '$issue • '
          '${result.severity ?? 'Unknown'} • '
          '${result.confidence ?? 'Low'} confidence';
    } else if (error != null) {
      summary =
      'Analysis failed';
    }

    return Container(
      decoration:
      BoxDecoration(
        color:
        AppColors.surface
            .withOpacity(
          0.55,
        ),

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
      Column(
        children: [
          InkWell(
            borderRadius:
            BorderRadius.circular(
              12,
            ),

            onTap:
            result == null
                ? null
                : () {
              toggleImageAnalysis(
                path,
              );
            },

            child:
            Padding(
              padding:
              const EdgeInsets.all(
                10,
              ),

              child:
              Row(
                children: [
                  ClipRRect(
                    borderRadius:
                    BorderRadius.circular(
                      8,
                    ),

                    child:
                    Image.file(
                      file,

                      width:
                      48,

                      height:
                      48,

                      fit:
                      BoxFit.cover,
                    ),
                  ),

                  const SizedBox(
                    width:
                    10,
                  ),

                  Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Image ${index + 1}',

                          style:
                          const TextStyle(
                            fontSize:
                            11,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height:
                          3,
                        ),

                        Text(
                          summary,

                          maxLines:
                          2,

                          overflow:
                          TextOverflow.ellipsis,

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

                  if (analyzing)
                    const SizedBox(
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
                  else if (
                  result !=
                      null
                  )
                    Icon(
                      expanded
                          ? Icons
                          .expand_less
                          : Icons
                          .expand_more,
                    ),
                ],
              ),
            ),
          ),

          if (
          error !=
              null
          )
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                10,
                0,
                10,
                10,
              ),

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Text(
                    error,

                    style:
                    const TextStyle(
                      color:
                      Colors.amber,

                      fontSize:
                      9,
                    ),
                  ),

                  const SizedBox(
                    height:
                    6,
                  ),

                  OutlinedButton.icon(
                    onPressed:
                    isBusy
                        ? null
                        : () {
                      reanalyzeImage(
                        file,
                      );
                    },

                    icon:
                    const Icon(
                      Icons.refresh,
                      size:
                      15,
                    ),

                    label:
                    const Text(
                      'Try Again',
                    ),
                  ),
                ],
              ),
            ),

          if (
          result != null &&
              expanded
          )
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                10,
                0,
                10,
                12,
              ),

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Divider(
                    color:
                    AppColors.border,
                  ),

                  _AiResultRow(
                    label:
                    'Detected Issue',

                    value:
                    result.issueDetected ==
                        true
                        ? result.issueLabel
                        : 'No clear issue detected',
                  ),

                  _AiResultRow(
                    label:
                    'Category',

                    value:
                    result.category ??
                        'Other',
                  ),

                  _AiResultRow(
                    label:
                    'Severity',

                    value:
                    result.severity ??
                        'Unknown',
                  ),

                  _AiResultRow(
                    label:
                    'Confidence',

                    value:
                    result.confidence ??
                        'Low',
                  ),

                  _AiResultRow(
                    label:
                    'Evidence Quality',

                    value:
                    result.evidenceQuality ??
                        'Unknown',
                  ),

                  if (
                  result.description
                      ?.trim()
                      .isNotEmpty ==
                      true
                  ) ...[
                    const SizedBox(
                      height:
                      6,
                    ),

                    Text(
                      result.description!,

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
                  ],

                  if (
                  result.safetyConcern
                      ?.trim()
                      .isNotEmpty ==
                      true
                  ) ...[
                    const SizedBox(
                      height:
                      6,
                    ),

                    Text(
                      '⚠ ${result.safetyConcern!}',

                      style:
                      const TextStyle(
                        color:
                        Colors.amber,

                        fontSize:
                        9,

                        height:
                        1.4,
                      ),
                    ),
                  ],

                  if (
                  result
                      .retakeRecommended
                  ) ...[
                    const SizedBox(
                      height:
                      6,
                    ),

                    Text(
                      'Retake recommended'
                          '${result.retakeReason?.trim().isNotEmpty == true ? ': ${result.retakeReason}' : ''}',

                      style:
                      const TextStyle(
                        color:
                        Colors.orange,

                        fontSize:
                        9,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height:
                    8,
                  ),

                  SizedBox(
                    width:
                    double.infinity,

                    child:
                    OutlinedButton.icon(
                      onPressed:
                      isBusy
                          ? null
                          : () {
                        reanalyzeImage(
                          file,
                        );
                      },

                      icon:
                      const Icon(
                        Icons.refresh,
                        size:
                        15,
                      ),

                      label:
                      Text(
                        'Reanalyze Image ${index + 1}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // FINAL COMBINED CARD
  // ============================================================

  Widget _buildFinalCombinedCard(
      ReportFinalAiAnalysis result,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Row(
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
              8,
            ),

            const Expanded(
              child:
              Text(
                'Final Combined Analysis',

                style:
                TextStyle(
                  color:
                  Color(
                    0xFF8F80FF,
                  ),

                  fontSize:
                  12,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),

            Text(
              '${result.analyzedImageCount} image'
                  '${result.analyzedImageCount == 1 ? '' : 's'}',

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

        const SizedBox(
          height:
          10,
        ),

        // ======================================================
        // REPORT QUALITY
        // ======================================================

        _buildFinalReportQuality(
          result,
        ),

        const SizedBox(
          height:
          12,
        ),

        // ======================================================
        // FINAL ISSUE
        // ======================================================

        _AiResultRow(
          label:
          'Final Issue',

          value:
          result.issueDetected ==
              true
              ? result.issueLabel
              : 'No clear issue detected',
        ),

        _AiResultRow(
          label:
          'Final Category',

          value:
          result.category ??
              'Other',
        ),

        _AiResultRow(
          label:
          'Severity',

          value:
          result.severity ??
              'Unknown',
        ),

        _AiResultRow(
          label:
          'Confidence',

          value:
          result.confidence ??
              'Low',
        ),

        _AiResultRow(
          label:
          'Evidence Quality',

          value:
          result.evidenceQuality ??
              'Unknown',
        ),

        _AiResultRow(
          label:
          'Consistency',

          value:
          result.evidenceConsistencyLabel,
        ),

        _AiResultRow(
          label:
          'Your Priority',

          value:
          widget.priority,
        ),

        _AiResultRow(
          label:
          'AI Priority',

          value:
          result.recommendedPriority ??
              result.severity ??
              'Low',
        ),

        // ======================================================
        // CONFLICT
        // ======================================================

        if (
        result.conflictingEvidence
        )
          _warningBox(
            title:
            'Mixed Evidence',

            message:
            result.conflictingEvidenceReason ??
                'The evidence images do not fully agree.',
          ),

        // ======================================================
        // HUMAN REVIEW
        // ======================================================

        if (
        result.needsHumanReview
        )
          _warningBox(
            title:
            'Human Review Recommended',

            message:
            result.humanReviewReason ??
                'The final AI result should be verified by a human reviewer.',
          ),

        // ======================================================
        // DESCRIPTION
        // ======================================================

        if (
        result.description
            ?.trim()
            .isNotEmpty ==
            true
        ) ...[
          const SizedBox(
            height:
            10,
          ),

          const Text(
            'Combined Evidence Summary',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              10,

              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            height:
            4,
          ),

          Text(
            result.description!,

            style:
            const TextStyle(
              fontSize:
              10,

              height:
              1.4,
            ),
          ),
        ],

        if (
        result.safetyConcern
            ?.trim()
            .isNotEmpty ==
            true
        ) ...[
          const SizedBox(
            height:
            8,
          ),

          Text(
            '⚠ ${result.safetyConcern!}',

            style:
            const TextStyle(
              color:
              Colors.amber,

              fontSize:
              10,

              height:
              1.4,
            ),
          ),
        ],

        const SizedBox(
          height:
          12,
        ),

        const Text(
          'Final Smart Assist recommendations are generated '
              'from all analyzed evidence. Human users remain '
              'responsible for the final report.',

          style:
          TextStyle(
            color:
            AppColors.textSecondary,

            fontSize:
            9,

            fontStyle:
            FontStyle.italic,
          ),
        ),

        const SizedBox(
          height:
          12,
        ),

        // ======================================================
        // KEEP / APPLY
        // ======================================================

        Row(
          children: [
            Expanded(
              child:
              OutlinedButton(
                onPressed:
                keepOriginalInformation,

                child:
                const Text(
                  'Keep Mine',
                ),
              ),
            ),

            const SizedBox(
              width:
              8,
            ),

            Expanded(
              child:
              ElevatedButton.icon(
                onPressed:
                result.issueDetected ==
                    true
                    ? applyAiSuggestions
                    : null,

                icon:
                const Icon(
                  Icons.auto_awesome,
                  size:
                  17,
                ),

                label:
                const Text(
                  'Apply AI',
                ),
              ),
            ),
          ],
        ),

        if (
        result.shouldSuggestReportEdit
        ) ...[
          const SizedBox(
            height:
            8,
          ),

          SizedBox(
            width:
            double.infinity,

            child:
            OutlinedButton.icon(
              onPressed:
              editReport,

              icon:
              const Icon(
                Icons.edit_outlined,
                size:
                17,
              ),

              label:
              const Text(
                'Edit Report',
              ),
            ),
          ),
        ],

        if (
        result.reviewedByUser
        ) ...[
          const SizedBox(
            height:
            8,
          ),

          Text(
            aiSuggestionsApplied
                ? '✓ Final AI suggestions selected'
                : '✓ Original report information selected',

            style:
            const TextStyle(
              color:
              AppColors.success,

              fontSize:
              10,

              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // FINAL REPORT QUALITY
  // ============================================================

  Widget _buildFinalReportQuality(
      ReportFinalAiAnalysis result,
      ) {
    final bool needsImprovement =
        result.shouldSuggestReportEdit;

    final Color color =
    needsImprovement
        ? Colors.amber
        : AppColors.success;

    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        12,
      ),

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

        border:
        Border.all(
          color:
          color.withOpacity(
            0.35,
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
              Icon(
                needsImprovement
                    ? Icons
                    .warning_amber_rounded
                    : Icons
                    .check_circle_outline,

                color:
                color,

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
                  needsImprovement
                      ? 'Report Needs Improvement'
                      : 'Report Quality',

                  style:
                  TextStyle(
                    color:
                    color,

                    fontSize:
                    11,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              Text(
                result.reportQualityLabel,

                style:
                TextStyle(
                  color:
                  color,

                  fontSize:
                  10,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            8,
          ),

          _AiResultRow(
            label:
            'Title',

            value:
            result.titleMeaningful ==
                false
                ? 'Unclear ✕'
                : 'Clear ✓',
          ),

          _AiResultRow(
            label:
            'Description',

            value:
            result.descriptionMeaningful ==
                false
                ? 'Unclear ✕'
                : 'Clear ✓',
          ),

          if (
          result.reportIssue
              ?.trim()
              .isNotEmpty ==
              true
          ) ...[
            const SizedBox(
              height:
              4,
            ),

            Text(
              result.reportIssue!,

              style:
              const TextStyle(
                color:
                AppColors.textSecondary,

                fontSize:
                9,

                height:
                1.4,
              ),
            ),
          ],

          if (
          result
              .missingInformation
              .isNotEmpty
          ) ...[
            const SizedBox(
              height:
              8,
            ),

            ...result
                .missingInformation
                .map(
                  (
                  item,
                  ) =>
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom:
                      2,
                    ),

                    child:
                    Text(
                      '• $item',

                      style:
                      const TextStyle(
                        fontSize:
                        9,
                      ),
                    ),
                  ),
            ),
          ],

          if (
          result.suggestedTitle
              ?.trim()
              .isNotEmpty ==
              true
          ) ...[
            const SizedBox(
              height:
              8,
            ),

            const Text(
              'Suggested Title',

              style:
              TextStyle(
                color:
                AppColors.textSecondary,

                fontSize:
                9,

                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
              2,
            ),

            Text(
              result.suggestedTitle!,

              style:
              const TextStyle(
                fontSize:
                10,

                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],

          if (
          result.suggestedDescription
              ?.trim()
              .isNotEmpty ==
              true
          ) ...[
            const SizedBox(
              height:
              8,
            ),

            const Text(
              'Suggested Description',

              style:
              TextStyle(
                color:
                AppColors.textSecondary,

                fontSize:
                9,

                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
              2,
            ),

            Text(
              result.suggestedDescription!,

              style:
              const TextStyle(
                fontSize:
                10,

                height:
                1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // WARNING BOX
  // ============================================================

  Widget _warningBox({
    required String title,
    required String message,
  }) {
    return Container(
      width:
      double.infinity,

      margin:
      const EdgeInsets.only(
        top:
        8,
      ),

      padding:
      const EdgeInsets.all(
        10,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.amber
            .withOpacity(
          0.08,
        ),

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        border:
        Border.all(
          color:
          Colors.amber
              .withOpacity(
            0.35,
          ),
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style:
            const TextStyle(
              color:
              Colors.amber,

              fontSize:
              10,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            3,
          ),

          Text(
            message,

            style:
            const TextStyle(
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

  // ============================================================
  // SMART ASSIST MESSAGE
  // ============================================================

  String _smartAssistMessage() {
    if (loadingImage) {
      return 'Preparing evidence images...';
    }

    if (
    analyzingImagePath !=
        null
    ) {
      int imageNumber =
          evidenceImages.indexWhere(
                (
                file,
                ) =>
            file.path ==
                analyzingImagePath,
          ) +
              1;

      if (imageNumber <= 0) {
        imageNumber =
        1;
      }

      return 'Analyzing Image $imageNumber of '
          '${evidenceImages.length}...';
    }

    if (combiningAnalyses) {
      return 'Combining all evidence analyses into one '
          'final Smart Assist result...';
    }

    if (finalAiAnalysis != null) {
      return 'All evidence analyzed. Review the individual '
          'results and final combined assessment.';
    }

    if (imageAnalyses.isNotEmpty) {
      return '${imageAnalyses.length} image(s) analyzed. '
          'Preparing the final combined assessment.';
    }

    if (evidenceImages.isEmpty) {
      return 'Add evidence images. Each image will be analyzed '
          'individually and then combined.';
    }

    return 'Evidence ready for Smart Assist analysis.';
  }
}

// ================================================================
// AI RESULT ROW
// ================================================================

class _AiResultRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _AiResultRow({
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
            125,

            child:
            Text(
              label,

              style:
              const TextStyle(
                color:
                AppColors.textSecondary,

                fontSize:
                10,
              ),
            ),
          ),

          Expanded(
            child:
            Text(
              value,

              style:
              const TextStyle(
                fontSize:
                11,

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

// ================================================================
// EVIDENCE PROGRESS
// ================================================================

class _EvidenceProgress
    extends StatelessWidget {
  const _EvidenceProgress();

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
                AppColors.primary,
              ),

              Text(
                'Evidence',

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

        Expanded(
          child:
          Column(
            children: [
              Divider(
                thickness:
                4,
                color:
                AppColors.border,
              ),

              Text(
                'Location',

                style:
                TextStyle(
                  color:
                  AppColors.textSecondary,

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

class _VideoPreviewDialog
    extends StatefulWidget {
  final VideoPlayerController
  controller;

  const _VideoPreviewDialog({
    required this.controller,
  });

  @override
  State<_VideoPreviewDialog>
  createState() =>
      _VideoPreviewDialogState();
}

class _VideoPreviewDialogState
    extends State<_VideoPreviewDialog> {
  @override
  void initState() {
    super.initState();

    widget.controller.addListener(
      _refresh,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(
      _refresh,
    );

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final VideoPlayerValue value =
        widget.controller.value;

    return Dialog(
      backgroundColor:
      AppColors.surface,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),

      child:
      Padding(
        padding:
        const EdgeInsets.all(
          16,
        ),

        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            Row(
              children: [
                const Expanded(
                  child:
                  Text(
                    'Video Preview',

                    style:
                    TextStyle(
                      fontSize:
                      16,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },

                  icon:
                  const Icon(
                    Icons.close,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
              10,
            ),

            AspectRatio(
              aspectRatio:
              value.aspectRatio >
                  0
                  ? value.aspectRatio
                  : 16 / 9,

              child:
              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  12,
                ),

                child:
                VideoPlayer(
                  widget.controller,
                ),
              ),
            ),

            const SizedBox(
              height:
              12,
            ),

            VideoProgressIndicator(
              widget.controller,
              allowScrubbing:
              true,

              padding:
              const EdgeInsets.symmetric(
                vertical:
                6,
              ),
            ),

            const SizedBox(
              height:
              6,
            ),

            SizedBox(
              width:
              double.infinity,

              child:
              ElevatedButton.icon(
                onPressed: () async {
                  if (value.isPlaying) {
                    await widget
                        .controller
                        .pause();
                  } else {
                    await widget
                        .controller
                        .play();
                  }

                  if (mounted) {
                    setState(() {});
                  }
                },

                icon:
                Icon(
                  value.isPlaying
                      ? Icons.pause
                      : Icons
                      .play_arrow,
                ),

                label:
                Text(
                  value.isPlaying
                      ? 'Pause'
                      : 'Play',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}