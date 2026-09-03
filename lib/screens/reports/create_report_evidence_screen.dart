import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/report_image_ai_analysis.dart';
import '../../services/ai_evidence_service.dart';
import '../../services/image_compression_service.dart';
import '../../theme/app_colors.dart';
import 'create_report_location_screen.dart';

// ================================================================
// CREATE REPORT EVIDENCE SCREEN
//
// Existing UI design preserved.
//
// High-quality Smart Assist adds:
//
// 1. Automatic evidence analysis after compression.
// 2. Report-context-aware Gemini analysis.
// 3. Evidence quality assessment.
// 4. Category comparison.
// 5. Priority recommendation.
// 6. Retake recommendation.
// 7. Human review indication.
// 8. Keep Mine / Apply AI choice.
// 9. Analyze Again cooldown.
// 10. Graceful failure without blocking reporting.
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
    extends State<CreateReportEvidenceScreen> {
  // ============================================================
  // IMAGE SERVICES
  // ============================================================

  final ImagePicker picker =
  ImagePicker();

  final ImageCompressionService compressionService =
  const ImageCompressionService();

  // ============================================================
  // AI SERVICE
  // ============================================================

  final AiEvidenceService aiEvidenceService =
  AiEvidenceService();

  // ============================================================
  // AI STATE
  // ============================================================

  bool analyzingEvidence =
  false;

  ReportImageAiAnalysis? aiAnalysis;

  String? aiError;

  bool aiSuggestionsApplied =
  false;

  // ============================================================
  // AI REQUEST COOLDOWN
  //
  // Prevents accidental repeated Gemini calls.
  // ============================================================

  DateTime? lastAiAnalysisAt;

  static const Duration aiCooldown =
  Duration(
    seconds:
    5,
  );

  // ============================================================
  // EFFECTIVE REPORT VALUES
  //
  // Begin with user's manually entered values.
  //
  // Only change when user chooses Apply AI.
  // ============================================================

  late String selectedCategory;

  late String selectedPriority;

  late String selectedDescription;

  // ============================================================
  // EVIDENCE
  // ============================================================

  final List<File> evidenceImages =
  [];

  bool loadingImage =
  false;

  int totalCompressedBytes =
  0;

  int compressedImageCount =
  0;

  String compressionMessage =
      'Evidence images are optimized before upload.';

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    selectedCategory =
        widget.category;

    selectedPriority =
        widget.priority;

    selectedDescription =
        widget.description;
  }

  // ============================================================
  // ANALYZE EVIDENCE
  // ============================================================

  Future<void> analyzeEvidence(
      File imageFile,
      ) async {
    if (analyzingEvidence) {
      return;
    }

    // ==========================================================
    // COOLDOWN
    // ==========================================================

    if (lastAiAnalysisAt != null) {
      final Duration elapsed =
      DateTime.now().difference(
        lastAiAnalysisAt!,
      );

      if (elapsed <
          aiCooldown) {
        final int remaining =
        (
            aiCooldown.inSeconds -
                elapsed.inSeconds
        ).clamp(
          1,
          aiCooldown.inSeconds,
        );

        showMessage(
          'Please wait $remaining second(s) '
              'before running Smart Assist again.',
        );

        return;
      }
    }

    // ==========================================================
    // FILE CHECK
    // ==========================================================

    if (!await imageFile.exists()) {
      showMessage(
        'Evidence image is no longer available.',
      );

      return;
    }

    // ==========================================================
    // START
    // ==========================================================

    lastAiAnalysisAt =
        DateTime.now();

    setState(() {
      analyzingEvidence =
      true;

      aiError =
      null;

      aiAnalysis =
      null;

      aiSuggestionsApplied =
      false;
    });

    try {
      // ========================================================
      // CONTEXT-AWARE SMART ASSIST
      // ========================================================

      final ReportImageAiAnalysis result =
      await aiEvidenceService
          .analyzeLocalImage(
        imageFile:
        imageFile,

        userCategory:
        widget.category,

        userPriority:
        widget.priority,

        userTitle:
        widget.title,

        userDescription:
        widget.description,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        aiAnalysis =
            result.copyWith(
              reviewedByUser:
              false,

              suggestionsApplied:
              false,

              originalUserCategory:
              widget.category,

              originalUserPriority:
              widget.priority,

              originalUserDescription:
              widget.description,
            );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      setState(() {
        aiError =
        message.trim().isEmpty
            ? 'Smart Assist is currently unavailable.'
            : message;
      });

      // ========================================================
      // AI FAILURE NEVER BLOCKS REPORTING
      // ========================================================

      showMessage(
        'AI analysis could not be completed. '
            'You can still continue manually.',
      );
    } finally {
      if (mounted) {
        setState(() {
          analyzingEvidence =
          false;
        });
      }
    }
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

      selectedDescription =
          widget.description;

      aiSuggestionsApplied =
      false;

      if (aiAnalysis != null) {
        aiAnalysis =
            aiAnalysis!.copyWith(
              suggestionsApplied:
              false,

              reviewedByUser:
              true,

              originalUserCategory:
              widget.category,

              originalUserPriority:
              widget.priority,

              originalUserDescription:
              widget.description,
            );
      }
    });

    showMessage(
      'Your original report information will be kept.',
    );
  }

  // ============================================================
  // APPLY AI SUGGESTIONS
  // ============================================================

  void applyAiSuggestions() {
    final ReportImageAiAnalysis? result =
        aiAnalysis;

    if (result == null) {
      return;
    }

    if (result.issueDetected != true) {
      showMessage(
        'Smart Assist did not clearly detect '
            'an infrastructure issue in this image.',
      );

      return;
    }

    setState(() {
      // ========================================================
      // CATEGORY
      // ========================================================

      if (result.category != null &&
          result.category!
              .trim()
              .isNotEmpty) {
        selectedCategory =
        result.category!;
      }

      // ========================================================
      // PRIORITY
      //
      // Prefer recommendedPriority if supplied.
      // Otherwise use severity.
      // ========================================================

      final String? recommended =
          result.recommendedPriority ??
              result.severity;

      if (recommended != null &&
          recommended
              .trim()
              .isNotEmpty) {
        selectedPriority =
            recommended;
      }

      // ========================================================
      // DESCRIPTION
      // ========================================================

      if (result.description != null &&
          result.description!
              .trim()
              .isNotEmpty) {
        selectedDescription =
            result.description!
                .trim();
      }

      aiSuggestionsApplied =
      true;

      aiAnalysis =
          result.copyWith(
            suggestionsApplied:
            true,

            reviewedByUser:
            true,

            originalUserCategory:
            widget.category,

            originalUserPriority:
            widget.priority,

            originalUserDescription:
            widget.description,
          );
    });

    showMessage(
      'Smart Assist suggestions applied.',
    );
  }

  // ============================================================
  // ANALYZE AGAIN
  // ============================================================

  Future<void> analyzeAgain() async {
    if (evidenceImages.isEmpty) {
      showMessage(
        'Please add an evidence image first.',
      );

      return;
    }

    await analyzeEvidence(
      evidenceImages.first,
    );
  }

  // ============================================================
  // TAKE PHOTO
  // ============================================================

  Future<void> takePhoto() async {
    if (loadingImage ||
        analyzingEvidence) {
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
        await analyzeEvidence(
          preparedFile,
        );
      }
    } catch (e) {
      showMessage(
        'Unable to open camera: $e',
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
  // PICK GALLERY IMAGES
  // ============================================================

  Future<void> pickGalleryImages() async {
    if (loadingImage ||
        analyzingEvidence) {
      return;
    }

    try {
      setState(() {
        loadingImage =
        true;

        compressionMessage =
        'Preparing selected images...';
      });

      final List<XFile> images =
      await picker.pickMultiImage(
        imageQuality:
        95,
      );

      if (images.isEmpty) {
        return;
      }

      File? firstPreparedFile;

      for (
      int index = 0;
      index < images.length;
      index++
      ) {
        if (mounted) {
          setState(() {
            compressionMessage =
            'Optimizing image '
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

        firstPreparedFile ??=
            preparedFile;
      }

      // ========================================================
      // PRIMARY IMAGE
      //
      // Analyze only first image automatically.
      // Other images remain additional evidence.
      // ========================================================

      if (firstPreparedFile != null) {
        await analyzeEvidence(
          firstPreparedFile,
        );
      }
    } catch (e) {
      showMessage(
        'Unable to open gallery: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingImage =
          false;

          if (evidenceImages.isNotEmpty) {
            compressionMessage =
            '$compressedImageCount '
                'image(s) compressed before upload.';
          }
        });
      }
    }
  }

  // ============================================================
  // ADD + COMPRESS IMAGE
  // ============================================================

  Future<File?> _addAndCompressFile(
      File originalFile,
      ) async {
    try {
      final ImageCompressionResult result =
      await compressionService
          .compressEvidenceImage(
        originalFile,
      );

      if (!mounted) {
        return null;
      }

      setState(() {
        evidenceImages.add(
          result.file,
        );

        totalCompressedBytes +=
            result.compressedBytes;

        if (result.compressed) {
          compressedImageCount++;
        }

        compressionMessage =
        result.compressed
            ? 'Image optimized: '
            '${compressionService.formatBytes(result.originalBytes)} → '
            '${compressionService.formatBytes(result.compressedBytes)} '
            '(${result.savedPercentage.toStringAsFixed(0)}% smaller)'
            : 'Image ready for upload.';
      });

      return result.file;
    } catch (e) {
      showMessage(
        'Unable to prepare image: $e',
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
            evidenceImages.length) {
      return;
    }

    final File file =
    evidenceImages[index];

    final int currentBytes =
    await file.length();

    setState(() {
      evidenceImages.removeAt(
        index,
      );

      totalCompressedBytes =
          (totalCompressedBytes -
              currentBytes)
              .clamp(
            0,
            1 << 62,
          );

      if (evidenceImages.isEmpty) {
        aiAnalysis =
        null;

        aiError =
        null;

        aiSuggestionsApplied =
        false;

        lastAiAnalysisAt =
        null;

        selectedCategory =
            widget.category;

        selectedPriority =
            widget.priority;

        selectedDescription =
            widget.description;
      }
    });

    await compressionService
        .deleteTemporaryCompressedFile(
      file,
    );
  }

  // ============================================================
  // CONTINUE TO LOCATION
  // ============================================================

  void continueToLocation() {
    if (evidenceImages.isEmpty) {
      showMessage(
        'Please add at least one evidence image.',
      );

      return;
    }

    if (loadingImage) {
      showMessage(
        'Please wait for image preparation to finish.',
      );

      return;
    }

    if (analyzingEvidence) {
      showMessage(
        'Please wait for Smart Assist analysis to finish.',
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateReportLocationScreen(
              category:
              selectedCategory,

              priority:
              selectedPriority,

              title:
              widget.title,

              description:
              selectedDescription,

              evidenceImages:
              evidenceImages,

              // ====================================================
              // IMPORTANT
              //
              // If CreateReportLocationScreen does not yet define
              // this parameter, add it in the next step.
              // ====================================================

              aiAnalysis:
              aiAnalysis,
            ),
      ),
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
                            loadingImage ||
                                analyzingEvidence
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

                            Text(
                              'Help improve your community',

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

                    // =================================================
                    // EXISTING PROGRESS
                    // =================================================

                    const _EvidenceProgress(),

                    const SizedBox(
                      height:
                      22,
                    ),

                    // =================================================
                    // SMART ASSIST
                    // =================================================

                    _buildSmartAssistCard(),

                    const SizedBox(
                      height:
                      20,
                    ),

                    // =================================================
                    // IMAGE OPTIMIZATION
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
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          const Icon(
                            Icons.compress_outlined,

                            color:
                            AppColors.primary,

                            size:
                            25,
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
                                  'Image Optimization',

                                  style:
                                  TextStyle(
                                    color:
                                    AppColors.primary,

                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                  4,
                                ),

                                Text(
                                  loadingImage
                                      ? compressionMessage
                                      : evidenceImages.isEmpty
                                      ? 'Evidence images are compressed before upload to reduce file size.'
                                      : '$compressionMessage\nPrepared size: '
                                      '${compressionService.formatBytes(totalCompressedBytes)}',

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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    // =================================================
                    // UPLOAD EVIDENCE
                    // =================================================

                    Container(
                      width:
                      double.infinity,

                      height:
                      190,

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
                          AppColors.primaryDark,

                          width:
                          1.5,
                        ),
                      ),

                      child:
                      const Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,

                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,

                            size:
                            48,

                            color:
                            AppColors.primary,
                          ),

                          SizedBox(
                            height:
                            10,
                          ),

                          Text(
                            'Upload Evidence',

                            style:
                            TextStyle(
                              fontSize:
                              16,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            height:
                            6,
                          ),

                          Text(
                            'Take a photo or choose from gallery',

                            style:
                            TextStyle(
                              color:
                              AppColors.textSecondary,

                              fontSize:
                              11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                      16,
                    ),

                    // =================================================
                    // CAMERA / GALLERY
                    // =================================================

                    Row(
                      children: [
                        Expanded(
                          child:
                          OutlinedButton.icon(
                            onPressed:
                            loadingImage ||
                                analyzingEvidence
                                ? null
                                : takePhoto,

                            icon:
                            const Icon(
                              Icons.camera_alt_outlined,
                            ),

                            label:
                            const Text(
                              'Take Photo',
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
                            loadingImage ||
                                analyzingEvidence
                                ? null
                                : pickGalleryImages,

                            icon:
                            const Icon(
                              Icons.photo_library_outlined,
                            ),

                            label:
                            const Text(
                              'Gallery',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    // =================================================
                    // IMAGE PREVIEW GRID
                    // =================================================

                    if (evidenceImages.isNotEmpty)
                      GridView.builder(
                        shrinkWrap:
                        true,

                        physics:
                        const NeverScrollableScrollPhysics(),

                        itemCount:
                        evidenceImages.length,

                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                          3,

                          crossAxisSpacing:
                          9,

                          mainAxisSpacing:
                          9,
                        ),

                        itemBuilder:
                            (
                            context,
                            index,
                            ) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child:
                                ClipRRect(
                                  borderRadius:
                                  BorderRadius.circular(
                                    12,
                                  ),

                                  child:
                                  Image.file(
                                    evidenceImages[index],

                                    fit:
                                    BoxFit.cover,
                                  ),
                                ),
                              ),

                              Positioned(
                                right:
                                4,

                                top:
                                4,

                                child:
                                GestureDetector(
                                  onTap:
                                  loadingImage ||
                                      analyzingEvidence
                                      ? null
                                      : () {
                                    removeImage(
                                      index,
                                    );
                                  },

                                  child:
                                  Container(
                                    padding:
                                    const EdgeInsets.all(
                                      4,
                                    ),

                                    decoration:
                                    const BoxDecoration(
                                      color:
                                      Colors.black54,

                                      shape:
                                      BoxShape.circle,
                                    ),

                                    child:
                                    const Icon(
                                      Icons.close,

                                      size:
                                      15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // =====================================================
            // BOTTOM BUTTONS
            // =====================================================

            Padding(
              padding:
              const EdgeInsets.all(
                18,
              ),

              child:
              Row(
                children: [
                  OutlinedButton(
                    onPressed:
                    loadingImage ||
                        analyzingEvidence
                        ? null
                        : () {
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
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        AppColors.primaryDark,

                        minimumSize:
                        const Size.fromHeight(
                          54,
                        ),
                      ),

                      onPressed:
                      loadingImage ||
                          analyzingEvidence
                          ? null
                          : continueToLocation,

                      child:
                      const Text(
                        'Continue →',
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
                      'Smart Assist Available',

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
                        AppColors
                            .textSecondary,

                        fontSize:
                        11,

                        height:
                        1.4,
                      ),
                    ),
                  ],
                ),
              ),

              if (analyzingEvidence)
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
          // ERROR
          // ======================================================

          if (aiError != null) ...[
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

            Text(
              aiError!,

              style:
              const TextStyle(
                color:
                Colors.amber,

                fontSize:
                11,

                height:
                1.4,
              ),
            ),

            const SizedBox(
              height:
              10,
            ),

            OutlinedButton.icon(
              onPressed:
              evidenceImages.isEmpty ||
                  analyzingEvidence
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
                'Try Again',
              ),
            ),
          ],

          // ======================================================
          // RESULT
          // ======================================================

          if (aiAnalysis != null) ...[
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

            // ==================================================
            // CORE RESULT
            // ==================================================

            _AiResultRow(
              label:
              'Detected Issue',

              value:
              aiAnalysis!
                  .issueDetected ==
                  true
                  ? aiAnalysis!.issueLabel
                  : 'No clear issue detected',
            ),

            _AiResultRow(
              label:
              'Evidence Quality',

              value:
              aiAnalysis!
                  .evidenceQuality ??
                  'Unknown',
            ),

            _AiResultRow(
              label:
              'AI Confidence',

              value:
              aiAnalysis!
                  .confidence ??
                  'Low',
            ),

            // ==================================================
            // USER VS AI
            // ==================================================

            const SizedBox(
              height:
              4,
            ),

            const Text(
              'Report Comparison',

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

            _AiResultRow(
              label:
              'Your Category',

              value:
              widget.category,
            ),

            _AiResultRow(
              label:
              'AI Category',

              value:
              aiAnalysis!
                  .category ??
                  'Other',
            ),

            _AiResultRow(
              label:
              'Category Match',

              value:
              aiAnalysis!
                  .categoryMatchesUser ==
                  true
                  ? 'Yes ✓'
                  : 'Different suggestion',
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
              aiAnalysis!
                  .recommendedPriority ??
                  aiAnalysis!
                      .severity ??
                  'Low',
            ),

            // ==================================================
            // PRIORITY CHANGE NOTICE
            // ==================================================

            if (aiAnalysis!
                .priorityChangeRecommended ==
                true)
              Container(
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
                Text(
                  '⚠ Smart Assist recommends changing priority '
                      'from ${widget.priority} to '
                      '${aiAnalysis!.recommendedPriority ?? aiAnalysis!.severity ?? 'Low'}.',

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
              ),

            // ==================================================
            // HUMAN REVIEW
            // ==================================================

            if (aiAnalysis!
                .needsHumanReview)
              Container(
                width:
                double.infinity,

                margin:
                const EdgeInsets.only(
                  top:
                  10,
                ),

                padding:
                const EdgeInsets.all(
                  10,
                ),

                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFF8F80FF,
                  ).withOpacity(
                    0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
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
                const Text(
                  'ℹ Human review recommended because the AI assessment may require additional verification.',

                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFFC7C1FF,
                    ),

                    fontSize:
                    10,

                    height:
                    1.4,
                  ),
                ),
              ),

            // ==================================================
            // RETAKE RECOMMENDATION
            // ==================================================

            if (aiAnalysis!
                .retakeRecommended)
              Container(
                width:
                double.infinity,

                margin:
                const EdgeInsets.only(
                  top:
                  10,
                ),

                padding:
                const EdgeInsets.all(
                  10,
                ),

                decoration:
                BoxDecoration(
                  color:
                  Colors.orange
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
                    Colors.orange
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
                    const Text(
                      'Better Evidence Recommended',

                      style:
                      TextStyle(
                        color:
                        Colors.orange,

                        fontSize:
                        11,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    if (aiAnalysis!
                        .retakeReason
                        ?.trim()
                        .isNotEmpty ==
                        true) ...[
                      const SizedBox(
                        height:
                        4,
                      ),

                      Text(
                        aiAnalysis!
                            .retakeReason!,

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
                    ],
                  ],
                ),
              ),

            // ==================================================
            // DESCRIPTION
            // ==================================================

            if (aiAnalysis!
                .description
                ?.trim()
                .isNotEmpty ==
                true) ...[
              const SizedBox(
                height:
                12,
              ),

              const Text(
                'Suggested Description',

                style:
                TextStyle(
                  color:
                  AppColors
                      .textSecondary,

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
                aiAnalysis!
                    .description!,

                style:
                const TextStyle(
                  fontSize:
                  11,

                  height:
                  1.4,
                ),
              ),
            ],

            // ==================================================
            // SAFETY
            // ==================================================

            if (aiAnalysis!
                .safetyConcern
                ?.trim()
                .isNotEmpty ==
                true) ...[
              const SizedBox(
                height:
                10,
              ),

              Text(
                '⚠ ${aiAnalysis!.safetyConcern!}',

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
              10,
            ),

            const Text(
              'AI-generated suggestion. '
                  'You remain responsible for the final report information.',

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

            // ==================================================
            // KEEP / APPLY
            // ==================================================

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
                    aiAnalysis!
                        .issueDetected ==
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
                analyzingEvidence ||
                    evidenceImages.isEmpty
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
                  'Analyze Again',
                ),
              ),
            ),

            // ==================================================
            // CURRENT DECISION
            // ==================================================

            if (aiAnalysis!
                .reviewedByUser) ...[
              const SizedBox(
                height:
                8,
              ),

              Text(
                aiSuggestionsApplied
                    ? '✓ AI suggestions selected'
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
        ],
      ),
    );
  }

  // ============================================================
  // SMART ASSIST MESSAGE
  // ============================================================

  String _smartAssistMessage() {
    if (analyzingEvidence) {
      return 'AI is analyzing the evidence and comparing it with your report details...';
    }

    if (aiAnalysis != null) {
      return 'AI analysis complete. Review the comparison before continuing.';
    }

    if (aiError != null) {
      return 'AI analysis could not be completed. '
          'Manual reporting is still available.';
    }

    if (evidenceImages.isEmpty) {
      return 'Add an evidence image to start AI analysis.';
    }

    return 'Evidence is ready for Smart Assist analysis.';
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
                AppColors
                    .textSecondary,

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
    );
  }
}