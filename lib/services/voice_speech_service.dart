import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/voice_speech_state.dart';


// ================================================================
// VOICE SPEECH SERVICE
// ================================================================
//
// PHASE 1A — SPEECH FOUNDATION
//
// RESPONSIBILITIES:
//
// 1. Initialize speech engine only once.
// 2. Prevent simultaneous recognition sessions.
// 3. Handle microphone permission failures.
// 4. Support Bluetooth microphones through Android.
// 5. Detect system locale.
// 6. Expose installed recognition locales.
// 7. Produce partial speech results.
// 8. Produce final speech results.
// 9. Track recognition confidence.
// 10. Track microphone sound level.
// 11. Track session timing.
// 12. Map platform errors to citizen-friendly messages.
// 13. Safely stop/cancel recognition.
// 14. Prevent callbacks after disposal.
// 15. Keep speech completely separate from ReportDraft / Supabase.
//
// ================================================================

class VoiceSpeechService {
  VoiceSpeechService._();

  static final VoiceSpeechService instance =
  VoiceSpeechService._();


  // ==============================================================
  // SPEECH ENGINE
  // ==============================================================

  final SpeechToText _speech =
  SpeechToText();


  // ==============================================================
  // STATE STREAM
  // ==============================================================

  final StreamController<VoiceSpeechState>
  _stateController =
  StreamController<VoiceSpeechState>.broadcast();

  VoiceSpeechState _state =
  const VoiceSpeechState(
    status:
    VoiceSpeechStatus.uninitialized,
  );

  Stream<VoiceSpeechState> get states =>
      _stateController.stream;

  VoiceSpeechState get state =>
      _state;


  // ==============================================================
  // SERVICE STATE
  // ==============================================================

  bool _initialized =
  false;

  bool _disposed =
  false;

  bool _stopRequested =
  false;

  Future<bool>? _initializationFuture;

  String _latestRecognizedWords =
      '';

  List<LocaleName> _locales =
  const [];


  // ==============================================================
  // PUBLIC GETTERS
  // ==============================================================

  bool get isInitialized =>
      _initialized;

  bool get isListening =>
      _speech.isListening;

  bool get isAvailable =>
      _initialized;

  List<LocaleName> get availableLocales =>
      List<LocaleName>.unmodifiable(
        _locales,
      );


  // ==============================================================
  // INITIALIZE
  // ==============================================================

  Future<bool> initialize() {
    if (_disposed) {
      return Future<bool>.value(
        false,
      );
    }

    // ------------------------------------------------------------
    // ALREADY READY
    // ------------------------------------------------------------

    if (_initialized) {
      return Future<bool>.value(
        true,
      );
    }

    // ------------------------------------------------------------
    // ANOTHER CALL ALREADY INITIALIZING
    // ------------------------------------------------------------

    final Future<bool>? pending =
        _initializationFuture;

    if (pending != null) {
      return pending;
    }

    final Future<bool> operation =
    _performInitialization();

    _initializationFuture =
        operation;

    return operation;
  }


  Future<bool> _performInitialization() async {
    _emit(
      _state.copyWith(
        status:
        VoiceSpeechStatus.initializing,

        clearError:
        true,
      ),
    );

    try {
      // ==========================================================
      // NATIVE INITIALIZATION
      // ==========================================================

      final bool available =
      await _speech.initialize(
        onStatus:
        _handleStatus,

        onError:
        _handleError,

        debugLogging:
        kDebugMode,
      );

      // ==========================================================
      // NOT AVAILABLE
      // ==========================================================

      if (!available) {
        _initialized =
        false;

        _emit(
          _state.copyWith(
            status:
            VoiceSpeechStatus.unavailable,

            errorMessage:
            'Speech recognition is not available on this device.',

            technicalError:
            'SpeechToText.initialize returned false.',
          ),
        );

        return false;
      }

      _initialized =
      true;


      // ==========================================================
      // SYSTEM LOCALE
      // ==========================================================

      String? systemLocaleId;

      try {
        final LocaleName? locale =
        await _speech.systemLocale();

        systemLocaleId =
            locale?.localeId;
      } catch (error) {
        debugPrint(
          '[VOICE] Unable to load system locale: $error',
        );
      }


      // ==========================================================
      // AVAILABLE LOCALES
      // ==========================================================

      try {
        final List<LocaleName> locales =
        await _speech.locales();

        // Remove duplicate locale IDs defensively.
        final Map<String, LocaleName>
        uniqueLocales =
        <String, LocaleName>{};

        for (final LocaleName locale
        in locales) {
          uniqueLocales[
          locale.localeId] =
              locale;
        }

        _locales =
        uniqueLocales.values
            .toList()
          ..sort(
                (
                LocaleName a,
                LocaleName b,
                ) {
              return a.name
                  .toLowerCase()
                  .compareTo(
                b.name
                    .toLowerCase(),
              );
            },
          );
      } catch (error) {
        debugPrint(
          '[VOICE] Unable to load speech locales: $error',
        );

        _locales =
        const [];
      }


      // ==========================================================
      // READY
      // ==========================================================

      _emit(
        _state.copyWith(
          status:
          VoiceSpeechStatus.ready,

          localeId:
          systemLocaleId,

          clearError:
          true,
        ),
      );

      debugPrint(
        '[VOICE] Speech initialized.',
      );

      debugPrint(
        '[VOICE] System locale: $systemLocaleId',
      );

      debugPrint(
        '[VOICE] Available locales: ${_locales.length}',
      );

      return true;
    } catch (error, stackTrace) {
    _initialized =
    false;

    debugPrint(
    '[VOICE] Initialization exception: $error',
    );

    debugPrint(
    '$stackTrace',
    );

    _emit(
    _state.copyWith(
    status:
    VoiceSpeechStatus.error,

    errorMessage:
    'Voice recognition could not be initialized.',

    technicalError:
    error.toString(),
    ),
    );

    return false;
    } finally {
    _initializationFuture =
    null;
    }
  }


