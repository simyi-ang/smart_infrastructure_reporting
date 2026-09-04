import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter/material.dart';

import '../../models/report_final_ai_analysis.dart';
import '../../models/report_image_ai_analysis.dart';
import '../../models/report_draft.dart';

import '../../services/connectivity_service.dart';
import '../../services/report_service.dart';
import '../../services/report_draft_service.dart';
import '../../theme/app_colors.dart';

// ================================================================
// REPORT PREVIEW SCREEN
//
// MULTI-IMAGE SMART ASSIST PREVIEW
//
// Existing report submission design and functionality preserved.
//
// Supports:
//
// Image 1
//      ↓
// Individual AI Analysis 1
//
// Image 2
//      ↓
// Individual AI Analysis 2
//
// Image 3
//      ↓
// Individual AI Analysis 3
//
// All individual analyses
//      ↓
// Final Combined Smart Assist Analysis
//
// Individual analyses can be expanded / collapsed.
//
// ================================================================

class ReportPreviewScreen
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
  // LOCATION
  // ============================================================

  final String address;

  final String landmark;

  final double? latitude;

  final double? longitude;

  final double? locationAccuracy;

  final String? detectedAddress;

  final String? locationVerificationStatus;

  // ============================================================
  // INDIVIDUAL IMAGE AI RESULTS
  //
  // Key:
  // local image path
  //
  // Value:
  // AI analysis belonging to that exact image.
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
  // LEGACY SINGLE AI RESULT
  //
  // Kept temporarily so older reporting paths still work.
  // ============================================================

  final ReportImageAiAnalysis?
  aiAnalysis;

  const ReportPreviewScreen({
    super.key,

    required this.category,

    required this.priority,

    required this.title,

    required this.description,

    required this.evidenceImages,

    this.evidenceVideos = const <File>[],

    required this.address,

    required this.landmark,

    this.latitude,

    this.longitude,

    this.locationAccuracy,

    this.detectedAddress,

    this.locationVerificationStatus,

    this.imageAnalyses =
    const {},

    this.finalAiAnalysis,

    this.aiAnalysis,
  });

  @override
  State<ReportPreviewScreen>
  createState() =>
      _ReportPreviewScreenState();
}

// ================================================================
// STATE
// ================================================================

