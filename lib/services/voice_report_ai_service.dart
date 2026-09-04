import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/voice_report_analysis.dart';


// ================================================================
// VOICE REPORT AI EXCEPTION
// ================================================================

enum VoiceReportAiFailureType {
  unauthenticated,
  invalidTranscript,
  timeout,
  serverRejected,
  malformedResponse,
  unavailable,
  unknown,
}


class VoiceReportAiException
    implements Exception {
  final VoiceReportAiFailureType type;

  final String message;

  final Object? technicalError;

  const VoiceReportAiException({
    required this.type,
    required this.message,
    this.technicalError,
  });

  @override
  String toString() =>
      message;
}


// ================================================================
// VOICE REPORT AI SERVICE
// ================================================================

class VoiceReportAiService {
  VoiceReportAiService._();

  static final VoiceReportAiService
  instance =
  VoiceReportAiService._();

  static const String _functionName =
      'analyze-voice-report';

  static const Duration _requestTimeout =
  Duration(
    seconds: 15,
  );

  bool _requestInProgress =
  false;

  bool get requestInProgress =>
      _requestInProgress;


  // ============================================================
  // ANALYZE TRANSCRIPT
  // ============================================================

  Future<VoiceReportAnalysis>
  analyzeTranscript({
    required String transcript,

    /// Locale supplied by speech recognizer.
    ///
    /// Examples:
    /// en_US
    /// ms_MY
    /// zh_CN
    ///
    /// AI still independently detects the actual language.
    String? speechLocaleId,
  }) async {
    final String normalized =
    _normalizeTranscript(
      transcript,
    );

    // ----------------------------------------------------------
    // LOCAL REQUEST SAFETY
    // ----------------------------------------------------------

    if (normalized.isEmpty) {
      throw const VoiceReportAiException(
        type:
        VoiceReportAiFailureType.invalidTranscript,

        message:
        'The voice transcript is empty.',
      );
    }

    if (normalized.length < 10) {
      throw const VoiceReportAiException(
        type:
        VoiceReportAiFailureType.invalidTranscript,

        message:
        'Please provide more detail before AI analysis.',
      );
    }

    if (normalized.length > 5000) {
      throw const VoiceReportAiException(
        type:
        VoiceReportAiFailureType.invalidTranscript,

        message:
        'The voice transcript is too long to analyse safely.',
      );
    }

    // ----------------------------------------------------------
    // AUTH
    // ----------------------------------------------------------

    final SupabaseClient client =
        Supabase.instance.client;

    final User? user =
        client.auth.currentUser;

    final Session? session =
        client.auth.currentSession;

    if (user == null ||
        session == null) {
      throw const VoiceReportAiException(
        type:
        VoiceReportAiFailureType.unauthenticated,

        message:
        'Your login session is unavailable. Please sign in again.',
      );
    }

    // ----------------------------------------------------------
    // DUPLICATE REQUEST PROTECTION
    // ----------------------------------------------------------

    if (_requestInProgress) {
      throw const VoiceReportAiException(
        type:
        VoiceReportAiFailureType.unavailable,

        message:
        'Voice analysis is already in progress.',
      );
    }

    _requestInProgress =
    true;

    try {
      final FunctionResponse response =
      await client.functions
          .invoke(
        _functionName,

        body:
        <String, dynamic>{
          'transcript':
          normalized,

          'speechLocaleId':
          speechLocaleId,

          // Server must never trust this as identity.
          // Useful only for correlation/debugging.
          'clientUserId':
          user.id,
        },
      ).timeout(
        _requestTimeout,
      );

      final dynamic rawData =
          response.data;

      if (rawData is! Map) {
        throw const VoiceReportAiException(
          type:
          VoiceReportAiFailureType.malformedResponse,

          message:
          'Voice AI returned an invalid response.',
        );
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(
        rawData,
      );

      final bool success =
          data['success'] ==
              true;

      if (!success) {
        throw VoiceReportAiException(
          type:
          VoiceReportAiFailureType.serverRejected,

          message:
          _safeServerMessage(
            data['message'],
          ),
        );
      }

      final dynamic rawAnalysis =
      data['analysis'];

      if (rawAnalysis is! Map) {
        throw const VoiceReportAiException(
          type:
          VoiceReportAiFailureType.malformedResponse,

          message:
          'Voice AI did not return structured report details.',
        );
      }

      try {
        return VoiceReportAnalysis
            .fromJson(
          Map<String, dynamic>.from(
            rawAnalysis,
          ),
        );
      } on FormatException catch (error) {
    throw VoiceReportAiException(
    type:
    VoiceReportAiFailureType.malformedResponse,

    message:
    'Voice AI returned report details in an unsupported format.',

    technicalError:
    error,
    );
    }
    } on TimeoutException
    catch (error) {
    throw VoiceReportAiException(
    type:
    VoiceReportAiFailureType.timeout,

    message:
    'Voice AI analysis took too long. Please try again.',

    technicalError:
    error,
    );
    } on FunctionException catch (error) {
    throw VoiceReportAiException(
    type:
    VoiceReportAiFailureType.unavailable,

    message:
    'Voice AI service is currently unavailable. Please try again.',

    technicalError:
    error,
    );
    } on VoiceReportAiException {
    rethrow;
    } catch (error) {
    throw VoiceReportAiException(
    type:
    VoiceReportAiFailureType.unknown,

    message:
    'Unable to analyse the voice report. Please try again.',

    technicalError:
    error,
    );
    } finally {
    _requestInProgress =
    false;
    }
  }


  // ============================================================
  // NORMALIZE TRANSCRIPT
  // ============================================================

  String _normalizeTranscript(
      String value,
      ) {
    return value
        .replaceAll(
      '\u00A0',
      ' ',
    )
        .replaceAll(
      RegExp(
        r'\s+',
        unicode: true,
      ),
      ' ',
    )
        .trim();
  }


  // ============================================================
  // SAFE SERVER MESSAGE
  // ============================================================

  static String _safeServerMessage(
      dynamic value,
      ) {
    final String message =
        value
            ?.toString()
            .trim() ??
            '';

    if (message.isEmpty ||
        message.length > 250) {
      return 'Unable to analyse the voice report.';
    }

    return message;
  }
}