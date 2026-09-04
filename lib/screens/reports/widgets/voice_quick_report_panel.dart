import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../models/voice_speech_state.dart';
import '../../../services/voice_speech_service.dart';
import '../../../theme/app_colors.dart';


// ================================================================
// VOICE QUICK REPORT PANEL
// ================================================================
//
// PHASE 1B — PRODUCTION VOICE INPUT UI
//
// PURPOSE:
//
// Provides a production-quality citizen-facing voice interface
// while keeping speech recognition isolated from report fields.
//
// THIS PHASE DOES:
//
// 1. Speech initialization.
// 2. Language selection.
// 3. Start / stop / cancel.
// 4. Live partial transcript.
// 5. Final transcript review.
// 6. Recognition confidence.
// 7. Session duration.
// 8. Microphone activity visualization.
// 9. Speech guidance.
// 10. Error recovery.
// 11. Retry workflow.
// 12. Safe lifecycle microphone cleanup.
// 13. Citizen confirmation of transcript.
//
// THIS PHASE DOES NOT:
//
// - call Groq
// - call Supabase
// - select report category
// - select report priority
// - generate report title
// - generate report description
// - write voice data to ReportDraft
// - silently overwrite citizen input
//
// ================================================================

class VoiceQuickReportPanel
    extends StatefulWidget {

  /// Called only when the citizen explicitly confirms that
  /// the transcript should be retained for the next voice stage.
  ///
  /// Phase 1B:
  /// Parent stores this in memory only.
  ///
  /// Phase 1C:
  /// This callback can be connected to formal transcript review.
  final ValueChanged<String>?
  onTranscriptAccepted;

  const VoiceQuickReportPanel({
    super.key,
    this.onTranscriptAccepted,
  });

  @override
  State<VoiceQuickReportPanel>
  createState() =>
      _VoiceQuickReportPanelState();
}


