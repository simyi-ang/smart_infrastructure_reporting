// ================================================================
// VOICE SPEECH STATE
// ================================================================
//
// PHASE 1A
//
// Immutable state model representing the lifecycle of one
// speech-recognition session.
//
// This model deliberately contains no report-specific logic.
// It can later be reused by:
//
// - Voice Quick Report
// - accessibility input
// - worker voice notes
// - search-by-voice
//
// ================================================================

enum VoiceSpeechStatus {
  uninitialized,
  initializing,
  ready,
  listening,
  processing,
  stopped,
  unavailable,
  permissionDenied,
  error,
}


// ================================================================
// VOICE SPEECH STATE
// ================================================================

class VoiceSpeechState {
  final VoiceSpeechStatus status;

  /// Last confirmed/final recognition result.
  final String transcript;

  /// Current non-final recognition result.
  final String partialTranscript;

  /// Human-friendly error shown by UI.
  final String? errorMessage;

  /// Native/raw recognizer error useful for debugging.
  final String? technicalError;

  /// Current recognition locale.
  final String? localeId;

  /// Confidence returned by recognizer where supported.
  ///
  /// 0.0 means unavailable/not reported.
  final double confidence;

  /// Whether the last result was final.
  final bool isFinal;

  /// Approximate current microphone sound level.
  final double soundLevel;

  /// Highest observed sound level for current session.
  final double peakSoundLevel;

  /// Start time for the current recognition session.
  final DateTime? startedAt;

  /// End time for the current recognition session.
  final DateTime? endedAt;

  /// Number of recognition callbacks received.
  final int resultCount;

  const VoiceSpeechState({
    required this.status,
    this.transcript = '',
    this.partialTranscript = '',
    this.errorMessage,
    this.technicalError,
    this.localeId,
    this.confidence = 0.0,
    this.isFinal = false,
    this.soundLevel = 0.0,
    this.peakSoundLevel = 0.0,
    this.startedAt,
    this.endedAt,
    this.resultCount = 0,
  });


  // ==============================================================
  // DERIVED STATE
  // ==============================================================

  bool get isReady {
    return status ==
        VoiceSpeechStatus.ready ||
        status ==
            VoiceSpeechStatus.stopped;
  }

  bool get isListening {
    return status ==
        VoiceSpeechStatus.listening;
  }

  bool get isBusy {
    return status ==
        VoiceSpeechStatus.initializing ||
        status ==
            VoiceSpeechStatus.listening ||
        status ==
            VoiceSpeechStatus.processing;
  }

  bool get hasError {
    return status ==
        VoiceSpeechStatus.error ||
        status ==
            VoiceSpeechStatus.permissionDenied ||
        status ==
            VoiceSpeechStatus.unavailable;
  }

  bool get hasFinalTranscript {
    return transcript
        .trim()
        .isNotEmpty;
  }

  bool get hasPartialTranscript {
    return partialTranscript
        .trim()
        .isNotEmpty;
  }

  bool get hasTranscript {
    return hasFinalTranscript ||
        hasPartialTranscript;
  }

  String get displayedTranscript {
    if (partialTranscript
        .trim()
        .isNotEmpty) {
      return partialTranscript.trim();
    }

    return transcript.trim();
  }

  Duration? get sessionDuration {
    final DateTime? start =
        startedAt;

    if (start == null) {
      return null;
    }

    final DateTime end =
        endedAt ??
            DateTime.now();

    return end.difference(
      start,
    );
  }


  // ==============================================================
  // COPY
  // ==============================================================

  VoiceSpeechState copyWith({
    VoiceSpeechStatus? status,
    String? transcript,
    String? partialTranscript,
    String? errorMessage,
    String? technicalError,
    bool clearError = false,
    String? localeId,
    double? confidence,
    bool? isFinal,
    double? soundLevel,
    double? peakSoundLevel,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    int? resultCount,
  }) {
    return VoiceSpeechState(
      status:
      status ??
          this.status,

      transcript:
      transcript ??
          this.transcript,

      partialTranscript:
      partialTranscript ??
          this.partialTranscript,

      errorMessage:
      clearError
          ? null
          : errorMessage ??
          this.errorMessage,

      technicalError:
      clearError
          ? null
          : technicalError ??
          this.technicalError,

      localeId:
      localeId ??
          this.localeId,

      confidence:
      confidence ??
          this.confidence,

      isFinal:
      isFinal ??
          this.isFinal,

      soundLevel:
      soundLevel ??
          this.soundLevel,

      peakSoundLevel:
      peakSoundLevel ??
          this.peakSoundLevel,

      startedAt:
      startedAt ??
          this.startedAt,

      endedAt:
      clearEndedAt
          ? null
          : endedAt ??
          this.endedAt,

      resultCount:
      resultCount ??
          this.resultCount,
    );
  }
}