  // ==============================================================
  // START LISTENING
  // ==============================================================

  Future<bool> startListening({
    String? localeId,

    Duration listenFor =
    const Duration(
      seconds: 45,
    ),

    Duration pauseFor =
    const Duration(
      seconds: 4,
    ),
  }) async {
    if (_disposed) {
      return false;
    }


    // ============================================================
    // ENSURE INITIALIZATION
    // ============================================================

    if (!_initialized) {
      final bool initialized =
      await initialize();

      if (!initialized) {
        return false;
      }
    }


    // ============================================================
    // DUPLICATE SESSION PROTECTION
    // ============================================================

    if (_speech.isListening) {
      debugPrint(
        '[VOICE] Ignored duplicate start request.',
      );

      return true;
    }


    // ============================================================
    // VALIDATE REQUESTED LOCALE
    // ============================================================

    String? effectiveLocale =
        localeId;

    if (effectiveLocale != null &&
        _locales.isNotEmpty) {
      final bool supported =
      _locales.any(
            (
            LocaleName locale,
            ) =>
        locale.localeId ==
            effectiveLocale,
      );

      if (!supported) {
        effectiveLocale =
            _state.localeId;

        debugPrint(
          '[VOICE] Requested locale not installed. '
              'Falling back to system locale.',
        );
      }
    }


    // ============================================================
    // RESET SESSION STATE
    // ============================================================

    _stopRequested =
    false;

    _latestRecognizedWords =
    '';

    final DateTime now =
    DateTime.now();

    _emit(
      VoiceSpeechState(
        status:
        VoiceSpeechStatus.listening,

        transcript:
        '',

        partialTranscript:
        '',

        localeId:
        effectiveLocale ??
            _state.localeId,

        confidence:
        0.0,

        isFinal:
        false,

        soundLevel:
        0.0,

        peakSoundLevel:
        0.0,

        startedAt:
        now,

        endedAt:
        null,

        resultCount:
        0,
      ),
    );


    // ============================================================
    // NATIVE LISTEN
    // ============================================================

    try {
      await _speech.listen(
        onResult:
        _handleResult,

        onSoundLevelChange:
        _handleSoundLevel,

        listenOptions:
        SpeechListenOptions(
          listenMode:
          ListenMode.dictation,

          partialResults:
          true,

          cancelOnError:
          true,

          onDevice:
          false,

          pauseFor:
          pauseFor,

          listenFor:
          listenFor,

          localeId:
          effectiveLocale,
        ),
      );

      debugPrint(
        '[VOICE] Listening started.',
      );

      return true;
    } catch (error, stackTrace) {
    debugPrint(
    '[VOICE] Listen exception: $error',
    );

    debugPrint(
    '$stackTrace',
    );

    _emit(
    _state.copyWith(
    status:
    VoiceSpeechStatus.error,

    errorMessage:
    'The microphone could not start listening.',

    technicalError:
    error.toString(),

    endedAt:
    DateTime.now(),
    ),
    );

    return false;
    }
  }


  // ==============================================================
  // RECOGNITION RESULT
  // ==============================================================