class _VoiceQuickReportPanelState
    extends State<VoiceQuickReportPanel>
    with WidgetsBindingObserver {

  // ==============================================================
  // SPEECH SERVICE
  // ==============================================================

  final VoiceSpeechService _speech =
      VoiceSpeechService.instance;

  StreamSubscription<VoiceSpeechState>?
  _speechSubscription;

  VoiceSpeechState _speechState =
  const VoiceSpeechState(
    status:
    VoiceSpeechStatus.uninitialized,
  );


  // ==============================================================
  // LOCAL UI STATE
  // ==============================================================

  bool _starting =
  false;

  bool _initializing =
  false;

  bool _transcriptAccepted =
  false;

  Timer? _displayTimer;

  Duration _liveDuration =
      Duration.zero;


  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    _speechState =
        _speech.state;

    _speechSubscription =
        _speech.states.listen(
          _handleSpeechState,
        );

    unawaited(
      _initializeSpeech(),
    );
  }


  // ==============================================================
  // APP LIFECYCLE
  // ==============================================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(
      state,
    );

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:

      // --------------------------------------------------------
      // PRIVACY / RESOURCE PROTECTION
      //
      // Never leave microphone recognition active when the app
      // is no longer in the foreground.
      // --------------------------------------------------------

        if (_speech.isListening) {
          unawaited(
            _speech.stopListening(),
          );
        }

        break;

      case AppLifecycleState.resumed:
        break;
    }
  }


  // ==============================================================
  // INITIALIZE SPEECH
  // ==============================================================

  Future<void> _initializeSpeech() async {
    if (_initializing) {
      return;
    }

    _initializing =
    true;

    try {
      await _speech.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _speechState =
            _speech.state;
      });
    } finally {
      _initializing =
      false;
    }
  }


  // ==============================================================
  // SPEECH STATE CALLBACK
  // ==============================================================

  void _handleSpeechState(
      VoiceSpeechState state,
      ) {
    if (!mounted) {
      return;
    }

    final bool wasListening =
        _speechState.isListening;

    final bool nowListening =
        state.isListening;

    setState(() {
      _speechState =
          state;

      if (nowListening) {
        _transcriptAccepted =
        false;
      }
    });

    if (!wasListening &&
        nowListening) {
      _startDisplayTimer();
    }

    if (wasListening &&
        !nowListening) {
      _stopDisplayTimer();
    }
  }


  // ==============================================================
  // SESSION DISPLAY TIMER
  // ==============================================================

  void _startDisplayTimer() {
    _displayTimer?.cancel();

    _liveDuration =
        Duration.zero;

    _displayTimer =
        Timer.periodic(
          const Duration(
            seconds: 1,
          ),
              (_) {
            if (!mounted) {
              return;
            }

            final Duration? actual =
                _speech.state.sessionDuration;

            setState(() {
              _liveDuration =
                  actual ??
                      _liveDuration +
                          const Duration(
                            seconds: 1,
                          );
            });
          },
        );
  }


  void _stopDisplayTimer() {
    _displayTimer?.cancel();
    _displayTimer =
    null;

    if (!mounted) {
      return;
    }

    final Duration? duration =
        _speech.state.sessionDuration;

    if (duration != null) {
      setState(() {
        _liveDuration =
            duration;
      });
    }
  }


  // ==============================================================
  // START LISTENING
  // ==============================================================

  Future<void> _startListening() async {
    if (_starting ||
        _speech.isListening) {
      return;
    }

    setState(() {
      _starting =
      true;

      _transcriptAccepted =
      false;
    });

    try {
      await _speech.startListening(
        localeId:
        _speechState.localeId,

        // --------------------------------------------------------
        // PHASE 1B:
        // Allow a citizen to provide a detailed report.
        // --------------------------------------------------------

        listenFor:
        const Duration(
          seconds: 60,
        ),

        pauseFor:
        const Duration(
          seconds: 6,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _starting =
          false;
        });
      }
    }
  }


  // ==============================================================
  // STOP LISTENING
  // ==============================================================

  Future<void> _stopListening() async {
    if (!_speech.isListening) {
      return;
    }

    await _speech.stopListening();
  }


  // ==============================================================
  // CANCEL
  // ==============================================================

  Future<void> _cancelListening() async {
    if (!_speech.isListening) {
      return;
    }

    await _speech.cancelListening();

    if (!mounted) {
      return;
    }

    setState(() {
      _transcriptAccepted =
      false;

      _liveDuration =
          Duration.zero;
    });
  }


  // ==============================================================
  // CLEAR / RETRY
  // ==============================================================

  void _clearTranscript() {
    if (_speech.isListening) {
      return;
    }

    _speech.clearTranscript();

    setState(() {
      _transcriptAccepted =
      false;

      _liveDuration =
          Duration.zero;
    });
  }


  Future<void> _retry() async {
    if (_speech.isListening) {
      await _speech.cancelListening();
    }

    _speech.clearTranscript();

    if (!mounted) {
      return;
    }

    setState(() {
      _transcriptAccepted =
      false;

      _liveDuration =
          Duration.zero;
    });

    await _startListening();
  }


  // ==============================================================
  // ACCEPT TRANSCRIPT
  // ==============================================================

  void _acceptTranscript() {
    final String transcript =
    _speechState.transcript
        .trim();

    if (transcript.isEmpty) {
      return;
    }

    setState(() {
      _transcriptAccepted =
      true;
    });

    widget.onTranscriptAccepted
        ?.call(
      transcript,
    );
  }


  // ==============================================================
  // LANGUAGE
  // ==============================================================

  Future<void> _openLanguageSelector() async {
    if (_speech.isListening ||
        _starting) {
      return;
    }

    final List<LocaleName> locales =
        _speech.availableLocales;

    if (locales.isEmpty) {
      _showMessage(
        'No additional speech languages are available on this device.',
      );

      return;
    }

    final String? selected =
    await showModalBottomSheet<String>(
      context:
      context,

      backgroundColor:
      AppColors.surface,

      isScrollControlled:
      true,

      shape:
      const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top:
          Radius.circular(
            22,
          ),
        ),
      ),

      builder:
          (
          sheetContext,
          ) {
        return SafeArea(
          child:
          SizedBox(
            height:
            MediaQuery
                .of(sheetContext)
                .size
                .height *
                0.68,

            child:
            Column(
              children: [
                const SizedBox(
                  height:
                  10,
                ),

                Container(
                  width:
                  38,

                  height:
                  4,

                  decoration:
                  BoxDecoration(
                    color:
                    AppColors.border,

                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),
                ),

                const Padding(
                  padding:
                  EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    14,
                  ),

                  child:
                  Row(
                    children: [
                      Icon(
                        Icons.language_rounded,

                        color:
                        AppColors.primary,
                      ),

                      SizedBox(
                        width:
                        10,
                      ),

                      Text(
                        'Speech Language',

                        style:
                        TextStyle(
                          color:
                          Colors.white,

                          fontSize:
                          18,

                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height:
                  1,

                  color:
                  AppColors.border,
                ),

                Expanded(
                  child:
                  ListView.separated(
                    itemCount:
                    locales.length,

                    separatorBuilder:
                        (
                        _,
                        __,
                        ) {
                      return const Divider(
                        height:
                        1,

                        indent:
                        58,

                        color:
                        AppColors.border,
                      );
                    },

                    itemBuilder:
                        (
                        context,
                        index,
                        ) {
                      final LocaleName locale =
                      locales[index];

                      final bool selected =
                          locale.localeId ==
                              _speechState
                                  .localeId;

                      return ListTile(
                        leading:
                        Icon(
                          selected
                              ? Icons
                              .check_circle_rounded
                              : Icons
                              .language_outlined,

                          color:
                          selected
                              ? AppColors.primary
                              : AppColors
                              .textSecondary,
                        ),

                        title:
                        Text(
                          locale.name,

                          style:
                          TextStyle(
                            color:
                            selected
                                ? AppColors.primary
                                : Colors.white,

                            fontWeight:
                            selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),

                        subtitle:
                        Text(
                          locale.localeId,

                          style:
                          const TextStyle(
                            color:
                            AppColors.textSecondary,

                            fontSize:
                            11,
                          ),
                        ),

                        onTap:
                            () {
                          Navigator.pop(
                            sheetContext,
                            locale.localeId,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    final bool changed =
    _speech.selectLocale(
      selected,
    );

    if (!changed) {
      _showMessage(
        'That speech language could not be selected.',
      );
    }
  }


  // ==============================================================
  // MESSAGE
  // ==============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger
        .of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger
        .of(context)
        .showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }


  // ==============================================================
  // DERIVED UI STATE
  // ==============================================================

  bool get _isListening =>
      _speechState.isListening;

  bool get _hasFinalTranscript =>
      _speechState.transcript
          .trim()
          .isNotEmpty;

  bool get _hasAnyTranscript =>
      _speechState.hasTranscript;

  bool get _hasError =>
      _speechState.hasError;

  bool get _isProcessing =>
      _speechState.status ==
          VoiceSpeechStatus.processing;

  bool get _canStart {
    if (_starting ||
        _isListening ||
        _isProcessing) {
      return false;
    }

    return _speechState.status !=
        VoiceSpeechStatus.initializing &&
        _speechState.status !=
            VoiceSpeechStatus.permissionDenied &&
        _speechState.status !=
            VoiceSpeechStatus.unavailable;
  }


  String get _statusTitle {
    switch (_speechState.status) {
      case VoiceSpeechStatus.uninitialized:
        return 'Voice recognition not started';

      case VoiceSpeechStatus.initializing:
        return 'Preparing voice recognition';

      case VoiceSpeechStatus.ready:
        return 'Ready when you are';

      case VoiceSpeechStatus.listening:
        return 'Listening to your report';

      case VoiceSpeechStatus.processing:
        return 'Finishing your transcript';

      case VoiceSpeechStatus.stopped:
        return _hasFinalTranscript
            ? 'Transcript ready for review'
            : 'No speech captured';

      case VoiceSpeechStatus.unavailable:
        return 'Voice recognition unavailable';

      case VoiceSpeechStatus.permissionDenied:
        return 'Microphone permission required';

      case VoiceSpeechStatus.error:
        return 'Voice recognition needs attention';
    }
  }


  String get _statusSubtitle {
    switch (_speechState.status) {
      case VoiceSpeechStatus.uninitialized:
      case VoiceSpeechStatus.initializing:
        return 'Preparing the microphone and speech service.';

      case VoiceSpeechStatus.ready:
        return 'Tap the microphone and describe the issue naturally.';

      case VoiceSpeechStatus.listening:
        return 'Mention what happened, where it is, how serious it is, '
            'and any safety concern.';

      case VoiceSpeechStatus.processing:
        return 'Please wait while the final words are confirmed.';

      case VoiceSpeechStatus.stopped:
        return _hasFinalTranscript
            ? 'Review the transcript before accepting it.'
            : 'Try again and speak clearly near the microphone.';

      case VoiceSpeechStatus.permissionDenied:
        return 'Allow microphone access in Android settings to use voice reporting.';

      case VoiceSpeechStatus.unavailable:
        return 'This device does not currently provide a compatible speech service.';

      case VoiceSpeechStatus.error:
        return _speechState.errorMessage ??
            'Try again or continue using the manual report form.';
    }
  }


  Color get _statusColor {
    if (_isListening) {
      return AppColors.primary;
    }

    if (_hasError) {
      return Colors.orangeAccent;
    }

    if (_hasFinalTranscript) {
      return const Color(
        0xFF2EE6A6,
      );
    }

    return AppColors.textSecondary;
  }


  IconData get _statusIcon {
    if (_isListening) {
      return Icons.graphic_eq_rounded;
    }

    if (_isProcessing) {
      return Icons.sync_rounded;
    }

    if (_hasError) {
      return Icons.warning_amber_rounded;
    }

    if (_hasFinalTranscript) {
      return Icons.check_circle_outline_rounded;
    }

    return Icons.mic_none_rounded;
  }


  String get _displayTranscript {
    final String text =
        _speechState.displayedTranscript;

    if (text.isNotEmpty) {
      return text;
    }

    return 'Your spoken report will appear here while you speak.';
  }


  String get _durationText {
    final Duration duration =
    _isListening
        ? _liveDuration
        : (_speechState
        .sessionDuration ??
        _liveDuration);

    final int minutes =
        duration.inMinutes;

    final int seconds =
        duration.inSeconds %
            60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }


  String get _confidenceText {
    if (_speechState.confidence <=
        0) {
      return '—';
    }

    return '${(_speechState.confidence * 100).round()}%';
  }


  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds:
        220,
      ),

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
          _isListening
              ? AppColors.primary
              : _hasError
              ? Colors.orangeAccent
              .withOpacity(
            0.65,
          )
              : AppColors.border,

          width:
          _isListening
              ? 1.5
              : 1,
        ),

        boxShadow:
        _isListening
            ? [
          BoxShadow(
            color:
            AppColors.primary
                .withOpacity(
              0.08,
            ),

            blurRadius:
            18,

            spreadRadius:
            1,
          ),
        ]
            : null,
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
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Container(
                width:
                44,

                height:
                44,

                decoration:
                BoxDecoration(
                  color:
                  AppColors.primary
                      .withOpacity(
                    0.10,
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
                      0.30,
                    ),
                  ),
                ),

                child:
                const Icon(
                  Icons.mic_rounded,

                  color:
                  AppColors.primary,

                  size:
                  23,
                ),
              ),

              const SizedBox(
                width:
                12,
              ),

              const Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      'VOICE QUICK REPORT',

                      style:
                      TextStyle(
                        color:
                        AppColors.primary,

                        fontSize:
                        11,

                        fontWeight:
                        FontWeight.bold,

                        letterSpacing:
                        0.6,
                      ),
                    ),

                    SizedBox(
                      height:
                      5,
                    ),

                    Text(
                      'Describe the issue naturally',

                      style:
                      TextStyle(
                        color:
                        Colors.white,

                        fontSize:
                        16,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height:
                      5,
                    ),

                    Text(
                      'Speak for up to about one minute. '
                          'You can review everything before using it.',

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
                  ],
                ),
              ),
            ],
          ),


          const SizedBox(
            height:
            16,
          ),


          // ======================================================
          // SPEECH GUIDANCE
          // ======================================================

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
                0.055,
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
            const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,

                  color:
                  AppColors.primary,

                  size:
                  17,
                ),

                SizedBox(
                  width:
                  9,
                ),

                Expanded(
                  child:
                  Text(
                    'For a useful report, mention the problem, '
                        'exact area or nearby landmark, severity, '
                        'what you observed, and any danger to road users.',

                    style:
                    TextStyle(
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
          ),


          const SizedBox(
            height:
            14,
          ),


          // ======================================================
          // LANGUAGE
          // ======================================================

          InkWell(
            borderRadius:
            BorderRadius.circular(
              12,
            ),

            onTap:
            _isListening
                ? null
                : _openLanguageSelector,

            child:
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal:
                12,

                vertical:
                11,
              ),

              decoration:
              BoxDecoration(
                color:
                AppColors.background
                    .withOpacity(
                  0.30,
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
              Row(
                children: [
                  const Icon(
                    Icons.language_rounded,

                    color:
                    AppColors.textSecondary,

                    size:
                    18,
                  ),

                  const SizedBox(
                    width:
                    9,
                  ),

                  const Text(
                    'Speech language',

                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,

                      fontSize:
                      11,
                    ),
                  ),

                  const Spacer(),

                  Flexible(
                    child:
                    Text(
                      _speechState.localeId ??
                          'System default',

                      maxLines:
                      1,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        color:
                        Colors.white,

                        fontSize:
                        11,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width:
                    7,
                  ),

                  const Icon(
                    Icons.keyboard_arrow_down_rounded,

                    color:
                    AppColors.textSecondary,

                    size:
                    18,
                  ),
                ],
              ),
            ),
          ),


          const SizedBox(
            height:
            16,
          ),


          // ======================================================
          // STATUS
          // ======================================================

          Row(
            children: [
              Icon(
                _statusIcon,

                color:
                _statusColor,

                size:
                19,
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
                    Text(
                      _statusTitle,

                      style:
                      TextStyle(
                        color:
                        _statusColor,

                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                      2,
                    ),

                    Text(
                      _statusSubtitle,

                      style:
                      const TextStyle(
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


          const SizedBox(
            height:
            16,
          ),


          // ======================================================
          // MICROPHONE ACTIVITY
          // ======================================================

          Center(
            child:
            _VoiceMicrophoneIndicator(
              listening:
              _isListening,

              processing:
              _isProcessing,

              soundLevel:
              _speechState.soundLevel,
            ),
          ),


          const SizedBox(
            height:
            16,
          ),


          // ======================================================
          // SESSION METRICS
          // ======================================================

          Row(
            children: [
              Expanded(
                child:
                _VoiceMetric(
                  icon:
                  Icons.timer_outlined,

                  label:
                  'TIME',

                  value:
                  _durationText,
                ),
              ),

              const SizedBox(
                width:
                8,
              ),

              Expanded(
                child:
                _VoiceMetric(
                  icon:
                  Icons.graphic_eq_rounded,

                  label:
                  'RESULTS',

                  value:
                  '${_speechState.resultCount}',
                ),
              ),

              const SizedBox(
                width:
                8,
              ),

              Expanded(
                child:
                _VoiceMetric(
                  icon:
                  Icons.analytics_outlined,

                  label:
                  'CONFIDENCE',

                  value:
                  _confidenceText,
                ),
              ),
            ],
          ),


          const SizedBox(
            height:
            18,
          ),


          // ======================================================
          // TRANSCRIPT
          // ======================================================

          const Text(
            'LIVE TRANSCRIPT',

            style:
            TextStyle(
              color:
              Color(
                0xFFA9C7EF,
              ),

              fontSize:
              11,

              fontWeight:
              FontWeight.w600,

              letterSpacing:
              0.5,
            ),
          ),

          const SizedBox(
            height:
            8,
          ),

          AnimatedContainer(
            duration:
            const Duration(
              milliseconds:
              180,
            ),

            width:
            double.infinity,

            constraints:
            const BoxConstraints(
              minHeight:
              125,
            ),

            padding:
            const EdgeInsets.all(
              14,
            ),

            decoration:
            BoxDecoration(
              color:
              AppColors.background
                  .withOpacity(
                0.34,
              ),

              borderRadius:
              BorderRadius.circular(
                13,
              ),

              border:
              Border.all(
                color:
                _isListening
                    ? AppColors.primary
                    .withOpacity(
                  0.55,
                )
                    : AppColors.border,
              ),
            ),

            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                if (_isListening)
                  const Padding(
                    padding:
                    EdgeInsets.only(
                      bottom:
                      10,
                    ),

                    child:
                    Row(
                      children: [
                        _LiveDot(),

                        SizedBox(
                          width:
                          7,
                        ),

                        Text(
                          'LIVE',

                          style:
                          TextStyle(
                            color:
                            Colors.redAccent,

                            fontSize:
                            9,

                            fontWeight:
                            FontWeight.bold,

                            letterSpacing:
                            0.7,
                          ),
                        ),

                        Spacer(),

                        Text(
                          'Speak naturally',

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

                Text(
                  _displayTranscript,

                  style:
                  TextStyle(
                    color:
                    _hasAnyTranscript
                        ? Colors.white
                        : AppColors.textSecondary,

                    fontSize:
                    14,

                    height:
                    1.55,

                    fontStyle:
                    _hasAnyTranscript
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),


          // ======================================================
          // ERROR
          // ======================================================

          if (_speechState.errorMessage !=
              null) ...[
            const SizedBox(
              height:
              12,
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
                Colors.orangeAccent
                    .withOpacity(
                  0.06,
                ),

                borderRadius:
                BorderRadius.circular(
                  11,
                ),

                border:
                Border.all(
                  color:
                  Colors.orangeAccent
                      .withOpacity(
                    0.30,
                  ),
                ),
              ),

              child:
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Icon(
                    Icons.warning_amber_rounded,

                    color:
                    Colors.orangeAccent,

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
                      _speechState.errorMessage!,

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
                  ),
                ],
              ),
            ),
          ],


          const SizedBox(
            height:
            16,
          ),


          // ======================================================
          // MAIN ACTION
          // ======================================================

          if (!_isListening)
            SizedBox(
              width:
              double.infinity,

              height:
              52,

              child:
              ElevatedButton.icon(
                onPressed:
                _canStart
                    ? _startListening
                    : null,

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

                icon:
                _starting ||
                    _isProcessing
                    ? const SizedBox(
                  width:
                  18,

                  height:
                  18,

                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,

                    color:
                    Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.mic_rounded,
                ),

                label:
                Text(
                  _starting
                      ? 'Starting microphone...'
                      : _isProcessing
                      ? 'Finishing transcript...'
                      : _hasFinalTranscript
                      ? 'Record Again'
                      : 'Start Voice Report',

                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),


          // ======================================================
          // LISTENING ACTIONS
          // ======================================================

          if (_isListening)
            Row(
              children: [
                Expanded(
                  flex:
                  2,

                  child:
                  SizedBox(
                    height:
                    52,

                    child:
                    ElevatedButton.icon(
                      onPressed:
                      _stopListening,

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
                            14,
                          ),
                        ),
                      ),

                      icon:
                      const Icon(
                        Icons.stop_rounded,
                      ),

                      label:
                      const Text(
                        'Finish',

                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  9,
                ),

                Expanded(
                  child:
                  SizedBox(
                    height:
                    52,

                    child:
                    OutlinedButton(
                      onPressed:
                      _cancelListening,

                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor:
                        AppColors.textSecondary,

                        side:
                        const BorderSide(
                          color:
                          AppColors.border,
                        ),

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),

                      child:
                      const Text(
                        'Cancel',
                      ),
                    ),
                  ),
                ),
              ],
            ),


          // ======================================================
          // FINAL TRANSCRIPT ACTIONS
          // ======================================================

          if (_hasFinalTranscript &&
              !_isListening) ...[
            const SizedBox(
              height:
              9,
            ),

            Row(
              children: [
                Expanded(
                  child:
                  OutlinedButton.icon(
                    onPressed:
                    _retry,

                    style:
                    OutlinedButton.styleFrom(
                      foregroundColor:
                      AppColors.textSecondary,

                      side:
                      const BorderSide(
                        color:
                        AppColors.border,
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),

                    icon:
                    const Icon(
                      Icons.refresh_rounded,

                      size:
                      17,
                    ),

                    label:
                    const Text(
                      'Retry',
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  8,
                ),

                Expanded(
                  child:
                  OutlinedButton.icon(
                    onPressed:
                    _clearTranscript,

                    style:
                    OutlinedButton.styleFrom(
                      foregroundColor:
                      Colors.orangeAccent,

                      side:
                      BorderSide(
                        color:
                        Colors.orangeAccent
                            .withOpacity(
                          0.45,
                        ),
                      ),

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),

                    icon:
                    const Icon(
                      Icons.delete_outline_rounded,

                      size:
                      17,
                    ),

                    label:
                    const Text(
                      'Clear',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
              9,
            ),

            SizedBox(
              width:
              double.infinity,

              height:
              48,

              child:
              ElevatedButton.icon(
                onPressed:
                _transcriptAccepted
                    ? null
                    : _acceptTranscript,

                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  _transcriptAccepted
                      ? const Color(
                    0xFF2EE6A6,
                  ).withOpacity(
                    0.16,
                  )
                      : AppColors.primary
                      .withOpacity(
                    0.14,
                  ),

                  foregroundColor:
                  _transcriptAccepted
                      ? const Color(
                    0xFF2EE6A6,
                  )
                      : AppColors.primary,

                  disabledForegroundColor:
                  const Color(
                    0xFF2EE6A6,
                  ),

                  disabledBackgroundColor:
                  const Color(
                    0xFF2EE6A6,
                  ).withOpacity(
                    0.10,
                  ),

                  elevation:
                  0,

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),

                    side:
                    BorderSide(
                      color:
                      _transcriptAccepted
                          ? const Color(
                        0xFF2EE6A6,
                      ).withOpacity(
                        0.45,
                      )
                          : AppColors.primary
                          .withOpacity(
                        0.45,
                      ),
                    ),
                  ),
                ),

                icon:
                Icon(
                  _transcriptAccepted
                      ? Icons.check_circle_rounded
                      : Icons
                      .fact_check_outlined,
                ),

                label:
                Text(
                  _transcriptAccepted
                      ? 'Transcript Kept for Review'
                      : 'Use This Transcript',

                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (_transcriptAccepted) ...[
              const SizedBox(
                height:
                9,
              ),

              const Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Icon(
                    Icons.lock_outline_rounded,

                    color:
                    AppColors.textSecondary,

                    size:
                    14,
                  ),

                  SizedBox(
                    width:
                    6,
                  ),

                  Expanded(
                    child:
                    Text(
                      'Phase 1B keeps the transcript locally on this '
                          'screen only. It will not change your report fields '
                          'until you explicitly review AI suggestions in a '
                          'later phase.',

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
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }


  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );

    _displayTimer?.cancel();

    _speechSubscription?.cancel();

    if (_speech.isListening) {
      unawaited(
        _speech.cancelListening(),
      );
    }

    // Do NOT dispose the singleton speech service here.

    super.dispose();
  }
}


// ================================================================
// MICROPHONE INDICATOR
// ================================================================

class _VoiceMicrophoneIndicator
    extends StatelessWidget {

  final bool listening;
  final bool processing;
  final double soundLevel;

  const _VoiceMicrophoneIndicator({
    required this.listening,
    required this.processing,
    required this.soundLevel,
  });


  double get _normalizedLevel {
    if (!listening) {
      return 0;
    }

    // Native recognizers expose different sound-level ranges.
    // We use a bounded visual approximation only.
    final double value =
    ((soundLevel + 2) /
        12)
        .clamp(
      0.0,
      1.0,
    );

    return value;
  }


  @override
  Widget build(
      BuildContext context,
      ) {
    final double level =
        _normalizedLevel;

    return SizedBox(
      width:
      104,

      height:
      104,

      child:
      Stack(
        alignment:
        Alignment.center,

        children: [
          AnimatedContainer(
            duration:
            const Duration(
              milliseconds:
              120,
            ),

            width:
            listening
                ? 90 +
                (level *
                    12)
                : 82,

            height:
            listening
                ? 90 +
                (level *
                    12)
                : 82,

            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,

              color:
              AppColors.primary
                  .withOpacity(
                listening
                    ? 0.07 +
                    (level *
                        0.05)
                    : 0.04,
              ),
            ),
          ),

          AnimatedContainer(
            duration:
            const Duration(
              milliseconds:
              120,
            ),

            width:
            72,

            height:
            72,

            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,

              color:
              listening
                  ? AppColors.primary
                  .withOpacity(
                0.16,
              )
                  : AppColors.background
                  .withOpacity(
                0.45,
              ),

              border:
              Border.all(
                color:
                listening
                    ? AppColors.primary
                    : AppColors.border,

                width:
                listening
                    ? 1.8
                    : 1,
              ),
            ),

            child:
            processing
                ? const Padding(
              padding:
              EdgeInsets.all(
                22,
              ),

              child:
              CircularProgressIndicator(
                strokeWidth:
                2.5,

                color:
                AppColors.primary,
              ),
            )
                : Icon(
              listening
                  ? Icons
                  .graphic_eq_rounded
                  : Icons
                  .mic_rounded,

              color:
              listening
                  ? AppColors.primary
                  : AppColors
                  .textSecondary,

              size:
              30,
            ),
          ),
        ],
      ),
    );
  }
}


// ================================================================
// VOICE METRIC
// ================================================================

class _VoiceMetric
    extends StatelessWidget {

  final IconData icon;
  final String label;
  final String value;

  const _VoiceMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        9,

        vertical:
        10,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.background
            .withOpacity(
          0.27,
        ),

        borderRadius:
        BorderRadius.circular(
          11,
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
          Icon(
            icon,

            color:
            AppColors.textSecondary,

            size:
            15,
          ),

          const SizedBox(
            height:
            5,
          ),

          Text(
            value,

            maxLines:
            1,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize:
              11,

              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            height:
            2,
          ),

          Text(
            label,

            maxLines:
            1,

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              7,

              fontWeight:
              FontWeight.w600,

              letterSpacing:
              0.4,
            ),
          ),
        ],
      ),
    );
  }
}


// ================================================================
// LIVE DOT
// ================================================================

class _LiveDot
    extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot>
  createState() =>
      _LiveDotState();
}


class _LiveDotState
    extends State<_LiveDot>
    with
        SingleTickerProviderStateMixin {

  late final AnimationController
  _controller;

  late final Animation<double>
  _opacity;


  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
          vsync:
          this,

          duration:
          const Duration(
            milliseconds:
            850,
          ),
        );

    _opacity =
        Tween<double>(
          begin:
          0.35,

          end:
          1,
        ).animate(
          CurvedAnimation(
            parent:
            _controller,

            curve:
            Curves.easeInOut,
          ),
        );

    _controller.repeat(
      reverse:
      true,
    );
  }


  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {
    return FadeTransition(
      opacity:
      _opacity,

      child:
      Container(
        width:
        8,

        height:
        8,

        decoration:
        const BoxDecoration(
          shape:
          BoxShape.circle,

          color:
          Colors.redAccent,
        ),
      ),
    );
  }
}