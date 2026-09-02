import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityPreferencesService {
  static const String _biometricLockKey =
      'biometric_lock_enabled';

  static const String _autoLockSecondsKey =
      'auto_lock_seconds';

  static const String _lastBackgroundTimeKey =
      'last_background_time';

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get _currentUserId =>
      Supabase.instance.client.auth
          .currentUser?.id;

  String? _userKey(
      String key,
      ) {
    final String? userId =
        _currentUserId;

    if (userId == null) {
      return null;
    }

    return '${key}_$userId';
  }

  // ============================================================
  // BIOMETRIC LOCK
  // ============================================================

  Future<bool>
  isBiometricLockEnabled() async {
    final String? key =
    _userKey(
      _biometricLockKey,
    );

    if (key == null) {
      return false;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    return prefs.getBool(
      key,
    ) ??
        false;
  }

  Future<void>
  setBiometricLockEnabled(
      bool enabled,
      ) async {
    final String? key =
    _userKey(
      _biometricLockKey,
    );

    if (key == null) {
      return;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setBool(
      key,
      enabled,
    );
  }

  // ============================================================
  // AUTO LOCK
  // ============================================================

  Future<int>
  getAutoLockSeconds() async {
    final String? key =
    _userKey(
      _autoLockSecondsKey,
    );

    if (key == null) {
      return 60;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final int seconds =
        prefs.getInt(
          key,
        ) ??
            60;

    if (seconds == 0 ||
        seconds == 60 ||
        seconds == 300) {
      return seconds;
    }

    return 60;
  }

  Future<void> setAutoLockSeconds(
      int seconds,
      ) async {
    if (seconds != 0 &&
        seconds != 60 &&
        seconds != 300) {
      throw Exception(
        'Unsupported auto-lock duration.',
      );
    }

    final String? key =
    _userKey(
      _autoLockSecondsKey,
    );

    if (key == null) {
      return;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setInt(
      key,
      seconds,
    );
  }

  // ============================================================
  // BACKGROUND TIME
  // ============================================================

  Future<void>
  saveBackgroundTime() async {
    final String? key =
    _userKey(
      _lastBackgroundTimeKey,
    );

    if (key == null) {
      return;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setInt(
      key,
      DateTime.now()
          .millisecondsSinceEpoch,
    );
  }

  Future<DateTime?>
  getLastBackgroundTime() async {
    final String? key =
    _userKey(
      _lastBackgroundTimeKey,
    );

    if (key == null) {
      return null;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final int? milliseconds =
    prefs.getInt(
      key,
    );

    if (milliseconds == null) {
      return null;
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      milliseconds,
    );
  }

  Future<void>
  clearBackgroundTime() async {
    final String? key =
    _userKey(
      _lastBackgroundTimeKey,
    );

    if (key == null) {
      return;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.remove(
      key,
    );
  }

  // ============================================================
  // CLEAR CURRENT USER SECURITY PREFERENCES
  //
  // Use this for:
  // Forget This Device
  //
  // Do not normally use it for the trusted-device
  // Sign Out flow.
  // ============================================================

  Future<void>
  clearCurrentUserSecurityPreferences() async {
    final String? biometricKey =
    _userKey(
      _biometricLockKey,
    );

    final String? autoLockKey =
    _userKey(
      _autoLockSecondsKey,
    );

    final String? backgroundKey =
    _userKey(
      _lastBackgroundTimeKey,
    );

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    if (biometricKey != null) {
      await prefs.remove(
        biometricKey,
      );
    }

    if (autoLockKey != null) {
      await prefs.remove(
        autoLockKey,
      );
    }

    if (backgroundKey != null) {
      await prefs.remove(
        backgroundKey,
      );
    }
  }
}