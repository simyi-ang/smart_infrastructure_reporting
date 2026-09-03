import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class PasswordResetWindowStatus {
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  final bool expired;

  final Duration remaining;

  const PasswordResetWindowStatus({
    required this.issuedAt,
    required this.expiresAt,
    required this.expired,
    required this.remaining,
  });
}

class PasswordResetRequestResult {
  final PasswordResetSecurityResult security;

  final PasswordResetWindowStatus window;

  const PasswordResetRequestResult({
    required this.security,
    required this.window,
  });
}

// ============================================================
// PASSWORD RESET SECURITY SERVICE
// ============================================================

class PasswordResetSecurityService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  static const Duration resetLinkValidity =
  Duration(
    minutes: 5,
  );

  static const String _prefix =
      'password_reset_security';

  String _normalizeEmail(
      String email,
      ) {
    return email
        .trim()
        .toLowerCase();
  }

  String _key(
      String email,
      String field,
      ) {
    final String cleanEmail =
    _normalizeEmail(
      email,
    );

    return '${_prefix}_${cleanEmail}_$field';
  }

  Future<void> startResetWindow(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final DateTime now =
    DateTime.now();

    final DateTime expiresAt =
    now.add(
      resetLinkValidity,
    );

    await prefs.setString(
      _key(
        email,
        'issued_at',
      ),
      now.toIso8601String(),
    );

    await prefs.setString(
      _key(
        email,
        'expires_at',
      ),
      expiresAt.toIso8601String(),
    );
  }

  Future<PasswordResetWindowStatus>
  getResetWindowStatus(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final DateTime now =
    DateTime.now();

    final String? issuedAtValue =
    prefs.getString(
      _key(
        email,
        'issued_at',
      ),
    );

    final String? expiresAtValue =
    prefs.getString(
      _key(
        email,
        'expires_at',
      ),
    );

    final DateTime? issuedAt =
    issuedAtValue == null
        ? null
        : DateTime.tryParse(
      issuedAtValue,
    );

    final DateTime? expiresAt =
    expiresAtValue == null
        ? null
        : DateTime.tryParse(
      expiresAtValue,
    );

    final bool expired =
        expiresAt != null &&
            !now.isBefore(
              expiresAt,
            );

    Duration remaining =
        Duration.zero;

    if (
    expiresAt != null &&
        now.isBefore(
          expiresAt,
        )
    ) {
      remaining =
          expiresAt.difference(
            now,
          );
    }

    return PasswordResetWindowStatus(
      issuedAt:
      issuedAt,

      expiresAt:
      expiresAt,

      expired:
      expired,

      remaining:
      remaining,
    );
  }

  Future<bool> isResetWindowValid(
      String email,
      ) async {
    final PasswordResetWindowStatus status =
    await getResetWindowStatus(
      email,
    );

    if (status.expiresAt == null) {
      return false;
    }

    return !status.expired;
  }

  Future<void> clearResetWindow(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.remove(
      _key(
        email,
        'issued_at',
      ),
    );

    await prefs.remove(
      _key(
        email,
        'expires_at',
      ),
    );
  }

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