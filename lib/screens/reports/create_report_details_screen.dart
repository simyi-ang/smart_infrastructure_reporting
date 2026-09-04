import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/report_draft.dart';
import '../../services/report_draft_service.dart';
import '../../theme/app_colors.dart';
import 'create_report_evidence_screen.dart';
import 'voice_speech_test_screen.dart';

// ================================================================
// CREATE REPORT DETAILS SCREEN
// ================================================================
//
// HIGH-COMPLEXITY FEATURES:
//
// 1. Smart Draft Recovery
// 2. Per-user local draft isolation
// 3. Debounced text autosave
// 4. Immediate category/priority persistence
// 5. Serialized draft writes to reduce save race conditions
// 6. App lifecycle persistence
// 7. Android system-back protection
// 8. Safe navigation persistence
// 9. Explicit discard-only deletion
// 10. Restore after app restart/navigation
// 11. Current workflow-step tracking
// 12. Draft save state feedback
// 13. Local anti-gibberish report validation
// 14. Duplicate-navigation protection
//
// Draft is NOT deleted when:
// - pressing Back
// - changing page
// - app goes to background
// - app is restarted
// - report validation fails
//
// Draft is deleted only when:
// - citizen explicitly chooses Discard Report
// - successful report submission later calls clearDraft()
//
// ================================================================

class CreateReportDetailsScreen extends StatefulWidget {
  const CreateReportDetailsScreen({
    super.key,
  });

  @override
  State<CreateReportDetailsScreen> createState() =>
      _CreateReportDetailsScreenState();
}

