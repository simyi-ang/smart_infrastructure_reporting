import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/infrastructure_report.dart';
import '../../models/report_image_ai_analysis.dart';

import '../../services/ai_evidence_service.dart';
import '../../services/location_service.dart';
import '../../services/report_edit_evidence_service.dart';
import '../../services/report_service.dart';

import '../../theme/app_colors.dart';
import '../../utils/multilingual_text_validator.dart';

import 'map_picker_screen.dart';

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

  final ReportEditEvidenceService
  evidenceService =
  ReportEditEvidenceService();

  final AiEvidenceService aiService =
  AiEvidenceService();

  final ImagePicker _picker =
  ImagePicker();

  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  late TextEditingController
  titleController;

  late TextEditingController
  descriptionController;

  late TextEditingController
  addressController;

  late TextEditingController
  landmarkController;

  late String selectedCategory;

  late String selectedPriority;

  // ============================================================
  // STATE
  // ============================================================

  bool saving = false;

  bool loadingEvidence = true;

  bool editingEvidence = false;

  bool analyzingAi = false;

  bool aiSuggestionsApplied = false;

  String? evidenceError;

  ReportImageAiAnalysis? aiResult;

  List<EditableReportEvidence> evidence =
  [];

  // ============================================================
  // OPTIONS
  // ============================================================

  final List<String> categories = [
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  final List<String> priorities = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

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

    _loadEvidence();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    titleController.dispose();

    descriptionController.dispose();

    addressController.dispose();

    landmarkController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD EVIDENCE
  // ============================================================

  Future<void> _loadEvidence() async {
    if (mounted) {
      setState(() {
        loadingEvidence = true;
        evidenceError = null;
      });
    }

    try {
      final List<EditableReportEvidence>
      result =
      await evidenceService
          .loadEvidence(
        reportId:
        widget.report.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        evidence = result;
        loadingEvidence = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingEvidence = false;

        evidenceError =
            e
                .toString()
                .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // MEANINGFUL TEXT VALIDATION
  //
  // SAME QUALITY RULES AS CREATE REPORT
  // ============================================================

  String? validateMeaningfulText(
      String value, {
        required String fieldName,
        required int minimumLength,
        required int minimumWords,
        bool optional = false,
      }) {
    final String text =
    value.trim();

    // ----------------------------------------------------------
    // OPTIONAL EMPTY
    // ----------------------------------------------------------

    if (optional &&
        text.isEmpty) {
      return null;
    }

    // ----------------------------------------------------------
    // EMPTY
    // ----------------------------------------------------------

    if (text.isEmpty) {
      return 'Please enter a $fieldName.';
    }

    // ----------------------------------------------------------
    // MINIMUM LENGTH
    // ----------------------------------------------------------

    if (text.length <
        minimumLength) {
      return 'The $fieldName is too short to be useful.';
    }

    // ----------------------------------------------------------
    // LETTERS REQUIRED
    // ----------------------------------------------------------

    final RegExp letterRegex =
    RegExp(
      r'[A-Za-zÀ-ÖØ-öø-ÿ]',
    );

    final int letterCount =
        letterRegex
            .allMatches(
          text,
        )
            .length;

    if (letterCount == 0) {
      return 'The $fieldName must contain meaningful words.';
    }

    // ----------------------------------------------------------
    // NUMBERS ONLY
    // ----------------------------------------------------------

    if (RegExp(
      r'^[0-9\s]+$',
    ).hasMatch(
      text,
    )) {
      return 'The $fieldName cannot contain only numbers.';
    }

    // ----------------------------------------------------------
    // SYMBOLS ONLY
    // ----------------------------------------------------------

    if (RegExp(
      r'^[^A-Za-zÀ-ÖØ-öø-ÿ0-9]+$',
    ).hasMatch(
      text,
    )) {
      return 'The $fieldName cannot contain only symbols.';
    }

    // ----------------------------------------------------------
    // SAME CHARACTER REPEATED
    // ----------------------------------------------------------

    final String compact =
    text.replaceAll(
      RegExp(
        r'\s+',
      ),
      '',
    );

    if (compact.length >= 4 &&
        RegExp(
          r'^(.)\1+$',
          caseSensitive: false,
        ).hasMatch(
          compact,
        )) {
      return 'The $fieldName contains repeated characters '
          'and does not appear meaningful.';
    }

    // ----------------------------------------------------------
    // LONG REPEATED CHARACTER RUN
    // ----------------------------------------------------------

    if (RegExp(
      r'(.)\1{3,}',
      caseSensitive: false,
    ).hasMatch(
      text,
    )) {
      return 'The $fieldName contains too many repeated characters.';
    }

    // ----------------------------------------------------------
    // SYMBOL RATIO
    // ----------------------------------------------------------

    final int symbolCount =
        RegExp(
          r'[^A-Za-zÀ-ÖØ-öø-ÿ0-9\s]',
        ).allMatches(
          text,
        ).length;

    final double symbolRatio =
        symbolCount /
            text.length;

    if (symbolRatio >
        0.30) {
      return 'The $fieldName contains too many symbols.';
    }

    // ----------------------------------------------------------
    // LETTER RATIO
    // ----------------------------------------------------------

    final double letterRatio =
        letterCount /
            text.length;

    if (letterRatio <
        0.45) {
      return 'The $fieldName does not contain enough meaningful text.';
    }

    // ----------------------------------------------------------
    // WORD EXTRACTION
    // ----------------------------------------------------------

    final List<String> words =
    text
        .split(
      RegExp(
        r'\s+',
      ),
    )
        .map(
          (word) =>
          word.replaceAll(
            RegExp(
              r'[^A-Za-zÀ-ÖØ-öø-ÿ]',
            ),
            '',
          ),
    )
        .where(
          (word) =>
      word.length >=
          2,
    )
        .toList();

    // ----------------------------------------------------------
    // MINIMUM WORD COUNT
    // ----------------------------------------------------------

    if (words.length <
        minimumWords) {
      return 'Please provide a meaningful $fieldName '
          'using at least $minimumWords useful words.';
    }

    // ----------------------------------------------------------
    // VERY LONG RANDOM TOKEN
    // ----------------------------------------------------------

    final String lettersOnly =
    text.replaceAll(
      RegExp(
        r'[^A-Za-zÀ-ÖØ-öø-ÿ]',
      ),
      '',
    );

    if (lettersOnly.length >=
        20 &&
        !text.contains(
          RegExp(
            r'\s',
          ),
        )) {
      return 'The $fieldName does not appear to contain '
          'a clear phrase or sentence.';
    }

    // ----------------------------------------------------------
    // RANDOM LOOKING WORDS
    // ----------------------------------------------------------

    int suspiciousWords =
    0;

    for (final String word
    in words) {
      final String lower =
      word.toLowerCase();

      if (RegExp(
        r'[bcdfghjklmnpqrstvwxyz]{7,}',
        caseSensitive: false,
      ).hasMatch(
        lower,
      )) {
        suspiciousWords++;
        continue;
      }

      if (lower.length >=
          7 &&
          !RegExp(
            r'[aeiou]',
          ).hasMatch(
            lower,
          )) {
        suspiciousWords++;
      }
    }

    if (words.isNotEmpty &&
        suspiciousWords >=
            words.length) {
      return 'The $fieldName does not appear to contain meaningful words.';
    }

    return null;
  }

  // ============================================================
  // ADDRESS VALIDATION
  // ============================================================

  String? _validateAddress(
      String? value,
      ) {
    return validateMeaningfulText(
      value ?? '',
      fieldName:
      'address',
      minimumLength:
      5,
      minimumWords:
      2,
    );
  }

  // ============================================================
  // LANDMARK VALIDATION
  // ============================================================

  String? _validateLandmark(
      String? value,
      ) {
    return validateMeaningfulText(
      value ?? '',
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
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage(
      ImageSource source,
      ) async {
    if (editingEvidence ||
        saving) {
      return;
    }

    try {
      final XFile? picked =
      await _picker.pickImage(
        source:
        source,
        imageQuality:
        88,
        maxWidth:
        2048,
      );

      if (picked == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        editingEvidence =
        true;
      });

      final EditableReportEvidence
      added =
      await evidenceService
          .addImage(
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

        // Evidence changed.
        // Previous AI result should not be treated as current.
        aiResult =
        null;

        aiSuggestionsApplied =
        false;
      });

      _showMessage(
        'Evidence image added successfully.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          editingEvidence =
          false;
        });

        _showMessage(
          e
              .toString()
              .replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    }
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo(
      ImageSource source,
      ) async {
    if (editingEvidence ||
        saving) {
      return;
    }

    try {
      final XFile? picked =
      await _picker.pickVideo(
        source:
        source,
        maxDuration:
        const Duration(
          seconds:
          60,
        ),
      );

      if (picked == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        editingEvidence =
        true;
      });

      final EditableReportEvidence
      added =
      await evidenceService
          .addVideo(
        reportId:
        widget.report.id,

        file:
        File(
          picked.path,
        ),

        latitude:
        widget.report.latitude,

        longitude:
        widget.report.longitude,
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

        aiResult =
        null;

        aiSuggestionsApplied =
        false;
      });

      _showMessage(
        'Evidence video added successfully.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          editingEvidence =
          false;
        });

        _showMessage(
          e
              .toString()
              .replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    }
  }

  // ============================================================
  // ADD EVIDENCE MENU
  // ============================================================

  Future<void> _showAddEvidenceMenu() async {
    if (saving ||
        editingEvidence) {
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
          (bottomContext) {
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
        await _pickImage(
          ImageSource.camera,
        );
        break;

      case 'gallery_image':
        await _pickImage(
          ImageSource.gallery,
        );
        break;

      case 'camera_video':
        await _pickVideo(
          ImageSource.camera,
        );
        break;

      case 'gallery_video':
        await _pickVideo(
          ImageSource.gallery,
        );
        break;
    }
  }

  // ============================================================
  // REMOVE EVIDENCE
  // ============================================================

  Future<void> _removeEvidence(
      EditableReportEvidence item,
      ) async {
    if (saving ||
        editingEvidence) {
      return;
    }

    // ==========================================================
    // REPORT MUST RETAIN EVIDENCE
    // ==========================================================

    if (evidence.length <=
        1) {
      _showMessage(
        'A report must keep at least one evidence photo or video.',
      );

      return;
    }

    final bool? confirmed =
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
            'Remove Evidence?',
          ),

          content:
          const Text(
            'This evidence will be permanently removed from the report.',
            style:
            TextStyle(
              color:
              AppColors.textSecondary,
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
                'Keep',
              ),
            ),

            TextButton(
              onPressed:
                  () =>
                  Navigator.pop(
                    dialogContext,
                    true,
                  ),
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

    if (confirmed !=
        true) {
      return;
    }

    setState(() {
      editingEvidence =
      true;
    });

    try {
      await evidenceService
          .removeEvidence(
        evidence:
        item,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        evidence.removeWhere(
              (element) =>
          element.id ==
              item.id &&
              element.sourceTable ==
                  item.sourceTable,
        );

        editingEvidence =
        false;

        aiResult =
        null;

        aiSuggestionsApplied =
        false;
      });

      _showMessage(
        'Evidence removed.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        editingEvidence =
        false;
      });

      _showMessage(
        e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // AI SMART ASSIST
  // ============================================================

  Future<void> _runAiAssist() async {
    if (analyzingAi ||
        saving ||
        editingEvidence) {
      return;
    }

    // ----------------------------------------------------------
    // LOCAL QUALITY VALIDATION FIRST
    // ----------------------------------------------------------

    if (!_formKey.currentState!
        .validate()) {
      _showMessage(
        'Please correct the highlighted report information before using Smart Assist.',
      );

      return;
    }

    final List<EditableReportEvidence>
    images =
    evidence
        .where(
          (item) =>
      item.isImage &&
          item.sourceTable ==
              ReportEditEvidenceService
                  .reportImagesTable,
    )
        .toList();

    if (images.isEmpty) {
      _showMessage(
        'Smart Assist needs at least one evidence image.',
      );

      return;
    }

    setState(() {
      analyzingAi =
      true;

      aiResult =
      null;

      aiSuggestionsApplied =
      false;
    });

    try {
      ReportImageAiAnalysis?
      selectedAnalysis;

      // ========================================================
      // ANALYSE EACH STORED IMAGE
      //
      // We keep the strongest useful result for the citizen
      // review panel.
      // ========================================================

      for (final EditableReportEvidence
      image in images) {
        final ReportImageAiAnalysis
        result =
        await aiService
            .analyzeImage(
          reportImageId:
          image.id,
        );

        selectedAnalysis =
            _preferAiResult(
              selectedAnalysis,
              result,
            );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        aiResult =
            selectedAnalysis;

        analyzingAi =
        false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        analyzingAi =
        false;
      });

      _showMessage(
        e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // PICK BEST AI RESULT
  // ============================================================

  ReportImageAiAnalysis _preferAiResult(
      ReportImageAiAnalysis? current,
      ReportImageAiAnalysis incoming,
      ) {
    if (current ==
        null) {
      return incoming;
    }

    int score(
        ReportImageAiAnalysis item,
        ) {
      int value =
      0;

      if (item.issueDetected ==
          true) {
        value +=
        4;
      }

      if ((item.suggestedTitle ??
          '')
          .trim()
          .isNotEmpty) {
        value +=
        3;
      }

      if ((item.suggestedDescription ??
          '')
          .trim()
          .isNotEmpty) {
        value +=
        3;
      }

      if (item.priorityChangeRecommended ==
          true) {
        value +=
        2;
      }

      if (item.categoryMatchesUser ==
          false) {
        value +=
        2;
      }

      if (item.reportSufficient ==
          false) {
        value +=
        2;
      }

      return value;
    }

    return score(
      incoming,
    ) >
        score(
          current,
        )
        ? incoming
        : current;
  }

  // ============================================================
  // APPLY AI SUGGESTIONS
  //
  // IMPORTANT:
  // AI NEVER SILENTLY OVERWRITES USER DATA.
  // ============================================================

  Future<void> _applyAiSuggestions() async {
    final ReportImageAiAnalysis?
    result =
        aiResult;

    if (result ==
        null) {
      return;
    }

    final bool? approved =
    await showDialog<bool>(
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
                  'Apply AI Suggestions?',
                ),
              ),
            ],
          ),

          content:
          const Text(
            'Smart Assist will update only the fields for which '
                'it has a usable recommendation. You can continue editing '
                'everything before saving.',
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
                'Cancel',
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
                'Apply',
              ),
            ),
          ],
        );
      },
    );

    if (approved !=
        true ||
        !mounted) {
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
      if (suggestedTitle.isNotEmpty) {
        titleController.text =
            suggestedTitle;
      }

      if (suggestedDescription.isNotEmpty) {
        descriptionController.text =
            suggestedDescription;
      }

      if (result.categoryMatchesUser ==
          false &&
          categories.contains(
            suggestedCategory,
          )) {
        selectedCategory =
            suggestedCategory;
      }

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
    });

    // ==========================================================
    // IMPORTANT
    //
    // Validate AI output using EXACTLY the same local rules.
    // AI output is not automatically trusted.
    // ==========================================================

    final bool valid =
    _formKey.currentState!
        .validate();

    if (!valid) {
      _showMessage(
        'Some AI suggestions still need manual editing before they can be saved.',
      );
    } else {
      _showMessage(
        'AI suggestions applied. Review or edit them before saving.',
      );
    }
  }

  // ============================================================
  // SAVE REPORT
  // ============================================================

  Future<void> saveReport() async {
    if (saving ||
        editingEvidence ||
        analyzingAi) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    // ==========================================================
    // SAME LOCAL VALIDATION AS CREATE REPORT
    // ==========================================================

    if (!_formKey.currentState!
        .validate()) {
      _showMessage(
        'Please correct the highlighted information before saving.',
      );

      return;
    }

    // ==========================================================
    // EVIDENCE VALIDATION
    // ==========================================================

    if (evidence.isEmpty) {
      _showMessage(
        'Please keep at least one evidence photo or video.',
      );

      return;
    }

    // ==========================================================
    // CATEGORY / PRIORITY VALIDATION
    // ==========================================================

    if (!categories.contains(
      selectedCategory,
    )) {
      _showMessage(
        'Please select a valid issue category.',
      );

      return;
    }

    if (!priorities.contains(
      selectedPriority,
    )) {
      _showMessage(
        'Please select a valid priority level.',
      );

      return;
    }

    setState(() {
      saving =
      true;
    });

    try {
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

        latitude:
        widget.report.latitude,

        longitude:
        widget.report.longitude,
      );

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
                      ? 'Report updated successfully with reviewed AI assistance.'
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
      _showMessage(
        e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
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

  void _showMessage(
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
        saving ||
            editingEvidence ||
            analyzingAi;

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
                  _formKey,

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
                                  widget.report
                                      .referenceNumber,

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
                              )
                                  .withOpacity(
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

                      // =================================================
                      // EDIT INFORMATION
                      // =================================================

                      _InfoCard(
                        icon:
                        Icons.edit_note_outlined,
                        text:
                        'You can update this report while it is pending review. '
                            'All edited text must remain meaningful and usable.',
                      ),

                      const SizedBox(
                        height:
                        18,
                      ),

                      // =================================================
                      // AI SMART ASSIST
                      // =================================================

                      _AiEditCard(
                        analyzing:
                        analyzingAi,

                        result:
                        aiResult,

                        suggestionsApplied:
                        aiSuggestionsApplied,

                        onAnalyze:
                        busy
                            ? null
                            : _runAiAssist,

                        onApply:
                        busy ||
                            aiResult ==
                                null
                            ? null
                            : _applyAiSuggestions,
                      ),

                      const SizedBox(
                        height:
                        24,
                      ),

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
                            return DropdownMenuItem(
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
                          if (value !=
                              null) {
                            setState(() {
                              selectedCategory =
                                  value;

                              aiSuggestionsApplied =
                              false;
                            });
                          }
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

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
                            return DropdownMenuItem(
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
                          if (value !=
                              null) {
                            setState(() {
                              selectedPriority =
                                  value;

                              aiSuggestionsApplied =
                              false;
                            });
                          }
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
                            (
                            value,
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
                          'Describe the infrastructure issue clearly, including '
                              'severity and any safety concern.',
                        ),

                        validator:
                            (
                            value,
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
                        'ADDRESS',
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

                        decoration:
                        _decoration(
                          hint:
                          'Issue location',
                        ),

                        validator:
                        _validateAddress,
                      ),

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
                        _validateLandmark,
                      ),

                      const SizedBox(
                        height:
                        26,
                      ),

                      // =================================================
                      // EVIDENCE EDITOR
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

                        onRetry:
                        _loadEvidence,

                        onAdd:
                        _showAddEvidenceMenu,

                        onRemove:
                        _removeEvidence,
                      ),

                      const SizedBox(
                        height:
                        18,
                      ),

                      // =================================================
                      // QUALITY INFORMATION
                      // =================================================

                      _InfoCard(
                        icon:
                        Icons.verified_user_outlined,

                        text:
                        'Edited title, description, address and optional landmark '
                            'are checked for meaningful text. AI suggestions are also '
                            'validated before saving and never overwrite your report '
                            'without approval.',
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
                    AppColors.primaryDark
                        .withOpacity(
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
// EVIDENCE EDITOR
// =================================================================

class _EvidenceEditor
    extends StatelessWidget {
  final List<EditableReportEvidence>
  evidence;

  final bool loading;

  final bool busy;

  final String? error;

  final Future<void> Function()
  onRetry;

  final Future<void> Function()
  onAdd;

  final Future<void> Function(
      EditableReportEvidence item,
      ) onRemove;

  const _EvidenceEditor({
    required this.evidence,
    required this.loading,
    required this.busy,
    required this.error,
    required this.onRetry,
    required this.onAdd,
    required this.onRemove,
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

              const Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
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
                      'Add or remove evidence before review begins.',
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

              TextButton.icon(
                onPressed:
                busy
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
              GridView.builder(
                shrinkWrap:
                true,

                physics:
                const NeverScrollableScrollPhysics(),

                itemCount:
                evidence.length,

                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                  2,
                  crossAxisSpacing:
                  10,
                  mainAxisSpacing:
                  10,
                  childAspectRatio:
                  1.12,
                ),

                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final EditableReportEvidence
                  item =
                  evidence[index];

                  return _EvidenceCard(
                    item:
                    item,

                    onRemove:
                    busy
                        ? null
                        : () {
                      onRemove(
                        item,
                      );
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

            const SizedBox(
              height:
              7,
            ),

            const Text(
              'Updating evidence...',
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
    );
  }
}

// =================================================================
// EVIDENCE CARD
// =================================================================

class _EvidenceCard
    extends StatelessWidget {
  final EditableReportEvidence item;

  final VoidCallback? onRemove;

  const _EvidenceCard({
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(
      BuildContext context,
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
                  40,
                ),
              ),
            ),
          ),
        ),

        Positioned(
          left:
          7,
          bottom:
          7,
          child:
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              7,
              vertical:
              4,
            ),

            decoration:
            BoxDecoration(
              color:
              Colors.black.withOpacity(
                0.70,
              ),

              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),

            child:
            Text(
              item.isImage
                  ? 'PHOTO'
                  : 'VIDEO',

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
    );
  }
}

// =================================================================
// AI EDIT CARD
// =================================================================

class _AiEditCard
    extends StatelessWidget {
  final bool analyzing;

  final bool suggestionsApplied;

  final ReportImageAiAnalysis? result;

  final Future<void> Function()? onAnalyze;

  final Future<void> Function()? onApply;

  const _AiEditCard({
    required this.analyzing,
    required this.suggestionsApplied,
    required this.result,
    required this.onAnalyze,
    required this.onApply,
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
        AppColors.primary
            .withOpacity(
          0.055,
        ),

        borderRadius:
        BorderRadius.circular(
          15,
        ),

        border:
        Border.all(
          color:
          AppColors.primary
              .withOpacity(
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
                      'Review evidence and suggest improvements',
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
                analyzing
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
                  'Analyse',
                ),
              ),
            ],
          ),

          if (result !=
              null) ...[
            const SizedBox(
              height:
              14,
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
              'AI category',
              value:
              result!.category ??
                  'Not available',
            ),

            _AiResultLine(
              label:
              'Severity',
              value:
              result!.severity ??
                  'Not available',
            ),

            _AiResultLine(
              label:
              'Evidence quality',
              value:
              result!.evidenceQuality ??
                  'Not available',
            ),

            _AiResultLine(
              label:
              'Report quality',
              value:
              result!.reportQuality ??
                  'Not available',
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
                result!.missingInformation
                    .join(
                  ', ',
                ),
              ),

            const SizedBox(
              height:
              12,
            ),

            SizedBox(
              width:
              double.infinity,

              child:
              ElevatedButton.icon(
                onPressed:
                onApply,

                icon:
                Icon(
                  suggestionsApplied
                      ? Icons.check_circle_outline
                      : Icons.auto_fix_high,
                ),

                label:
                Text(
                  suggestionsApplied
                      ? 'Suggestions Applied — You Can Still Edit'
                      : 'Review & Apply AI Suggestions',
                ),
              ),
            ),
          ],

          const SizedBox(
            height:
            9,
          ),

          const Text(
            'AI recommendations are assistance only. '
                'Nothing is applied until you approve it.',
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
            120,

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
        AppColors.primary
            .withOpacity(
          0.07,
        ),

        borderRadius:
        BorderRadius.circular(
          13,
        ),

        border:
        Border.all(
          color:
          AppColors.primary
              .withOpacity(
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
// DECORATION
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