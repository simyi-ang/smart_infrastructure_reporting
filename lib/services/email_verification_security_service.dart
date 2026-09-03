import 'package:shared_preferences/shared_preferences.dart';

// ================================================================
// EMAIL VERIFICATION SECURITY STATUS
// ================================================================

class EmailVerificationSecurityStatus {
  final DateTime? verificationIssuedAt;
  final DateTime? verificationExpiresAt;

  final int resendAttempts;

  final DateTime? resendBlockedUntil;

  final bool verificationExpired;
  final bool resendBlocked;

  final Duration verificationRemaining;
  final Duration resendBlockRemaining;

  const EmailVerificationSecurityStatus({
    required this.verificationIssuedAt,
    required this.verificationExpiresAt,
    required this.resendAttempts,
    required this.resendBlockedUntil,
    required this.verificationExpired,
    required this.resendBlocked,
    required this.verificationRemaining,
    required this.resendBlockRemaining,
  });
}

// ================================================================
// EMAIL VERIFICATION RESEND RESULT
// ================================================================

class EmailVerificationResendResult {
  final bool allowed;

  final bool protectionActivated;

  final int resendAttempts;

  final DateTime? blockedUntil;

  final String? message;

  const EmailVerificationResendResult({
    required this.allowed,
    required this.protectionActivated,
    required this.resendAttempts,
    required this.blockedUntil,
    this.message,
  });
}

// ================================================================
// EMAIL VERIFICATION SECURITY SERVICE
//
// PURPOSE
//
// This service provides SmartCity-side protection for:
//
// - 5-minute verification window
// - resend attempt tracking
// - resend temporary blocking
// - persisted timing across app restarts
//
// IMPORTANT:
//
// This service does NOT replace Supabase Auth security.
//
// Supabase must still:
// - generate the verification token
// - validate the verification token
// - enforce its own Auth rate limits
//
// SmartCity adds an additional application-level security layer.
// ================================================================

class EmailVerificationSecurityService {
  // ==============================================================
  // CONFIG
  // ==============================================================

  static const Duration verificationValidity =
  Duration(
    minutes: 5,
  );

  static const Duration resendWindow =
  Duration(
    minutes: 10,
  );

  static const Duration resendBlockDuration =
  Duration(
    minutes: 15,
  );

  static const int maxResendAttempts =
  3;

  static const Duration minimumResendInterval =
  Duration(
    seconds: 60,
  );

  // ==============================================================
  // SHARED PREFERENCES KEY PREFIX
  // ==============================================================

  static const String _prefix =
      'email_verification_security';

  // ==============================================================
  // NORMALIZE EMAIL
  // ==============================================================

  String _normalizeEmail(
      String email,
      ) {
    return email
        .trim()
        .toLowerCase();
  }

  // ==============================================================
  // EMAIL-SPECIFIC KEY
  // ==============================================================

  String _key(
      String email,
      String field,
      ) {
    final String normalized =
    _normalizeEmail(
      email,
    );

    return '${_prefix}_${normalized}_$field';
  }

  // ==============================================================
  // START NEW VERIFICATION WINDOW
  //
  // Call this immediately after:
  //
  // signUp()
  //
  // OR after a successful resend.
  //
  // This starts a fresh 5-minute SmartCity verification window.
  // ==============================================================