class _CreateReportDetailsScreenState
    extends State<CreateReportDetailsScreen>
    with WidgetsBindingObserver {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController titleController =
  TextEditingController();

  final TextEditingController descriptionController =
  TextEditingController();

  // ============================================================
  // SMART DRAFT RECOVERY STATE
  // ============================================================

  Timer? _draftDebounce;

  static const Duration _draftSaveDelay =
  Duration(
    milliseconds: 650,
  );

  bool _isRestoringDraft = true;
  bool _isSavingDraft = false;
  bool _draftSaveFailed = false;
  bool _draftWasRestored = false;

  bool _isNavigating = false;

  bool _reportSubmitted = false;

  /// Required because PopScope(canPop: false) would also block
  /// our own intentional Navigator.pop().
  bool _allowPop = false;

  DateTime? _lastDraftSavedAt;

  bool _restoreNoticeShown = false;

  /// Used to serialize local writes.
  ///
  /// Without serialization, multiple async saves could finish
  /// in a different order and an older snapshot might overwrite
  /// a newer one.
  Future<void> _saveQueue =
  Future<void>.value();

  String? get _currentUserId {
    return Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.id;
  }

  // ============================================================
  // SELECTED VALUES
  // ============================================================

  String? selectedCategory;
  String? selectedPriority;

  // ============================================================
  // FIELD ERRORS
  // ============================================================

  String? titleError;
  String? descriptionError;

  // ============================================================
  // CATEGORY OPTIONS
  // ============================================================

  final List<Map<String, String>> categories = [
    {
      'name': 'Road Damage',
      'icon': '🛣️',
    },
    {
      'name': 'Street Light',
      'icon': '💡',
    },
    {
      'name': 'Drainage',
      'icon': '🌊',
    },
    {
      'name': 'Public Facility',
      'icon': '🏗️',
    },
    {
      'name': 'Other',
      'icon': '📌',
    },
  ];

  // ============================================================
  // PRIORITY OPTIONS
  // ============================================================

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

    WidgetsBinding.instance.addObserver(
      this,
    );

    _restoreDraft(
      showRestoreNotice: true,
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

    titleController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE PROTECTION
  // ============================================================

  @override
  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(
      state,
    );

    // ==========================================================
    // DO NOT SAVE AFTER SUCCESSFUL SUBMISSION
    // ==========================================================

    if (_isRestoringDraft ||
        _reportSubmitted) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(
          _saveDraftImmediately(
            showFailureMessage: false,
          ),
        );
        break;

      case AppLifecycleState.resumed:
        break;
    }
  }

  // ============================================================
  // RESTORE ACTIVE DRAFT
  // ============================================================

  Future<void> _restoreDraft({
    required bool showRestoreNotice,
  }) async {
    final String? userId =
        _currentUserId;

    if (userId == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringDraft = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isRestoringDraft = true;
      });
    }

    try {
      final ReportDraft? draft =
      await ReportDraftService.loadDraft(
        userId: userId,
      );

      if (!mounted) {
        return;
      }

      if (draft == null) {
        setState(() {
          _isRestoringDraft = false;
          _draftWasRestored = false;
          _lastDraftSavedAt = null;
        });

        return;
      }

      // ----------------------------------------------------------
      // STORED VALUE VALIDATION
      // ----------------------------------------------------------

      final bool categoryValid =
      categories.any(
            (item) =>
        item['name'] ==
            draft.category,
      );

      final bool priorityValid =
      priorities.contains(
        draft.priority,
      );

      titleController.text =
          draft.title;

      descriptionController.text =
          draft.description;

      setState(() {
        selectedCategory =
        categoryValid &&
            draft.category.isNotEmpty
            ? draft.category
            : null;

        selectedPriority =
        priorityValid &&
            draft.priority.isNotEmpty
            ? draft.priority
            : null;

        _lastDraftSavedAt =
            draft.updatedAt;

        _draftWasRestored =
            draft.hasData;

        _draftSaveFailed = false;

        _isRestoringDraft = false;
      });

      if (showRestoreNotice &&
          _draftWasRestored &&
          !_restoreNoticeShown) {
        _restoreNoticeShown = true;

        WidgetsBinding.instance
            .addPostFrameCallback(
              (_) {
            if (!mounted) {
              return;
            }

            ScaffoldMessenger
                .of(context)
                .hideCurrentSnackBar();

            ScaffoldMessenger
                .of(context)
                .showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(
                      Icons.restore,
                      color: Colors.white,
                      size: 19,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'Your unfinished report has been restored.',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringDraft = false;
        _draftSaveFailed = true;
      });
    }
  }

  // ============================================================
  // BUILD CURRENT DRAFT SNAPSHOT
  // ============================================================

  ReportDraft _buildCurrentDraft({
    ReportDraft? existing,
  }) {
    final DateTime now =
    DateTime.now();

    return ReportDraft(
      id: existing?.id,

      category:
      selectedCategory ?? '',

      priority:
      selectedPriority ?? '',

      title:
      titleController.text.trim(),

      description:
      descriptionController.text.trim(),

      // ==========================================================
// PRESERVE LOCATION DATA
//
// Details screen does not own Location.
// Never erase Location data when saving Details.
// ==========================================================

      landmark:
      existing?.landmark,

      manualAddress:
      existing?.manualAddress,

      latitude:
      existing?.latitude,

      longitude:
      existing?.longitude,

      locationAccuracy:
      existing?.locationAccuracy,

      detectedAddress:
      existing?.detectedAddress,

      locationVerificationStatus:
      existing?.locationVerificationStatus,

      addressDistanceMeters:
      existing?.addressDistanceMeters,

// ==========================================================
// PRESERVE VOICE DATA
// ==========================================================

      voiceTranscript:
      existing?.voiceTranscript,

      voiceLocationContext:
      existing?.voiceLocationContext,

      voiceSafetyConcern:
      existing?.voiceSafetyConcern,

// ==========================================================
// PRESERVE PHOTO EVIDENCE
// ==========================================================

      evidenceImagePaths:
      existing?.evidenceImagePaths ??
          const <String>[],

// ==========================================================
// PRESERVE VIDEO EVIDENCE
//
// Details screen does not own evidence.
// It must preserve whatever Evidence screen already saved.
// ==========================================================

      evidenceVideoPaths:
      existing?.evidenceVideoPaths ??
          const <String>[],

      createdAt:
      existing?.createdAt ??
          now,

      updatedAt:
      now,
    );
  }

  // ============================================================
  // DEBOUNCED AUTOSAVE
  // ============================================================

  void _scheduleDraftSave() {
    // ==========================================================
    // NEVER SCHEDULE A SAVE FOR A SUBMITTED REPORT
    // ==========================================================

    if (_isRestoringDraft ||
        _reportSubmitted) {
      return;
    }

    _draftDebounce?.cancel();

    if (mounted) {
      setState(() {
        _isSavingDraft = true;
        _draftSaveFailed = false;
      });
    }

    _draftDebounce =
        Timer(
          _draftSaveDelay,
              () {
            // --------------------------------------------------------
            // Check again when timer actually fires.
            // Submission may have happened during the 650ms delay.
            // --------------------------------------------------------

            if (_reportSubmitted) {
              return;
            }

            unawaited(
              _saveDraftImmediately(
                showFailureMessage: false,
              ),
            );
          },
        );
  }

  // ============================================================
  // SERIALIZED IMMEDIATE SAVE
  // ============================================================

  Future<bool> _saveDraftImmediately({
    required bool showFailureMessage,
  }) {
    // ==========================================================
    // REPORT ALREADY SUBMITTED
    //
    // Do not place another save into the serialized queue.
    // ==========================================================

    if (_reportSubmitted) {
      return Future<bool>.value(
        true,
      );
    }

    final Completer<bool> completer =
    Completer<bool>();

    _saveQueue =
        _saveQueue.then(
              (_) async {
            // --------------------------------------------------------
            // IMPORTANT:
            // This save may have been queued BEFORE submission.
            //
            // Check the submitted flag again when it actually starts.
            // --------------------------------------------------------

            if (_reportSubmitted) {
              if (!completer.isCompleted) {
                completer.complete(
                  true,
                );
              }

              return;
            }

            final bool result =
            await _performDraftSave(
              showFailureMessage:
              showFailureMessage,
            );

            if (!completer.isCompleted) {
              completer.complete(
                result,
              );
            }
          },
        ).catchError(
              (_) {
            if (!completer.isCompleted) {
              completer.complete(
                false,
              );
            }
          },
        );

    return completer.future;
  }
  // ============================================================
  // ACTUAL SAVE OPERATION
  // ============================================================

  Future<bool> _performDraftSave({
    required bool showFailureMessage,
  }) async {
    // ==========================================================
    // NEVER SAVE AFTER SUCCESSFUL SUBMISSION
    // ==========================================================

    if (_isRestoringDraft ||
        _reportSubmitted) {
      return true;
    }

    final String? userId =
        _currentUserId;

    if (userId == null) {
      return false;
    }

    _draftDebounce?.cancel();

    if (mounted &&
        !_reportSubmitted) {
      setState(() {
        _isSavingDraft = true;
        _draftSaveFailed = false;
      });
    }

    try {
      // ========================================================
      // FIRST CHECK
      // ========================================================

      if (_reportSubmitted) {
        return true;
      }

      final ReportDraft? existing =
      await ReportDraftService.loadDraft(
        userId: userId,
      );

      // ========================================================
      // SECOND CHECK
      //
      // Submission might have completed while loadDraft()
      // was waiting.
      // ========================================================

      if (_reportSubmitted) {
        return true;
      }

      final ReportDraft updatedDraft =
      _buildCurrentDraft(
        existing: existing,
      );

      if (!updatedDraft.hasData) {
        if (mounted &&
            !_reportSubmitted) {
          setState(() {
            _isSavingDraft = false;
            _draftSaveFailed = false;
          });
        }

        return true;
      }

      // ========================================================
      // THIRD CHECK
      //
      // This is the most important check:
      // never write after clearDraft().
      // ========================================================

      if (_reportSubmitted) {
        return true;
      }

      await ReportDraftService.saveDraft(
        userId: userId,
        draft: updatedDraft,
      );

      // ========================================================
      // SUBMISSION MAY HAVE HAPPENED DURING saveDraft()
      //
      // If so, remove the late save immediately.
      // ========================================================

      if (_reportSubmitted) {
        try {
          await ReportDraftService.clearDraft(
            userId: userId,
          );
        } catch (_) {
          // Preview / success cleanup will also attempt removal.
        }

        return true;
      }

      if (!mounted) {
        return true;
      }

      setState(() {
        _isSavingDraft = false;
        _draftSaveFailed = false;
        _draftWasRestored = true;

        _lastDraftSavedAt =
            DateTime.now();
      });

      return true;
    } catch (_) {
      // --------------------------------------------------------
      // If submission already succeeded, a draft save failure
      // is irrelevant and must not show a draft error.
      // --------------------------------------------------------

      if (_reportSubmitted) {
        return true;
      }

      if (!mounted) {
        return false;
      }

      setState(() {
        _isSavingDraft = false;
        _draftSaveFailed = true;
      });

      if (showFailureMessage) {
        showMessage(
          'Your report could not be saved locally. '
              'Please try again before leaving.',
        );
      }

      return false;
    }
  }

  // ============================================================
  // SAFE LEAVE
  // ============================================================

  Future<void> _leaveScreenSafely() async {
    if (_isNavigating) {
      return;
    }

    _isNavigating = true;

    FocusScope.of(context)
        .unfocus();

    await _saveDraftImmediately(
      showFailureMessage: false,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _allowPop = true;
    });

    Navigator.of(context).pop();
  }

  // ============================================================
  // DISCARD REPORT
  // ============================================================

  Future<void> _confirmDiscardDraft() async {
    FocusScope.of(context)
        .unfocus();

    final bool? confirmed =
    await showDialog<bool>(
      context: context,

      builder: (
          dialogContext,
          ) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              18,
            ),
          ),

          title:
          const Row(
            children: [
              Icon(
                Icons.delete_outline,
                color:
                Colors.orangeAccent,
              ),

              SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  'Discard Report?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          content:
          const Text(
            'Your unfinished report will be permanently removed '
                'from this device. Choose Keep Draft if you may want '
                'to continue it later.',
            style: TextStyle(
              color:
              AppColors.textSecondary,
              height: 1.45,
            ),
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
                'Keep Draft',
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
              const Text(
                'Discard Report',
                style: TextStyle(
                  color:
                  Colors.orangeAccent,
                  fontWeight:
                  FontWeight.w600,
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

    final String? userId =
        _currentUserId;

    if (userId == null) {
      showMessage(
        'Unable to identify the current account.',
      );

      return;
    }

    try {
      _draftDebounce?.cancel();

      await ReportDraftService.clearDraft(
        userId: userId,
      );

      titleController.clear();
      descriptionController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        selectedCategory = null;
        selectedPriority = null;

        titleError = null;
        descriptionError = null;

        _draftWasRestored = false;
        _draftSaveFailed = false;
        _lastDraftSavedAt = null;

        _allowPop = true;
      });

      Navigator.of(context).pop();
    } catch (_) {
      showMessage(
        'Unable to discard the report draft. Please try again.',
      );
    }
  }

  // ============================================================
  // CONTINUE TO EVIDENCE
  // ============================================================

  Future<void> continueToEvidence() async {
    if (_isNavigating ||
        _isRestoringDraft) {
      return;
    }

    FocusScope.of(context)
        .unfocus();

    // ----------------------------------------------------------
    // CATEGORY
    // ----------------------------------------------------------

    if (selectedCategory == null) {
      showMessage(
        'Please select an issue category.',
      );

      return;
    }

    // ----------------------------------------------------------
    // PRIORITY
    // ----------------------------------------------------------

    if (selectedPriority == null) {
      showMessage(
        'Please select a priority level.',
      );

      return;
    }

    // ----------------------------------------------------------
    // PREPARE TEXT
    // ----------------------------------------------------------

    final String title =
    titleController.text.trim();

    final String description =
    descriptionController.text.trim();

    // ----------------------------------------------------------
    // TITLE QUALITY
    // ----------------------------------------------------------

    final String? currentTitleError =
    validateMeaningfulText(
      title,
      fieldName:
      'report title',
      minimumLength:
      5,
      minimumWords:
      2,
    );

    // ----------------------------------------------------------
    // DESCRIPTION QUALITY
    // ----------------------------------------------------------

    final String? currentDescriptionError =
    validateMeaningfulText(
      description,
      fieldName:
      'description',
      minimumLength:
      10,
      minimumWords:
      3,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      titleError =
          currentTitleError;

      descriptionError =
          currentDescriptionError;
    });

    if (currentTitleError != null) {
      showMessage(
        currentTitleError,
      );

      return;
    }

    if (currentDescriptionError != null) {
      showMessage(
        currentDescriptionError,
      );

      return;
    }

    // ----------------------------------------------------------
    // SAVE BEFORE NAVIGATION
    // ----------------------------------------------------------

    _isNavigating =
    true;

    final bool saved =
    await _saveDraftImmediately(
      showFailureMessage:
      true,
    );

    if (!mounted) {
      return;
    }

    if (!saved) {
      _isNavigating =
      false;

      return;
    }

    final String? userId =
        _currentUserId;

    if (userId == null) {
      _isNavigating =
      false;

      showMessage(
        'Your login session is unavailable. '
            'Please sign in again.',
      );

      return;
    }

    try {
      // --------------------------------------------------------
      // MARK EVIDENCE AS NEXT ACTIVE STEP
      // --------------------------------------------------------

      await ReportDraftService.updateDraft(
        userId:
        userId,

        category:
        selectedCategory!,

        priority:
        selectedPriority!,

        title:
        title,

        description:
        description,

        currentStep:
        2,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _isNavigating =
      false;

      showMessage(
        'Unable to prepare the saved report '
            'for the next step.',
      );

      return;
    }

    if (!mounted) {
      return;
    }

    // ==========================================================
    // OPEN EVIDENCE AND WAIT FOR SUBMISSION RESULT
    // ==========================================================

    final bool? submitted =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateReportEvidenceScreen(
              category:
              selectedCategory!,

              priority:
              selectedPriority!,

              title:
              title,

              description:
              description,
            ),
      ),
    );

    if (!mounted) {
      return;
    }

    // ==========================================================
    // REPORT SUCCESSFULLY SUBMITTED
    //
    // IMPORTANT:
    // Do not restore the old Details draft.
    // ==========================================================

    if (submitted == true) {
      // ==========================================================
      // MARK SUBMITTED FIRST
      //
      // This MUST happen before clearDraft().
      //
      // From this exact moment:flutt
      // - lifecycle save stops
      // - debounce save stops
      // - queued save stops
      // - actual save operation stops
      // ==========================================================

      _reportSubmitted = true;

      // ----------------------------------------------------------
      // Cancel any save timer that has not fired yet.
      // ----------------------------------------------------------

      _draftDebounce?.cancel();

      // ----------------------------------------------------------
      // Update local UI state.
      // ----------------------------------------------------------

      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _draftSaveFailed = false;
          _draftWasRestored = false;
          _lastDraftSavedAt = null;
        });
      }

      // ==========================================================
      // WAIT FOR OLD QUEUED SAVE OPERATIONS
      //
      // They now see _reportSubmitted == true and exit without
      // writing.
      // ==========================================================

      try {
        await _saveQueue;
      } catch (_) {
        // Ignore an old draft-save failure after submission.
      }

      // ==========================================================
      // FINAL DELETE
      // ==========================================================

      try {
        await ReportDraftService.clearDraft(
          userId: userId,
        );

        debugPrint(
          '[REPORT DRAFT] '
              'Submitted Details draft cleared.',
        );
      } catch (e) {
        debugPrint(
          '[REPORT DRAFT] '
              'Unable to clear submitted Details draft: $e',
        );
      }

      if (!mounted) {
        return;
      }

      // ==========================================================
      // IMPORTANT
      //
      // Allow PopScope to close this screen directly.
      // Otherwise PopScope can invoke _leaveScreenSafely(), which
      // is designed to save drafts before leaving.
      // ==========================================================

      setState(() {
        _allowPop = true;
        _isNavigating = false;
      });

      Navigator.pop(
        context,
        true,
      );

      return;
    }

    // ==========================================================
    // NORMAL RETURN FROM EVIDENCE
    //
    // Report was NOT submitted.
    // Keep and restore the unfinished draft.
    // ==========================================================

    _isNavigating =
    false;

    await _restoreDraft(
      showRestoreNotice:
      false,
    );
  }

  // ============================================================
  // MEANINGFUL TEXT VALIDATION
  // ============================================================

  String? validateMeaningfulText(
      String value, {
        required String fieldName,
        required int minimumLength,
        required int minimumWords,
      }) {
    final String text =
    value.trim();

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
    ).hasMatch(text)) {
      return 'The $fieldName cannot contain only numbers.';
    }

    // ----------------------------------------------------------
    // SYMBOLS ONLY
    // ----------------------------------------------------------

    if (RegExp(
      r'^[^A-Za-zÀ-ÖØ-öø-ÿ0-9]+$',
    ).hasMatch(text)) {
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
          caseSensitive:
          false,
        ).hasMatch(
          compact,
        )) {
      return 'The $fieldName contains repeated characters '
          'and does not appear to contain meaningful information.';
    }

    // ----------------------------------------------------------
    // LONG REPEATED CHARACTER RUN
    // ----------------------------------------------------------

    if (RegExp(
      r'(.)\1{3,}',
      caseSensitive:
      false,
    ).hasMatch(text)) {
      return 'The $fieldName contains too many repeated characters.';
    }

    // ----------------------------------------------------------
    // SYMBOL RATIO
    // ----------------------------------------------------------

    final int symbolCount =
        RegExp(
          r'[^A-Za-zÀ-ÖØ-öø-ÿ0-9\s]',
        ).allMatches(text).length;

    final double symbolRatio =
        symbolCount /
            text.length;

    if (symbolRatio > 0.30) {
      return 'The $fieldName contains too many symbols.';
    }

    // ----------------------------------------------------------
    // LETTER RATIO
    // ----------------------------------------------------------

    final double letterRatio =
        letterCount /
            text.length;

    if (letterRatio < 0.45) {
      return 'The $fieldName does not contain enough meaningful text.';
    }

    // ----------------------------------------------------------
    // EXTRACT WORDS
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
      word.length >= 2,
    )
        .toList();

    // ----------------------------------------------------------
    // MINIMUM WORD COUNT
    // ----------------------------------------------------------

    if (words.length <
        minimumWords) {
      if (fieldName ==
          'report title') {
        return 'Please enter a meaningful report title '
            'using at least two useful words.';
      }

      return 'Please provide a meaningful description '
          'using at least three useful words.';
    }

    // ----------------------------------------------------------
    // VERY LONG RANDOM SINGLE TOKEN
    // ----------------------------------------------------------

    final String lettersOnly =
    text.replaceAll(
      RegExp(
        r'[^A-Za-zÀ-ÖØ-öø-ÿ]',
      ),
      '',
    );

    if (lettersOnly.length >= 20 &&
        !text.contains(
          RegExp(
            r'\s',
          ),
        )) {
      return 'The $fieldName does not appear to contain '
          'a clear phrase or sentence.';
    }

    // ----------------------------------------------------------
    // RANDOM-LOOKING TOKEN ANALYSIS
    // ----------------------------------------------------------

    int suspiciousWords = 0;

    for (final String word
    in words) {
      final String lower =
      word.toLowerCase();

      if (RegExp(
        r'[bcdfghjklmnpqrstvwxyz]{7,}',
        caseSensitive:
        false,
      ).hasMatch(lower)) {
        suspiciousWords++;
        continue;
      }

      if (lower.length >= 7 &&
          !RegExp(
            r'[aeiou]',
          ).hasMatch(lower)) {
        suspiciousWords++;
      }
    }

    if (words.isNotEmpty &&
        suspiciousWords >=
            words.length) {
      return 'The $fieldName does not appear to contain '
          'meaningful words.';
    }

    return null;
  }

  // ============================================================
  // TITLE CHANGED
  // ============================================================

  void onTitleChanged(
      String value,
      ) {
    if (titleError != null) {
      setState(() {
        titleError = null;
      });
    }

    _scheduleDraftSave();
  }

  // ============================================================
  // DESCRIPTION CHANGED
  // ============================================================

  void onDescriptionChanged(
      String value,
      ) {
    if (descriptionError != null) {
      setState(() {
        descriptionError = null;
      });
    }

    _scheduleDraftSave();
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
  // PRIORITY COLOR
  // ============================================================

  Color getPriorityColor(
      String priority,
      ) {
    switch (priority) {
      case 'Low':
        return const Color(
          0xFF2EE6A6,
        );

      case 'Medium':
        return const Color(
          0xFFFFC62E,
        );

      case 'High':
        return const Color(
          0xFFFF7A32,
        );

      case 'Critical':
        return const Color(
          0xFFFF526D,
        );

      default:
        return AppColors.primary;
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
          bool didPop,
          Object? result,
          ) async {
        if (didPop) {
          return;
        }

        await _leaveScreenSafely();
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
                  const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
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
                              _isNavigating
                                  ? null
                                  : _leaveScreenSafely,

                              icon:
                              const Icon(
                                Icons.arrow_back,
                                color:
                                AppColors.textSecondary,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          const Expanded(
                            child:
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,

                              children: [
                                Text(
                                  'Report Issue',
                                  style:
                                  TextStyle(
                                    fontSize: 22,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                SizedBox(
                                  height: 2,
                                ),

                                Text(
                                  'Help improve your community',
                                  style:
                                  TextStyle(
                                    color:
                                    AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          PopupMenuButton<String>(
                            tooltip:
                            'Report options',

                            color:
                            AppColors.surface,

                            enabled:
                            !_isNavigating,

                            icon:
                            const Icon(
                              Icons.more_vert,
                              color:
                              AppColors.textSecondary,
                            ),

                            onSelected:
                                (
                                value,
                                ) {
                              // ============================================================
                              // PHASE 1A — VOICE TEST
                              // ============================================================

                              if (value ==
                                  'voice_test') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) =>
                                    const VoiceSpeechTestScreen(),
                                  ),
                                );

                                return;
                              }

                              // ============================================================
                              // DISCARD REPORT
                              // ============================================================

                              if (value ==
                                  'discard') {
                                _confirmDiscardDraft();
                              }
                            },

                            itemBuilder:
                                (
                                context,
                                ) {
                              return const [
                                // =========================================================
                                // VOICE TEST
                                // =========================================================

                                PopupMenuItem<String>(
                                  value:
                                  'voice_test',

                                  child:
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.mic_none_rounded,

                                        color:
                                        AppColors.primary,

                                        size:
                                        20,
                                      ),

                                      SizedBox(
                                        width:
                                        10,
                                      ),

                                      Text(
                                        'Voice Test',

                                        style:
                                        TextStyle(
                                          color:
                                          AppColors.primary,

                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // =========================================================
                                // DISCARD REPORT
                                // =========================================================

                                PopupMenuItem<String>(
                                  value:
                                  'discard',

                                  child:
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,

                                        color:
                                        Colors.orangeAccent,

                                        size:
                                        20,
                                      ),

                                      SizedBox(
                                        width:
                                        10,
                                      ),

                                      Text(
                                        'Discard Report',

                                        style:
                                        TextStyle(
                                          color:
                                          Colors.orangeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      // =================================================
                      // PROGRESS
                      // =================================================

                      const _ProgressHeader(
                        currentStep: 1,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // =================================================
                      // SMART DRAFT STATUS
                      // =================================================

                      _DraftStatusCard(
                        isRestoring:
                        _isRestoringDraft,

                        isSaving:
                        _isSavingDraft,

                        saveFailed:
                        _draftSaveFailed,

                        restored:
                        _draftWasRestored,

                        lastSavedAt:
                        _lastDraftSavedAt,
                      ),

                      const SizedBox(
                        height: 26,
                      ),

                      // =================================================
                      // CATEGORY
                      // =================================================

                      const Text(
                        'ISSUE CATEGORY',
                        style:
                        _sectionTitle,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      GridView.builder(
                        shrinkWrap: true,

                        physics:
                        const NeverScrollableScrollPhysics(),

                        itemCount:
                        categories.length,

                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.05,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),

                        itemBuilder:
                            (
                            context,
                            index,
                            ) {
                          final category =
                          categories[index];

                          final String name =
                              category['name'] ??
                                  '';

                          final String icon =
                              category['icon'] ??
                                  '';

                          final bool selected =
                              selectedCategory ==
                                  name;

                          return GestureDetector(
                            onTap:
                            _isRestoringDraft
                                ? null
                                : () {
                              setState(() {
                                selectedCategory =
                                    name;
                              });

                              unawaited(
                                _saveDraftImmediately(
                                  showFailureMessage:
                                  false,
                                ),
                              );
                            },

                            child:
                            AnimatedContainer(
                              duration:
                              const Duration(
                                milliseconds: 160,
                              ),

                              decoration:
                              BoxDecoration(
                                color:
                                selected
                                    ? AppColors.primary
                                    .withOpacity(
                                  0.12,
                                )
                                    : AppColors.surface,

                                borderRadius:
                                BorderRadius.circular(
                                  14,
                                ),

                                border:
                                Border.all(
                                  color:
                                  selected
                                      ? AppColors.primary
                                      : AppColors.border,

                                  width:
                                  selected
                                      ? 1.5
                                      : 1,
                                ),
                              ),

                              child:
                              Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,

                                children: [
                                  Text(
                                    icon,
                                    style:
                                    const TextStyle(
                                      fontSize: 28,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 8,
                                  ),

                                  Padding(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),

                                    child:
                                    Text(
                                      name,

                                      textAlign:
                                      TextAlign.center,

                                      style:
                                      TextStyle(
                                        color:
                                        selected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,

                                        fontSize: 11,

                                        fontWeight:
                                        selected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(
                        height: 26,
                      ),

                      // =================================================
                      // PRIORITY
                      // =================================================

                      const Text(
                        'PRIORITY LEVEL',
                        style:
                        _sectionTitle,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Row(
                        children:
                        priorities.map(
                              (
                              priority,
                              ) {
                            final bool selected =
                                selectedPriority ==
                                    priority;

                            final Color color =
                            getPriorityColor(
                              priority,
                            );

                            return Expanded(
                              child:
                              Padding(
                                padding:
                                const EdgeInsets.only(
                                  right: 7,
                                ),

                                child:
                                GestureDetector(
                                  onTap:
                                  _isRestoringDraft
                                      ? null
                                      : () {
                                    setState(() {
                                      selectedPriority =
                                          priority;
                                    });

                                    unawaited(
                                      _saveDraftImmediately(
                                        showFailureMessage:
                                        false,
                                      ),
                                    );
                                  },

                                  child:
                                  AnimatedContainer(
                                    duration:
                                    const Duration(
                                      milliseconds: 160,
                                    ),

                                    height: 42,

                                    alignment:
                                    Alignment.center,

                                    decoration:
                                    BoxDecoration(
                                      color:
                                      color.withOpacity(
                                        selected
                                            ? 0.17
                                            : 0.08,
                                      ),

                                      borderRadius:
                                      BorderRadius.circular(
                                        12,
                                      ),

                                      border:
                                      Border.all(
                                        color:
                                        selected
                                            ? color
                                            : color.withOpacity(
                                          0.4,
                                        ),
                                      ),
                                    ),

                                    child:
                                    Text(
                                      priority,

                                      style:
                                      TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight:
                                        FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      // =================================================
                      // REPORT TITLE
                      // =================================================

                      const Text(
                        'REPORT TITLE',
                        style:
                        _sectionTitle,
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                        titleController,

                        enabled:
                        !_isRestoringDraft,

                        onChanged:
                        onTitleChanged,

                        maxLength: 100,

                        textCapitalization:
                        TextCapitalization.sentences,

                        style:
                        const TextStyle(
                          color: Colors.white,
                        ),

                        textInputAction:
                        TextInputAction.next,

                        decoration:
                        _inputDecoration(
                          hint:
                          'e.g., Large pothole on Jalan Ampang',
                          errorText:
                          titleError,
                        ),
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      // =================================================
                      // DESCRIPTION
                      // =================================================

                      const Text(
                        'DESCRIPTION',
                        style:
                        _sectionTitle,
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                        descriptionController,

                        enabled:
                        !_isRestoringDraft,

                        onChanged:
                        onDescriptionChanged,

                        maxLength: 500,

                        minLines: 5,
                        maxLines: 7,

                        textCapitalization:
                        TextCapitalization.sentences,

                        style:
                        const TextStyle(
                          color: Colors.white,
                        ),

                        decoration:
                        _inputDecoration(
                          hint:
                          'Describe the issue in detail. '
                              'Include size, severity, and any '
                              'safety concerns...',
                          errorText:
                          descriptionError,
                        ),
                      ),

                      // =================================================
                      // QUALITY GUIDANCE
                      // =================================================

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
                              0.25,
                            ),
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
                              size: 18,
                            ),

                            SizedBox(
                              width: 9,
                            ),

                            Expanded(
                              child:
                              Text(
                                'Both the title and description must '
                                    'clearly describe the infrastructure '
                                    'issue. Random characters, repeated '
                                    'text, or unusable information cannot '
                                    'be submitted.',
                                style:
                                TextStyle(
                                  color:
                                  AppColors.textSecondary,
                                  fontSize: 10,
                                  height: 1.4,
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

              // =====================================================
              // CONTINUE
              // =====================================================

              Container(
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
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

                  height: 56,

                  child:
                  ElevatedButton(
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      AppColors.primaryDark,

                      foregroundColor:
                      Colors.white,

                      disabledBackgroundColor:
                      AppColors.primaryDark
                          .withOpacity(
                        0.45,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),

                    onPressed:
                    _isRestoringDraft ||
                        _isNavigating
                        ? null
                        : continueToEvidence,

                    child:
                    _isNavigating
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color:
                        Colors.white,
                      ),
                    )
                        : const Text(
                      'Continue →',
                      style:
                      TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
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
// SECTION TITLE
// ================================================================

const TextStyle _sectionTitle =
TextStyle(
  color:
  Color(
    0xFFA9C7EF,
  ),
  fontSize: 12,
  fontWeight:
  FontWeight.w600,
  letterSpacing: 0.5,
);

// ================================================================
// INPUT DECORATION
// ================================================================

InputDecoration _inputDecoration({
  required String hint,
  String? errorText,
}) {
  return InputDecoration(
    hintText: hint,

    errorText:
    errorText,

    hintStyle:
    const TextStyle(
      color:
      AppColors.textSecondary,
    ),

    errorStyle:
    const TextStyle(
      color:
      Colors.orangeAccent,
      fontSize: 10,
      height: 1.25,
    ),

    filled: true,

    fillColor:
    AppColors.surface,

    counterStyle:
    const TextStyle(
      color:
      AppColors.textSecondary,
    ),

    contentPadding:
    const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),

    enabledBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        14,
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
        14,
      ),
      borderSide:
      const BorderSide(
        color:
        AppColors.primary,
        width: 1.5,
      ),
    ),

    errorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      borderSide:
      const BorderSide(
        color:
        Colors.orangeAccent,
      ),
    ),

    focusedErrorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      borderSide:
      const BorderSide(
        color:
        Colors.orangeAccent,
        width: 1.5,
      ),
    ),

    disabledBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      borderSide:
      BorderSide(
        color:
        AppColors.border.withOpacity(
          0.6,
        ),
      ),
    ),
  );
}

// ================================================================
// PROGRESS HEADER
// ================================================================

class _ProgressHeader
    extends StatelessWidget {
  final int currentStep;

  const _ProgressHeader({
    required this.currentStep,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      children: [
        _ProgressItem(
          label:
          'Details',
          active:
          currentStep >= 1,
          complete:
          currentStep > 1,
        ),

        _ProgressItem(
          label:
          'Evidence',
          active:
          currentStep >= 2,
          complete:
          currentStep > 2,
        ),

        _ProgressItem(
          label:
          'Location',
          active:
          currentStep >= 3,
          complete:
          currentStep > 3,
        ),
      ],
    );
  }
}

// ================================================================
// PROGRESS ITEM
// ================================================================

class _ProgressItem
    extends StatelessWidget {
  final String label;
  final bool active;
  final bool complete;

  const _ProgressItem({
    required this.label,
    required this.active,
    required this.complete,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Expanded(
      child:
      Column(
        children: [
          Container(
            height: 4,

            margin:
            const EdgeInsets.symmetric(
              horizontal: 4,
            ),

            decoration:
            BoxDecoration(
              color:
              active
                  ? AppColors.primary
                  : AppColors.border,

              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            complete
                ? '✓ $label'
                : label,

            style:
            TextStyle(
              color:
              active
                  ? AppColors.primary
                  : AppColors.textSecondary,

              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SMART DRAFT STATUS CARD
// ================================================================

class _DraftStatusCard
    extends StatelessWidget {
  final bool isRestoring;
  final bool isSaving;
  final bool saveFailed;
  final bool restored;
  final DateTime? lastSavedAt;

  const _DraftStatusCard({
    required this.isRestoring,
    required this.isSaving,
    required this.saveFailed,
    required this.restored,
    required this.lastSavedAt,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    IconData icon;
    String title;
    String subtitle;
    Color statusColor;

    if (isRestoring) {
      icon =
          Icons.sync;

      title =
      'Checking saved progress';

      subtitle =
      'Looking for an unfinished report on this device.';

      statusColor =
          AppColors.primary;
    } else if (isSaving) {
      icon =
          Icons.save_outlined;

      title =
      'Saving report draft';

      subtitle =
      'Your latest changes are being protected automatically.';

      statusColor =
          AppColors.primary;
    } else if (saveFailed) {
      icon =
          Icons.error_outline;

      title =
      'Draft save needs attention';

      subtitle =
      'The latest changes could not be saved locally.';

      statusColor =
          Colors.orangeAccent;
    } else if (lastSavedAt != null) {
      icon =
          Icons.check_circle_outline;

      title =
      restored
          ? 'Draft protected'
          : 'Draft saved';

      subtitle =
      'Last saved ${_formatDraftTime(lastSavedAt!)}';

      statusColor =
      const Color(
        0xFF2EE6A6,
      );
    } else {
      icon =
          Icons.shield_outlined;

      title =
      'Smart Draft Recovery';

      subtitle =
      'Your unfinished report will be saved automatically.';

      statusColor =
          AppColors.primary;
    }

    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 220,
      ),

      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        12,
      ),

      decoration:
      BoxDecoration(
        color:
        statusColor.withOpacity(
          0.07,
        ),

        borderRadius:
        BorderRadius.circular(
          12,
        ),

        border:
        Border.all(
          color:
          statusColor.withOpacity(
            0.30,
          ),
        ),
      ),

      child:
      Row(
        children: [
          if (isSaving ||
              isRestoring)
            SizedBox(
              width: 18,
              height: 18,

              child:
              CircularProgressIndicator(
                strokeWidth: 2,
                color:
                statusColor,
              ),
            )
          else
            Icon(
              icon,
              color:
              statusColor,
              size: 19,
            ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                  TextStyle(
                    color:
                    statusColor,

                    fontSize: 11,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  subtitle,

                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,

                    fontSize: 9,

                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDraftTime(
      DateTime value,
      ) {
    final DateTime now =
    DateTime.now();

    final Duration difference =
    now.difference(
      value,
    );

    if (difference.isNegative) {
      return 'just now';
    }

    if (difference.inSeconds < 60) {
      return 'just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }
}