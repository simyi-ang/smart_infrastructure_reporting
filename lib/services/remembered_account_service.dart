import 'package:shared_preferences/shared_preferences.dart';

class RememberedAccountService {
  static const String _rememberAccountKey =
      'smartcity_remember_account';

  static const String _rememberedEmailKey =
      'smartcity_remembered_email';

  static const String _rememberedGoogleEmailKey =
      'smartcity_remembered_google_email';

  static const String _rememberedGoogleNameKey =
      'smartcity_remembered_google_name';

  static const String _lastLoginMethodKey =
      'smartcity_last_login_method';

  // ============================================================
  // REMEMBER ACCOUNT ENABLED
  // ============================================================

  Future<void> setRememberAccount(
      bool enabled,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setBool(
      _rememberAccountKey,
      enabled,
    );

    if (!enabled) {
      await clearRememberedAccount();
    }
  }

  Future<bool>
  isRememberAccountEnabled() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    return prefs.getBool(
      _rememberAccountKey,
    ) ??
        false;
  }

  // ============================================================
  // EMAIL ACCOUNT
  // ============================================================

  Future<void> rememberEmail(
      String email,
      ) async {
    final String cleanEmail =
    email
        .trim()
        .toLowerCase();

    if (cleanEmail.isEmpty) {
      return;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setString(
      _rememberedEmailKey,
      cleanEmail,
    );

    await prefs.setString(
      _lastLoginMethodKey,
      'email',
    );
  }

  Future<String?>
  getRememberedEmail() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final String? value =
    prefs.getString(
      _rememberedEmailKey,
    );

    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  // ============================================================
  // GOOGLE ACCOUNT
  // ============================================================

  Future<void> rememberGoogleAccount({
    required String email,
    String? name,
  }) async {
    final String cleanEmail =
    email
        .trim()
        .toLowerCase();

    if (cleanEmail.isEmpty) {
      return;
    }

    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.setString(
      _rememberedGoogleEmailKey,
      cleanEmail,
    );

    if (name != null &&
        name.trim().isNotEmpty) {
      await prefs.setString(
        _rememberedGoogleNameKey,
        name.trim(),
      );
    } else {
      await prefs.remove(
        _rememberedGoogleNameKey,
      );
    }

    await prefs.setString(
      _lastLoginMethodKey,
      'google',
    );
  }

  Future<String?>
  getRememberedGoogleEmail() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final String? value =
    prefs.getString(
      _rememberedGoogleEmailKey,
    );

    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  Future<String?>
  getRememberedGoogleName() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final String? value =
    prefs.getString(
      _rememberedGoogleNameKey,
    );

    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  // ============================================================
  // LAST LOGIN METHOD
  // ============================================================

  Future<String?>
  getLastLoginMethod() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final String? method =
    prefs.getString(
      _lastLoginMethodKey,
    );

    if (method == 'email' ||
        method == 'google') {
      return method;
    }

    return null;
  }

  // ============================================================
  // HAS REMEMBERED ACCOUNT
  // ============================================================

  Future<bool>
  hasRememberedAccount() async {
    final bool enabled =
    await isRememberAccountEnabled();

    if (!enabled) {
      return false;
    }

    final String? email =
    await getRememberedEmail();

    final String? googleEmail =
    await getRememberedGoogleEmail();

    return email != null ||
        googleEmail != null;
  }

  // ============================================================
  // CLEAR REMEMBERED INFORMATION
  //
  // IMPORTANT:
  //
  // Passwords are NOT stored here.
  //
  // Android / iOS password manager handles passwords.
  // ============================================================

  Future<void>
  clearRememberedAccount() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.remove(
      _rememberedEmailKey,
    );

    await prefs.remove(
      _rememberedGoogleEmailKey,
    );

    await prefs.remove(
      _rememberedGoogleNameKey,
    );

    await prefs.remove(
      _lastLoginMethodKey,
    );
  }

  // ============================================================
  // FORGET THIS DEVICE
  // ============================================================

  Future<void> forgetDevice() async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.remove(
      _rememberAccountKey,
    );

    await clearRememberedAccount();
  }
}