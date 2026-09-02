import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// PASSWORD RESET SECURITY RESULT
// ============================================================

class PasswordResetSecurityResult {
  final bool allowed;

  final int retryAfterSeconds;

  final int attemptsInWindow;

  final DateTime? blockedUntil;

  const PasswordResetSecurityResult({
    required this.allowed,
    required this.retryAfterSeconds,
    required this.attemptsInWindow,
    required this.blockedUntil,
  });

  // ==========================================================
  // BLOCKED?
  // ==========================================================

  bool get isBlocked =>
      !allowed;

  // ==========================================================
  // THIRD REQUEST?
  //
  // The third request is still allowed, but further requests
  // are temporarily blocked.
  // ==========================================================

  bool get protectionActivated =>
      allowed &&
          attemptsInWindow >= 3 &&
          blockedUntil != null;

  // ==========================================================
  // FRIENDLY RETRY TIME
  // ==========================================================

  String get retryTimeLabel {
    if (retryAfterSeconds <= 0) {
      return '';
    }

    final int minutes =
    (retryAfterSeconds / 60)
        .ceil();

    if (minutes <= 1) {
      return 'about 1 minute';
    }

    return 'about $minutes minutes';
  }
}

// ============================================================
// PASSWORD RESET SECURITY SERVICE
// ============================================================

class PasswordResetSecurityService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // CHECK AND RECORD RESET REQUEST
  // ============================================================

  Future<PasswordResetSecurityResult>
  checkAndRecordRequest(
      String email,
      ) async {
    final String cleanEmail =
    email
        .trim()
        .toLowerCase();

    if (cleanEmail.isEmpty) {
      throw Exception(
        'Please enter your email address.',
      );
    }

    try {
      final dynamic response =
      await _supabase.rpc(
        'check_password_reset_rate_limit',

        params: {
          'p_email':
          cleanEmail,
        },
      );

      if (response is! List ||
          response.isEmpty) {
        throw Exception(
          'Unable to verify password-reset security.',
        );
      }

      final dynamic first =
          response.first;

      if (first is! Map) {
        throw Exception(
          'Invalid password-reset security response.',
        );
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(
        first,
      );

      final bool allowed =
          data['allowed']
          as bool? ??
              false;

      final int retryAfterSeconds =
          (data[
          'retry_after_seconds']
          as num?)
              ?.toInt() ??
              0;

      final int attemptsInWindow =
          (data[
          'attempts_in_window']
          as num?)
              ?.toInt() ??
              0;

      final String? blockedUntilValue =
      data['block_until']
          ?.toString();

      final DateTime? blockedUntil =
      blockedUntilValue ==
          null ||
          blockedUntilValue
              .isEmpty
          ? null
          : DateTime.tryParse(
        blockedUntilValue,
      );

      return PasswordResetSecurityResult(
        allowed:
        allowed,

        retryAfterSeconds:
        retryAfterSeconds,

        attemptsInWindow:
        attemptsInWindow,

        blockedUntil:
        blockedUntil,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (e) {
      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      if (message.trim().isEmpty) {
        throw Exception(
          'Unable to verify password-reset security.',
        );
      }

      throw Exception(
        message,
      );
    }
  }
}