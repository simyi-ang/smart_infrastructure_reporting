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
import '../../services/video_compression_service.dart';
import '../../models/report_video_ai_analysis.dart';
import '../../services/video_evidence_ai_service.dart';

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

  final VideoCompressionService videoCompressionService =
  const VideoCompressionService();

  final AiEvidenceService aiEvidenceService =
  AiEvidenceService();

  final VideoEvidenceAiService
  videoAiService =
      VideoEvidenceAiService.instance;

  bool analyzingVideo =
  false;

  String? videoAiError;

  ReportVideoAiAnalysis?
  videoAiAnalysis;

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

  int totalCompressedVideoBytes = 0;

  int compressedVideoCount = 0;

  String videoCompressionMessage =
      'Short videos are optimized before upload.';

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
          analyzingVideo ||
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
    // ============================================================
    // IMPORTANT:
    //
    // Opening Android camera/gallery temporarily changes the
    // Flutter lifecycle to inactive/paused.
    //
    // Do NOT save the evidence draft while an external picker is
    // active because the newly captured file has not yet been
    // added to evidenceImages/evidenceVideos.
    // ============================================================

    if (
    loadingImage ||
        loadingVideo) {
      return;
    }

    if (
    state ==
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

  Future<void> analyzeVideoEvidence(
      File videoFile,
      ) async {
    if (analyzingVideo) {
      return;
    }

    if (!await videoFile.exists()) {
      showMessage(
        'The selected video is no longer available.',
      );

      return;
    }

    setState(() {
      analyzingVideo =
      true;

      videoAiError =
      null;

      videoAiAnalysis =
      null;
    });

    try {
      final ReportVideoAiAnalysis
      result =
      await videoAiService
          .analyzeLocalVideo(
        videoFile:
        videoFile,

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
        videoAiAnalysis =
            result;

        analyzingVideo =
        false;
      });

      if (!result.issueDetected) {
        showMessage(
          'Video analysed. The reported issue was not clearly '
              'confirmed in the sampled frames. Please review the evidence.',
        );
      } else if (result.reportSufficient ==
          false) {
        showMessage(
          'Video analysed. Additional report information may be useful.',
        );
      } else {
        showMessage(
          'Video evidence analysed successfully.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        analyzingVideo =
        false;

        videoAiError =
            e
                .toString()
                .replaceFirst(
              'Exception: ',
              '',
            );
      });

      showMessage(
        videoAiError!,
      );
    }
  }

  // ============================================================
  // RESTORE DRAFT
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

      // ============================================================
      // NO EXISTING DRAFT
      // ============================================================

      if (draft == null) {
        setState(() {
          restoringDraft = false;
        });

        await _saveDraft(
          currentStep: 2,
        );

        return;
      }

      // ============================================================
      // RESTORE PHOTOS
      // ============================================================

      final List<File> restoredImages =
      <File>[];

      for (final String path
      in draft.evidenceImagePaths) {
        try {
          final File file = File(path);

          if (await file.exists()) {
            restoredImages.add(
              file,
            );
          }
        } catch (_) {
          // Ignore missing or inaccessible image.
        }
      }

      // ============================================================
      // RESTORE VIDEOS
      // ============================================================

      final List<File> restoredVideos =
      <File>[];

      for (final String path
      in draft.evidenceVideoPaths) {
        try {
          final File file = File(path);

          if (await file.exists()) {
            restoredVideos.add(
              file,
            );
          }
        } catch (_) {
          // Ignore missing or inaccessible video.
        }
      }

      // ============================================================
      // RESTORE TOTAL PHOTO SIZE
      // ============================================================

      int restoredImageBytes = 0;

      for (final File file
      in restoredImages) {
        try {
          restoredImageBytes +=
          await file.length();
        } catch (_) {
          // Ignore file-size failure.
        }
      }

      // ============================================================
      // RESTORE TOTAL VIDEO SIZE
      // ============================================================

      int restoredVideoBytes = 0;

      for (final File file
      in restoredVideos) {
        try {
          restoredVideoBytes +=
          await file.length();
        } catch (_) {
          // Ignore file-size failure.
        }
      }

      // ============================================================
      // RESTORE REPORT DETAILS
      // ============================================================

      if (draft.category
          .trim()
          .isNotEmpty) {
        selectedCategory =
            draft.category;
      }

      if (draft.priority
          .trim()
          .isNotEmpty) {
        selectedPriority =
            draft.priority;
      }

      if (draft.title
          .trim()
          .isNotEmpty) {
        selectedTitle =
            draft.title;
      }

      if (draft.description
          .trim()
          .isNotEmpty) {
        selectedDescription =
            draft.description;
      }

      if (!mounted) {
        return;
      }

      // ============================================================
      // RESTORE SCREEN STATE
      // ============================================================

      setState(() {
        // ----------------------------------------------------------
        // Images
        // ----------------------------------------------------------

        evidenceImages
          ..clear()
          ..addAll(
            restoredImages,
          );

        // ----------------------------------------------------------
        // Videos
        // ----------------------------------------------------------

        evidenceVideos
          ..clear()
          ..addAll(
            restoredVideos,
          );

        // ----------------------------------------------------------
        // Image size
        // ----------------------------------------------------------

        totalCompressedBytes =
            restoredImageBytes;

        // ----------------------------------------------------------
        // Video size
        // ----------------------------------------------------------

        totalCompressedVideoBytes =
            restoredVideoBytes;

        // ----------------------------------------------------------
        // Image compression message
        // ----------------------------------------------------------

        compressionMessage =
        restoredImages.isEmpty
            ? 'Evidence photos are optimized before upload.'
            : '${restoredImages.length} saved photo'
            '${restoredImages.length == 1 ? '' : 's'} '
            'restored from draft.';

        // ----------------------------------------------------------
        // Video compression message
        // ----------------------------------------------------------

        videoCompressionMessage =
        restoredVideos.isEmpty
            ? 'Short videos are optimized before upload.'
            : '${restoredVideos.length} saved video'
            '${restoredVideos.length == 1 ? '' : 's'} '
            'restored from draft.';

        // ----------------------------------------------------------
        // Reset video compression statistics.
        //
        // We know the saved videos are already prepared, but unless
        // compression metadata is stored separately in ReportDraft,
        // we should not guess how many were actually compressed.
        // ----------------------------------------------------------

        compressedVideoCount = 0;

        restoringDraft = false;
        draftSaveFailed = false;
      });

      // ============================================================
      // RESTORE VIDEO DURATIONS
      // ============================================================

      for (final File video
      in restoredVideos) {
        await _loadVideoDuration(
          video,
        );
      }

      if (!mounted) {
        return;
      }

      // ============================================================
      // SAVE CLEANED DRAFT AGAIN
      //
      // If any image/video file was missing, this rewrites the draft
      // using only files that still exist.
      // ============================================================

      final bool saved =
      await _saveDraft(
        currentStep: 2,
      );

      if (!saved &&
          mounted) {
        setState(() {
          draftSaveFailed = true;
        });
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
// BUILD CURRENT DRAFT
// ============================================================

  Future<ReportDraft> _buildCurrentDraft({
    required int currentStep,
  }) async {
    final String? userId =
        _userId;

    ReportDraft base =
    ReportDraft.empty();

    // ============================================================
    // LOAD EXISTING DRAFT FIRST
    //
    // This preserves fields owned by other steps such as:
    // location, GPS accuracy, voice context, etc.
    // ============================================================

    if (userId != null) {
      final ReportDraft? existing =
      await ReportDraftService.loadDraft(
        userId: userId,
      );

      if (existing != null) {
        base = existing;
      }
    }

    // ============================================================
    // BUILD UPDATED EVIDENCE DRAFT
    // ============================================================

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

    // ============================================================
    // QUEUE DRAFT SAVES
    //
    // Prevents multiple async saves from overwriting each other.
    // ============================================================

    _saveQueue =
        _saveQueue.then(
              (_) async {
            final String? userId =
                _userId;

            if (userId == null) {
              if (!completer.isCompleted) {
                completer.complete(
                  false,
                );
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
                  savingDraft = false;
                  draftSaveFailed = false;
                });
              }

              if (!completer.isCompleted) {
                completer.complete(
                  true,
                );
              }
            } catch (_) {
              if (mounted) {
                setState(() {
                  savingDraft = false;
                  draftSaveFailed = true;
                });
              }

              if (!completer.isCompleted) {
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
// SAVE EFFECTIVE AI VALUES
// ============================================================

  Future<void> _saveEffectiveReportValues() async {
    final bool saved =
    await _saveDraft(
      currentStep: 2,
    );

    if (!saved ||
        !mounted) {
      return;
    }
  }

// ============================================================
// VIDEO DURATION
// ============================================================

  Future<Duration?> _loadVideoDuration(
      File videoFile,
      ) async {
    VideoPlayerController? controller;

    try {
      // ==========================================================
      // VIDEO MUST STILL EXIST
      // ==========================================================

      if (!await videoFile.exists()) {
        videoDurations.remove(
          videoFile.path,
        );

        return null;
      }

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
      videoDurations.remove(
        videoFile.path,
      );

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
        duration.inSeconds % 60;

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

    if (evidenceVideos.isNotEmpty ||
        evidenceImages.isNotEmpty) {
      return 'Evidence saved in draft';
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
      return Icons.cloud_off_outlined;
    }

    return Icons.cloud_done_outlined;
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

    // ============================================================
    // 0. CHECK EVIDENCE LIMIT
    // ============================================================

    if (
    evidenceImages.length +
        evidenceVideos.length >=
        maxEvidenceItems) {
      showMessage(
        'You can add up to '
            '$maxEvidenceItems evidence items.',
      );

      return;
    }

    if (!await sourceFile.exists()) {
      showMessage(
        'The selected video is no longer available.',
      );

      return;
    }

    VideoPlayerController? controller;

    File? temporaryCompressedFile;

    File? persistentFile;

    String? persistentPath;

    bool addedToUi =
    false;

    try {
      // ==========================================================
      // 1. CHECK ORIGINAL VIDEO
      // ==========================================================

      controller =
          VideoPlayerController.file(
            sourceFile,
          );

      await controller.initialize();

      final Duration originalDuration =
          controller.value.duration;

      await controller.dispose();
      controller = null;

      if (
      originalDuration >
          maxVideoDuration) {
        showMessage(
          'Please choose a video that is '
              '30 seconds or shorter.',
        );

        return;
      }

      if (
      originalDuration <=
          Duration.zero) {
        showMessage(
          'The selected video could not be read.',
        );

        return;
      }

      if (mounted) {
        setState(() {
          videoCompressionMessage =
          'Optimizing video...';
        });
      }

      // ==========================================================
      // 2. COMPRESS VIDEO
      // ==========================================================

      final VideoCompressionResult result =
      await videoCompressionService
          .compressEvidenceVideo(
        sourceFile,
      );

      final File preparedVideo =
          result.file;

      if (result.compressed) {
        temporaryCompressedFile =
            preparedVideo;
      }

      if (!await preparedVideo.exists()) {
        throw Exception(
          'Prepared video could not be found.',
        );
      }

      // ==========================================================
      // 3. VERIFY PREPARED VIDEO
      // ==========================================================

      controller =
          VideoPlayerController.file(
            preparedVideo,
          );

      await controller.initialize();

      final Duration preparedDuration =
          controller.value.duration;

      await controller.dispose();
      controller = null;

      if (
      preparedDuration >
          maxVideoDuration) {
        throw Exception(
          'Prepared video exceeds the '
              '30-second evidence limit.',
        );
      }

      if (
      preparedDuration <=
          Duration.zero) {
        throw Exception(
          'Prepared video could not be verified.',
        );
      }

      // ==========================================================
      // 4. COPY INTO PERMANENT DRAFT STORAGE
      //
      // IMPORTANT:
      // Do NOT save preparedVideo.path into the draft.
      // The compression result may be a temporary/cache file.
      // ==========================================================

      persistentPath =
      await ReportDraftService
          .persistEvidenceVideo(
        userId: userId,
        sourceFile: preparedVideo,
      );

      persistentFile =
          File(
            persistentPath,
          );

      if (!await persistentFile.exists()) {
        throw Exception(
          'Unable to preserve the video '
              'in draft storage.',
        );
      }

      // ==========================================================
      // 5. VERIFY THE PERMANENT COPY
      //
      // We verify the actual file that will be restored later,
      // not only the temporary compression output.
      // ==========================================================

      controller =
          VideoPlayerController.file(
            persistentFile,
          );

      await controller.initialize();

      final Duration persistentDuration =
          controller.value.duration;

      await controller.dispose();
      controller = null;

      if (
      persistentDuration >
          maxVideoDuration ||
          persistentDuration <=
              Duration.zero) {
        throw Exception(
          'The saved draft video could not be verified.',
        );
      }

      final int persistentBytes =
      await persistentFile.length();

      if (persistentBytes <= 0) {
        throw Exception(
          'The saved draft video is empty.',
        );
      }

      // ==========================================================
      // 6. PREVENT DUPLICATE PATH
      // ==========================================================

      final bool alreadyAdded =
      evidenceVideos.any(
            (File video) =>
        video.path ==
            persistentFile!.path,
      );

      if (alreadyAdded) {
        throw Exception(
          'This video is already included '
              'in the report draft.',
        );
      }

      if (!mounted) {
        return;
      }

      // ==========================================================
      // 7. ADD PERMANENT FILE TO UI STATE
      //
      // _buildCurrentDraft() should read evidenceVideos and save
      // these permanent paths into evidenceVideoPaths.
      // ==========================================================

      setState(() {
        evidenceVideos.add(
          persistentFile!,
        );

        videoDurations[
        persistentFile!.path
        ] = persistentDuration;

        // Use the permanent file's actual size.
        totalCompressedVideoBytes +=
            persistentBytes;

        if (result.compressed) {
          compressedVideoCount++;

          videoCompressionMessage =
          'Video optimized: '
              '${videoCompressionService.formatBytes(result.originalBytes)} '
              '→ '
              '${videoCompressionService.formatBytes(persistentBytes)} '
              '(${result.savedPercentage.toStringAsFixed(0)}% smaller)';
        } else {
          videoCompressionMessage =
          'Video prepared and saved to draft.';
        }
      });

      addedToUi =
      true;

      // ==========================================================
      // 8. SAVE REPORT DRAFT
      //
      // IMPORTANT:
      // Check the result. Do not claim the video was saved if
      // SharedPreferences / draft serialization failed.
      // ==========================================================

      final bool draftSaved =
      await _saveDraft(
        currentStep: 2,
      );

      if (!draftSaved) {
        throw Exception(
          'The video was prepared, but the '
              'report draft could not be saved.',
        );
      }

      // ==========================================================
      // 9. VERIFY DRAFT ACTUALLY CONTAINS VIDEO PATH
      //
      // This catches the exact situation where the file exists
      // but evidenceVideoPaths was not written into the draft.
      // ==========================================================

      final ReportDraft? savedDraft =
      await ReportDraftService.loadDraft(
        userId: userId,
      );

      if (savedDraft == null) {
        throw Exception(
          'The saved report draft could not be reloaded.',
        );
      }

      final bool pathSaved =
      savedDraft.evidenceVideoPaths.any(
            (String path) =>
        path ==
            persistentPath,
      );

      if (!pathSaved) {
        throw Exception(
          'The video file was saved, but its '
              'draft reference was not preserved.',
        );
      }

      if (!mounted) {
        return;
      }

// ==========================================================
// 10. VIDEO AI ANALYSIS
//
// Run AI only AFTER:
// ✓ video compressed
// ✓ permanent file created
// ✓ file verified
// ✓ video added to screen
// ✓ draft saved
// ✓ saved draft verified
//
// This prevents AI results from being attached to a video
// that later fails draft persistence.
// ==========================================================

      setState(() {
        videoAiAnalysis =
        null;

        videoAiError =
        null;

        videoCompressionMessage =
        'Video saved. Smart Assist is reviewing sampled frames...';
      });

      await analyzeVideoEvidence(
        persistentFile,
      );

      if (!mounted) {
        return;
      }

      // ==========================================================
      // 11. SUCCESS
      // ==========================================================

      if (result.compressed) {
        showMessage(
          videoAiAnalysis != null
              ? 'Video optimized, saved and analysed successfully.'
              : 'Video optimized and saved. '
              'AI analysis was unavailable, but your evidence is preserved.',
        );
      } else {
        showMessage(
          videoAiAnalysis != null
              ? 'Video saved and analysed successfully.'
              : 'Video saved. AI analysis was unavailable, '
              'but your evidence is preserved.',
        );
      }

    } catch (e) {
      // ==========================================================
      // ROLLBACK UI STATE WHEN DRAFT SAVE FAILED
      // ==========================================================

      if (
      addedToUi &&
          persistentFile != null &&
          mounted) {
        final String failedPath =
            persistentFile.path;

        int removedBytes =
        0;

        try {
          if (await persistentFile.exists()) {
            removedBytes =
            await persistentFile.length();
          }
        } catch (_) {
          // Ignore size lookup failure.
        }

        setState(() {
          evidenceVideos.removeWhere(
                (File video) =>
            video.path ==
                failedPath,
          );

          videoDurations.remove(
            failedPath,
          );

          totalCompressedVideoBytes =
              (
                  totalCompressedVideoBytes -
                      removedBytes
              )
                  .clamp(
                0,
                1 << 62,
              )
                  .toInt();

          videoCompressionMessage =
          'Video could not be saved to draft.';
        });
      }

      showMessage(
        'Unable to prepare video: '
            '${_cleanException(e)}',
      );
    } finally {
      // ==========================================================
      // 11. CLEAN CONTROLLER
      // ==========================================================

      try {
        await controller?.dispose();
      } catch (_) {
        // Ignore cleanup errors.
      }

      // ==========================================================
      // 12. DELETE ONLY TEMPORARY COMPRESSED OUTPUT
      //
      // Never delete:
      // - sourceFile
      // - persistentFile
      // ==========================================================

      if (temporaryCompressedFile != null) {
        try {
          await videoCompressionService
              .deleteTemporaryCompressedFile(
            temporaryCompressedFile,
            originalFile: sourceFile,
          );
        } catch (_) {
          // Temporary cleanup failure must not invalidate
          // an otherwise successfully saved draft.
        }
      }
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
    // ============================================================
    // VALIDATE
    // ============================================================

    if (index < 0 ||
        index >= evidenceVideos.length ||
        isBusy) {
      return;
    }

    final String? userId = _userId;

    if (userId == null) {
      showMessage(
        'Your session is unavailable. '
            'Please sign in again.',
      );

      return;
    }

    final File file = evidenceVideos[index];

    final String path = file.path;

    // ============================================================
    // GET VIDEO SIZE BEFORE DELETING IT
    // ============================================================

    int videoBytes = 0;

    try {
      if (await file.exists()) {
        videoBytes = await file.length();
      }
    } catch (_) {
      videoBytes = 0;
    }

    // ============================================================
    // UPDATE SCREEN
    // ============================================================

    if (!mounted) {
      return;
    }

    setState(() {
      evidenceVideos.removeAt(
        index,
      );

      videoDurations.remove(
        path,
      );

      // Remove this video's size from the prepared total.
      totalCompressedVideoBytes =
          (totalCompressedVideoBytes - videoBytes)
              .clamp(
            0,
            1 << 62,
          )
              .toInt();

      // Keep the compression count sensible.
      if (compressedVideoCount > 0) {
        compressedVideoCount--;
      }

      // ==========================================================
      // UPDATE MESSAGE
      // ==========================================================

      if (evidenceVideos.isEmpty) {
        totalCompressedVideoBytes = 0;

        compressedVideoCount = 0;

        videoCompressionMessage =
        'Short videos are optimized before upload.';
      } else {
        videoCompressionMessage =
        '${evidenceVideos.length} video'
            '${evidenceVideos.length == 1 ? '' : 's'} '
            'prepared for upload.';
      }
    });

    // ============================================================
    // DELETE PERSISTENT DRAFT VIDEO
    // ============================================================

    try {
      await ReportDraftService.removeEvidenceVideo(
        userId: userId,
        videoPath: path,
      );
    } catch (e) {
      // The UI has already removed the item, but make the user
      // aware if local cleanup did not complete successfully.
      if (mounted) {
        showMessage(
          'Video removed, but local file cleanup '
              'could not be completed.',
        );
      }
    }

    // ============================================================
    // SAVE UPDATED DRAFT
    // ============================================================

    final bool saved = await _saveDraft(
      currentStep: 2,
    );

    if (!mounted) {
      return;
    }

    if (!saved) {
      showMessage(
        'Video was removed, but the draft could not '
            'be updated. Please try again.',
      );

      return;
    }

    showMessage(
      'Video removed from your draft.',
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
// SEMANTIC QUALITY GATE
//
// PURPOSE:
//
// The citizen must NOT reach Location when the available
// evidence intelligence indicates that:
//
// - title is semantically unclear
// - description is semantically unclear
// - category strongly conflicts with evidence
// - report is insufficient
// - combined AI recommends editing
// - video AI indicates a category mismatch / poor report
//
// IMPORTANT:
//
// AI NEVER silently changes citizen information.
//
// If a mandatory issue exists, citizen must explicitly:
// 1. Re-edit Report
// OR
// 2. Apply AI
//
// After correction, citizen presses Continue again.
// ============================================================

// ============================================================
// NORMALIZE CATEGORY
//
// Makes category comparison safe against:
// Road Damage
// road damage
// road_damage
// ROAD-DAMAGE
// ============================================================

  String _normalizeCategoryForComparison(
      String? value,
      ) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(
        r'[\s_-]+',
      ),
      '',
    );
  }

// ============================================================
// SAME CATEGORY?
// ============================================================

  bool _sameCategory(
      String? first,
      String? second,
      ) {
    final String a =
    _normalizeCategoryForComparison(
      first,
    );

    final String b =
    _normalizeCategoryForComparison(
      second,
    );

    if (a.isEmpty ||
        b.isEmpty) {
      return true;
    }

    return a == b;
  }

// ============================================================
// FINAL IMAGE / COMBINED AI CATEGORY MISMATCH
// ============================================================

  bool _hasFinalCategoryMismatch(
      ReportFinalAiAnalysis result,
      ) {
    if (result.issueDetected !=
        true) {
      return false;
    }

    final String aiCategory =
        result.category
            ?.trim() ??
            '';

    if (aiCategory.isEmpty) {
      return false;
    }

    return !_sameCategory(
      selectedCategory,
      aiCategory,
    );
  }

// ============================================================
// VIDEO CATEGORY MISMATCH
// ============================================================

  bool _hasVideoCategoryMismatch(
      ReportVideoAiAnalysis result,
      ) {
    // Prefer explicit AI consistency result.
    if (result.categoryMatchesUser ==
        false) {
      return true;
    }

    if (result.issueDetected !=
        true) {
      return false;
    }

    final String aiCategory =
        result.category
            ?.trim() ??
            '';

    if (aiCategory.isEmpty) {
      return false;
    }

    return !_sameCategory(
      selectedCategory,
      aiCategory,
    );
  }

// ============================================================
// DOES FINAL AI REQUIRE MANDATORY CORRECTION?
// ============================================================

  bool _finalAiRequiresCorrection(
      ReportFinalAiAnalysis result,
      ) {
    // Citizen already explicitly accepted the AI correction.
    //
    // Local validation still runs before this method, so applying
    // AI does not bypass basic quality rules.
    if (aiSuggestionsApplied) {
      return false;
    }

    if (result.titleMeaningful ==
        false) {
      return true;
    }

    if (result.descriptionMeaningful ==
        false) {
      return true;
    }

    if (result.reportSufficient ==
        false) {
      return true;
    }

    if (_hasFinalCategoryMismatch(
      result,
    )) {
      return true;
    }

    if (result.shouldSuggestReportEdit) {
      return true;
    }

    return false;
  }

// ============================================================
// DOES VIDEO AI REQUIRE MANDATORY CORRECTION?
// ============================================================

  bool _videoAiRequiresCorrection(
      ReportVideoAiAnalysis result,
      ) {
    if (aiSuggestionsApplied) {
      return false;
    }

    if (result.reportSufficient ==
        false) {
      return true;
    }

    if (_hasVideoCategoryMismatch(
      result,
    )) {
      return true;
    }

    return false;
  }

// ============================================================
// BUILD HUMAN-READABLE QUALITY PROBLEMS
// ============================================================

  List<String> _buildMandatoryQualityProblems() {
    final Set<String> problems =
    <String>{};

    final ReportFinalAiAnalysis?
    combined =
        finalAiAnalysis;

    // ----------------------------------------------------------
    // FINAL COMBINED IMAGE INTELLIGENCE
    // ----------------------------------------------------------

    if (combined != null &&
        !aiSuggestionsApplied) {
      if (combined.titleMeaningful ==
          false) {
        problems.add(
          'The report title does not clearly describe the '
              'infrastructure issue shown in the evidence.',
        );
      }

      if (combined.descriptionMeaningful ==
          false) {
        problems.add(
          'The report description is unclear or does not provide '
              'a meaningful explanation of the issue.',
        );
      }

      if (_hasFinalCategoryMismatch(
        combined,
      )) {
        final String aiCategory =
            combined.category
                ?.trim() ??
                '';

        if (aiCategory.isNotEmpty) {
          problems.add(
            'The selected category "$selectedCategory" does not '
                'match the evidence analysis. Smart Assist identifies '
                'the issue as "$aiCategory".',
          );
        } else {
          problems.add(
            'The selected report category does not appear to match '
                'the submitted evidence.',
          );
        }
      }

      if (combined.reportSufficient ==
          false) {
        problems.add(
          combined.reportIssue
              ?.trim()
              .isNotEmpty ==
              true
              ? combined.reportIssue!.trim()
              : 'The current report information is not sufficient '
              'for a responding worker to understand the issue.',
        );
      }

      if (combined.shouldSuggestReportEdit &&
          problems.isEmpty) {
        problems.add(
          combined.reportIssue
              ?.trim()
              .isNotEmpty ==
              true
              ? combined.reportIssue!.trim()
              : 'Smart Assist recommends reviewing the report '
              'information before continuing.',
        );
      }

      for (final String item
      in combined.missingInformation) {
        final String clean =
        item.trim();

        if (clean.isNotEmpty) {
          problems.add(
            'Missing or unclear: $clean',
          );
        }
      }
    }

    // ----------------------------------------------------------
    // VIDEO INTELLIGENCE
    // ----------------------------------------------------------

    final ReportVideoAiAnalysis?
    video =
        videoAiAnalysis;

    if (video != null &&
        !aiSuggestionsApplied) {
      if (_hasVideoCategoryMismatch(
        video,
      )) {
        final String aiCategory =
            video.category
                ?.trim() ??
                '';

        if (aiCategory.isNotEmpty) {
          problems.add(
            'Video evidence suggests "$aiCategory", which does not '
                'match the selected category "$selectedCategory".',
          );
        } else {
          problems.add(
            'Video evidence does not appear to match the selected '
                'report category.',
          );
        }
      }

      if (video.reportSufficient ==
          false) {
        problems.add(
          'The video evidence analysis indicates that the report '
              'details need improvement before continuing.',
        );
      }

      for (final String item
      in video.missingInformation) {
        final String clean =
        item.trim();

        if (clean.isNotEmpty) {
          problems.add(
            'Missing or unclear: $clean',
          );
        }
      }
    }

    return problems.toList();
  }

// ============================================================
// ENSURE CURRENT EVIDENCE HAS AI REVIEW
//
// This solves an important Draft Recovery case:
//
// User:
// Details
//   ↓
// Evidence analysed
//   ↓
// Re-edit
//   ↓
// Details
//   ↓
// Evidence restored
//
// The evidence files are restored from draft, but in-memory AI
// objects may no longer exist.
//
// Before Location, we therefore rebuild available AI analysis.
//
// AI network failure does NOT destroy evidence or the draft.
// Local validation remains available.
// ============================================================

  Future<void> _ensureCurrentAiReviewBeforeLocation() async {
    if (isBusy) {
      return;
    }

    // ----------------------------------------------------------
    // PHOTO / MULTI-IMAGE ANALYSIS
    // ----------------------------------------------------------

    if (evidenceImages.isNotEmpty &&
        finalAiAnalysis == null &&
        finalAnalysisError == null) {
      await analyzeImageBatch(
        List<File>.from(
          evidenceImages,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    // ----------------------------------------------------------
    // VIDEO ANALYSIS
    //
    // Existing architecture currently exposes one video-level
    // aggregate result. If it is absent after draft restoration,
    // analyse one available current video before navigation.
    // ----------------------------------------------------------

    if (evidenceVideos.isNotEmpty &&
        videoAiAnalysis == null &&
        videoAiError == null &&
        !analyzingVideo) {
      final File video =
          evidenceVideos.first;

      try {
        await analyzeVideoEvidence(
          video,
        );
      } catch (_) {
        // analyzeVideoEvidence already owns its UI error state.
        //
        // Do not destroy or remove evidence merely because an
        // external AI service is temporarily unavailable.
      }
    }
  }

// ============================================================
// DOES ANY AI RESULT REQUIRE CORRECTION?
// ============================================================

  bool _requiresMandatoryAiCorrection() {
    final ReportFinalAiAnalysis?
    combined =
        finalAiAnalysis;

    if (combined != null &&
        _finalAiRequiresCorrection(
          combined,
        )) {
      return true;
    }

    final ReportVideoAiAnalysis?
    video =
        videoAiAnalysis;

    if (video != null &&
        _videoAiRequiresCorrection(
          video,
        )) {
      return true;
    }

    return false;
  }

// ============================================================
// HAS USABLE AI CORRECTION?
// ============================================================

  bool _hasUsableAiCorrection() {
    final ReportFinalAiAnalysis?
    combined =
        finalAiAnalysis;

    if (combined != null &&
        combined.issueDetected ==
            true) {
      final bool hasCategory =
          combined.category
              ?.trim()
              .isNotEmpty ==
              true;

      final bool hasTitle =
          combined.suggestedTitle
              ?.trim()
              .isNotEmpty ==
              true;

      final bool hasDescription =
          (combined.suggestedDescription ??
              combined.description)
              ?.trim()
              .isNotEmpty ==
              true;

      final bool hasPriority =
          (combined.recommendedPriority ??
              combined.severity)
              ?.trim()
              .isNotEmpty ==
              true;

      if (combined.hasSuggestedReportText ||
          hasCategory ||
          hasTitle ||
          hasDescription ||
          hasPriority) {
        return true;
      }
    }

    final ReportVideoAiAnalysis?
    video =
        videoAiAnalysis;

    if (video != null &&
        video.issueDetected ==
            true) {
      final bool hasCategory =
          (video.category?.trim() ?? '').isNotEmpty;

      final bool hasTitle =
          video.suggestedTitle
              ?.trim()
              .isNotEmpty ==
              true;

      final bool hasDescription =
          video.suggestedDescription
              ?.trim()
              .isNotEmpty ==
              true;

      final bool hasPriority =
          video.recommendedPriority
              ?.trim()
              .isNotEmpty ==
              true;

      return hasCategory ||
          hasTitle ||
          hasDescription ||
          hasPriority;
    }

    return false;
  }

// ============================================================
// APPLY BEST AVAILABLE AI CORRECTION
//
// Priority:
// 1. Final combined image analysis
// 2. Video-level analysis
//
// This is ALWAYS explicit citizen action.
// ============================================================

  Future<void> _applyBestAvailableAiCorrection() async {
    final ReportFinalAiAnalysis?
    combined =
        finalAiAnalysis;

    if (combined != null &&
        combined.issueDetected ==
            true) {
      applyAiSuggestions();

      return;
    }

    final ReportVideoAiAnalysis?
    video =
        videoAiAnalysis;

    if (video == null ||
        video.issueDetected !=
            true) {
      showMessage(
        'Smart Assist does not currently have a usable correction. '
            'Please re-edit the report.',
      );

      return;
    }

    setState(() {
      // ----------------------------------------------------------
      // CATEGORY
      // ----------------------------------------------------------

      final String aiCategory =
          video.category?.trim() ?? '';

      if (aiCategory.isNotEmpty) {
        selectedCategory =
            aiCategory;
      }

      // ----------------------------------------------------------
      // PRIORITY
      // ----------------------------------------------------------

      final String? priority =
      video.recommendedPriority
          ?.trim();

      if (priority != null &&
          priority.isNotEmpty) {
        selectedPriority =
            priority;
      }

      // ----------------------------------------------------------
      // TITLE
      // ----------------------------------------------------------

      final String? title =
      video.suggestedTitle
          ?.trim();

      if (title != null &&
          title.isNotEmpty) {
        selectedTitle =
            title;
      }

      // ----------------------------------------------------------
      // DESCRIPTION
      // ----------------------------------------------------------

      final String? description =
      video.suggestedDescription
          ?.trim();

      if (description != null &&
          description.isNotEmpty) {
        selectedDescription =
            description;
      }

      aiSuggestionsApplied =
      true;
    });

    await _saveEffectiveReportValues();

    if (!mounted) {
      return;
    }

    showMessage(
      'Smart Assist corrections applied. '
          'Please review the updated report and tap Continue again.',
    );
  }

// ============================================================
// MANDATORY SEMANTIC CORRECTION DIALOG
//
// barrierDismissible = false
//
// A detected semantic problem cannot be bypassed using the
// outside area / Android back gesture.
//
// Citizen must:
// - re-edit
// OR
// - explicitly apply AI when a usable suggestion exists.
// ============================================================

  Future<void> showMandatoryAiCorrectionDialog() async {
    if (!mounted) {
      return;
    }

    final List<String> problems =
    _buildMandatoryQualityProblems();

    final bool canApplyAi =
    _hasUsableAiCorrection();

    final String? action =
    await showDialog<String>(
      context: context,

      barrierDismissible:
      false,

      builder: (
          BuildContext dialogContext,
          ) {
        return PopScope(
          canPop: false,

          child: AlertDialog(
            title:
            const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons
                      .report_problem_outlined,

                  color:
                  Colors.orange,
                ),

                SizedBox(
                  width:
                  10,
                ),

                Expanded(
                  child: Text(
                    'Report Must Be Corrected',
                  ),
                ),
              ],
            ),

            content:
            SingleChildScrollView(
              child: Column(
                mainAxisSize:
                MainAxisSize.min,

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Smart Assist found a significant mismatch or '
                        'meaningfulness problem in the report details.',
                  ),

                  const SizedBox(
                    height:
                    10,
                  ),

                  const Text(
                    'You cannot continue to Report Location until '
                        'the report information is corrected.',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  if (problems.isNotEmpty) ...[
                    const SizedBox(
                      height:
                      14,
                    ),

                    const Text(
                      'Why correction is required:',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      7,
                    ),

                    ...problems.map(
                          (
                          String problem,
                          ) {
                        return Padding(
                          padding:
                          const EdgeInsets.only(
                            bottom:
                            6,
                          ),

                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [
                              const Padding(
                                padding:
                                EdgeInsets.only(
                                  top:
                                  2,
                                ),

                                child: Icon(
                                  Icons.close_rounded,

                                  color:
                                  Colors.orange,

                                  size:
                                  15,
                                ),
                              ),

                              const SizedBox(
                                width:
                                6,
                              ),

                              Expanded(
                                child: Text(
                                  problem,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

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
                      AppColors.primary
                          .withOpacity(
                        0.06,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors.primary
                            .withOpacity(
                          0.20,
                        ),
                      ),
                    ),

                    child:
                    const Text(
                      'Smart Assist is advisory and will never silently '
                          'overwrite your report. Choose Re-edit to write your '
                          'own correction, or Apply AI to explicitly accept the '
                          'suggested correction.',
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

            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    'edit',
                  );
                },

                icon:
                const Icon(
                  Icons.edit_outlined,
                ),

                label:
                const Text(
                  'Re-edit Report',
                ),
              ),

              if (canApplyAi)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      'apply_ai',
                    );
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
          ),
        );
      },
    );

    if (!mounted ||
        action == null) {
      return;
    }

    if (action ==
        'edit') {
      await editReport();

      return;
    }

    if (action ==
        'apply_ai') {
      await _applyBestAvailableAiCorrection();
    }
  }

// ============================================================
// CONTINUE TO LOCATION — FINAL VERSION
// ============================================================

  Future<void> continueToLocation() async {
    // ==========================================================
    // 1. EVIDENCE REQUIRED
    // ==========================================================

    if (!hasEvidence) {
      showMessage(
        'Please add at least one photo or video.',
      );

      return;
    }

    // ==========================================================
    // 2. CURRENT OPERATION MUST FINISH
    // ==========================================================

    if (isBusy) {
      showMessage(
        'Please wait for the current operation to finish.',
      );

      return;
    }

    // ==========================================================
    // 3. LOCAL QUALITY VALIDATION
    //
    // Fast/offline layer.
    // ==========================================================

    final String? localProblem =
    validateReportLocally(
      title:
      selectedTitle,

      description:
      selectedDescription,
    );

    if (localProblem !=
        null) {
      await showInvalidReportDialog(
        localProblem,
      );

      return;
    }

    // ==========================================================
    // 4. RESTORED DRAFT AI REFRESH
    //
    // If evidence was restored but its in-memory AI result was
    // lost, rebuild available analysis before deciding whether
    // Location may be opened.
    // ==========================================================

    await _ensureCurrentAiReviewBeforeLocation();

    if (!mounted) {
      return;
    }

    // ==========================================================
    // 5. MANDATORY SEMANTIC AI GATE
    //
    // BLOCK when AI has established:
    //
    // ✕ meaningless title
    // ✕ meaningless description
    // ✕ category mismatch
    // ✕ insufficient report
    // ✕ strong edit recommendation
    // ✕ video/report mismatch
    //
    // Citizen MUST explicitly Re-edit or Apply AI.
    // ==========================================================

    if (_requiresMandatoryAiCorrection()) {
      await showMandatoryAiCorrectionDialog();

      return;
    }

    // ==========================================================
    // 6. FINAL LOCAL CHECK AGAIN
    //
    // This matters because an AI suggestion may have been applied
    // during an earlier interaction.
    // ==========================================================

    final String? finalLocalProblem =
    validateReportLocally(
      title:
      selectedTitle,

      description:
      selectedDescription,
    );

    if (finalLocalProblem !=
        null) {
      await showInvalidReportDialog(
        finalLocalProblem,
      );

      return;
    }

    // ==========================================================
    // 7. START NAVIGATION
    // ==========================================================

    if (!mounted) {
      return;
    }

    setState(() {
      isNavigating =
      true;
    });

    // ==========================================================
    // 8. SAVE CURRENT EFFECTIVE VALUES
    // ==========================================================

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

    // ==========================================================
    // 9. LEGACY IMAGE ANALYSIS COMPATIBILITY
    // ==========================================================

    ReportImageAiAnalysis?
    legacyAnalysis;

    if (imageAnalyses.isNotEmpty) {
      legacyAnalysis =
          imageAnalyses.values.first;
    }

    bool submitted =
    false;

    try {
      if (!mounted) {
        return;
      }

      // ========================================================
      // 10. OPEN LOCATION
      //
      // Only reached after the semantic quality gate passes.
      // ========================================================

      final bool? navigationResult =
      await Navigator.push<bool>(
        context,

        MaterialPageRoute<bool>(
          builder: (
              BuildContext context,
              ) {
            return CreateReportLocationScreen(
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

              evidenceVideos:
              List<File>.from(
                evidenceVideos,
              ),

              imageAnalyses:
              Map<
                  String,
                  ReportImageAiAnalysis>.from(
                imageAnalyses,
              ),

              finalAiAnalysis:
              finalAiAnalysis,

              aiAnalysis:
              legacyAnalysis,
            );
          },
        ),
      );

      submitted =
          navigationResult ==
              true;

      // ========================================================
      // 11. SUCCESSFUL SUBMISSION
      // ========================================================

      if (submitted) {
        if (!mounted) {
          return;
        }

        Navigator.pop(
          context,
          true,
        );

        return;
      }
    } finally {
      // ========================================================
      // 12. NORMAL RETURN FROM LOCATION
      //
      // Preserve existing Smart Draft Recovery behaviour.
      // ========================================================

      if (!submitted &&
          mounted) {
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
//
// Existing design preserved.
// ============================================================

  Future<void> showInvalidReportDialog(
      String reason,
      ) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,

      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,

                color:
                Colors.orange,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child: Text(
                  'Report Needs Improvement',
                ),
              ),
            ],
          ),

          content: Text(
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
//
// KEPT for compatibility with the rest of your existing UI.
//
// The new mandatory quality gate is stricter, but this method is
// deliberately retained so no existing caller/design is broken.
// ============================================================

  Future<void> showPoorReportDialog() async {
    final ReportFinalAiAnalysis?
    result =
        finalAiAnalysis;

    if (!mounted ||
        result ==
            null) {
      return;
    }

    await showDialog<void>(
      context: context,

      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,

                color:
                Colors.orange,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child: Text(
                  'Report Information Is Unclear',
                ),
              ),
            ],
          ),

          content:
          SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  result.reportIssue ??
                      'Smart Assist found that the report does not '
                          'contain enough meaningful information.',
                ),

                if (result.titleMeaningful ==
                    false) ...[
                  const SizedBox(
                    height:
                    10,
                  ),

                  const Text(
                    '• The report title is unclear or not meaningful.',
                  ),
                ],

                if (result.descriptionMeaningful ==
                    false) ...[
                  const SizedBox(
                    height:
                    6,
                  ),

                  const Text(
                    '• The report description is unclear or not meaningful.',
                  ),
                ],

                if (_hasFinalCategoryMismatch(
                  result,
                )) ...[
                  const SizedBox(
                    height:
                    6,
                  ),

                  Text(
                    '• Selected category "$selectedCategory" does not '
                        'match Smart Assist category '
                        '"${result.category ?? 'Unknown'}".',
                  ),
                ],

                if (result
                    .missingInformation
                    .isNotEmpty) ...[
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
                        String item,
                        ) {
                      return Padding(
                        padding:
                        const EdgeInsets.only(
                          bottom:
                          3,
                        ),

                        child: Text(
                          '• $item',
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          actions: [
            TextButton.icon(
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
                'Re-edit Report',
              ),
            ),

            if (_hasUsableAiCorrection())
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await _applyBestAvailableAiCorrection();
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

                                  if (evidenceVideos.isNotEmpty) ...[
                                    const SizedBox(
                                      height: 6,
                                    ),
                                    Text(
                                      videoCompressionMessage,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],

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
                        const SizedBox(
                          height: 12,
                        ),

                        if (analyzingVideo)
                          const _VideoAiLoadingCard(),

                        if (videoAiError != null)
                          _VideoAiErrorCard(
                            message:
                            videoAiError!,

                            onRetry:
                            evidenceVideos.isEmpty ||
                                isBusy
                                ? null
                                : () async {
                              await analyzeVideoEvidence(
                                evidenceVideos.last,
                              );
                            },
                          ),

                        if (videoAiAnalysis != null)
                          _VideoAiResultCard(
                            result:
                            videoAiAnalysis!,

                            onAnalyzeAgain:
                            isBusy ||
                                evidenceVideos.isEmpty
                                ? null
                                : () async {
                              await analyzeVideoEvidence(
                                evidenceVideos.last,
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

class _VideoAiLoadingCard
    extends StatelessWidget {
  const _VideoAiLoadingCard();

  @override
  Widget build(
      BuildContext context,
      ) {
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
        AppColors.primary
            .withValues(
          alpha: 0.06,
        ),

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        border:
        Border.all(
          color:
          AppColors.primary
              .withValues(
            alpha: 0.30,
          ),
        ),
      ),

      child:
      const Row(
        children: [
          SizedBox(
            width:
            22,

            height:
            22,

            child:
            CircularProgressIndicator(
              strokeWidth:
              2.2,
            ),
          ),

          SizedBox(
            width:
            12,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                Text(
                  'Video Smart Assist',
                  style:
                  TextStyle(
                    color:
                    Colors.white,

                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                SizedBox(
                  height:
                  4,
                ),

                Text(
                  'Reviewing representative frames across the video...',
                  style:
                  TextStyle(
                    color:
                    AppColors
                        .textSecondary,

                    fontSize:
                    10,
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

class _VideoAiErrorCard
    extends StatelessWidget {
  final String message;

  final Future<void> Function()?
  onRetry;

  const _VideoAiErrorCard({
    required this.message,
    required this.onRetry,
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
        14,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.orange
            .withValues(
          alpha:
          0.06,
        ),

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        border:
        Border.all(
          color:
          Colors.orangeAccent
              .withValues(
            alpha:
            0.35,
          ),
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,

        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .warning_amber_rounded,

                color:
                Colors.orangeAccent,

                size:
                19,
              ),

              SizedBox(
                width:
                8,
              ),

              Text(
                'Video AI Unavailable',
                style:
                TextStyle(
                  color:
                  Colors.white,

                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            8,
          ),

          Text(
            message,

            style:
            const TextStyle(
              color:
              AppColors
                  .textSecondary,

              fontSize:
              10,

              height:
              1.4,
            ),
          ),

          if (onRetry !=
              null) ...[
            const SizedBox(
              height:
              10,
            ),

            OutlinedButton.icon(
              onPressed:
                  () async {
                await onRetry!();
              },

              icon:
              const Icon(
                Icons
                    .refresh_rounded,
              ),

              label:
              const Text(
                'Analyse Again',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoAiLine
    extends StatelessWidget {
  final String label;
  final String value;

  const _VideoAiLine({
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
            112,

            child:
            Text(
              label,

              style:
              const TextStyle(
                color:
                AppColors
                    .textSecondary,

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

                fontWeight:
                FontWeight.w600,

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

// ================================================================
// VIDEO AI RESULT CARD
// ================================================================

class _VideoAiResultCard
    extends StatelessWidget {

  final ReportVideoAiAnalysis result;

  final Future<void> Function()?
  onAnalyzeAgain;

  const _VideoAiResultCard({
    required this.result,
    required this.onAnalyzeAgain,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(16),

      decoration:
      BoxDecoration(
        color:
        AppColors.primary.withValues(
          alpha: 0.055,
        ),

        borderRadius:
        BorderRadius.circular(15),

        border:
        Border.all(
          color:
          AppColors.primary.withValues(
            alpha: 0.32,
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
              Container(
                width: 38,
                height: 38,

                decoration:
                BoxDecoration(
                  color:
                  AppColors.primary
                      .withValues(
                    alpha: 0.12,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child:
                const Icon(
                  Icons.movie_filter_outlined,
                  color:
                  AppColors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Video Evidence Intelligence',
                      style: TextStyle(
                        color:
                        Colors.white,
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    SizedBox(
                      height: 2,
                    ),

                    Text(
                      'AI-reviewed sampled video frames',
                      style: TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                result.issueDetected
                    ? Icons.verified_outlined
                    : Icons.help_outline_rounded,

                color:
                result.issueDetected
                    ? AppColors.success
                    : Colors.orangeAccent,
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          _VideoAiLine(
            label:
            'Issue detected',
            value:
            result.issueDetected
                ? 'Yes'
                : 'Not confirmed',
          ),

          _VideoAiLine(
            label:
            'Category',
            value:
            result.category ??
                'Not available',
          ),

          _VideoAiLine(
            label:
            'Severity',
            value:
            result.severity ??
                'Not available',
          ),

          _VideoAiLine(
            label:
            'Confidence',
            value:
            result.confidence ??
                'Not available',
          ),

          _VideoAiLine(
            label:
            'Evidence quality',
            value:
            result.evidenceQuality ??
                'Not available',
          ),

          _VideoAiLine(
            label:
            'Across frames',
            value:
            result.temporalConsistency ??
                'Not assessable',
          ),

          _VideoAiLine(
            label:
            'Useful frames',
            value:
            '${result.usefulFrameCount} / '
                '${result.analyzedFrameCount}',
          ),

          _VideoAiLine(
            label:
            'Category match',

            value:
            result.categoryMatchesUser ==
                true
                ? 'Matches report'
                : result.categoryMatchesUser ==
                false
                ? 'Possible mismatch'
                : 'Not available',
          ),

          if ((result.reportQuality ?? '')
              .trim()
              .isNotEmpty)
            _VideoAiLine(
              label:
              'Report quality',
              value:
              result.reportQuality!,
            ),

          if ((result.safetyConcern ?? '')
              .trim()
              .isNotEmpty)
            _VideoAiLine(
              label:
              'Safety concern',
              value:
              result.safetyConcern!,
            ),

          if (result
              .missingInformation
              .isNotEmpty)
            _VideoAiLine(
              label:
              'Missing info',

              value:
              result
                  .missingInformation
                  .join(' • '),
            ),

          if ((result.summary ?? '')
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 10,
            ),

            Container(
              width:
              double.infinity,

              padding:
              const EdgeInsets.all(11),

              decoration:
              BoxDecoration(
                color:
                AppColors.surface,

                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),

              child:
              Text(
                result.summary!,

                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize: 10,
                  height: 1.45,
                ),
              ),
            ),
          ],

          const SizedBox(
            height: 12,
          ),

          const Text(
            'AI reviewed representative frames sampled across the video. '
                'It did not continuously inspect every frame or independently '
                'verify GPS location.',
            style: TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 9,
              height: 1.4,
            ),
          ),

          if (onAnalyzeAgain != null) ...[
            const SizedBox(
              height: 12,
            ),

            SizedBox(
              width:
              double.infinity,

              child:
              OutlinedButton.icon(
                onPressed:
                    () async {
                  await onAnalyzeAgain!();
                },

                icon:
                const Icon(
                  Icons.refresh_rounded,
                ),

                label:
                const Text(
                  'Analyse Video Again',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