  void _handleResult(
      SpeechRecognitionResult result,
      ) {
    if (_disposed) {
      return;
    }

    final String recognized =
    result.recognizedWords
        .trim();

    if (recognized.isEmpty) {
      return;
    }

    _latestRecognizedWords =
        recognized;


    // ============================================================
    // CONFIDENCE
    // ============================================================

    final double confidence =
    result.hasConfidenceRating
        ? result.confidence
        : 0.0;


    // ============================================================
    // FINAL RESULT
    // ============================================================

    if (result.finalResult) {
      _emit(
        _state.copyWith(
          transcript:
          recognized,

          partialTranscript:
          '',

          confidence:
          confidence,

          isFinal:
          true,

          resultCount:
          _state.resultCount +
              1,

          clearError:
          true,
        ),
      );

      debugPrint(
        '[VOICE] Final transcript: $recognized',
      );

      return;
    }


    // ============================================================
    // PARTIAL RESULT
    // ============================================================

    _emit(
      _state.copyWith(
        status:
        VoiceSpeechStatus.listening,

        partialTranscript:
        recognized,

        confidence:
        confidence,

        isFinal:
        false,

        resultCount:
        _state.resultCount +
            1,

        clearError:
        true,
      ),
    );
  }


  // ==============================================================
  // SOUND LEVEL
  // ==============================================================

  void _handleSoundLevel(
      double level,
      ) {
    if (_disposed ||
        !_speech.isListening) {
      return;
    }

    final double peak =
    level >
        _state.peakSoundLevel
        ? level
        : _state.peakSoundLevel;

    _emit(
      _state.copyWith(
        soundLevel:
        level,

        peakSoundLevel:
        peak,
      ),
    );
  }


  // ==============================================================
  // STOP LISTENING
  // ==============================================================

  Future<void> stopListening() async {
    if (_disposed) {
      return;
    }

    if (_stopRequested) {
      return;
    }

    _stopRequested =
    true;

    if (!_speech.isListening) {
      _finalizeSession();

      return;
    }

    _emit(
      _state.copyWith(
        status:
        VoiceSpeechStatus.processing,
      ),
    );

    try {
      await _speech.stop();

      // Give native recognizer a short opportunity to deliver
      // its final callback before freezing our current transcript.
      await Future<void>.delayed(
        const Duration(
          milliseconds: 250,
        ),
      );

      if (_disposed) {
        return;
      }

      _finalizeSession();
    } catch (error) {
      debugPrint(
        '[VOICE] Stop exception: $error',
      );

      _emit(
        _state.copyWith(
          status:
          VoiceSpeechStatus.error,

          errorMessage:
          'Voice recognition could not be stopped safely.',

          technicalError:
          error.toString(),

          endedAt:
          DateTime.now(),
        ),
      );
    } finally {
      _stopRequested =
      false;
    }
  }


  // ==============================================================
  // FINALIZE SESSION
  // ==============================================================

  void _finalizeSession() {
    String transcript =
    _state.transcript.trim();

    if (transcript.isEmpty) {
      transcript =
          _latestRecognizedWords.trim();
    }

    if (transcript.isEmpty) {
      transcript =
          _state.partialTranscript.trim();
    }

    _emit(
      _state.copyWith(
        status:
        VoiceSpeechStatus.stopped,

        transcript:
        transcript,

        partialTranscript:
        '',

        isFinal:
        transcript.isNotEmpty,

        soundLevel:
        0.0,

        endedAt:
        DateTime.now(),
      ),
    );
  }


  // ==============================================================
  // CANCEL SESSION
  // ==============================================================

  Future<void> cancelListening() async {
    if (_disposed) {
      return;
    }

    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (error) {
      debugPrint(
        '[VOICE] Cancel exception: $error',
      );
    }

    _latestRecognizedWords =
    '';

    _stopRequested =
    false;

    _emit(
      VoiceSpeechState(
        status:
        _initialized
            ? VoiceSpeechStatus.ready
            : VoiceSpeechStatus.uninitialized,

        localeId:
        _state.localeId,
      ),
    );
  }


  // ==============================================================
  // CLEAR TRANSCRIPT
  // ==============================================================

  void clearTranscript() {
    if (_disposed ||
        _speech.isListening) {
      return;
    }

    _latestRecognizedWords =
    '';

    _emit(
      VoiceSpeechState(
        status:
        _initialized
            ? VoiceSpeechStatus.ready
            : VoiceSpeechStatus.uninitialized,

        localeId:
        _state.localeId,
      ),
    );
  }


  // ==============================================================
  // CHANGE DEFAULT LOCALE
  // ==============================================================

  bool selectLocale(
      String localeId,
      ) {
    if (_disposed ||
        _speech.isListening) {
      return false;
    }

    final bool supported =
    _locales.any(
          (
          LocaleName locale,
          ) =>
      locale.localeId ==
          localeId,
    );

    if (!supported) {
      return false;
    }

    _emit(
      _state.copyWith(
        localeId:
        localeId,
      ),
    );

    return true;
  }


