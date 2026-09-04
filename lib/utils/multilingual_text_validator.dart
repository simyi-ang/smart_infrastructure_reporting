// ================================================================
// MULTILINGUAL TEXT VALIDATOR
// ================================================================
//
// Shared report text-quality validation for:
//
// 1. Manual report title
// 2. Manual report description
// 3. Voice report transcript
//
// Designed for multilingual Malaysian usage including:
//
// - English
// - Bahasa Melayu
// - Chinese
// - Mixed Malay / English
// - Mixed Chinese / English
// - Mixed Chinese / Malay
// - Basic Japanese script handling
// - Basic Korean script handling
//
// IMPORTANT:
//
// This is LOCAL QUALITY VALIDATION.
//
// It checks whether text appears usable enough to continue.
// It does NOT attempt to determine whether the report is factually true,
// whether the infrastructure problem actually exists, or whether a
// category/priority is correct.
//
// Semantic intelligence belongs to the server-side AI layer.
// ================================================================

enum MultilingualTextFieldType {
  reportTitle,
  description,
  voiceTranscript,
}


// ================================================================
// VALIDATION RESULT
// ================================================================
//
// Keeping a structured result makes this validator reusable later
// for:
// - UI quality indicators
// - AI request preparation
// - analytics
// - debugging
//
// Existing screens that only need String? can continue using the
// convenience methods at the bottom.
// ================================================================

class MultilingualValidationResult {
  final bool isValid;

  final String? errorMessage;

  final DetectedWritingSystem writingSystem;

  final int totalCharacters;

  final int meaningfulCharacters;

  final int latinCharacters;

  final int cjkCharacters;

  final int digitCharacters;

  final int symbolCharacters;

  final int whitespaceWordCount;

  final int uniqueWordCount;

  final double symbolRatio;

  final double digitRatio;

  final double repetitionRatio;

  const MultilingualValidationResult({
    required this.isValid,
    required this.errorMessage,
    required this.writingSystem,
    required this.totalCharacters,
    required this.meaningfulCharacters,
    required this.latinCharacters,
    required this.cjkCharacters,
    required this.digitCharacters,
    required this.symbolCharacters,
    required this.whitespaceWordCount,
    required this.uniqueWordCount,
    required this.symbolRatio,
    required this.digitRatio,
    required this.repetitionRatio,
  });
}


// ================================================================
// WRITING SYSTEM
// ================================================================

enum DetectedWritingSystem {
  latin,
  cjk,
  mixed,
  unknown,
}


// ================================================================
// FIELD POLICY
// ================================================================

class _ValidationPolicy {
  final String fieldName;

  final int minimumLatinWords;

  final int minimumLatinCharacters;

  final int minimumCjkCharacters;

  final int minimumMeaningfulCharacters;

  final int maximumCharacters;

  final int minimumUniqueLatinWords;

  final int minimumUniqueCjkCharacters;

  final double maximumSymbolRatio;

  final double maximumDigitRatio;

  final double maximumRepeatedWordRatio;

  final int repeatedWordMinimumOccurrences;

  final int maximumRepeatedCharacterRun;

  final bool rejectUrlOnly;

  final bool rejectEmailOnly;

  const _ValidationPolicy({
    required this.fieldName,
    required this.minimumLatinWords,
    required this.minimumLatinCharacters,
    required this.minimumCjkCharacters,
    required this.minimumMeaningfulCharacters,
    required this.maximumCharacters,
    required this.minimumUniqueLatinWords,
    required this.minimumUniqueCjkCharacters,
    required this.maximumSymbolRatio,
    required this.maximumDigitRatio,
    required this.maximumRepeatedWordRatio,
    required this.repeatedWordMinimumOccurrences,
    required this.maximumRepeatedCharacterRun,
    required this.rejectUrlOnly,
    required this.rejectEmailOnly,
  });
}


// ================================================================
// MAIN VALIDATOR
// ================================================================

class MultilingualTextValidator {
  MultilingualTextValidator._();


  // ============================================================
  // SCRIPT REGEX
  // ============================================================

  static final RegExp _latinRegex =
  RegExp(
    r'[A-Za-zÀ-ÖØ-öø-ÿĀ-ž]',
    unicode: true,
  );