  Future<void> startVerificationWindow(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final DateTime now =
    DateTime.now();

    final DateTime expiresAt =
    now.add(
      verificationValidity,
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

    // ============================================================
    // STORE LAST SEND TIME
    //
    // Used to enforce minimum resend interval.
    // ============================================================

    await prefs.setString(
      _key(
        email,
        'last_sent_at',
      ),
      now.toIso8601String(),
    );
  }

  // ==============================================================
  // GET CURRENT STATUS
  // ==============================================================

  Future<EmailVerificationSecurityStatus>
  getStatus(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final DateTime now =
    DateTime.now();

    final DateTime? issuedAt =
    _parseDate(
      prefs.getString(
        _key(
          email,
          'issued_at',
        ),
      ),
    );

    final DateTime? expiresAt =
    _parseDate(
      prefs.getString(
        _key(
          email,
          'expires_at',
        ),
      ),
    );

    final int resendAttempts =
        prefs.getInt(
          _key(
            email,
            'resend_attempts',
          ),
        ) ??
            0;

    final DateTime? blockedUntil =
    _parseDate(
      prefs.getString(
        _key(
          email,
          'blocked_until',
        ),
      ),
    );

    // ============================================================
    // VERIFICATION EXPIRY
    // ============================================================

    final bool verificationExpired =
        expiresAt != null &&
            !now.isBefore(
              expiresAt,
            );

    Duration verificationRemaining =
        Duration.zero;

    if (
    expiresAt != null &&
        now.isBefore(
          expiresAt,
        )
    ) {
      verificationRemaining =
          expiresAt.difference(
            now,
          );
    }

    // ============================================================
    // RESEND BLOCK
    // ============================================================

    final bool resendBlocked =
        blockedUntil != null &&
            now.isBefore(
              blockedUntil,
            );

    Duration resendBlockRemaining =
        Duration.zero;

    if (resendBlocked) {
      resendBlockRemaining =
          blockedUntil.difference(
            now,
          );
    }

    // ============================================================
    // AUTO-CLEAR EXPIRED BLOCK
    // ============================================================

    if (
    blockedUntil != null &&
        !resendBlocked
    ) {
      await prefs.remove(
        _key(
          email,
          'blocked_until',
        ),
      );

      await prefs.setInt(
        _key(
          email,
          'resend_attempts',
        ),
        0,
      );
    }

    return EmailVerificationSecurityStatus(
      verificationIssuedAt:
      issuedAt,

      verificationExpiresAt:
      expiresAt,

      resendAttempts:
      resendAttempts,

      resendBlockedUntil:
      resendBlocked
          ? blockedUntil
          : null,

      verificationExpired:
      verificationExpired,

      resendBlocked:
      resendBlocked,

      verificationRemaining:
      verificationRemaining,

      resendBlockRemaining:
      resendBlockRemaining,
    );
  }

  // ==============================================================
  // CHECK WHETHER RESEND CAN PROCEED
  //
  // Rules:
  //
  // - blocked users cannot resend
  // - minimum 60 seconds between resend attempts
  // - max 3 resends in a 10-minute window
  // - too many requests -> block for 15 minutes
  // ==============================================================

  Future<EmailVerificationResendResult>
  checkAndRecordResend(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final DateTime now =
    DateTime.now();

    // ============================================================
    // EXISTING BLOCK
    // ============================================================

    final DateTime? blockedUntil =
    _parseDate(
      prefs.getString(
        _key(
          email,
          'blocked_until',
        ),
      ),
    );

    if (
    blockedUntil != null &&
        now.isBefore(
          blockedUntil,
        )
    ) {
      return EmailVerificationResendResult(
        allowed:
        false,

        protectionActivated:
        true,

        resendAttempts:
        prefs.getInt(
          _key(
            email,
            'resend_attempts',
          ),
        ) ??
            0,

        blockedUntil:
        blockedUntil,

        message:
        'Too many verification email requests. '
            'Please wait before requesting another email.',
      );
    }

    // ============================================================
    // MINIMUM RESEND INTERVAL
    // ============================================================

    final DateTime? lastSentAt =
    _parseDate(
      prefs.getString(
        _key(
          email,
          'last_sent_at',
        ),
      ),
    );

    if (
    lastSentAt != null
    ) {
      final Duration sinceLastSend =
      now.difference(
        lastSentAt,
      );

      if (
      sinceLastSend <
          minimumResendInterval
      ) {
        final int remainingSeconds =
            minimumResendInterval
                .inSeconds -
                sinceLastSend
                    .inSeconds;

        return EmailVerificationResendResult(
          allowed:
          false,

          protectionActivated:
          false,

          resendAttempts:
          prefs.getInt(
            _key(
              email,
              'resend_attempts',
            ),
          ) ??
              0,

          blockedUntil:
          null,

          message:
          'Please wait $remainingSeconds seconds '
              'before requesting another verification email.',
        );
      }
    }

    // ============================================================
    // RESEND WINDOW
    // ============================================================

    DateTime? resendWindowStartedAt =
    _parseDate(
      prefs.getString(
        _key(
          email,
          'resend_window_started_at',
        ),
      ),
    );

    int resendAttempts =
        prefs.getInt(
          _key(
            email,
            'resend_attempts',
          ),
        ) ??
            0;

    // ============================================================
    // RESET OLD WINDOW
    // ============================================================

    if (
    resendWindowStartedAt ==
        null ||
        now.difference(
          resendWindowStartedAt,
        ) >
            resendWindow
    ) {
      resendWindowStartedAt =
          now;

      resendAttempts =
      0;

      await prefs.setString(
        _key(
          email,
          'resend_window_started_at',
        ),
        now.toIso8601String(),
      );

      await prefs.setInt(
        _key(
          email,
          'resend_attempts',
        ),
        0,
      );
    }

    // ============================================================
    // INCREMENT ATTEMPT
    // ============================================================

    resendAttempts++;

    await prefs.setInt(
      _key(
        email,
        'resend_attempts',
      ),
      resendAttempts,
    );

    // ============================================================
    // TOO MANY REQUESTS
    // ============================================================

    if (
    resendAttempts >
        maxResendAttempts
    ) {
      final DateTime newBlockedUntil =
      now.add(
        resendBlockDuration,
      );

      await prefs.setString(
        _key(
          email,
          'blocked_until',
        ),
        newBlockedUntil
            .toIso8601String(),
      );

      return EmailVerificationResendResult(
        allowed:
        false,

        protectionActivated:
        true,

        resendAttempts:
        resendAttempts,

        blockedUntil:
        newBlockedUntil,

        message:
        'Too many verification email requests. '
            'Verification resend has been temporarily '
            'blocked for 15 minutes.',
      );
    }

    // ============================================================
    // ALLOWED
    // ============================================================

    await prefs.setString(
      _key(
        email,
        'last_sent_at',
      ),
      now.toIso8601String(),
    );

    return EmailVerificationResendResult(
      allowed:
      true,

      protectionActivated:
      false,

      resendAttempts:
      resendAttempts,

      blockedUntil:
      null,
    );
  }

  // ==============================================================
  // RECORD SUCCESSFUL RESEND
  //
  // Call this AFTER Supabase resend succeeds.
  //
  // A successful resend gives the new email another 5-minute
  // SmartCity verification window.
  // ==============================================================

  Future<void> recordSuccessfulResend(
      String email,
      ) async {
    await startVerificationWindow(
      email,
    );
  }

  // ==============================================================
  // CHECK SMARTCITY VERIFICATION WINDOW
  // ==============================================================

  Future<bool> isVerificationWindowValid(
      String email,
      ) async {
    final EmailVerificationSecurityStatus
    status =
    await getStatus(
      email,
    );

    if (
    status.verificationExpiresAt ==
        null
    ) {
      return false;
    }

    return !status
        .verificationExpired;
  }

  // ==============================================================
  // CLEAR AFTER SUCCESS
  //
  // Call this after the email is confirmed and SmartCity accepts
  // the completed registration.
  // ==============================================================

  Future<void> clear(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final List<String> fields = [
      'issued_at',
      'expires_at',
      'last_sent_at',
      'resend_attempts',
      'resend_window_started_at',
      'blocked_until',
    ];

    for (
    final String field
    in fields
    ) {
      await prefs.remove(
        _key(
          email,
          field,
        ),
      );
    }
  }

  // ==============================================================
  // RESET RESEND PROTECTION
  //
  // Useful for testing/admin recovery.
  // ==============================================================

  Future<void> resetResendProtection(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.remove(
      _key(
        email,
        'blocked_until',
      ),
    );

    await prefs.remove(
      _key(
        email,
        'resend_window_started_at',
      ),
    );

    await prefs.setInt(
      _key(
        email,
        'resend_attempts',
      ),
      0,
    );
  }

  // ==============================================================
  // PARSE DATE
  // ==============================================================

  DateTime? _parseDate(
      String? value,
      ) {
    if (
    value == null ||
        value.trim().isEmpty
    ) {
      return null;
    }

    try {
      return DateTime.parse(
        value,
      );
    } catch (_) {
      return null;
    }
  }
}