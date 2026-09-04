import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/voice_speech_state.dart';
import '../../services/voice_speech_service.dart';
import '../../theme/app_colors.dart';


// ================================================================
// VOICE SPEECH TEST SCREEN
// ================================================================
//
// PHASE 1A VALIDATION SCREEN
//
// This screen intentionally does NOT update:
//
// - selectedCategory
// - selectedPriority
// - titleController
// - descriptionController
// - ReportDraft
// - Supabase
//
// ================================================================

class VoiceSpeechTestScreen
    extends StatefulWidget {
  const VoiceSpeechTestScreen({
    super.key,
  });

  @override
  State<VoiceSpeechTestScreen>
  createState() =>
      _VoiceSpeechTestScreenState();
}


class _VoiceSpeechTestScreenState
    extends State<VoiceSpeechTestScreen> {

  final VoiceSpeechService _speech =
      VoiceSpeechService.instance;

  StreamSubscription<VoiceSpeechState>?
  _stateSubscription;

  VoiceSpeechState _speechState =
  const VoiceSpeechState(
    status:
    VoiceSpeechStatus.uninitialized,
  );

  bool _starting =
  false;


  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    _speechState =
        _speech.state;

    _stateSubscription =
        _speech.states.listen(
          _onSpeechStateChanged,
        );

    unawaited(
      _initializeSpeech(),
    );
  }


  void _onSpeechStateChanged(
      VoiceSpeechState state,
      ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _speechState =
          state;
    });
  }


  Future<void> _initializeSpeech() async {
    await _speech.initialize();

    if (!mounted) {
      return;
    }

    setState(() {
      _speechState =
          _speech.state;
    });
  }


  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _stateSubscription?.cancel();

    if (_speech.isListening) {
      unawaited(
        _speech.cancelListening(),
      );
    }

    // IMPORTANT:
    //
    // Do NOT dispose VoiceSpeechService.instance here.
    // It is an application-level singleton.

    super.dispose();
  }


  // ==============================================================
  // START
  // ==============================================================

  Future<void> _start() async {
    if (_starting ||
        _speech.isListening) {
      return;
    }

    setState(() {
      _starting =
      true;
    });

    try {
      await _speech.startListening(
        localeId:
        _speechState.localeId,
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
  // STOP
  // ==============================================================

  Future<void> _stop() async {
    await _speech.stopListening();
  }


  // ==============================================================
  // CANCEL / CLEAR
  // ==============================================================

  Future<void> _cancelOrClear() async {
    if (_speech.isListening) {
      await _speech.cancelListening();

      return;
    }

    _speech.clearTranscript();
  }


  // ==============================================================
  // STATUS
  // ==============================================================

  String get _statusText {
    switch (_speechState.status) {
      case VoiceSpeechStatus.uninitialized:
        return 'Not initialized';

      case VoiceSpeechStatus.initializing:
        return 'Preparing voice recognition';

      case VoiceSpeechStatus.ready:
        return 'Ready to listen';

      case VoiceSpeechStatus.listening:
        return 'Listening';

      case VoiceSpeechStatus.processing:
        return 'Finishing recognition';

      case VoiceSpeechStatus.stopped:
        return 'Recognition completed';

      case VoiceSpeechStatus.unavailable:
        return 'Recognition unavailable';

      case VoiceSpeechStatus.permissionDenied:
        return 'Microphone permission denied';

      case VoiceSpeechStatus.error:
        return 'Recognition error';
    }
  }


  Color get _statusColor {
    switch (_speechState.status) {
      case VoiceSpeechStatus.listening:
      case VoiceSpeechStatus.ready:
      case VoiceSpeechStatus.stopped:
        return AppColors.primary;

      case VoiceSpeechStatus.permissionDenied:
      case VoiceSpeechStatus.error:
      case VoiceSpeechStatus.unavailable:
        return Colors.orangeAccent;

      default:
        return AppColors.textSecondary;
    }
  }


  IconData get _statusIcon {
    switch (_speechState.status) {
      case VoiceSpeechStatus.listening:
        return Icons.graphic_eq_rounded;

      case VoiceSpeechStatus.ready:
        return Icons.mic_none_rounded;

      case VoiceSpeechStatus.stopped:
        return Icons.check_circle_outline_rounded;

      case VoiceSpeechStatus.permissionDenied:
        return Icons.mic_off_outlined;

      case VoiceSpeechStatus.error:
      case VoiceSpeechStatus.unavailable:
        return Icons.error_outline;

      case VoiceSpeechStatus.initializing:
      case VoiceSpeechStatus.processing:
        return Icons.sync_rounded;

      case VoiceSpeechStatus.uninitialized:
        return Icons.hourglass_empty_rounded;
    }
  }


  // ==============================================================
  // TRANSCRIPT
  // ==============================================================

  String get _displayTranscript {
    final String current =
        _speechState.displayedTranscript;

    if (current.isNotEmpty) {
      return current;
    }

    return 'Your speech will appear here while you speak.';
  }


  // ==============================================================
  // SESSION DURATION
  // ==============================================================

  String get _sessionDurationText {
    final Duration? duration =
        _speechState.sessionDuration;

    if (duration == null) {
      return '—';
    }

    final int seconds =
        duration.inSeconds;

    return '${seconds}s';
  }


  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool listening =
        _speechState.isListening;

    return Scaffold(
      backgroundColor:
      AppColors.background,

      appBar:
      AppBar(
        backgroundColor:
        AppColors.background,

        foregroundColor:
        Colors.white,

        elevation:
        0,

        title:
        const Text(
          'Voice Intelligence Test',
        ),
      ),

      body:
      SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            30,
          ),

          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              // ==================================================
              // PHASE LABEL
              // ==================================================

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
                const Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      'PHASE 1A',
                      style:
                      TextStyle(
                        color:
                        AppColors.primary,

                        fontSize:
                        11,

                        fontWeight:
                        FontWeight.bold,

                        letterSpacing:
                        0.8,
                      ),
                    ),

                    SizedBox(
                      height:
                      8,
                    ),

                    Text(
                      'Speech Recognition Foundation',
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

                    SizedBox(
                      height:
                      7,
                    ),

                    Text(
                      'This test converts live microphone speech '
                          'into text. It does not use AI or modify '
                          'your report.',
                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,

                        fontSize:
                        12,

                        height:
                        1.45,
                      ),
                    ),
                  ],
                ),
              ),


              const SizedBox(
                height:
                18,
              ),


              // ==================================================
              // STATUS
              // ==================================================

              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.all(
                  14,
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
                    listening
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),

                child:
                Row(
                  children: [
                    Icon(
                      _statusIcon,

                      color:
                      _statusColor,
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
                            'VOICE STATUS',
                            style:
                            TextStyle(
                              color:
                              AppColors.textSecondary,

                              fontSize:
                              10,

                              letterSpacing:
                              0.5,
                            ),
                          ),

                          const SizedBox(
                            height:
                            4,
                          ),

                          Text(
                            _statusText,
                            style:
                            TextStyle(
                              color:
                              _statusColor,

                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_speechState.status ==
                        VoiceSpeechStatus.initializing ||
                        _speechState.status ==
                            VoiceSpeechStatus.processing)
                      const SizedBox(
                        width:
                        18,

                        height:
                        18,

                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,

                          color:
                          AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),


              const SizedBox(
                height:
                14,
              ),


              // ==================================================
              // SESSION INFORMATION
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child:
                    _MetricCard(
                      label:
                      'LANGUAGE',

                      value:
                      _speechState.localeId ??
                          'System',
                    ),
                  ),

                  const SizedBox(
                    width:
                    10,
                  ),

                  Expanded(
                    child:
                    _MetricCard(
                      label:
                      'RESULTS',

                      value:
                      '${_speechState.resultCount}',
                    ),
                  ),

                  const SizedBox(
                    width:
                    10,
                  ),

                  Expanded(
                    child:
                    _MetricCard(
                      label:
                      'DURATION',

                      value:
                      _sessionDurationText,
                    ),
                  ),
                ],
              ),


              const SizedBox(
                height:
                24,
              ),


              // ==================================================
              // TRANSCRIPT
              // ==================================================

              const Text(
                'LIVE TRANSCRIPT',
                style:
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
                ),
              ),

              const SizedBox(
                height:
                10,
              ),

              Container(
                width:
                double.infinity,

                constraints:
                const BoxConstraints(
                  minHeight:
                  190,
                ),

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
                    listening
                        ? AppColors.primary
                        .withOpacity(
                      0.65,
                    )
                        : AppColors.border,
                  ),
                ),

                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    if (listening)
                      const Row(
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color:
                            Colors.redAccent,
                            size:
                            12,
                          ),

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
                              10,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                    if (listening)
                      const SizedBox(
                        height:
                        12,
                      ),

                    Text(
                      _displayTranscript,

                      style:
                      TextStyle(
                        color:
                        _speechState.hasTranscript
                            ? Colors.white
                            : AppColors.textSecondary,

                        fontSize:
                        16,

                        height:
                        1.55,
                      ),
                    ),
                  ],
                ),
              ),


              // ==================================================
              // CONFIDENCE
              // ==================================================

              if (_speechState.confidence >
                  0) ...[
                const SizedBox(
                  height:
                  12,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color:
                      AppColors.textSecondary,
                      size:
                      16,
                    ),

                    const SizedBox(
                      width:
                      7,
                    ),

                    Text(
                      'Recognition confidence: '
                          '${(_speechState.confidence * 100).toStringAsFixed(1)}%',

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
              ],


              // ==================================================
              // ERROR
              // ==================================================

              if (_speechState.errorMessage !=
                  null) ...[
                const SizedBox(
                  height:
                  16,
                ),

                Container(
                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets.all(
                    13,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    Colors.orangeAccent
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
                      Colors.orangeAccent
                          .withOpacity(
                        0.35,
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
                        19,
                      ),

                      const SizedBox(
                        width:
                        9,
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
                            11,

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
                24,
              ),


              // ==================================================
              // START / STOP
              // ==================================================

              SizedBox(
                width:
                double.infinity,

                height:
                56,

                child:
                ElevatedButton.icon(
                  onPressed:
                  _starting
                      ? null
                      : listening
                      ? _stop
                      : _start,

                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    listening
                        ? Colors.redAccent
                        .withOpacity(
                      0.85,
                    )
                        : AppColors.primaryDark,

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

                  icon:
                  Icon(
                    listening
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                  ),

                  label:
                  Text(
                    _starting
                        ? 'Starting microphone...'
                        : listening
                        ? 'Stop Listening'
                        : 'Start Listening',

                    style:
                    const TextStyle(
                      fontSize:
                      15,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),


              const SizedBox(
                height:
                10,
              ),


              // ==================================================
              // CANCEL / CLEAR
              // ==================================================

              SizedBox(
                width:
                double.infinity,

                height:
                48,

                child:
                OutlinedButton.icon(
                  onPressed:
                  _cancelOrClear,

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

                  icon:
                  Icon(
                    listening
                        ? Icons.close_rounded
                        : Icons.refresh_rounded,
                  ),

                  label:
                  Text(
                    listening
                        ? 'Cancel Listening'
                        : 'Clear Transcript',
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
// METRIC CARD
// ================================================================

class _MetricCard
    extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
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
        10,

        vertical:
        11,
      ),

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
              8,

              fontWeight:
              FontWeight.w600,
            ),
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
        ],
      ),
    );
  }
}