import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String get _userId {
    final User? user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated user.',
      );
    }

    return user.id;
  }

  // ============================================================
  // GET SECURITY SETTINGS
  // ============================================================

  Future<Map<String, dynamic>?>
  getSecuritySettings() async {
    final Map<String, dynamic>? data =
    await _supabase
        .from(
      'user_security_settings',
    )
        .select()
        .eq(
      'user_id',
      _userId,
    )
        .maybeSingle();

    return data;
  }

  // ============================================================
  // ENSURE SECURITY SETTINGS EXIST
  // ============================================================

  Future<void>
  ensureSecuritySettings() async {
    final Map<String, dynamic>? existing =
    await getSecuritySettings();

    if (existing != null) {
      return;
    }

    await _supabase
        .from(
      'user_security_settings',
    )
        .insert({
      'user_id':
      _userId,

      'biometric_lock_enabled':
      false,

      'device_credential_fallback_enabled':
      true,

      'auto_lock_seconds':
      60,

      'quick_login_enabled':
      false,

      'security_notifications_enabled':
      true,
    });
  }

  // ============================================================
  // BIOMETRIC APP LOCK
  // ============================================================

  Future<void> setBiometricEnabled(
      bool enabled,
      ) async {
    await ensureSecuritySettings();

    final String now =
    DateTime.now()
        .toIso8601String();

    await _supabase
        .from(
      'user_security_settings',
    )
        .update({
      'biometric_lock_enabled':
      enabled,

      'last_security_update':
      now,

      'updated_at':
      now,
    })
        .eq(
      'user_id',
      _userId,
    );

    await logActivity(
      enabled
          ? 'BIOMETRIC_ENABLED'
          : 'BIOMETRIC_DISABLED',

      enabled
          ? 'Biometric app lock was enabled.'
          : 'Biometric app lock was disabled.',
    );
  }

  // ============================================================
  // BIOMETRIC STATUS
  // ============================================================

  Future<bool>
  isBiometricEnabled() async {
    await ensureSecuritySettings();

    final Map<String, dynamic>? settings =
    await getSecuritySettings();

    return settings?[
    'biometric_lock_enabled'
    ]
    as bool? ??
        false;
  }

  // ============================================================
  // AUTO LOCK
  // ============================================================

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

    await ensureSecuritySettings();

    final String now =
    DateTime.now()
        .toIso8601String();

    await _supabase
        .from(
      'user_security_settings',
    )
        .update({
      'auto_lock_seconds':
      seconds,

      'last_security_update':
      now,

      'updated_at':
      now,
    })
        .eq(
      'user_id',
      _userId,
    );

    await logActivity(
      'AUTO_LOCK_UPDATED',
      'Auto-lock duration was updated to $seconds seconds.',
    );
  }

  Future<int>
  getAutoLockSeconds() async {
    await ensureSecuritySettings();

    final Map<String, dynamic>? settings =
    await getSecuritySettings();

    final int seconds =
        settings?[
        'auto_lock_seconds'
        ]
        as int? ??
            60;

    if (seconds == 0 ||
        seconds == 60 ||
        seconds == 300) {
      return seconds;
    }

    return 60;
  }

  // ============================================================
  // QUICK LOGIN
  // ============================================================

  Future<void> setQuickLoginEnabled(
      bool enabled,
      ) async {
    await ensureSecuritySettings();

    final String now =
    DateTime.now()
        .toIso8601String();

    await _supabase
        .from(
      'user_security_settings',
    )
        .update({
      'quick_login_enabled':
      enabled,

      'last_security_update':
      now,

      'updated_at':
      now,
    })
        .eq(
      'user_id',
      _userId,
    );

    await logActivity(
      enabled
          ? 'QUICK_LOGIN_ENABLED'
          : 'QUICK_LOGIN_DISABLED',

      enabled
          ? 'Quick Login was enabled.'
          : 'Quick Login was disabled.',
    );
  }

  Future<bool>
  isQuickLoginEnabled() async {
    await ensureSecuritySettings();

    final Map<String, dynamic>? settings =
    await getSecuritySettings();

    return settings?[
    'quick_login_enabled'
    ]
    as bool? ??
        false;
  }

  // ============================================================
  // DEVICE CREDENTIAL FALLBACK
  // ============================================================

  Future<void>
  setDeviceCredentialFallbackEnabled(
      bool enabled,
      ) async {
    await ensureSecuritySettings();

    final String now =
    DateTime.now()
        .toIso8601String();

    await _supabase
        .from(
      'user_security_settings',
    )
        .update({
      'device_credential_fallback_enabled':
      enabled,

      'last_security_update':
      now,

      'updated_at':
      now,
    })
        .eq(
      'user_id',
      _userId,
    );

    await logActivity(
      enabled
          ? 'DEVICE_CREDENTIAL_FALLBACK_ENABLED'
          : 'DEVICE_CREDENTIAL_FALLBACK_DISABLED',

      enabled
          ? 'Device credential fallback was enabled.'
          : 'Device credential fallback was disabled.',
    );
  }

  Future<bool>
  isDeviceCredentialFallbackEnabled() async {
    await ensureSecuritySettings();

    final Map<String, dynamic>? settings =
    await getSecuritySettings();

    return settings?[
    'device_credential_fallback_enabled'
    ]
    as bool? ??
        true;
  }

  // ============================================================
  // SECURITY NOTIFICATIONS
  // ============================================================

  Future<void>
  setSecurityNotificationsEnabled(
      bool enabled,
      ) async {
    await ensureSecuritySettings();

    final String now =
    DateTime.now()
        .toIso8601String();

    await _supabase
        .from(
      'user_security_settings',
    )
        .update({
      'security_notifications_enabled':
      enabled,

      'last_security_update':
      now,

      'updated_at':
      now,
    })
        .eq(
      'user_id',
      _userId,
    );

    await logActivity(
      enabled
          ? 'SECURITY_NOTIFICATIONS_ENABLED'
          : 'SECURITY_NOTIFICATIONS_DISABLED',

      enabled
          ? 'Security notifications were enabled.'
          : 'Security notifications were disabled.',
    );
  }

  Future<bool>
  isSecurityNotificationsEnabled() async {
    await ensureSecuritySettings();

    final Map<String, dynamic>? settings =
    await getSecuritySettings();

    return settings?[
    'security_notifications_enabled'
    ]
    as bool? ??
        true;
  }

  // ============================================================
  // ACCOUNT ACTIVITY
  //
  // Safe even during logout.
  // ============================================================

  Future<void> logActivity(
      String activityType,
      String description,
      ) async {
    try {
      final User? user =
          _supabase.auth.currentUser;

      if (user == null) {
        return;
      }

      await _supabase
          .from(
        'account_activity',
      )
          .insert({
        'user_id':
        user.id,

        'activity_type':
        activityType,

        'description':
        description,
      });
    } catch (_) {
      // Security logging must never break
      // the user's primary action.
    }
  }
}