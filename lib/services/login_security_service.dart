import 'package:shared_preferences/shared_preferences.dart';

class LoginSecurityStatus {
  final int failedAttempts;
  final bool isBlocked;
  final DateTime? blockedUntil;

  const LoginSecurityStatus({
    required this.failedAttempts,
    required this.isBlocked,
    this.blockedUntil,
  });

  Duration get remainingBlockTime {
    final until = blockedUntil;

    if (until == null) {
      return Duration.zero;
    }

    final difference =
    until.difference(
      DateTime.now(),
    );

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }
}

class LoginSecurityService {
  static const int maxFailedAttempts = 5;

  static const Duration blockDuration =
  Duration(
    minutes: 5,
  );

  final SharedPreferencesAsync _preferences =
  SharedPreferencesAsync();

  // ============================================================
  // KEY HELPERS
  // ============================================================

  String _normalizedEmail(
      String email,
      ) {
    return email
        .trim()
        .toLowerCase();
  }

  String _attemptKey(
      String email,
      ) {
    return 'login_attempts_${_normalizedEmail(email)}';
  }

  String _blockKey(
      String email,
      ) {
    return 'login_block_until_${_normalizedEmail(email)}';
  }

  // ============================================================
  // GET CURRENT SECURITY STATUS
  // ============================================================

  Future<LoginSecurityStatus> getStatus(
      String email,
      ) async {
    final normalized =
    _normalizedEmail(
      email,
    );

    if (normalized.isEmpty) {
      return const LoginSecurityStatus(
        failedAttempts: 0,
        isBlocked: false,
      );
    }

    final int failedAttempts =
        await _preferences.getInt(
          _attemptKey(
            normalized,
          ),
        ) ??
            0;

    final String? blockUntilValue =
    await _preferences.getString(
      _blockKey(
        normalized,
      ),
    );

    if (blockUntilValue == null) {
      return LoginSecurityStatus(
        failedAttempts:
        failedAttempts,
        isBlocked:
        false,
      );
    }

    final DateTime? blockedUntil =
    DateTime.tryParse(
      blockUntilValue,
    );

    if (blockedUntil == null) {
      await _clearBlockOnly(
        normalized,
      );

      return LoginSecurityStatus(
        failedAttempts:
        failedAttempts,
        isBlocked:
        false,
      );
    }

    final bool stillBlocked =
    DateTime.now().isBefore(
      blockedUntil,
    );

    if (!stillBlocked) {
      await resetAttempts(
        normalized,
      );

      return const LoginSecurityStatus(
        failedAttempts: 0,
        isBlocked: false,
      );
    }

    return LoginSecurityStatus(
      failedAttempts:
      failedAttempts,
      isBlocked:
      true,
      blockedUntil:
      blockedUntil,
    );
  }

  // ============================================================
  // RECORD FAILED ATTEMPT
  // ============================================================

  Future<LoginSecurityStatus> recordFailedAttempt(
      String email,
      ) async {
    final normalized =
    _normalizedEmail(
      email,
    );

    final LoginSecurityStatus current =
    await getStatus(
      normalized,
    );

    if (current.isBlocked) {
      return current;
    }

    final int newAttempts =
        current.failedAttempts +
            1;

    await _preferences.setInt(
      _attemptKey(
        normalized,
      ),
      newAttempts,
    );

    if (newAttempts >=
        maxFailedAttempts) {
      final DateTime blockedUntil =
      DateTime.now().add(
        blockDuration,
      );

      await _preferences.setString(
        _blockKey(
          normalized,
        ),
        blockedUntil
            .toIso8601String(),
      );

      return LoginSecurityStatus(
        failedAttempts:
        newAttempts,
        isBlocked:
        true,
        blockedUntil:
        blockedUntil,
      );
    }

    return LoginSecurityStatus(
      failedAttempts:
      newAttempts,
      isBlocked:
      false,
    );
  }

  // ============================================================
  // RESET AFTER SUCCESS
  // ============================================================

  Future<void> resetAttempts(
      String email,
      ) async {
    final normalized =
    _normalizedEmail(
      email,
    );

    await _preferences.remove(
      _attemptKey(
        normalized,
      ),
    );

    await _preferences.remove(
      _blockKey(
        normalized,
      ),
    );
  }

  // ============================================================
  // CLEAR BLOCK ONLY
  // ============================================================

  Future<void> _clearBlockOnly(
      String email,
      ) async {
    await _preferences.remove(
      _blockKey(
        email,
      ),
    );
  }

  // ============================================================
  // ATTEMPTS REMAINING
  // ============================================================

  Future<int> getAttemptsRemaining(
      String email,
      ) async {
    final status =
    await getStatus(
      email,
    );

    if (status.isBlocked) {
      return 0;
    }

    final remaining =
        maxFailedAttempts -
            status.failedAttempts;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }
}