class _ReportPreviewScreenState
    extends State<ReportPreviewScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final ReportService reportService =
  ReportService();

  final ConnectivityService
  connectivityService =
  const ConnectivityService();

  // ============================================================
  // SUBMISSION STATE
  // ============================================================

  bool submitting =
  false;

  double uploadProgress =
  0;

  String uploadMessage =
      '';

  String? submissionError;

  bool savingPreviewDraft =
  false;

  bool previewDraftSaveFailed =
  false;

  bool _allowPop =
  false;

  String? get _userId =>
      Supabase.instance.client.auth.currentUser?.id;

  // ============================================================
  // INIT — SAVE EXACT PREVIEW STEP
  // ============================================================

  @override
  void initState() {
    super.initState();

    unawaited(
      _savePreviewDraft(),
    );
  }

  // ============================================================
  // SAVE PREVIEW DRAFT
  // ============================================================

  Future<bool> _savePreviewDraft() async {
    final String? userId = _userId;

    if (userId == null) {
      return false;
    }

    if (mounted) {
      setState(() {
        savingPreviewDraft = true;
        previewDraftSaveFailed = false;
      });
    }

    try {
      final ReportDraft? existing =
      await ReportDraftService.loadDraft(
        userId: userId,
      );

      final ReportDraft base =
          existing ??
              ReportDraft.empty();

      final ReportDraft updated =
      base.copyWith(
        category: widget.category,
        priority: widget.priority,
        title: widget.title,
        description: widget.description,

        landmark:
        widget.landmark.trim().isEmpty
            ? null
            : widget.landmark.trim(),

        manualAddress:
        widget.address.trim().isEmpty
            ? null
            : widget.address.trim(),

        latitude: widget.latitude,
        longitude: widget.longitude,

        locationAccuracy:
        widget.locationAccuracy,

        detectedAddress:
        widget.detectedAddress,

        locationVerificationStatus:
        widget.locationVerificationStatus,

        currentStep: 4,

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

      await ReportDraftService.saveDraft(
        userId: userId,
        draft: updated,
      );

      if (mounted) {
        setState(() {
          savingPreviewDraft = false;
          previewDraftSaveFailed = false;
        });
      }

      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          savingPreviewDraft = false;
          previewDraftSaveFailed = true;
        });
      }

      return false;
    }
  }

  // ============================================================
  // SAFE BACK
  // ============================================================

  Future<void> _goBackSafely() async {
    if (submitting || savingPreviewDraft) {
      return;
    }

    final bool saved =
    await _savePreviewDraft();

    if (!saved || !mounted) {
      ScaffoldMessenger.of(
        context,
      ).hideCurrentSnackBar();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
          Text(
            'Your preview draft could not be saved. '
                'Please try again.',
          ),
        ),
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
  // VIDEO PREVIEW
  // ============================================================

  Future<void> _previewVideo(
      File videoFile,
      ) async {
    if (!await videoFile.exists()) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
          Text(
            'This saved draft video is no longer available.',
          ),
        ),
      );

      return;
    }

    final VideoPlayerController controller =
    VideoPlayerController.file(
      videoFile,
    );

    try {
      await controller.initialize();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder:
            (
            dialogContext,
            ) {
          return AlertDialog(
            backgroundColor:
            AppColors.surface,

            contentPadding:
            const EdgeInsets.all(
              12,
            ),

            content:
            AspectRatio(
              aspectRatio:
              controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,

              child:
              VideoPlayer(
                controller,
              ),
            ),

            actions: [
              TextButton.icon(
                onPressed:
                    () {
                  if (
                  controller.value.isPlaying
                  ) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },

                icon:
                const Icon(
                  Icons.play_arrow_rounded,
                ),

                label:
                const Text(
                  'Play / Pause',
                ),
              ),

              TextButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                  );
                },

                child:
                const Text(
                  'Close',
                ),
              ),
            ],
          );
        },
      );
    } finally {
      await controller.dispose();
    }
  }

  // ============================================================
  // EXPANDED IMAGE ANALYSES
  // ============================================================

  final Set<String>
  expandedImageAnalyses =
  <String>{};

  // ============================================================
  // TOGGLE IMAGE ANALYSIS
  // ============================================================

  void toggleImageAnalysis(
      String imagePath,
      ) {
    setState(() {
      if (
      expandedImageAnalyses
          .contains(
        imagePath,
      )
      ) {
        expandedImageAnalyses
            .remove(
          imagePath,
        );
      } else {
        expandedImageAnalyses.add(
          imagePath,
        );
      }
    });
  }

  // ============================================================
  // GET ANALYSIS FOR IMAGE
  //
  // New:
  // use image path → AI result.
  //
  // Legacy:
  // if only old aiAnalysis exists, attach it to first image.
  // ============================================================

  ReportImageAiAnalysis?
  analysisForImage(
      File image,
      int index,
      ) {
    final ReportImageAiAnalysis?
    mapped =
    widget.imageAnalyses[
    image.path];

    if (mapped != null) {
      return mapped;
    }

    if (
    widget.imageAnalyses.isEmpty &&
        widget.aiAnalysis != null &&
        index == 0
    ) {
      return widget.aiAnalysis;
    }

    return null;
  }

  // ============================================================
  // SUBMIT REPORT
  //
  // IMPORTANT:
  //
  // Existing ReportService signature is preserved temporarily.
  //
  // Next step:
  // ReportService will be upgraded to also receive:
  //
  // imageAnalyses
  // finalAiAnalysis
  //
  // and persist them after report_images rows are generated.
  // ============================================================

  Future<void> submitReport() async {
    if (submitting) {
      return;
    }

    // ==========================================================
    // SAVE LATEST PREVIEW DRAFT BEFORE SUBMISSION
    // ==========================================================

    final bool draftSaved =
    await _savePreviewDraft();

    if (!draftSaved || !mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Your report draft could not be saved. '
                'Please try again before submitting.',
          ),
        ),
      );

      return;
    }

    // ==========================================================
    // START SUBMISSION
    // ==========================================================

    setState(() {
      submitting = true;
      uploadProgress = 0.02;
      uploadMessage =
      'Checking internet connection...';
      submissionError = null;
    });

    try {
      // ========================================================
      // INTERNET CHECK
      // ========================================================

      await connectivityService
          .requireInternetConnection();

      if (!mounted) {
        return;
      }

      setState(() {
        uploadProgress = 0.05;
        uploadMessage =
        'Preparing submission...';
      });

      // ========================================================
      // SUBMIT REPORT
      //
      // ReportService now supports:
      // - photo only
      // - video only
      // - photo + video
      // ========================================================

      final result =
      await reportService.submitReport(
        title:
        widget.title,

        category:
        widget.category,

        priority:
        widget.priority,

        description:
        widget.description,

        address:
        widget.address,

        landmark:
        widget.landmark,

        latitude:
        widget.latitude,

        longitude:
        widget.longitude,

        evidenceImages:
        widget.evidenceImages,

        evidenceVideos:
        widget.evidenceVideos,

        imageAnalyses:
        widget.imageAnalyses,

        finalAiAnalysis:
        widget.finalAiAnalysis,

        onProgress:
            (
            ReportUploadProgress progress,
            ) {
          if (!mounted) {
            return;
          }

          setState(() {
            uploadProgress =
                progress.progress.clamp(
                  0.0,
                  1.0,
                );

            uploadMessage =
                progress.message;
          });
        },
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // REMOTE SUBMISSION SUCCEEDED
      //
      // ONLY NOW CLEAR LOCAL DRAFT
      // ========================================================

      final String? userId =
          _userId;

      if (userId != null) {
        try {
          await ReportDraftService.clearDraft(
            userId:
            userId,
          );
        } catch (_) {
          // Remote submission succeeded.
          // Local cleanup failure must not change that success.
        }
      }

      // ========================================================
      // SUCCESS DIALOG
      // ========================================================

      await showDialog<void>(
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
                  Icons.check_circle_outline,
                  color:
                  AppColors.success,
                ),

                SizedBox(
                  width:
                  10,
                ),

                Text(
                  'Report Submitted',
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
                  'Your infrastructure report was submitted successfully.',
                ),

                const SizedBox(
                  height:
                  18,
                ),

                const Text(
                  'REFERENCE NUMBER',
                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize:
                    10,
                  ),
                ),

                const SizedBox(
                  height:
                  5,
                ),

                SelectableText(
                  result.referenceNumber,
                  style:
                  const TextStyle(
                    color:
                    AppColors.primary,
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                if (widget.latitude != null &&
                    widget.longitude != null) ...[
                  const SizedBox(
                    height:
                    16,
                  ),

                  const Text(
                    'GPS LOCATION',
                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize:
                      10,
                    ),
                  ),

                  const SizedBox(
                    height:
                    4,
                  ),

                  Text(
                    '${widget.latitude!.toStringAsFixed(6)}, '
                        '${widget.longitude!.toStringAsFixed(6)}',
                    style:
                    const TextStyle(
                      color:
                      AppColors.success,
                      fontSize:
                      10,
                    ),
                  ),
                ],
              ],
            ),

            actions: [
              ElevatedButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                  );
                },

                child:
                const Text(
                  'Done',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).popUntil(
            (
            route,
            ) =>
        route.isFirst,
      );
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

      // ========================================================
      // FAILURE — KEEP THE DRAFT
      // ========================================================

      setState(() {
        submissionError =
            message;

        uploadMessage =
        'Submission failed. Your report data is still here.';

        uploadProgress =
        0;
      });

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
    } finally {
      if (mounted) {
        setState(() {
          submitting =
          false;
        });
      }
    }
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
                          IconButton(
                            onPressed:
                            submitting ||
                                savingPreviewDraft
                                ? null
                                : _goBackSafely,

                            icon:
                            const Icon(
                              Icons.arrow_back,
                            ),
                          ),

                          const SizedBox(
                            width:
                            8,
                          ),

                          const Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [
                              Text(
                                'Preview Report',

                                style:
                                TextStyle(
                                  fontSize:
                                  22,

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),

                              Text(
                                'Review before submitting',

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
                        20,
                      ),

                      // =================================================
                      // DRAFT STATUS
                      // =================================================

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
                          (
                              previewDraftSaveFailed
                                  ? AppColors.warning
                                  : AppColors.success
                          ).withOpacity(
                            0.07,
                          ),

                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),

                          border:
                          Border.all(
                            color:
                            (
                                previewDraftSaveFailed
                                    ? AppColors.warning
                                    : AppColors.success
                            ).withOpacity(
                              0.45,
                            ),
                          ),
                        ),

                        child:
                        Row(
                          children: [
                            Icon(
                              savingPreviewDraft
                                  ? Icons.sync_rounded
                                  : previewDraftSaveFailed
                                  ? Icons.cloud_off_outlined
                                  : Icons.cloud_done_outlined,

                              color:
                              previewDraftSaveFailed
                                  ? AppColors.warning
                                  : AppColors.success,

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
                                savingPreviewDraft
                                    ? 'Saving preview draft...'
                                    : previewDraftSaveFailed
                                    ? 'Preview draft could not be saved'
                                    : 'Preview saved in draft',

                                style:
                                TextStyle(
                                  color:
                                  previewDraftSaveFailed
                                      ? AppColors.warning
                                      : AppColors.success,

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
                      // EVIDENCE
                      // =================================================

                      if (
                      widget.evidenceImages.isNotEmpty ||
                          widget.evidenceVideos.isNotEmpty
                      )
                        _buildEvidenceSection(),

                      if (
                      widget.evidenceImages.isNotEmpty ||
                          widget.evidenceVideos.isNotEmpty
                      )
                        const SizedBox(
                          height:
                          16,
                        ),

                      // =================================================
                      // FINAL SMART ASSIST RESULT
                      // =================================================

                      if (
                      widget.finalAiAnalysis !=
                          null
                      ) ...[
                        _buildFinalAiCard(
                          widget
                              .finalAiAnalysis!,
                        ),

                        const SizedBox(
                          height:
                          15,
                        ),
                      ],

                      // =================================================
                      // DETAILS
                      // =================================================

                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets.all(
                          16,
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
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [
                            Text(
                              widget.title,

                              style:
                              const TextStyle(
                                fontSize:
                                18,

                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                              height:
                              16,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                  _InfoItem(
                                    label:
                                    'CATEGORY',

                                    value:
                                    widget.category,
                                  ),
                                ),

                                const SizedBox(
                                  width:
                                  10,
                                ),

                                Expanded(
                                  child:
                                  _InfoItem(
                                    label:
                                    'PRIORITY',

                                    value:
                                    widget.priority,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                              10,
                            ),

                            _InfoItem(
                              label:
                              'EVIDENCE',

                              value:
                              '${widget.evidenceImages.length} photo(s) • '
                                  '${widget.evidenceVideos.length} video(s)',
                            ),

                            const SizedBox(
                              height:
                              18,
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
                              'DESCRIPTION',

                              style:
                              TextStyle(
                                color:
                                AppColors.textSecondary,

                                fontSize:
                                10,
                              ),
                            ),

                            const SizedBox(
                              height:
                              6,
                            ),

                            Text(
                              widget.description,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height:
                        15,
                      ),

                      // =================================================
                      // LOCATION
                      // =================================================

                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets.all(
                          16,
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
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [
                            const Text(
                              'LOCATION',

                              style:
                              TextStyle(
                                color:
                                AppColors.textSecondary,

                                fontSize:
                                10,
                              ),
                            ),

                            const SizedBox(
                              height:
                              7,
                            ),

                            Text(
                              '📍 ${widget.address}',

                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            if (
                            widget.landmark
                                .isNotEmpty
                            ) ...[
                              const SizedBox(
                                height:
                                7,
                              ),

                              Text(
                                'Landmark: '
                                    '${widget.landmark}',

                                style:
                                const TextStyle(
                                  color:
                                  AppColors.textSecondary,

                                  fontSize:
                                  11,
                                ),
                              ),
                            ],

                            if (
                            widget.latitude !=
                                null &&
                                widget.longitude !=
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
                                  10,
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
                                    10,
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
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.gps_fixed,

                                      color:
                                      AppColors.success,

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
                                        '${widget.latitude!.toStringAsFixed(6)}, '
                                            '${widget.longitude!.toStringAsFixed(6)}',

                                        style:
                                        const TextStyle(
                                          color:
                                          AppColors.textSecondary,

                                          fontSize:
                                          9,
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
                    ],
                  ),
                ),
              ),

              // =====================================================
              // SUBMISSION PROGRESS
              // =====================================================

              if (submitting)
                Container(
                  margin:
                  const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    12,
                  ),

                  padding:
                  const EdgeInsets.all(
                    13,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    AppColors.primary
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
                      AppColors.primaryDark,
                    ),
                  ),

                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width:
                            18,

                            height:
                            18,

                            child:
                            CircularProgressIndicator(
                              strokeWidth:
                              2,
                            ),
                          ),

                          const SizedBox(
                            width:
                            9,
                          ),

                          Expanded(
                            child:
                            Text(
                              uploadMessage
                                  .isEmpty
                                  ? 'Submitting report...'
                                  : uploadMessage,

                              style:
                              const TextStyle(
                                fontSize:
                                10,

                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),

                          Text(
                            '${(uploadProgress * 100).round()}%',

                            style:
                            const TextStyle(
                              color:
                              AppColors.primary,

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
                        9,
                      ),

                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          10,
                        ),

                        child:
                        LinearProgressIndicator(
                          value:
                          uploadProgress
                              .clamp(
                            0.0,
                            1.0,
                          ),

                          minHeight:
                          6,

                          backgroundColor:
                          AppColors.border,

                          color:
                          AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

              // =====================================================
              // SUBMISSION ERROR / RETRY
              // =====================================================

              if (
              !submitting &&
                  submissionError !=
                      null
              )
                Container(
                  margin:
                  const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    12,
                  ),

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
                      12,
                    ),

                    border:
                    Border.all(
                      color:
                      AppColors.warning,
                    ),
                  ),

                  child:
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      const Icon(
                        Icons
                            .cloud_off_outlined,

                        color:
                        AppColors.warning,

                        size:
                        20,
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
                              'Submission Not Sent',

                              style:
                              TextStyle(
                                fontWeight:
                                FontWeight.bold,

                                fontSize:
                                11,
                              ),
                            ),

                            const SizedBox(
                              height:
                              4,
                            ),

                            Text(
                              submissionError!,

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

                            const SizedBox(
                              height:
                              5,
                            ),

                            const Text(
                              'Your entered details, images and '
                                  'location are preserved. Reconnect '
                                  'and tap Retry Submission.',

                              style:
                              TextStyle(
                                color:
                                AppColors.success,

                                fontSize:
                                9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // =====================================================
              // BUTTONS
              // =====================================================

              Container(
                padding:
                const EdgeInsets.all(
                  18,
                ),

                decoration:
                const BoxDecoration(
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
                    OutlinedButton.icon(
                      onPressed:
                      submitting ||
                          savingPreviewDraft
                          ? null
                          : _goBackSafely,

                      icon:
                      const Icon(
                        Icons.edit,
                      ),

                      label:
                      const Text(
                        'Edit',
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
                          AppColors.primaryDark,

                          minimumSize:
                          const Size
                              .fromHeight(
                            54,
                          ),
                        ),

                        onPressed:
                        submitting
                            ? null
                            : submitReport,

                        child:
                        submitting
                            ? const SizedBox(
                          width:
                          22,

                          height:
                          22,

                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2.5,

                            color:
                            Colors.white,
                          ),
                        )
                            : Text(
                          submissionError ==
                              null
                              ? '✓ Submit Report'
                              : '↻ Retry Submission',
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

  // ============================================================
  // EVIDENCE SECTION
  //
  // Every evidence image gets its own AI card.
  // ============================================================

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        const Text(
          'EVIDENCE',

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
          8,
        ),

        ...List.generate(
          widget.evidenceImages.length,
              (
              index,
              ) {
            final File image =
            widget
                .evidenceImages[
            index
            ];

            final ReportImageAiAnalysis?
            analysis =
            analysisForImage(
              image,
              index,
            );

            return Padding(
              padding:
              const EdgeInsets.only(
                bottom:
                10,
              ),

              child:
              _buildEvidenceImageCard(
                image:
                image,

                index:
                index,

                analysis:
                analysis,
              ),
            );
          },
        ),

        if (
        widget.evidenceVideos.isNotEmpty
        ) ...[
          const SizedBox(
            height:
            4,
          ),

          const Text(
            'VIDEO EVIDENCE',

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
            8,
          ),

          ...List.generate(
            widget.evidenceVideos.length,
                (
                index,
                ) {
              final File video =
              widget.evidenceVideos[index];

              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom:
                  10,
                ),

                child:
                InkWell(
                  onTap:
                      () {
                    _previewVideo(
                      video,
                    );
                  },

                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),

                  child:
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

                    child:
                    Row(
                      children: [
                        Container(
                          width:
                          58,

                          height:
                          48,

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

                          child:
                          const Icon(
                            Icons.videocam_outlined,

                            color:
                            AppColors.primary,
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
                              Text(
                                'Video ${index + 1}',

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
                                4,
                              ),

                              const Text(
                                'Saved local video evidence • tap to preview',

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

                        const Icon(
                          Icons.play_circle_outline_rounded,

                          color:
                          AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // ============================================================
  // EVIDENCE IMAGE CARD
  //
  // IMAGE
  //   ↓
  // AI STATUS
  //   ↓
  // SUMMARY
  //   ↓ tap
  // EXPANDED RESULT
  // ============================================================

  Widget _buildEvidenceImageCard({
    required File image,

    required int index,

    required ReportImageAiAnalysis?
    analysis,
  }) {
    final bool expanded =
    expandedImageAnalyses
        .contains(
      image.path,
    );

    return Container(
      width:
      double.infinity,

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
      Column(
        children: [
          // =====================================================
          // IMAGE
          // =====================================================

          ClipRRect(
            borderRadius:
            const BorderRadius.only(
              topLeft:
              Radius.circular(
                15,
              ),

              topRight:
              Radius.circular(
                15,
              ),
            ),

            child:
            Image.file(
              image,

              width:
              double.infinity,

              height:
              190,

              fit:
              BoxFit.cover,
            ),
          ),

          // =====================================================
          // AI AREA
          // =====================================================

          Padding(
            padding:
            const EdgeInsets.all(
              12,
            ),

            child:
            Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal:
                        8,

                        vertical:
                        4,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        analysis !=
                            null
                            ? AppColors
                            .success
                            .withOpacity(
                          0.10,
                        )
                            : AppColors
                            .border
                            .withOpacity(
                          0.5,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          20,
                        ),
                      ),

                      child:
                      Text(
                        analysis !=
                            null
                            ? '✓ AI Analysed'
                            : 'AI Not Available',

                        style:
                        TextStyle(
                          color:
                          analysis !=
                              null
                              ? AppColors
                              .success
                              : AppColors
                              .textSecondary,

                          fontSize:
                          9,

                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),
                    ),

                    const Spacer(),

                    Text(
                      'Image ${index + 1}',

                      style:
                      const TextStyle(
                        color:
                        AppColors
                            .textSecondary,

                        fontSize:
                        10,
                      ),
                    ),
                  ],
                ),

                // =================================================
                // COLLAPSED SUMMARY
                // =================================================

                if (analysis !=
                    null) ...[
                  const SizedBox(
                    height:
                    9,
                  ),

                  InkWell(
                    onTap: () {
                      toggleImageAnalysis(
                        image.path,
                      );
                    },

                    borderRadius:
                    BorderRadius
                        .circular(
                      8,
                    ),

                    child:
                    Padding(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        vertical:
                        5,
                      ),

                      child:
                      Row(
                        children: [
                          Expanded(
                            child:
                            Text(
                              analysis.issueDetected ==
                                  true
                                  ? '${analysis.issueLabel} • '
                                  '${analysis.severity ?? 'Unknown'} • '
                                  '${analysis.confidence ?? 'Low'} confidence'
                                  : 'No clear infrastructure issue detected',

                              style:
                              const TextStyle(
                                fontSize:
                                10,

                                fontWeight:
                                FontWeight
                                    .w600,
                              ),
                            ),
                          ),

                          Icon(
                            expanded
                                ? Icons
                                .expand_less
                                : Icons
                                .expand_more,

                            color:
                            AppColors
                                .primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // =================================================
                // EXPANDED AI RESULT
                // =================================================

                if (
                analysis !=
                    null &&
                    expanded
                ) ...[
                  const Divider(
                    color:
                    AppColors.border,
                  ),

                  const SizedBox(
                    height:
                    5,
                  ),

                  _AiInfoRow(
                    label:
                    'Detected Issue',

                    value:
                    analysis.issueDetected ==
                        true
                        ? analysis
                        .issueLabel
                        : 'No clear issue detected',
                  ),

                  _AiInfoRow(
                    label:
                    'Category',

                    value:
                    analysis.category ??
                        'Other',
                  ),

                  _AiInfoRow(
                    label:
                    'Subcategory',

                    value:
                    analysis.subcategory ??
                        'Unknown',
                  ),

                  _AiInfoRow(
                    label:
                    'Severity',

                    value:
                    analysis.severity ??
                        'Unknown',
                  ),

                  _AiInfoRow(
                    label:
                    'Confidence',

                    value:
                    analysis.confidence ??
                        'Low',
                  ),

                  _AiInfoRow(
                    label:
                    'Evidence Quality',

                    value:
                    analysis.evidenceQuality ??
                        'Unknown',
                  ),

                  if (
                  analysis.description
                      ?.trim()
                      .isNotEmpty ==
                      true
                  ) ...[
                    const SizedBox(
                      height:
                      6,
                    ),

                    _AiTextBlock(
                      label:
                      'AI Observation',

                      text:
                      analysis.description!,
                    ),
                  ],

                  if (
                  analysis.safetyConcern
                      ?.trim()
                      .isNotEmpty ==
                      true
                  ) ...[
                    const SizedBox(
                      height:
                      6,
                    ),

                    _AiTextBlock(
                      label:
                      'Safety Concern',

                      text:
                      analysis
                          .safetyConcern!,

                      warning:
                      true,
                    ),
                  ],

                  if (
                  analysis
                      .retakeRecommended
                  ) ...[
                    const SizedBox(
                      height:
                      6,
                    ),

                    _AiTextBlock(
                      label:
                      'Retake Recommended',

                      text:
                      analysis.retakeReason ??
                          'A clearer evidence image may improve analysis accuracy.',

                      warning:
                      true,
                    ),
                  ],

                  if (
                  analysis
                      .needsHumanReview
                  ) ...[
                    const SizedBox(
                      height:
                      6,
                    ),

                    const _AiTextBlock(
                      label:
                      'Human Review',

                      text:
                      'This image analysis may require additional human verification.',

                      warning:
                      true,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FINAL COMBINED SMART ASSIST CARD
  // ============================================================

  Widget _buildFinalAiCard(
      ReportFinalAiAnalysis result,
      ) {
    final Color qualityColor =
    result.shouldSuggestReportEdit
        ? AppColors.warning
        : AppColors.success;

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
          16,
        ),

        border:
        Border.all(
          color:
          const Color(
            0xFF8F80FF,
          ).withOpacity(
            0.45,
          ),
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // =====================================================
          // HEADER
          // =====================================================

          Row(
            children: [
              const Icon(
                Icons.auto_awesome,

                color:
                Color(
                  0xFF8F80FF,
                ),

                size:
                20,
              ),

              const SizedBox(
                width:
                9,
              ),

              const Expanded(
                child:
                Text(
                  'Final Smart Assist Analysis',

                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFF8F80FF,
                    ),

                    fontSize:
                    13,

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
                  AppColors
                      .textSecondary,

                  fontSize:
                  9,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            12,
          ),

          // =====================================================
          // REPORT QUALITY
          // =====================================================

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
              qualityColor
                  .withOpacity(
                0.08,
              ),

              borderRadius:
              BorderRadius
                  .circular(
                10,
              ),

              border:
              Border.all(
                color:
                qualityColor
                    .withOpacity(
                  0.35,
                ),
              ),
            ),

            child:
            Row(
              children: [
                Icon(
                  result
                      .shouldSuggestReportEdit
                      ? Icons
                      .warning_amber_rounded
                      : Icons
                      .check_circle_outline,

                  color:
                  qualityColor,

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
                    result.shouldSuggestReportEdit
                        ? 'Report Needs Improvement'
                        : 'Report Quality',

                    style:
                    TextStyle(
                      color:
                      qualityColor,

                      fontSize:
                      10,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  result
                      .reportQualityLabel,

                  style:
                  TextStyle(
                    color:
                    qualityColor,

                    fontSize:
                    10,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            12,
          ),

          // =====================================================
          // FINAL RESULT
          // =====================================================

          _AiInfoRow(
            label:
            'Final Issue',

            value:
            result.issueDetected ==
                true
                ? result.issueLabel
                : 'No clear issue detected',
          ),

          _AiInfoRow(
            label:
            'Final Category',

            value:
            result.category ??
                'Other',
          ),

          _AiInfoRow(
            label:
            'Subcategory',

            value:
            result.subcategory ??
                'Unknown',
          ),

          _AiInfoRow(
            label:
            'Severity',

            value:
            result.severity ??
                'Unknown',
          ),

          _AiInfoRow(
            label:
            'Confidence',

            value:
            result.confidence ??
                'Low',
          ),

          _AiInfoRow(
            label:
            'Evidence Quality',

            value:
            result.evidenceQuality ??
                'Unknown',
          ),

          _AiInfoRow(
            label:
            'Consistency',

            value:
            result
                .evidenceConsistencyLabel,
          ),

          _AiInfoRow(
            label:
            'Recommended Priority',

            value:
            result.recommendedPriority ??
                result.severity ??
                widget.priority,
          ),

          _AiInfoRow(
            label:
            'Title Quality',

            value:
            result.titleMeaningful ==
                false
                ? 'Needs Improvement'
                : 'Meaningful',
          ),

          _AiInfoRow(
            label:
            'Description Quality',

            value:
            result.descriptionMeaningful ==
                false
                ? 'Needs Improvement'
                : 'Meaningful',
          ),

          // =====================================================
          // EVIDENCE CONFLICT
          // =====================================================

          if (
          result.conflictingEvidence
          ) ...[
            const SizedBox(
              height:
              7,
            ),

            _AiTextBlock(
              label:
              'Evidence Conflict',

              text:
              result.conflictingEvidenceReason ??
                  'The evidence images do not fully agree.',

              warning:
              true,
            ),
          ],

          // =====================================================
          // HUMAN REVIEW
          // =====================================================

          if (
          result.needsHumanReview
          ) ...[
            const SizedBox(
              height:
              7,
            ),

            _AiTextBlock(
              label:
              'Human Review Recommended',

              text:
              result.humanReviewReason ??
                  'The final AI assessment should be verified by a worker.',

              warning:
              true,
            ),
          ],

          // =====================================================
          // REPORT ISSUE
          // =====================================================

          if (
          result.reportIssue
              ?.trim()
              .isNotEmpty ==
              true
          ) ...[
            const SizedBox(
              height:
              7,
            ),

            _AiTextBlock(
              label:
              'Report Quality Issue',

              text:
              result.reportIssue!,

              warning:
              true,
            ),
          ],

          // =====================================================
          // MISSING INFORMATION
          // =====================================================

          if (
          result
              .missingInformation
              .isNotEmpty
          ) ...[
            const SizedBox(
              height:
              7,
            ),

            _AiTextBlock(
              label:
              'Missing / Unclear Information',

              text:
              result
                  .missingInformation
                  .map(
                    (
                    item,
                    ) =>
                '• $item',
              )
                  .join(
                '\n',
              ),

              warning:
              true,
            ),
          ],

          // =====================================================
          // COMBINED SUMMARY
          // =====================================================

          if (
          result.description
              ?.trim()
              .isNotEmpty ==
              true
          ) ...[
            const SizedBox(
              height:
              7,
            ),

            _AiTextBlock(
              label:
              'Combined Evidence Summary',

              text:
              result.description!,
            ),
          ],

          // =====================================================
          // SAFETY
          // =====================================================

          if (
          result.safetyConcern
              ?.trim()
              .isNotEmpty ==
              true
          ) ...[
            const SizedBox(
              height:
              7,
            ),

            _AiTextBlock(
              label:
              'Safety Concern',

              text:
              result
                  .safetyConcern!,

              warning:
              true,
            ),
          ],

          // =====================================================
          // SUGGESTED TITLE
          // =====================================================

          if (
          result.suggestedTitle
              ?.trim()
              .isNotEmpty ==
              true
          ) ...[
            const SizedBox(
              height:
              7,
            ),

            _AiTextBlock(
              label:
              'AI Suggested Title',

              text:
              result.suggestedTitle!,
            ),
          ],

          // =====================================================
          // SUGGESTED DESCRIPTION
          // =====================================================

          if (
          result
              .suggestedDescription
              ?.trim()
              .isNotEmpty ==
              true
          ) ...[
            const SizedBox(
              height:
              7,
            ),

            _AiTextBlock(
              label:
              'AI Suggested Description',

              text:
              result
                  .suggestedDescription!,
            ),
          ],

          const SizedBox(
            height:
            10,
          ),

          // =====================================================
          // HUMAN-IN-THE-LOOP STATUS
          // =====================================================

          if (
          result.reviewedByUser
          )
            Text(
              result.suggestionsApplied
                  ? '✓ Citizen selected the final Smart Assist suggestions.'
                  : '✓ Citizen reviewed Smart Assist and kept the original report information.',

              style:
              const TextStyle(
                color:
                AppColors.success,

                fontSize:
                9,

                fontWeight:
                FontWeight.w600,

                height:
                1.4,
              ),
            ),

          if (
          result.reviewedByUser
          )
            const SizedBox(
              height:
              8,
            ),

          const Text(
            'AI-generated assessment based on all analyzed '
                'evidence. Smart Assist is advisory and the final '
                'report remains subject to human review.',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              9,

              fontStyle:
              FontStyle.italic,

              height:
              1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO ITEM
// ================================================================

class _InfoItem
    extends StatelessWidget {
  final String label;

  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
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
        AppColors.surfaceLight,

        borderRadius:
        BorderRadius.circular(
          11,
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
              AppColors.textSecondary,

              fontSize:
              9,
            ),
          ),

          const SizedBox(
            height:
            4,
          ),

          Text(
            value,

            style:
            const TextStyle(
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// AI INFO ROW
// ================================================================

class _AiInfoRow
    extends StatelessWidget {
  final String label;

  final String value;

  const _AiInfoRow({
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
                fontSize:
                10,

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
// AI TEXT BLOCK
// ================================================================

class _AiTextBlock
    extends StatelessWidget {
  final String label;

  final String text;

  final bool warning;

  const _AiTextBlock({
    required this.label,
    required this.text,
    this.warning = false,
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
        10,
      ),

      decoration:
      BoxDecoration(
        color:
        warning
            ? AppColors.warning
            .withOpacity(
          0.07,
        )
            : AppColors
            .surfaceLight,

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        border:
        warning
            ? Border.all(
          color:
          AppColors.warning
              .withOpacity(
            0.35,
          ),
        )
            : null,
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            label,

            style:
            TextStyle(
              color:
              warning
                  ? AppColors.warning
                  : AppColors
                  .textSecondary,

              fontSize:
              9,

              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            height:
            4,
          ),

          Text(
            text,

            style:
            const TextStyle(
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
