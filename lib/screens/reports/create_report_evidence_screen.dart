import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/report_final_ai_analysis.dart';
import '../../models/report_image_ai_analysis.dart';
import '../../services/ai_evidence_service.dart';
import '../../services/image_compression_service.dart';
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

class CreateReportEvidenceScreen
    extends StatefulWidget {
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
  State<CreateReportEvidenceScreen>
  createState() =>
      _CreateReportEvidenceScreenState();
}

class _CreateReportEvidenceScreenState
    extends State<CreateReportEvidenceScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final ImagePicker picker =
  ImagePicker();

  final ImageCompressionService
  compressionService =
  const ImageCompressionService();

  final AiEvidenceService
  aiEvidenceService =
  AiEvidenceService();

  // ============================================================
  // LIMIT
  //
  // Same limit as AiEvidenceService.
  // ============================================================

  static const int maxAiImages =
  5;

  // ============================================================
  // EVIDENCE
  // ============================================================

  final List<File> evidenceImages =
  [];

  // ============================================================
  // INDIVIDUAL IMAGE ANALYSES
  //
  // KEY:
  // local image path
  //
  // VALUE:
  // analysis belonging to that exact image
  //
  // Do NOT use list index for permanent mapping.
  // ============================================================

  final Map<
      String,
      ReportImageAiAnalysis
  > imageAnalyses = {};

  // ============================================================
  // EXPANDED IMAGE CARDS
  // ============================================================

  final Set<String>
  expandedImageAnalyses =
  {};

  // ============================================================
  // IMAGE-SPECIFIC ERRORS
  // ============================================================

  final Map<String, String>
  imageAnalysisErrors =
  {};

  // ============================================================
  // IMAGE CURRENTLY BEING ANALYZED
  // ============================================================

  String? analyzingImagePath;

  // ============================================================
  // FINAL COMBINED RESULT
  // ============================================================

  ReportFinalAiAnalysis?
  finalAiAnalysis;

  bool combiningAnalyses =
  false;

  String? finalAnalysisError;

  // ============================================================
  // GENERAL STATE
  // ============================================================

  bool loadingImage =
  false;

  bool analyzingEvidence =
  false;

  bool aiSuggestionsApplied =
  false;

  // ============================================================
  // IMAGE COMPRESSION
  // ============================================================

  int totalCompressedBytes =
  0;

  int compressedImageCount =
  0;

  String compressionMessage =
      'Evidence images are optimized before upload.';

  // ============================================================
  // EFFECTIVE REPORT VALUES
  //
  // These are the values that will eventually be submitted.
  //
  // They start with the citizen's original values.
  // ============================================================

  late String selectedCategory;

  late String selectedPriority;

  late String selectedTitle;

  late String selectedDescription;

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

    selectedTitle =
        widget.title;

    selectedDescription =
        widget.description;
  }

  // ============================================================
  // BUSY?
  // ============================================================

  bool get isBusy =>
      loadingImage ||
          analyzingEvidence ||
          combiningAnalyses;

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
    );
  }

  // ============================================================
  // EDIT REPORT
  // ============================================================

  void editReport() {
    if (isBusy) {
      return;
    }

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

    if (
    evidenceImages.length >=
        maxAiImages
    ) {
      showMessage(
        'A maximum of $maxAiImages evidence images '
            'can be analyzed by Smart Assist.',
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
          [
            preparedFile,
          ],
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
  // PICK MULTIPLE GALLERY IMAGES
  // ============================================================

  Future<void> pickGalleryImages() async {
    if (isBusy) {
      return;
    }

    final int remaining =
        maxAiImages -
            evidenceImages.length;

    if (remaining <= 0) {
      showMessage(
        'A maximum of $maxAiImages evidence images '
            'can be analyzed by Smart Assist.',
      );

      return;
    }

    try {
      setState(() {
        loadingImage =
        true;

        compressionMessage =
        'Preparing selected images...';
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

      if (
      selected.length >
          remaining
      ) {
        showMessage(
          'Only the first $remaining image(s) were added. '
              'Smart Assist supports up to $maxAiImages images.',
        );
      }

      final List<File>
      preparedFiles =
      [];

      for (
      int index = 0;
      index < images.length;
      index++
      ) {
        if (mounted) {
          setState(() {
            compressionMessage =
            'Optimizing image '
                '${index + 1} of ${images.length}...';
          });
        }

        final File? preparedFile =
        await _addAndCompressFile(
          File(
            images[index]
                .path,
          ),
        );

        if (preparedFile != null) {
          preparedFiles.add(
            preparedFile,
          );
        }
      }

      // ========================================================
      // IMPORTANT
      //
      // OLD:
      // only firstPreparedFile analyzed
      //
      // NEW:
      // every prepared image analyzed
      // ========================================================

      if (preparedFiles.isNotEmpty) {
        await analyzeImageBatch(
          preparedFiles,
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

          if (
          evidenceImages
              .isNotEmpty
          ) {
            compressionMessage =
            '$compressedImageCount image(s) compressed '
                'before upload.';
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
      final ImageCompressionResult
      result =
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
    if (
    index < 0 ||
        index >=
            evidenceImages.length ||
        isBusy
    ) {
      return;
    }

    final File file =
    evidenceImages[index];

    final String path =
        file.path;

    final int currentBytes =
    await file.length();

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

      // Always restore original report values because the
      // evidence set has changed.
      selectedCategory =
          widget.category;

      selectedPriority =
          widget.priority;

      selectedTitle =
          widget.title;

      selectedDescription =
          widget.description;
    });

    await compressionService
        .deleteTemporaryCompressedFile(
      file,
    );

    // ==========================================================
    // REBUILD FINAL RESULT FROM REMAINING IMAGES
    // ==========================================================

    if (imageAnalyses.isNotEmpty) {
      await combineAllAnalyses();
    }
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
    if (evidenceImages.isEmpty) {
      showMessage(
        'Please add at least one evidence image.',
      );

      return;
    }

    if (isBusy) {
      showMessage(
        'Please wait for Smart Assist to finish.',
      );

      return;
    }

    // ==========================================================
    // LOCAL QUALITY CHECK
    // ==========================================================

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

    // ==========================================================
    // FINAL AI REPORT QUALITY
    //
    // Use FINAL combined analysis, not one arbitrary image.
    // ==========================================================

    final ReportFinalAiAnalysis?
    result =
        finalAiAnalysis;

    if (
    result != null &&
        result.reportSufficient ==
            false &&
        !aiSuggestionsApplied
    ) {
      await showPoorReportDialog();

      return;
    }

    if (!mounted) {
      return;
    }

    // ==========================================================
    // TEMPORARY BACKWARD COMPATIBILITY
    //
    // LocationScreen currently still expects:
    //
    // ReportImageAiAnalysis? aiAnalysis
    //
    // Until the next step updates Location + Preview, pass the
    // first available individual analysis.
    //
    // The actual final report values below already use the
    // combined Smart Assist decision.
    // ==========================================================

    ReportImageAiAnalysis?
    legacyAnalysis;

    if (imageAnalyses.isNotEmpty) {
      legacyAnalysis =
          imageAnalyses.values.first;
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
              selectedTitle,

              description:
              selectedDescription,

              evidenceImages:
              evidenceImages,

              aiAnalysis:
              legacyAnalysis,
            ),
      ),
    );
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
                            isBusy
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
                            Icons
                                .compress_outlined,
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
                                      ? 'Evidence images are compressed before upload.'
                                      : '$compressionMessage\n'
                                      'Prepared size: '
                                      '${compressionService.formatBytes(totalCompressedBytes)}',

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

                                const SizedBox(
                                  height:
                                  4,
                                ),

                                Text(
                                  'Smart Assist supports up to '
                                      '$maxAiImages evidence images.',

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
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    // =================================================
                    // UPLOAD BOX
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
                            Icons
                                .cloud_upload_outlined,
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
                            'Each image will be analyzed separately',
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
                            isBusy
                                ? null
                                : takePhoto,

                            icon:
                            const Icon(
                              Icons
                                  .camera_alt_outlined,
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
                            isBusy
                                ? null
                                : pickGalleryImages,

                            icon:
                            const Icon(
                              Icons
                                  .photo_library_outlined,
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

                    if (
                    evidenceImages
                        .isNotEmpty
                    )
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
                          final File file =
                          evidenceImages[
                          index];

                          final bool
                          complete =
                          imageAnalyses
                              .containsKey(
                            file.path,
                          );

                          final bool
                          analyzing =
                              analyzingImagePath ==
                                  file.path;

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
                                    file,

                                    fit:
                                    BoxFit.cover,
                                  ),
                                ),
                              ),

                              Positioned(
                                left:
                                4,
                                bottom:
                                4,

                                child:
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal:
                                    6,
                                    vertical:
                                    3,
                                  ),

                                  decoration:
                                  BoxDecoration(
                                    color:
                                    Colors.black54,

                                    borderRadius:
                                    BorderRadius.circular(
                                      8,
                                    ),
                                  ),

                                  child:
                                  Text(
                                    analyzing
                                        ? 'Analyzing...'
                                        : complete
                                        ? 'AI ✓'
                                        : 'Pending',

                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white,
                                      fontSize:
                                      8,
                                    ),
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
                                  isBusy
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
                    isBusy
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
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        AppColors.primaryDark,

                        minimumSize:
                        const Size.fromHeight(
                          54,
                        ),
                      ),

                      onPressed:
                      isBusy
                          ? null
                          : continueToLocation,

                      child:
                      isBusy
                          ? const SizedBox(
                        width:
                        20,
                        height:
                        20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                        ),
                      )
                          : const Text(
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