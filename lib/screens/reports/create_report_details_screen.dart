import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'create_report_evidence_screen.dart';

// ================================================================
// CREATE REPORT DETAILS SCREEN
//
// Existing design preserved.
//
// Added local report-quality validation for BOTH:
//
// 1. Report title
// 2. Report description
//
// This screen performs fast deterministic validation BEFORE:
// - evidence upload
// - image compression
// - Gemini API analysis
//
// Smart Assist later performs the deeper semantic check.
// ================================================================

class CreateReportDetailsScreen
    extends StatefulWidget {
  const CreateReportDetailsScreen({
    super.key,
  });

  @override
  State<CreateReportDetailsScreen>
  createState() =>
      _CreateReportDetailsScreenState();
}

class _CreateReportDetailsScreenState
    extends State<CreateReportDetailsScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController titleController =
  TextEditingController();

  final TextEditingController descriptionController =
  TextEditingController();

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
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  // ============================================================
  // CONTINUE TO EVIDENCE
  //
  // BOTH title and description must pass meaningful-content
  // validation before navigation.
  // ============================================================

  void continueToEvidence() {
    FocusScope.of(context)
        .unfocus();

    // ==========================================================
    // CATEGORY
    // ==========================================================

    if (selectedCategory == null) {
      showMessage(
        'Please select an issue category.',
      );

      return;
    }

    // ==========================================================
    // PRIORITY
    // ==========================================================

    if (selectedPriority == null) {
      showMessage(
        'Please select a priority level.',
      );

      return;
    }

    // ==========================================================
    // PREPARE USER TEXT
    // ==========================================================

    final String title =
    titleController.text
        .trim();

    final String description =
    descriptionController.text
        .trim();

    // ==========================================================
    // TITLE QUALITY CHECK
    //
    // Title must contain meaningful information.
    // ==========================================================

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

    // ==========================================================
    // DESCRIPTION QUALITY CHECK
    //
    // Description has a slightly higher requirement because
    // responders need enough information to understand the issue.
    // ==========================================================

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

    // ==========================================================
    // UPDATE FIELD ERRORS
    // ==========================================================

    setState(() {
      titleError =
          currentTitleError;

      descriptionError =
          currentDescriptionError;
    });

    // ==========================================================
    // STOP TITLE
    // ==========================================================

    if (currentTitleError != null) {
      showMessage(
        currentTitleError,
      );

      return;
    }

    // ==========================================================
    // STOP DESCRIPTION
    // ==========================================================

    if (currentDescriptionError != null) {
      showMessage(
        currentDescriptionError,
      );

      return;
    }

    // ==========================================================
    // VALID → EVIDENCE
    // ==========================================================

    Navigator.push(
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
  }

  // ============================================================
  // MEANINGFUL TEXT VALIDATOR
  //
  // Used for BOTH title and description.
  //
  // This does NOT attempt to replace Gemini.
  //
  // It catches obvious garbage locally:
  //
  // xxxxx
  // @@@@@@@
  // 123456789
  // asdfghjkl
  // zxcvbnm
  // @@@WWWWijvkjd;clnodflwepwoefkndlv
  //
  // Semantic ambiguity is handled later by Smart Assist.
  // ============================================================

  String? validateMeaningfulText(
      String value, {
        required String fieldName,
        required int minimumLength,
        required int minimumWords,
      }) {
    final String text =
    value.trim();

    // ==========================================================
    // 1. EMPTY
    // ==========================================================

    if (text.isEmpty) {
      return 'Please enter a $fieldName.';
    }

    // ==========================================================
    // 2. MINIMUM LENGTH
    // ==========================================================

    if (text.length <
        minimumLength) {
      return 'The $fieldName is too short to be useful.';
    }

    // ==========================================================
    // 3. MUST CONTAIN LETTERS
    //
    // Supports ordinary English / Malay Latin characters.
    // ==========================================================

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

    if (letterCount ==
        0) {
      return 'The $fieldName must contain meaningful words.';
    }

    // ==========================================================
    // 4. NUMBERS ONLY
    //
    // Reject:
    //
    // 123456789
    // 999999
    // ==========================================================

    if (
    RegExp(
      r'^[0-9\s]+$',
    ).hasMatch(
      text,
    )
    ) {
      return 'The $fieldName cannot contain only numbers.';
    }

    // ==========================================================
    // 5. SYMBOLS ONLY
    //
    // Reject:
    //
    // @@@@@@
    // !!!!!!
    // ###///
    // ==========================================================

    if (
    RegExp(
      r'^[^A-Za-zÀ-ÖØ-öø-ÿ0-9]+$',
    ).hasMatch(
      text,
    )
    ) {
      return 'The $fieldName cannot contain only symbols.';
    }

    // ==========================================================
    // 6. SAME CHARACTER REPEATED AS WHOLE VALUE
    //
    // Reject:
    //
    // xxxxx
    // aaaaa
    // 111111
    // !!!!!!
    // ==========================================================

    final String compact =
    text.replaceAll(
      RegExp(
        r'\s+',
      ),
      '',
    );

    if (
    compact.length >=
        4 &&
        RegExp(
          r'^(.)\1+$',
          caseSensitive:
          false,
        ).hasMatch(
          compact,
        )
    ) {
      return 'The $fieldName contains repeated characters '
          'and does not appear to contain meaningful information.';
    }

    // ==========================================================
    // 7. LONG REPEATED CHARACTER RUN
    //
    // Rejects:
    //
    // WWWWabcd
    // @@@@abc
    // xxxxxroad
    //
    // Three repeated letters such as "ooo" are not automatically
    // blocked; four or more are treated as suspicious.
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
          'characters.';
    }

    // ==========================================================
    // 8. SYMBOL RATIO
    //
    // Some punctuation is normal:
    //
    // "Road damaged near Block A."
    //
    // But text dominated by @#$% etc is rejected.
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

    if (symbolRatio >
        0.30) {
      return 'The $fieldName contains too many symbols.';
    }

    // ==========================================================
    // 9. LETTER RATIO
    //
    // Ensures the input is mostly actual written content.
    // ==========================================================

    final double letterRatio =
        letterCount /
            text.length;

    if (letterRatio <
        0.45) {
      return 'The $fieldName does not contain enough '
          'meaningful text.';
    }

    // ==========================================================
    // 10. EXTRACT WORDS
    //
    // Remove surrounding punctuation from every token.
    // ==========================================================

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

    // ==========================================================
    // 11. MINIMUM MEANINGFUL WORD COUNT
    //
    // Title:
    // minimum 2 words
    //
    // Description:
    // minimum 3 words
    // ==========================================================

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

    // ==========================================================
    // 12. VERY LONG RANDOM SINGLE TOKEN
    //
    // Reject:
    //
    // ijvkjdclnodflwepwoefkndlv
    //
    // Threshold is intentionally high so genuine terms such as
    // "streetlight" are accepted.
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
        20 &&
        !text.contains(
          RegExp(
            r'\s',
          ),
        )
    ) {
      return 'The $fieldName does not appear to contain '
          'a clear phrase or sentence.';
    }

    // ==========================================================
    // 13. RANDOM-LOOKING WORD DETECTION
    //
    // Count suspicious tokens instead of rejecting the entire
    // report because of one unusual word.
    //
    // This reduces false positives.
    // ==========================================================

    int suspiciousWords =
    0;

    for (final String word in words) {
      final String lower =
      word.toLowerCase();

      // ========================================================
      // EXTREMELY LONG CONSONANT SEQUENCE
      //
      // Example:
      //
      // xdfghjklm
      // ========================================================

      if (
      RegExp(
        r'[bcdfghjklmnpqrstvwxyz]{7,}',
        caseSensitive:
        false,
      ).hasMatch(
        lower,
      )
      ) {
        suspiciousWords++;

        continue;
      }

      // ========================================================
      // LONG TOKEN WITHOUT COMMON VOWEL
      //
      // Random keyboard strings often contain no vowels.
      //
      // Only apply to longer words.
      // ========================================================

      if (
      lower.length >=
          7 &&
          !RegExp(
            r'[aeiou]',
          ).hasMatch(
            lower,
          )
      ) {
        suspiciousWords++;
      }
    }

    // ==========================================================
    // 14. IF ALL / MOST WORDS LOOK RANDOM
    //
    // Example:
    //
    // "fkjdl skdlfj"
    //
    // This should fail.
    //
    // But:
    //
    // "road near skdlfj"
    //
    // is not automatically blocked here because Gemini can
    // perform the deeper semantic check.
    // ==========================================================

    if (
    words.isNotEmpty &&
        suspiciousWords >=
            words.length
    ) {
      return 'The $fieldName does not appear to contain '
          'meaningful words.';
    }

    // ==========================================================
    // PASSED LOCAL VALIDATION
    // ==========================================================

    return null;
  }

  // ============================================================
  // TITLE CHANGED
  //
  // Remove old error while user corrects the field.
  // ============================================================

  void onTitleChanged(
      String value,
      ) {
    if (titleError ==
        null) {
      return;
    }

    setState(() {
      titleError =
      null;
    });
  }

  // ============================================================
  // DESCRIPTION CHANGED
  // ============================================================

  void onDescriptionChanged(
      String value,
      ) {
    if (descriptionError ==
        null) {
      return;
    }

    setState(() {
      descriptionError =
      null;
    });
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
                const EdgeInsets.symmetric(
                  horizontal:
                  20,
                  vertical:
                  18,
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
                            onPressed: () {
                              Navigator.pop(
                                context,
                              );
                            },

                            icon:
                            const Icon(
                              Icons.arrow_back,
                              color:
                              AppColors.textSecondary,
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

                    // =================================================
                    // PROGRESS
                    // =================================================

                    const _ProgressHeader(
                      currentStep:
                      1,
                    ),

                    const SizedBox(
                      height:
                      26,
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
                      height:
                      12,
                    ),

                    GridView.builder(
                      shrinkWrap:
                      true,

                      physics:
                      const NeverScrollableScrollPhysics(),

                      itemCount:
                      categories.length,

                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                        3,

                        childAspectRatio:
                        1.05,

                        crossAxisSpacing:
                        10,

                        mainAxisSpacing:
                        10,
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
                          onTap: () {
                            setState(() {
                              selectedCategory =
                                  name;
                            });
                          },

                          child:
                          AnimatedContainer(
                            duration:
                            const Duration(
                              milliseconds:
                              160,
                            ),

                            decoration:
                            BoxDecoration(
                              color:
                              selected
                                  ? AppColors.primary.withOpacity(
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
                                    fontSize:
                                    28,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                  8,
                                ),

                                Padding(
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal:
                                    4,
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

                                      fontSize:
                                      11,

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
                      height:
                      26,
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
                      height:
                      12,
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
                                right:
                                7,
                              ),

                              child:
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedPriority =
                                        priority;
                                  });
                                },

                                child:
                                AnimatedContainer(
                                  duration:
                                  const Duration(
                                    milliseconds:
                                    160,
                                  ),

                                  height:
                                  42,

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
                                      color:
                                      color,

                                      fontSize:
                                      11,

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
                      height:
                      24,
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
                      height:
                      8,
                    ),

                    TextField(
                      controller:
                      titleController,

                      onChanged:
                      onTitleChanged,

                      maxLength:
                      100,

                      textCapitalization:
                      TextCapitalization.sentences,

                      style:
                      const TextStyle(
                        color:
                        Colors.white,
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
                      height:
                      22,
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
                      height:
                      8,
                    ),

                    TextField(
                      controller:
                      descriptionController,

                      onChanged:
                      onDescriptionChanged,

                      maxLength:
                      500,

                      minLines:
                      5,

                      maxLines:
                      7,

                      textCapitalization:
                      TextCapitalization.sentences,

                      style:
                      const TextStyle(
                        color:
                        Colors.white,
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
                        AppColors.primary.withOpacity(
                          0.06,
                        ),

                        borderRadius:
                        BorderRadius.circular(
                          12,
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
                              'Both the title and description must '
                                  'clearly describe the infrastructure '
                                  'issue. Random characters, repeated '
                                  'text, or unusable information cannot '
                                  'be submitted.',

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

                height:
                56,

                child:
                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.primaryDark,

                    foregroundColor:
                    Colors.white,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        15,
                      ),
                    ),
                  ),

                  onPressed:
                  continueToEvidence,

                  child:
                  const Text(
                    'Continue →',

                    style:
                    TextStyle(
                      fontSize:
                      16,

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

  fontSize:
  12,

  fontWeight:
  FontWeight.w600,

  letterSpacing:
  0.5,
);

// ================================================================
// INPUT DECORATION
// ================================================================

InputDecoration _inputDecoration({
  required String hint,
  String? errorText,
}) {
  return InputDecoration(
    hintText:
    hint,

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

      fontSize:
      10,

      height:
      1.25,
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

    contentPadding:
    const EdgeInsets.symmetric(
      horizontal:
      16,

      vertical:
      16,
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

        width:
        1.5,
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

        width:
        1.5,
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
          currentStep >=
              1,

          complete:
          currentStep >
              1,
        ),

        _ProgressItem(
          label:
          'Evidence',

          active:
          currentStep >=
              2,

          complete:
          currentStep >
              2,
        ),

        _ProgressItem(
          label:
          'Location',

          active:
          currentStep >=
              3,

          complete:
          false,
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
            height:
            4,

            margin:
            const EdgeInsets.symmetric(
              horizontal:
              4,
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
            height:
            7,
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

              fontSize:
              10,
            ),
          ),
        ],
      ),
    );
  }
}