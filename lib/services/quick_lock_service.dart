import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuickLockService {
  // ============================================================
  // STORAGE KEYS
  // ============================================================

  static const String _lockedKey =
      'smartcity_quick_locked';

  static const String _lockedUserIdKey =
      'smartcity_quick_locked_user_id';

  static const String _lockReasonKey =
      'smartcity_quick_lock_reason';

  static const String _enabledPrefix =
      'smartcity_quick_login_enabled_';

  // ============================================================
  // LOCK REASONS
  // ============================================================

  static const String manualLockReason =
      'manual';

  static const String returnToLoginReason =
      'login';

  // ============================================================
  // CURRENT APP-RUN VERIFICATION
  //
  // MEMORY ONLY.
  //
  // This prevents:
  //
  // Email Login
  // -> biometric again ❌
  //
  // Google Login
  // -> biometric again ❌
  //
  // Instead:
  //
  // successful authentication
  // -> dashboard ✅
  // ============================================================

  static bool _verifiedForCurrentRun =
  false;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId =>
      Supabase.instance.client.auth
          .currentUser?.id;

  String _enabledKey(
      String userId,
      ) {
    return '$_enabledPrefix$userId';
  }

  // ============================================================
  // GENERIC LOCK
  // ============================================================

  Future<void> lock({
    String reason =
        manualLockReason,
  }) async {
    final String? userId =
        currentUserId;

    if (userId == null) {
      throw Exception(
        'No authenticated user.',
      );
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setBool(
      _lockedKey,
      true,
    );

    await prefs.setString(
      _lockedUserIdKey,
      userId,
    );

    await prefs.setString(
      _lockReasonKey,
      reason,
    );

    _verifiedForCurrentRun =
    false;
  }

  // ============================================================
  // MANUAL QUICK LOCK
  //
  // Back must NOT bypass this.
  // ============================================================

  Future<void> manualQuickLock() async {
    await lock(
      reason:
      manualLockReason,
    );
  }

  // ============================================================
  // SIGN OUT TO LOGIN
  //
  // This deliberately keeps the Supabase session.
  //
  // Login can then offer:
  // - Quick Login
  // - Email / Password
  // - Google
  // ============================================================

  Future<void>
  lockForReturnToLogin() async {
    await lock(
      reason:
      returnToLoginReason,
    );
  }

  // ============================================================
  // UNLOCK
  // ============================================================

  Future<void> unlock() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setBool(
      _lockedKey,
      false,
    );

    await prefs.remove(
      _lockedUserIdKey,
    );

    await prefs.remove(
      _lockReasonKey,
    );
  }

  // ============================================================
  // CHECK LOCK
  // ============================================================

  Future<bool> isLocked() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final bool locked =
        prefs.getBool(
          _lockedKey,
        ) ??
            false;

    if (!locked) {
      return false;
    }

    final String? savedUserId =
    prefs.getString(
      _lockedUserIdKey,
    );

    final String? activeUserId =
        currentUserId;

    // A lock belongs only to the same
    // authenticated Supabase user.
    if (savedUserId == null ||
        activeUserId == null ||
        savedUserId != activeUserId) {
      await unlock();

      return false;
    }

    return true;
  }

  // ============================================================
  // LOCK REASON
  // ============================================================

  Future<String?>
  getLockReason() async {
    final bool locked =
    await isLocked();

    if (!locked) {
      return null;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    return prefs.getString(
      _lockReasonKey,
    );
  }

  // ============================================================
  // MANUAL QUICK LOCK?
  // ============================================================

  Future<bool>
  isManualQuickLock() async {
    final String? reason =
    await getLockReason();

    return reason ==
        manualLockReason;
  }

  // ============================================================
  // SIGN-OUT-TO-LOGIN?
  // ============================================================

  Future<bool>
  isReturnToLogin() async {
    final String? reason =
    await getLockReason();

    return reason ==
        returnToLoginReason;
  }

  // ============================================================
  // QUICK LOGIN ENABLE / DISABLE
  // ============================================================

  Future<void> setQuickLoginEnabled(
      bool enabled,
      ) async {
    final String? userId =
        currentUserId;

    if (userId == null) {
      throw Exception(
        'No authenticated user.',
      );
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setBool(
      _enabledKey(
        userId,
      ),
      enabled,
    );

    if (!enabled) {
      await unlock();

      _verifiedForCurrentRun =
      false;
    }
  }

  // ============================================================
  // QUICK LOGIN STATUS
  // ============================================================

  Future<bool>
  isQuickLoginEnabled() async {
    final String? userId =
        currentUserId;

    if (userId == null) {
      return false;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    return prefs.getBool(
      _enabledKey(
        userId,
      ),
    ) ??
        false;
  }

  // ============================================================
  // CURRENT RUN VERIFICATION
  // ============================================================

  bool get isVerifiedForCurrentRun =>
      _verifiedForCurrentRun;

  // ============================================================
  // AUTHENTICATION SUCCEEDED
  //
  // Call after:
  // - Email / Password success
  // - Google success
  // - Quick Login success
  // ============================================================

  void markVerifiedForCurrentRun() {
    _verifiedForCurrentRun =
    true;
  }

  // ============================================================
  // REQUIRE VERIFICATION AGAIN
  // ============================================================

  void requireVerificationAgain() {
    _verifiedForCurrentRun =
    false;
  }

  // ============================================================
  // LOCKED USER
  // ============================================================

  Future<String?>
  getLockedUserId() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    return prefs.getString(
      _lockedUserIdKey,
    );
  }

  // ============================================================
  // CLEAR LOCK STATE
  // ============================================================

  Future<void>
  clearQuickLockState() async {
    await unlock();
  }

  // ============================================================
  // FULL SESSION RESET
  //
  // Use BEFORE a real Supabase logout.
  // ============================================================

  Future<void>
  clearForFullSignOut() async {
    await unlock();

    _verifiedForCurrentRun =
    false;
  }
}