  static final RegExp _chineseRegex =
  RegExp(
    r'[\u3400-\u4DBF'
    r'\u4E00-\u9FFF'
    r'\uF900-\uFAFF]',
    unicode: true,
  );


  static final RegExp _hiraganaKatakanaRegex =
  RegExp(
    r'[\u3040-\u30FF]',
    unicode: true,
  );


  static final RegExp _koreanRegex =
  RegExp(
    r'[\uAC00-\uD7AF]',
    unicode: true,
  );


  static final RegExp _digitRegex =
  RegExp(
    r'[0-9]',
  );


  static final RegExp _whitespaceRegex =
  RegExp(
    r'\s+',
    unicode: true,
  );


  static final RegExp _urlRegex =
  RegExp(
    r'^(https?:\/\/|www\.)\S+$',
    caseSensitive: false,
  );


  static final RegExp _emailRegex =
  RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );


  // ============================================================
  // POLICY
  // ============================================================

  static _ValidationPolicy _policyFor(
      MultilingualTextFieldType type,
      ) {
    switch (type) {
      case MultilingualTextFieldType.reportTitle:
        return const _ValidationPolicy(
          fieldName:
          'report title',

          minimumLatinWords:
          2,

          minimumLatinCharacters:
          5,

          minimumCjkCharacters:
          4,

          minimumMeaningfulCharacters:
          4,

          maximumCharacters:
          100,

          minimumUniqueLatinWords:
          2,

          minimumUniqueCjkCharacters:
          3,

          maximumSymbolRatio:
          0.40,

          maximumDigitRatio:
          0.75,

          maximumRepeatedWordRatio:
          0.65,

          repeatedWordMinimumOccurrences:
          3,

          maximumRepeatedCharacterRun:
          4,

          rejectUrlOnly:
          true,

          rejectEmailOnly:
          true,
        );


      case MultilingualTextFieldType.description:
        return const _ValidationPolicy(
          fieldName:
          'description',

          minimumLatinWords:
          3,

          minimumLatinCharacters:
          10,

          minimumCjkCharacters:
          8,

          minimumMeaningfulCharacters:
          8,

          maximumCharacters:
          500,

          minimumUniqueLatinWords:
          3,

          minimumUniqueCjkCharacters:
          5,

          maximumSymbolRatio:
          0.40,

          maximumDigitRatio:
          0.70,

          maximumRepeatedWordRatio:
          0.55,

          repeatedWordMinimumOccurrences:
          4,

          maximumRepeatedCharacterRun:
          5,

          rejectUrlOnly:
          true,

          rejectEmailOnly:
          true,
        );


      case MultilingualTextFieldType.voiceTranscript:
        return const _ValidationPolicy(
          fieldName:
          'voice report',

          minimumLatinWords:
          6,

          minimumLatinCharacters:
          20,

          minimumCjkCharacters:
          10,

          minimumMeaningfulCharacters:
          12,

          maximumCharacters:
          5000,

          minimumUniqueLatinWords:
          5,

          minimumUniqueCjkCharacters:
          6,

          maximumSymbolRatio:
          0.45,

          maximumDigitRatio:
          0.70,

          maximumRepeatedWordRatio:
          0.45,

          repeatedWordMinimumOccurrences:
          5,

          maximumRepeatedCharacterRun:
          6,

          rejectUrlOnly:
          true,

          rejectEmailOnly:
          true,
        );
    }
  }


  // ============================================================
  // PUBLIC FULL VALIDATION
  // ============================================================

  static MultilingualValidationResult validateDetailed({
    required String value,
    required MultilingualTextFieldType type,
  }) {
    final _ValidationPolicy policy =
    _policyFor(
      type,
    );


    final String text =
    _normalizeText(
      value,
    );


    // ==========================================================
    // EMPTY
    // ==========================================================

    if (text.isEmpty) {
      return _failure(
        policy:
        policy,

        message:
        'Please enter a ${policy.fieldName}.',
      );
    }


    // ==========================================================
    // CHARACTER LIMIT
    // ==========================================================

    if (text.runes.length >
        policy.maximumCharacters) {
      return _failure(
        policy:
        policy,

        message:
        'The ${policy.fieldName} is too long. '
            'Please keep it within ${policy.maximumCharacters} characters.',
      );
    }


    // ==========================================================
    // CHARACTER COUNTS
    // ==========================================================

    final int latinCount =
        _latinRegex
            .allMatches(
          text,
        )
            .length;


    final int chineseCount =
        _chineseRegex
            .allMatches(
          text,
        )
            .length;


    final int japaneseCount =
        _hiraganaKatakanaRegex
            .allMatches(
          text,
        )
            .length;


    final int koreanCount =
        _koreanRegex
            .allMatches(
          text,
        )
            .length;


    final int cjkCount =
        chineseCount +
            japaneseCount +
            koreanCount;


    final int digitCount =
        _digitRegex
            .allMatches(
          text,
        )
            .length;


    final int meaningfulCharacters =
        latinCount +
            cjkCount;


    final DetectedWritingSystem
    writingSystem =
    _detectWritingSystem(
      latinCount:
      latinCount,

      cjkCount:
      cjkCount,
    );


    // ==========================================================
    // WORD ANALYSIS
    // ==========================================================

    final List<String> latinWords =
    _extractLatinWords(
      text,
    );


    final int wordCount =
        latinWords.length;


    final Set<String>
    uniqueLatinWords =
    latinWords
        .map(
          (
          word,
          ) =>
          word.toLowerCase(),
    )
        .where(
          (
          word,
          ) =>
      word.isNotEmpty,
    )
        .toSet();


    final Set<String>
    uniqueCjkCharacters =
    _extractUniqueCjkCharacters(
      text,
    );


    // ==========================================================
    // SYMBOL ANALYSIS
    // ==========================================================

    final int symbolCount =
    _countSymbols(
      text,
    );


    final int totalLength =
        text.runes.length;


    final double symbolRatio =
    totalLength == 0
        ? 0
        : symbolCount /
        totalLength;


    final double digitRatio =
    totalLength == 0
        ? 0
        : digitCount /
        totalLength;


    final double repetitionRatio =
    _calculateHighestWordRepetitionRatio(
      latinWords,
    );


    // ==========================================================
    // BASE RESULT DATA
    // ==========================================================

    MultilingualValidationResult fail(
        String message,
        ) {
      return MultilingualValidationResult(
        isValid:
        false,

        errorMessage:
        message,

        writingSystem:
        writingSystem,

        totalCharacters:
        totalLength,

        meaningfulCharacters:
        meaningfulCharacters,

        latinCharacters:
        latinCount,

        cjkCharacters:
        cjkCount,

        digitCharacters:
        digitCount,

        symbolCharacters:
        symbolCount,

        whitespaceWordCount:
        wordCount,

        uniqueWordCount:
        uniqueLatinWords.length,

        symbolRatio:
        symbolRatio,

        digitRatio:
        digitRatio,

        repetitionRatio:
        repetitionRatio,
      );
    }


    // ==========================================================
    // NO MEANINGFUL SCRIPT
    // ==========================================================

    if (meaningfulCharacters ==
        0) {
      return fail(
        'The ${policy.fieldName} must contain meaningful text.',
      );
    }


    // ==========================================================
    // URL-ONLY
    // ==========================================================

    if (policy.rejectUrlOnly &&
        _urlRegex.hasMatch(
          text,
        )) {
      return fail(
        'Please describe the infrastructure issue instead of entering only a web link.',
      );
    }


    // ==========================================================
    // EMAIL-ONLY
    // ==========================================================

    if (policy.rejectEmailOnly &&
        _emailRegex.hasMatch(
          text,
        )) {
      return fail(
        'Please describe the infrastructure issue instead of entering only an email address.',
      );
    }


    // ==========================================================
    // NUMBER-ONLY / MOSTLY NUMBERS
    // ==========================================================

    if (RegExp(
      r'^[0-9\s.,:/+-]+$',
    ).hasMatch(
      text,
    )) {
      return fail(
        'The ${policy.fieldName} cannot contain only numbers.',
      );
    }


    if (digitRatio >
        policy.maximumDigitRatio) {
      return fail(
        'The ${policy.fieldName} contains too many numbers and not enough descriptive information.',
      );
    }


    // ==========================================================
    // SYMBOL ABUSE
    // ==========================================================

    if (symbolRatio >
        policy.maximumSymbolRatio) {
      return fail(
        'The ${policy.fieldName} contains too many symbols or unusable characters.',
      );
    }


    // ==========================================================
    // REPEATED CHARACTER RUN
    //
    // Examples:
    //
    // aaaaaaaa
    // !!!!!!!!!
    // 哈哈哈哈哈哈哈
    // ==========================================================

    if (_hasExcessiveCharacterRun(
      text,
      maximumAllowedRun:
      policy.maximumRepeatedCharacterRun,
    )) {
      return fail(
        'The ${policy.fieldName} contains too many repeated characters.',
      );
    }


    // ==========================================================
    // SAME CHARACTER ONLY
    // ==========================================================

    if (_isEffectivelySingleRepeatedCharacter(
      text,
    )) {
      return fail(
        'The ${policy.fieldName} does not appear to contain meaningful information.',
      );
    }


    // ==========================================================
    // MINIMUM MEANINGFUL CHARACTER REQUIREMENT
    // ==========================================================

    if (meaningfulCharacters <
        policy.minimumMeaningfulCharacters) {
      return fail(
        'Please provide more meaningful information in the ${policy.fieldName}.',
      );
    }


    // ==========================================================
    // LATIN LANGUAGE VALIDATION
    //
    // Supports:
    //
    // English
    // Bahasa Melayu
    // mixed Malay/English
    //
    // This runs when Latin is the only script OR is sufficiently
    // present in a mixed-script report.
    // ==========================================================

    if (writingSystem ==
        DetectedWritingSystem.latin ||
        writingSystem ==
            DetectedWritingSystem.mixed) {
      final bool enoughLatinToEvaluate =
          latinCount >=
              policy.minimumLatinCharacters ||
              wordCount >=
                  policy.minimumLatinWords;


      if (writingSystem ==
          DetectedWritingSystem.latin &&
          !enoughLatinToEvaluate) {
        return fail(
          'The ${policy.fieldName} is too short to be useful.',
        );
      }


      if (writingSystem ==
          DetectedWritingSystem.latin &&
          wordCount <
              policy.minimumLatinWords) {
        return fail(
          _minimumWordMessage(
            type,
          ),
        );
      }


      if (wordCount >=
          policy.minimumLatinWords &&
          uniqueLatinWords.length <
              policy.minimumUniqueLatinWords) {
        return fail(
          'The ${policy.fieldName} contains too much repeated information.',
        );
      }


      // --------------------------------------------------------
      // REPEATED WORD
      //
      // Example:
      // pothole pothole pothole pothole pothole
      // --------------------------------------------------------

      final int highestFrequency =
      _highestWordFrequency(
        latinWords,
      );


      if (highestFrequency >=
          policy
              .repeatedWordMinimumOccurrences &&
          repetitionRatio >
              policy
                  .maximumRepeatedWordRatio) {
        return fail(
          'The ${policy.fieldName} contains too much repeated text.',
        );
      }


      // --------------------------------------------------------
      // RANDOM LOOKING LATIN TOKENS
      // --------------------------------------------------------

      if (_looksLikeRandomLatinText(
        latinWords,
      )) {
        return fail(
          'The ${policy.fieldName} does not appear to contain clear meaningful words.',
        );
      }


      // --------------------------------------------------------
      // VERY LONG SINGLE TOKEN
      //
      // Example:
      // ajshdkashdkashdkashdkas
      // --------------------------------------------------------

      if (writingSystem ==
          DetectedWritingSystem.latin &&
          latinWords.length <=
              1 &&
          latinCount >=
              18) {
        return fail(
          'The ${policy.fieldName} does not appear to contain a clear phrase or sentence.',
        );
      }
    }


    // ==========================================================
    // CJK VALIDATION
    //
    // Chinese cannot be judged using spaces because:
    //
    // 安邦路附近有一个很大的坑洞
    //
    // is a normal sentence without whitespace.
    // ==========================================================

    if (writingSystem ==
        DetectedWritingSystem.cjk ||
        writingSystem ==
            DetectedWritingSystem.mixed) {
      if (writingSystem ==
          DetectedWritingSystem.cjk &&
          cjkCount <
              policy.minimumCjkCharacters) {
        return fail(
          'Please provide more detail in the ${policy.fieldName}.',
        );
      }


      if (cjkCount >=
          policy.minimumCjkCharacters &&
          uniqueCjkCharacters.length <
              policy
                  .minimumUniqueCjkCharacters) {
        return fail(
          'The ${policy.fieldName} contains too much repeated information.',
        );
      }


      if (_looksLikeRepeatedCjkPattern(
        text,
      )) {
        return fail(
          'The ${policy.fieldName} contains too much repeated information.',
        );
      }
    }


    // ==========================================================
    // MIXED LANGUAGE INFORMATION CHECK
    //
    // Example:
    //
    // Jalan Ampang 的 traffic light 附近有一个大坑洞
    //
    // Neither side should independently need to satisfy the full
    // English or Chinese thresholds if the combined sentence is
    // clearly informative.
    // ==========================================================

    if (writingSystem ==
        DetectedWritingSystem.mixed) {
      final int combinedInformation =
          latinCount +
              cjkCount;


      if (combinedInformation <
          policy.minimumMeaningfulCharacters) {
        return fail(
          'Please provide more detail in the ${policy.fieldName}.',
        );
      }
    }


    // ==========================================================
    // SUCCESS
    // ==========================================================

    return MultilingualValidationResult(
      isValid:
      true,

      errorMessage:
      null,

      writingSystem:
      writingSystem,

      totalCharacters:
      totalLength,

      meaningfulCharacters:
      meaningfulCharacters,

      latinCharacters:
      latinCount,

      cjkCharacters:
      cjkCount,

      digitCharacters:
      digitCount,

      symbolCharacters:
      symbolCount,

      whitespaceWordCount:
      wordCount,

      uniqueWordCount:
      uniqueLatinWords.length,

      symbolRatio:
      symbolRatio,

      digitRatio:
      digitRatio,

      repetitionRatio:
      repetitionRatio,
    );
  }


  // ============================================================
  // SIMPLE PUBLIC APIs
  // ============================================================

  static String? validateReportTitle(
      String value,
      ) {
    return validateDetailed(
      value:
      value,

      type:
      MultilingualTextFieldType.reportTitle,
    ).errorMessage;
  }


  static String? validateDescription(
      String value,
      ) {
    return validateDetailed(
      value:
      value,

      type:
      MultilingualTextFieldType.description,
    ).errorMessage;
  }


  static String? validateVoiceTranscript(
      String value,
      ) {
    return validateDetailed(
      value:
      value,

      type:
      MultilingualTextFieldType.voiceTranscript,
    ).errorMessage;
  }


  // ============================================================
  // NORMALIZE INPUT
  // ============================================================

  static String _normalizeText(
      String value,
      ) {
    return value
        .replaceAll(
      '\u00A0',
      ' ',
    )
        .replaceAll(
      RegExp(
        r'[\r\n\t]+',
      ),
      ' ',
    )
        .replaceAll(
      RegExp(
        r'\s{2,}',
      ),
      ' ',
    )
        .trim();
  }


  // ============================================================
  // WRITING SYSTEM DETECTION
  // ============================================================

  static DetectedWritingSystem
  _detectWritingSystem({
    required int latinCount,
    required int cjkCount,
  }) {
    if (latinCount >
        0 &&
        cjkCount >
            0) {
      return DetectedWritingSystem.mixed;
    }


    if (latinCount >
        0) {
      return DetectedWritingSystem.latin;
    }


    if (cjkCount >
        0) {
      return DetectedWritingSystem.cjk;
    }


    return DetectedWritingSystem.unknown;
  }


  // ============================================================
  // LATIN WORD EXTRACTION
  // ============================================================

  static List<String> _extractLatinWords(
      String text,
      ) {
    return text
        .split(
      _whitespaceRegex,
    )
        .map(
          (
          token,
          ) =>
          token.replaceAll(
            RegExp(
              r'[^A-Za-zÀ-ÖØ-öø-ÿĀ-ž0-9''’-]',
              unicode: true,
            ),
            '',
          ),
    )
        .where(
          (
          token,
          ) =>
      token.length >=
          2,
    )
        .toList();
  }


  // ============================================================
  // UNIQUE CJK CHARACTER EXTRACTION
  // ============================================================

  static Set<String>
  _extractUniqueCjkCharacters(
      String text,
      ) {
    final Set<String> characters =
    <String>{};


    for (final int rune
    in text.runes) {
      final String character =
      String.fromCharCode(
        rune,
      );


      if (_chineseRegex.hasMatch(
        character,
      ) ||
          _hiraganaKatakanaRegex
              .hasMatch(
            character,
          ) ||
          _koreanRegex.hasMatch(
            character,
          )) {
        characters.add(
          character,
        );
      }
    }


    return characters;
  }


  // ============================================================
  // SYMBOL COUNT
  // ============================================================

  static int _countSymbols(
      String text,
      ) {
    int count =
    0;


    for (final int rune
    in text.runes) {
      final String character =
      String.fromCharCode(
        rune,
      );


      if (character.trim().isEmpty) {
        continue;
      }


      if (_latinRegex.hasMatch(
        character,
      ) ||
          _chineseRegex.hasMatch(
            character,
          ) ||
          _hiraganaKatakanaRegex
              .hasMatch(
            character,
          ) ||
          _koreanRegex.hasMatch(
            character,
          ) ||
          _digitRegex.hasMatch(
            character,
          )) {
        continue;
      }


      count++;
    }


    return count;
  }


  // ============================================================
  // WORD FREQUENCY
  // ============================================================

  static int _highestWordFrequency(
      List<String> words,
      ) {
    if (words.isEmpty) {
      return 0;
    }


    final Map<String, int> counts =
    <String, int>{};


    for (final String word
    in words) {
      final String normalized =
      word.toLowerCase();


      counts[normalized] =
          (counts[normalized] ??
              0) +
              1;
    }


    int highest =
    0;


    for (final int value
    in counts.values) {
      if (value >
          highest) {
        highest =
            value;
      }
    }


    return highest;
  }


  // ============================================================
  // REPETITION RATIO
  // ============================================================

  static double
  _calculateHighestWordRepetitionRatio(
      List<String> words,
      ) {
    if (words.isEmpty) {
      return 0;
    }


    return _highestWordFrequency(
      words,
    ) /
        words.length;
  }


  // ============================================================
  // EXCESSIVE CHARACTER RUN
  // ============================================================

  static bool _hasExcessiveCharacterRun(
      String text, {
        required int maximumAllowedRun,
      }) {
    if (text.isEmpty) {
      return false;
    }


    int? previousRune;

    int currentRun =
    0;


    for (final int rune
    in text.runes) {
      if (rune ==
          previousRune) {
        currentRun++;
      } else {
        previousRune =
            rune;

        currentRun =
        1;
      }


      if (currentRun >
          maximumAllowedRun) {
        return true;
      }
    }


    return false;
  }


  // ============================================================
  // ONE CHARACTER REPEATED
  // ============================================================

  static bool
  _isEffectivelySingleRepeatedCharacter(
      String text,
      ) {
    final List<int> meaningfulRunes =
    text.runes
        .where(
          (
          rune,
          ) {
        final String character =
        String.fromCharCode(
          rune,
        );


        return _latinRegex.hasMatch(
          character,
        ) ||
            _chineseRegex.hasMatch(
              character,
            ) ||
            _hiraganaKatakanaRegex
                .hasMatch(
              character,
            ) ||
            _koreanRegex.hasMatch(
              character,
            ) ||
            _digitRegex.hasMatch(
              character,
            );
      },
    )
        .toList();


    if (meaningfulRunes.length <
        4) {
      return false;
    }


    return meaningfulRunes
        .toSet()
        .length ==
        1;
  }


  // ============================================================
  // RANDOM LATIN TEXT DETECTION
  // ============================================================

  static bool _looksLikeRandomLatinText(
      List<String> words,
      ) {
    if (words.isEmpty) {
      return false;
    }


    int suspiciousWords =
    0;


    for (final String original
    in words) {
      final String word =
      original
          .toLowerCase()
          .replaceAll(
        RegExp(
          r'[^a-zà-öø-ÿā-ž]',
          unicode: true,
        ),
        '',
      );


      if (word.length <
          6) {
        continue;
      }


      // --------------------------------------------------------
      // VERY LONG CONSONANT RUN
      // --------------------------------------------------------

      if (RegExp(
        r'[bcdfghjklmnpqrstvwxyz]{7,}',
        caseSensitive: false,
      ).hasMatch(
        word,
      )) {
        suspiciousWords++;

        continue;
      }


      // --------------------------------------------------------
      // LONG TOKEN WITHOUT BASIC VOWEL
      //
      // Do not apply aggressively to short tokens because Malay
      // infrastructure names/acronyms may legitimately differ.
      // --------------------------------------------------------

      if (word.length >=
          8 &&
          !RegExp(
            r'[aeiou]',
            caseSensitive: false,
          ).hasMatch(
            word,
          )) {
        suspiciousWords++;
      }
    }


    if (suspiciousWords ==
        0) {
      return false;
    }


    final double suspiciousRatio =
        suspiciousWords /
            words.length;


    return suspiciousWords >=
        2 &&
        suspiciousRatio >=
            0.65;
  }


  // ============================================================
  // REPEATED CJK PATTERN
  // ============================================================

  static bool _looksLikeRepeatedCjkPattern(
      String text,
      ) {
    final List<String> cjk =
    <String>[];


    for (final int rune
    in text.runes) {
      final String character =
      String.fromCharCode(
        rune,
      );


      if (_chineseRegex.hasMatch(
        character,
      ) ||
          _hiraganaKatakanaRegex
              .hasMatch(
            character,
          ) ||
          _koreanRegex.hasMatch(
            character,
          )) {
        cjk.add(
          character,
        );
      }
    }


    if (cjk.length <
        8) {
      return false;
    }


    // ----------------------------------------------------------
    // ONE CHARACTER DOMINATES MOST OF INPUT
    // ----------------------------------------------------------

    final Map<String, int> frequencies =
    <String, int>{};


    for (final String character
    in cjk) {
      frequencies[character] =
          (frequencies[character] ??
              0) +
              1;
    }


    int highest =
    0;


    for (final int count
    in frequencies.values) {
      if (count >
          highest) {
        highest =
            count;
      }
    }


    if (highest /
        cjk.length >
        0.60) {
      return true;
    }


    // ----------------------------------------------------------
    // REPEATED 2-CHARACTER PATTERN
    //
    // Example:
    // 危险危险危险危险危险
    // ----------------------------------------------------------

    if (cjk.length >=
        10) {
      final String joined =
      cjk.join();


      for (int length =
      1;
      length <=
          3;
      length++) {
        if (joined.length <
            length * 4) {
          continue;
        }


        final String candidate =
        joined.substring(
          0,
          length,
        );


        final StringBuffer rebuilt =
        StringBuffer();


        while (rebuilt.length <
            joined.length) {
          rebuilt.write(
            candidate,
          );
        }


        final String repeated =
        rebuilt
            .toString()
            .substring(
          0,
          joined.length,
        );


        if (repeated ==
            joined) {
          return true;
        }
      }
    }


    return false;
  }


  // ============================================================
  // MINIMUM WORD MESSAGE
  // ============================================================

  static String _minimumWordMessage(
      MultilingualTextFieldType type,
      ) {
    switch (type) {
      case MultilingualTextFieldType.reportTitle:
        return 'Please enter a meaningful report title using at least two useful words.';

      case MultilingualTextFieldType.description:
        return 'Please provide a meaningful description with enough detail about the infrastructure issue.';

      case MultilingualTextFieldType.voiceTranscript:
        return 'Please explain what the infrastructure problem is and provide a little more detail.';
    }
  }


  // ============================================================
  // EARLY FAILURE RESULT
  // ============================================================

  static MultilingualValidationResult
  _failure({
    required _ValidationPolicy policy,
    required String message,
  }) {
    return MultilingualValidationResult(
      isValid:
      false,

      errorMessage:
      message,

      writingSystem:
      DetectedWritingSystem.unknown,

      totalCharacters:
      0,

      meaningfulCharacters:
      0,

      latinCharacters:
      0,

      cjkCharacters:
      0,

      digitCharacters:
      0,

      symbolCharacters:
      0,

      whitespaceWordCount:
      0,

      uniqueWordCount:
      0,

      symbolRatio:
      0,

      digitRatio:
      0,

      repetitionRatio:
      0,
    );
  }
}