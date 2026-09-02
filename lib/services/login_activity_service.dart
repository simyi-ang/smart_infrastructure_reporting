import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/login_activity.dart';

class LoginActivityService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  User? get currentUser =>
      _supabase.auth.currentUser;

  // ============================================================
  // RECORD LOGIN
  // ============================================================

  Future<void> recordLogin({
    required String loginMethod,
  }) async {
    final user =
        currentUser;

    if (user == null) {
      return;
    }

    try {
      await _supabase
          .from('login_activity')
          .insert({
        'user_id':
        user.id,

        'login_method':
        loginMethod,

        'device_info':
        _deviceInfo(),

        'platform':
        _platformName(),

        'success':
        true,
      });
    } catch (_) {
      // Login activity should never block login.
    }
  }

  // ============================================================
  // GET ACTIVITY
  // ============================================================

  Future<List<LoginActivity>>
  getMyLoginActivity({
    int limit = 20,
  }) async {
    final user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from('login_activity')
          .select()
          .eq(
        'user_id',
        user.id,
      )
          .order(
        'created_at',
        ascending:
        false,
      )
          .limit(
        limit,
      );

      return response
          .map(
            (item) =>
            LoginActivity.fromMap(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList();
    } catch (e) {
      throw Exception(
        'Unable to load login activity: $e',
      );
    }
  }

  // ============================================================
  // PLATFORM
  // ============================================================

  String _platformName() {
    if (Platform.isAndroid) {
      return 'Android';
    }

    if (Platform.isIOS) {
      return 'iOS';
    }

    if (Platform.isWindows) {
      return 'Windows';
    }

    if (Platform.isMacOS) {
      return 'macOS';
    }

    if (Platform.isLinux) {
      return 'Linux';
    }

    return 'Unknown';
  }

  // ============================================================
  // DEVICE INFO
  // ============================================================

  String _deviceInfo() {
    if (Platform.isAndroid) {
      return 'Android Device';
    }

    if (Platform.isIOS) {
      return 'iPhone / iPad';
    }

    return _platformName();
  }
}