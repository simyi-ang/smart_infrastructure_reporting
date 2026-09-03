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
// FEATURES
//
// - 5-minute verification validity
// - persistent verification timer
// - 60-second minimum resend interval
// - maximum 3 successful resends in 10 minutes
// - 15-minute temporary resend block
// - failed Supabase resend does NOT consume an attempt
// - successful resend starts a fresh 5-minute window
//
// IMPORTANT
//
// This is an application security layer.
//
// Supabase still remains responsible for:
// - generating the verification token
// - validating the token
// - actual token expiration
// - Auth rate limits
// ================================================================

class EmailVerificationSecurityService {
  // ==============================================================
  // CONFIGURATION
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
  // STORAGE PREFIX
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
  // KEY
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
  // START INITIAL VERIFICATION WINDOW
  //
  // Call this after signUp() succeeds.
  //
  // This represents the initial verification email.
  //
  // IMPORTANT:
  // This does NOT increase resendAttempts because the signup email
  // is not considered a resend.
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
      expiresAt
          .toIso8601String(),
    );

    // Initial signup email was just sent.
    // Prevent immediate resend spam.
    await prefs.setString(
      _key(
        email,
        'last_sent_at',
      ),
      now.toIso8601String(),
    );

    // Start clean resend protection for a new registration.
    await prefs.setInt(
      _key(
        email,
        'resend_attempts',
      ),
      0,
    );

    await prefs.remove(
      _key(
        email,
        'resend_window_started_at',
      ),
    );

    await prefs.remove(
      _key(
        email,
        'blocked_until',
      ),
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

    int resendAttempts =
        prefs.getInt(
          _key(
            email,
            'resend_attempts',
          ),
        ) ??
            0;

    DateTime? blockedUntil =
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

    bool resendBlocked =
        blockedUntil != null &&
            now.isBefore(
              blockedUntil,
            );

    Duration resendBlockRemaining =
        Duration.zero;

    if (resendBlocked) {
      resendBlockRemaining =
          blockedUntil!.difference(
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

      resendAttempts =
      0;

      blockedUntil =
      null;

      resendBlocked =
      false;

      resendBlockRemaining =
          Duration.zero;
    }

    // ============================================================
    // AUTO-RESET OLD RESEND WINDOW
    //
    // If 10 minutes passed since the resend window began and
    // there is no active block, reset successful resend count.
    // ============================================================

    final DateTime? resendWindowStartedAt =
    _parseDate(
      prefs.getString(
        _key(
          email,
          'resend_window_started_at',
        ),
      ),
    );

    if (
    !resendBlocked &&
        resendWindowStartedAt !=
            null &&
        now.difference(
          resendWindowStartedAt,
        ) >=
            resendWindow
    ) {
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

      resendAttempts =
      0;
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
  // CHECK WHETHER RESEND IS ALLOWED
  //
  // IMPORTANT:
  //
  // This method DOES NOT:
  // - increment resendAttempts
  // - restart the 5-minute verification timer
  // - record a successful send
  //
  // It only determines whether Flutter is allowed to call:
  //
  // Supabase.auth.resend(...)
  //
  // Therefore, a network/API failure does not consume an attempt.
  // ==============================================================

  Future<EmailVerificationResendResult>
  checkResendAllowed(
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
      final int attempts =
          prefs.getInt(
            _key(
              email,
              'resend_attempts',
            ),
          ) ??
              0;

      return EmailVerificationResendResult(
        allowed:
        false,

        protectionActivated:
        true,

        resendAttempts:
        attempts,

        blockedUntil:
        blockedUntil,

        message:
        'Too many verification email requests. '
            'Please wait before requesting another email.',
      );
    }

    // ============================================================
    // CLEAR EXPIRED BLOCK
    // ============================================================

    if (
    blockedUntil != null &&
        !now.isBefore(
          blockedUntil,
        )
    ) {
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

    // ============================================================
    // 60-SECOND MINIMUM SEND INTERVAL
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

    if (lastSentAt != null) {
      final Duration sinceLastSend =
      now.difference(
        lastSentAt,
      );

      if (
      sinceLastSend <
          minimumResendInterval
      ) {
        int remainingSeconds =
            minimumResendInterval
                .inSeconds -
                sinceLastSend
                    .inSeconds;

        if (remainingSeconds <
            1) {
          remainingSeconds =
          1;
        }

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
          'Please wait $remainingSeconds second'
              '${remainingSeconds == 1 ? '' : 's'} '
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
    resendWindowStartedAt !=
        null &&
        now.difference(
          resendWindowStartedAt,
        ) >=
            resendWindow
    ) {
      resendWindowStartedAt =
      null;

      resendAttempts =
      0;

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

    // ============================================================
    // MAXIMUM SUCCESSFUL RESENDS ALREADY USED
    //
    // 3 successful resends are allowed.
    //
    // The next request activates the 15-minute block.
    // ============================================================

    if (
    resendAttempts >=
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
  // CALL ONLY AFTER:
  //
  // await Supabase.instance.client.auth.resend(...)
  //
  // succeeds.
  //
  // This:
  // - increments successful resend count
  // - records last successful send
  // - creates resend window when needed
  // - creates a fresh five-minute verification window
  // ==============================================================

  Future<void> recordSuccessfulResend(
      String email,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final DateTime now =
    DateTime.now();

    // ============================================================
    // LOAD RESEND WINDOW
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
    // NEW / EXPIRED RESEND WINDOW
    // ============================================================

    if (
    resendWindowStartedAt ==
        null ||
        now.difference(
          resendWindowStartedAt,
        ) >=
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
    }

    // ============================================================
    // INCREMENT ONLY AFTER SUCCESS
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
    // LAST SUCCESSFUL EMAIL SEND
    // ============================================================

    await prefs.setString(
      _key(
        email,
        'last_sent_at',
      ),
      now.toIso8601String(),
    );

    // ============================================================
    // NEW VERIFICATION WINDOW
    // ============================================================

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
      now
          .add(
        verificationValidity,
      )
          .toIso8601String(),
    );
  }

  // ==============================================================
  // CHECK WHETHER SMARTCITY VERIFICATION WINDOW IS VALID
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
  // GET VERIFICATION EXPIRY
  // ==============================================================

  Future<DateTime?> getVerificationExpiresAt(
      String email,
      ) async {
    final EmailVerificationSecurityStatus
    status =
    await getStatus(
      email,
    );

    return status
        .verificationExpiresAt;
  }

  // ==============================================================
  // GET RESEND ATTEMPTS
  // ==============================================================

  Future<int> getResendAttempts(
      String email,
      ) async {
    final EmailVerificationSecurityStatus
    status =
    await getStatus(
      email,
    );

    return status
        .resendAttempts;
  }

  // ==============================================================
  // CHECK WHETHER RESEND IS BLOCKED
  // ==============================================================

  Future<bool> isResendBlocked(
      String email,
      ) async {
    final EmailVerificationSecurityStatus
    status =
    await getStatus(
      email,
    );

    return status
        .resendBlocked;
  }

  // ==============================================================
  // CLEAR AFTER SUCCESSFUL VERIFICATION
  //
  // Call when:
  //
  // emailConfirmed == true
  //
  // and SmartCity accepts registration as complete.
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
  // Primarily useful while testing.
  //
  // Does NOT clear the verification timer.
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
  // CLEAR VERIFICATION WINDOW ONLY
  //
  // Useful when a pending registration is abandoned without
  // clearing resend-security information.
  // ==============================================================

  Future<void> clearVerificationWindow(
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