  // ==============================================================
  // STATUS CALLBACK
  // ==============================================================

  void _handleStatus(
      String status,
      ) {
    if (_disposed) {
      return;
    }

    debugPrint(
      '[VOICE STATUS] $status',
    );

    final String normalized =
    status.toLowerCase();


    // ============================================================
    // LISTENING
    // ============================================================

    if (normalized ==
        SpeechToText.listeningStatus
            .toLowerCase() ||
        normalized ==
            'listening') {
      if (_state.status !=
          VoiceSpeechStatus.listening) {
        _emit(
          _state.copyWith(
            status:
            VoiceSpeechStatus.listening,
          ),
        );
      }

      return;
    }


    // ============================================================
    // DONE / NOT LISTENING
    // ============================================================

    if (normalized ==
        SpeechToText.doneStatus
            .toLowerCase() ||
        normalized ==
            SpeechToText.notListeningStatus
                .toLowerCase() ||
        normalized.contains(
          'done',
        ) ||
        normalized.contains(
          'notlistening',
        )) {
      if (_state.status ==
          VoiceSpeechStatus.error ||
          _state.status ==
              VoiceSpeechStatus.permissionDenied) {
        return;
      }

      // Avoid destroying a processing state while stop()
      // is still waiting for the final recognition callback.
      if (_stopRequested) {
        return;
      }

      _finalizeSession();
    }
  }


  // ==============================================================
  // ERROR CALLBACK
  // ==============================================================

  void _handleError(
      SpeechRecognitionError error,
      ) {
    if (_disposed) {
      return;
    }

    final String raw =
        error.errorMsg;

    final String normalized =
    raw.toLowerCase();

    debugPrint(
      '[VOICE ERROR] '
          '$raw | permanent=${error.permanent}',
    );


    VoiceSpeechStatus status =
        VoiceSpeechStatus.error;

    String friendlyMessage =
        'Voice recognition failed. Please try again.';


    // ============================================================
    // PERMISSION
    // ============================================================

    if (normalized.contains(
      'permission',
    ) ||
        normalized.contains(
          'not_allowed',
        ) ||
        normalized.contains(
          'not allowed',
        )) {
      status =
          VoiceSpeechStatus.permissionDenied;

      friendlyMessage =
      'Microphone permission is required to use Voice Quick Report.';
    }


    // ============================================================
    // NOTHING RECOGNIZED
    // ============================================================

    else if (normalized.contains(
      'no_match',
    )) {
      friendlyMessage =
      'No clear speech was detected. '
          'Try speaking closer to the microphone.';
    }


    // ============================================================
    // NETWORK
    // ============================================================

    else if (normalized.contains(
      'network',
    )) {
      friendlyMessage =
      'The speech recognition service could not be reached. '
          'Check your connection and try again.';
    }


    // ============================================================
    // LANGUAGE
    // ============================================================

    else if (normalized.contains(
      'language_not_supported',
    ) ||
        normalized.contains(
          'language_unavailable',
        ) ||
        normalized.contains(
          'language',
        )) {
      friendlyMessage =
      'This speech language is not available on the device.';
    }


    // ============================================================
    // BUSY
    // ============================================================

    else if (normalized.contains(
      'busy',
    )) {
      friendlyMessage =
      'The device speech recognizer is currently busy. '
          'Please try again.';
    }


    // ============================================================
    // SERVER
    // ============================================================

    else if (normalized.contains(
      'server',
    )) {
      friendlyMessage =
      'The speech recognition service is temporarily unavailable.';
    }


    // ============================================================
    // TOO MANY REQUESTS
    // ============================================================

    else if (normalized.contains(
      'too_many_requests',
    )) {
      friendlyMessage =
      'Too many voice recognition requests were made. '
          'Please try again shortly.';
    }


    _emit(
      _state.copyWith(
        status:
        status,

        errorMessage:
        friendlyMessage,

        technicalError:
        raw,

        soundLevel:
        0.0,

        endedAt:
        DateTime.now(),
      ),
    );
  }


  // ==============================================================
  // EMIT STATE
  // ==============================================================

  void _emit(
      VoiceSpeechState newState,
      ) {
    if (_disposed) {
      return;
    }

    _state =
        newState;

    if (!_stateController.isClosed) {
      _stateController.add(
        newState,
      );
    }
  }


  // ==============================================================
  // DISPOSE
  // ==============================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (_) {
      // Cleanup must never crash application shutdown.
    }

    _disposed =
    true;

    await _stateController.close();
  }
}