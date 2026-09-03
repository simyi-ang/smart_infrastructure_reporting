import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import 'password_reset_security_service.dart';
import 'security_service.dart';

class RegistrationEmailCheckResult {
  final bool exists;
  final bool emailConfirmed;

  const RegistrationEmailCheckResult({
    required this.exists,
    required this.emailConfirmed,
  });
}

class AuthService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final PasswordResetSecurityService
  _passwordResetSecurityService =
  PasswordResetSecurityService();

  final SecurityService _securityService =
  SecurityService();

  // ============================================================
  // CONFIG
  // ============================================================

  static const String googleWebClientId =
      '307771884157-g5ja24663ijl6ohbm8q0ufl1hb1ogoaj.apps.googleusercontent.com';

  static const String avatarBucket =
      'avatars';

  bool _googleInitialized = false;

  // ============================================================
  // CURRENT USER / SESSION
  // ============================================================

  User? get currentUser =>
      _supabase.auth.currentUser;

  Session? get currentSession =>
      _supabase.auth.currentSession;

  bool get isLoggedIn =>
      currentUser != null;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // ============================================================
// CHECK REGISTRATION EMAIL
//
// Calls the server-side Edge Function.
//
// IMPORTANT:
// Flutter never receives SUPABASE_SERVICE_ROLE_KEY.
// The privileged auth.users lookup stays on the server.
//
// RESULT:
//
// exists == false
// → registration may continue.
//
// exists == true
// → do NOT call signUp() again.
// → RegisterScreen will show AccountAlreadyExistsScreen.
// ============================================================

  Future<RegistrationEmailCheckResult>
  checkRegistrationEmail(
      String email,
      ) async {
    final String cleanEmail =
    email
        .trim()
        .toLowerCase();

    if (cleanEmail.isEmpty) {
      throw Exception(
        'Email address is required.',
      );
    }

    try {
      final FunctionResponse response =
      await _supabase.functions.invoke(
        'check-registration-email',
        body: {
          'email':
          cleanEmail,
        },
      );

      // ==========================================================
      // EDGE FUNCTION ERROR
      // ==========================================================

      if (
      response.status <
          200 ||
          response.status >=
              300
      ) {
        final dynamic data =
            response.data;

        if (
        data is Map &&
            data['error'] !=
                null
        ) {
          throw Exception(
            data['error']
                .toString(),
          );
        }

        throw Exception(
          'Unable to check this email address. '
              'Please try again.',
        );
      }

      // ==========================================================
      // VALIDATE RESPONSE
      // ==========================================================

      final dynamic data =
          response.data;

      if (data is! Map) {
        throw Exception(
          'Unable to validate this email address.',
        );
      }

      // ==========================================================
      // RESULT
      // ==========================================================

      return RegistrationEmailCheckResult(
        exists:
        data['exists'] ==
            true,

        emailConfirmed:
        data['email_confirmed'] ==
            true,
      );
    } on FunctionException catch (e) {
      // ==========================================================
      // SUPABASE EDGE FUNCTION ERROR
      // ==========================================================

      final dynamic details =
          e.details;

      if (
      details is Map &&
          details['error'] !=
              null
      ) {
        throw Exception(
          details['error']
              .toString(),
        );
      }

      throw Exception(
        'Unable to check whether this email is already registered. '
            'Please try again.',
      );
    } catch (e) {
      // ==========================================================
      // PRESERVE OUR OWN FRIENDLY EXCEPTIONS
      // ==========================================================

      final String message =
      e
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      )
          .trim();

      if (message.isNotEmpty) {
        throw Exception(
          message,
        );
      }

      throw Exception(
        'Unable to check whether this email is already registered. '
            'Please try again.',
      );
    }
  }

  // ============================================================
  // REGISTER
  //
  // Supabase "Confirm Email" MUST be enabled.
  //
  // The account is created but cannot enter SmartCity until the
  // verification link has been completed.
  // ============================================================

  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final String cleanEmail =
    email
        .trim()
        .toLowerCase();

    try {
      final AuthResponse response =
      await _supabase.auth.signUp(
        email:
        cleanEmail,

        password:
        password,

        emailRedirectTo:
        'smartcity://email-verified',

        data: {
          'full_name':
          fullName.trim(),

          'phone':
          phone.trim(),
        },
      );

      if (
      response.user ==
          null
      ) {
        throw Exception(
          'Unable to create account.',
        );
      }

      // ==========================================================
      // IMPORTANT
      //
      // With Confirm Email enabled:
      //
      // response.user    -> exists
      // response.session -> normally null
      //
      // The citizen is therefore NOT authenticated yet.
      // ==========================================================

      if (
      response.session !=
          null &&
          response.user
              ?.emailConfirmedAt ==
              null
      ) {
        // Defensive protection in case project Auth settings are
        // changed accidentally.
        await _supabase.auth
            .signOut();
      }

      return response;
    } on AuthException catch (e) {
      final String normalized =
      e.message
          .toLowerCase();

      if (
      normalized.contains(
        'already registered',
      ) ||
          normalized.contains(
            'already exists',
          )
      ) {
        throw Exception(
          'This email address is already registered. '
              'Please sign in or use Forgot Password.',
        );
      }

      throw Exception(
        e.message,
      );
    } catch (e) {
      final String message =
      e
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      )
          .trim();

      if (message.isNotEmpty) {
        throw Exception(
          message,
        );
      }

      throw Exception(
        'Unable to create account.',
      );
    }
  }

// ============================================================
// LOGIN
//
// EMAIL/PASSWORD USERS MUST HAVE VERIFIED THEIR EMAIL.
//
// This is an application-level second check in addition to
// Supabase Confirm Email.
// ============================================================

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final String cleanEmail =
    email
        .trim()
        .toLowerCase();

    try {
      final AuthResponse response =
      await _supabase.auth
          .signInWithPassword(
        email:
        cleanEmail,

        password:
        password,
      );

      final User? user =
          response.user;

      if (user == null) {
        throw Exception(
          'Unable to sign in.',
        );
      }

      // ==========================================================
      // CHECK EMAIL/PASSWORD IDENTITY
      // ==========================================================

      final bool hasEmailIdentity =
          user.identities?.any(
                (
                identity,
                ) =>
            identity.provider ==
                'email',
          ) ??
              false;

      // ==========================================================
      // EMAIL VERIFICATION REQUIRED
      //
      // Google identity is handled by Google authentication and is
      // not blocked by this email/password-specific check.
      // ==========================================================

      if (
      hasEmailIdentity &&
          user.emailConfirmedAt ==
              null
      ) {
        await _supabase.auth
            .signOut();

        throw Exception(
          'EMAIL_NOT_VERIFIED',
        );
      }

      return response;
    } on AuthException catch (e) {
      final String normalized =
      e.message
          .toLowerCase();

      // Supabase normally returns this before creating a session
      // when Confirm Email is enabled.
      if (
      normalized.contains(
        'email not confirmed',
      ) ||
          normalized.contains(
            'email_not_confirmed',
          )
      ) {
        try {
          await _supabase.auth
              .signOut();
        } catch (_) {}

        throw Exception(
          'EMAIL_NOT_VERIFIED',
        );
      }

      throw Exception(
        e.message,
      );
    } catch (e) {
      final String message =
      e
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      )
          .trim();

      if (
      message ==
          'EMAIL_NOT_VERIFIED'
      ) {
        throw Exception(
          'EMAIL_NOT_VERIFIED',
        );
      }

      if (message.isNotEmpty) {
        throw Exception(
          message,
        );
      }

      throw Exception(
        'Unable to sign in.',
      );
    }
  }

  // ============================================================
  // GOOGLE INITIALIZATION
  // ============================================================

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) {
      return;
    }

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
        googleWebClientId,
      );

      _googleInitialized = true;
    } catch (_) {
      throw Exception(
        'Unable to initialize Google Sign-In.',
      );
    }
  }

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  Future<AuthResponse>
  signInWithGoogle() async {
    try {
      await _initializeGoogle();

      // ========================================================
      // START GOOGLE AUTHENTICATION
      // ========================================================

      final GoogleSignInAccount googleUser =
      await GoogleSignIn.instance
          .authenticate();

      // ========================================================
      // GOOGLE ID TOKEN
      // ========================================================

      final GoogleSignInAuthentication
      googleAuth =
          googleUser.authentication;

      final String? idToken =
          googleAuth.idToken;

      if (idToken == null ||
          idToken.isEmpty) {
        throw Exception(
          'Google did not return an ID token.',
        );
      }

      // ========================================================
      // GOOGLE ACCESS TOKEN
      //
      // First try to reuse existing authorization.
      // If none exists, request the required scopes.
      // ========================================================

      var authorization =
      await googleUser
          .authorizationClient
          .authorizationForScopes(
        const <String>[
          'email',
          'profile',
        ],
      );

      authorization ??=
      await googleUser
          .authorizationClient
          .authorizeScopes(
        const <String>[
          'email',
          'profile',
        ],
      );

      final String accessToken =
          authorization.accessToken;

      if (accessToken.isEmpty) {
        throw Exception(
          'Google did not return an access token.',
        );
      }

      // ========================================================
      // SUPABASE LOGIN
      // ========================================================

      final AuthResponse response =
      await _supabase.auth
          .signInWithIdToken(
        provider:
        OAuthProvider.google,

        idToken:
        idToken,

        accessToken:
        accessToken,
      );

      if (response.user == null) {
        throw Exception(
          'Google authentication completed, but SmartCity could not create a session.',
        );
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (e) {
      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      // ========================================================
      // FRIENDLIER GOOGLE ERRORS
      // ========================================================

      final String normalized =
      message.toLowerCase();

      if (normalized.contains(
        'cancel',
      ) ||
          normalized.contains(
            'canceled',
          )) {
        throw Exception(
          'Google Sign-In was cancelled.',
        );
      }

      if (normalized.contains(
        'network',
      ) ||
          normalized.contains(
            'internet',
          )) {
        throw Exception(
          'Unable to connect to Google. Check your internet connection and try again.',
        );
      }

      if (normalized.contains(
        'developer_error',
      ) ||
          normalized.contains(
            '10:',
          )) {
        throw Exception(
          'Google Sign-In configuration is invalid. Check the Android package name, SHA certificate fingerprints, and Google OAuth client settings.',
        );
      }

      if (message.trim().isEmpty) {
        throw Exception(
          'Unable to sign in with Google.',
        );
      }

      throw Exception(
        message,
      );
    }
  }

  // ============================================================
  // RE-AUTH EMAIL/PASSWORD USER
  // ============================================================

  Future<void> reauthenticateWithPassword({
    required String currentPassword,
  }) async {
    final User? user =
        currentUser;

    final String? email =
        user?.email;

    if (user == null ||
        email == null) {
      throw Exception(
        'Unable to verify your account.',
      );
    }

    if (!hasEmailPasswordIdentity) {
      throw Exception(
        'This account does not use an email/password sign-in.',
      );
    }

    try {
      final AuthResponse response =
      await _supabase.auth
          .signInWithPassword(
        email:
        email,

        password:
        currentPassword,
      );

      if (response.user == null) {
        throw Exception(
          'Current password is incorrect.',
        );
      }
    } on AuthException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // RE-AUTH GOOGLE USER
  // ============================================================

  Future<void>
  reauthenticateGoogle() async {
    if (!isGoogleUser) {
      throw Exception(
        'This account is not connected to Google.',
      );
    }

    try {
      final AuthResponse response =
      await signInWithGoogle();

      if (response.user == null) {
        throw Exception(
          'Google verification failed.',
        );
      }
    } catch (e) {
      throw Exception(
        'Google verification failed: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();

      try {
        await _initializeGoogle();

        await GoogleSignIn.instance
            .signOut();
      } catch (_) {
        // Google local sign-out failure should
        // not prevent Supabase logout.
      }
    } on AuthException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (_) {
      throw Exception(
        'Unable to sign out.',
      );
    }
  }

  // ============================================================
// FORGOT PASSWORD
//
// SECURITY CONTROLS:
//
// - Recovery email expires according to Supabase Auth settings.
// - SmartCity recovery callback uses PKCE.
// - Supabase Auth rate limits remain active.
// - SmartCity additionally monitors repeated reset requests.
// - Repeated abuse can cause temporary recovery restriction.
// - Generic UI responses prevent account enumeration.
// - Security events are logged where a user identity is
//   available.
// ============================================================

  Future<PasswordResetSecurityResult> forgotPassword(
      String email,
      ) async {
    final String cleanEmail =
    email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      throw Exception(
        'Please enter your email address.',
      );
    }

    // ==========================================================
    // SMARTCITY PASSWORD-RESET SECURITY CHECK
    // ==========================================================

    final PasswordResetSecurityResult securityResult =
    await _passwordResetSecurityService
        .checkAndRecordRequest(
      cleanEmail,
    );

    // ==========================================================
    // TEMPORARY SECURITY BLOCK
    // ==========================================================

    if (!securityResult.allowed) {
      await _safeSecurityLog(
        'PASSWORD_RESET_RATE_LIMITED',
        'Repeated password reset requests were temporarily restricted.',
      );

      return securityResult;
    }

    try {
      // ========================================================
      // SEND RECOVERY EMAIL
      // ========================================================

      await _supabase.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo:
        'smartcity://reset-password',
      );

      // ========================================================
      // PASSWORD RESET REQUEST AUDIT
      //
      // Forgot Password normally happens while signed out.
      // SecurityService safely ignores this event if there is no
      // authenticated user available for account_activity.
      // ========================================================

      await _safeSecurityLog(
        'PASSWORD_RESET_REQUESTED',
        'A password reset was requested.',
      );

      // ========================================================
      // SMARTCITY PROTECTION ACTIVATED
      // ========================================================

      if (securityResult.protectionActivated) {
        await _safeSecurityLog(
          'PASSWORD_RESET_PROTECTION_ACTIVATED',
          'Password reset protection was activated after repeated requests.',
        );
      }

      return securityResult;
    } on AuthException catch (e) {
      final String normalized =
      e.message.toLowerCase();

      // ========================================================
      // SUPABASE RATE LIMIT
      // ========================================================

      if (normalized.contains(
        'rate',
      ) ||
          normalized.contains(
            'too many',
          )) {
        await _safeSecurityLog(
          'PASSWORD_RESET_RATE_LIMITED',
          'Supabase temporarily restricted repeated password reset requests.',
        );

        throw Exception(
          'Too many password reset requests. '
              'Please wait before requesting another email.',
        );
      }

      await _safeSecurityLog(
        'PASSWORD_RESET_REQUEST_FAILED',
        'A password reset request could not be completed.',
      );

      throw Exception(
        e.message,
      );
    } catch (e) {
      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      await _safeSecurityLog(
        'PASSWORD_RESET_REQUEST_FAILED',
        'A password reset request could not be completed.',
      );

      if (message.trim().isEmpty) {
        throw Exception(
          'Unable to process the password reset request.',
        );
      }

      throw Exception(
        message,
      );
    }
  }

// ============================================================
// UPDATE PASSWORD DURING RECOVERY
//
// This keeps password-recovery business logic inside
// AuthService instead of directly inside the UI.
// ============================================================

  Future<UserResponse> updateRecoveredPassword({
    required String newPassword,
  }) async {
    final Session? recoverySession =
        _supabase.auth.currentSession;

    if (recoverySession == null) {
      throw Exception(
        'Your password reset session is no longer valid. '
            'Please request a new password reset link.',
      );
    }

    if (newPassword.trim().isEmpty) {
      throw Exception(
        'New password is required.',
      );
    }

    try {
      final UserResponse response =
      await _supabase.auth.updateUser(
        UserAttributes(
          password:
          newPassword,
        ),
      );

      if (response.user == null) {
        throw Exception(
          'Unable to update password.',
        );
      }

      // ========================================================
      // AUDIT PASSWORD CHANGE BEFORE RECOVERY SESSION ENDS
      // ========================================================

      await _safeSecurityLog(
        'PASSWORD_CHANGED',
        'The account password was changed successfully.',
      );

      return response;
    } on AuthException catch (e) {
      final String normalized =
      e.message.toLowerCase();

      if (normalized.contains(
        'expired',
      ) ||
          normalized.contains(
            'invalid',
          ) ||
          normalized.contains(
            'session',
          ) ||
          normalized.contains(
            'otp_expired',
          )) {
        await _safeSecurityLog(
          'PASSWORD_RESET_FAILED',
          'Password recovery failed because the recovery session was invalid or expired.',
        );

        throw Exception(
          'This password reset session is invalid or has expired. '
              'Please request a new password reset link.',
        );
      }

      await _safeSecurityLog(
        'PASSWORD_RESET_FAILED',
        'The password could not be changed during recovery.',
      );

      throw Exception(
        e.message,
      );
    } catch (e) {
      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      await _safeSecurityLog(
        'PASSWORD_RESET_FAILED',
        'The password could not be changed during recovery.',
      );

      if (message.trim().isEmpty) {
        throw Exception(
          'Unable to update password.',
        );
      }

      throw Exception(
        message,
      );
    }
  }

  // ============================================================
  // END PASSWORD RECOVERY SESSION
  //
  // After recovery succeeds, the temporary authenticated
  // recovery session is ended so the user must sign in normally
  // using the new password.
  // ============================================================

  Future<void> endRecoverySession() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (_) {
      throw Exception(
        'Unable to end the password recovery session.',
      );
    }
  }

  // ============================================================
  // SAFE SECURITY LOG
  //
  // Authentication must never fail because activity logging
  // failed.
  // ============================================================

  Future<void> _safeSecurityLog(
      String activityType,
      String description,
      ) async {
    try {
      await _securityService.logActivity(
        activityType,
        description,
      );
    } catch (_) {
      // Logging failure intentionally ignored.
    }
  }

  // ============================================================
  // CHANGE PASSWORD WITH CURRENT PASSWORD
  // ============================================================

  Future<void>
  changePasswordWithCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User? user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    if (!hasEmailPasswordIdentity) {
      throw Exception(
        'Password change is only available for email/password accounts.',
      );
    }

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password:
          newPassword,

          currentPassword:
          currentPassword,
        ),
      );
    } on AuthException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (_) {
      throw Exception(
        'Unable to change password.',
      );
    }
  }

  // ============================================================
  // EMAIL VERIFIED
  // ============================================================

  bool get isEmailVerified {
    final User? user =
        currentUser;

    if (user == null) {
      return false;
    }

    return user.emailConfirmedAt !=
        null;
  }

  // ============================================================
  // GOOGLE USER
  // ============================================================

  bool get isGoogleUser {
    final User? user =
        currentUser;

    if (user == null) {
      return false;
    }

    return user.identities?.any(
          (identity) =>
      identity.provider ==
          'google',
    ) ??
        false;
  }

  // ============================================================
  // EMAIL/PASSWORD USER
  // ============================================================

  bool get hasEmailPasswordIdentity {
    final User? user =
        currentUser;

    if (user == null) {
      return false;
    }

    return user.identities?.any(
          (identity) =>
      identity.provider ==
          'email',
    ) ??
        false;
  }

  // ============================================================
  // SIGN-IN METHOD
  // ============================================================

  String get signInMethod {
    if (isGoogleUser &&
        hasEmailPasswordIdentity) {
      return 'Google + Email/Password';
    }

    if (isGoogleUser) {
      return 'Google';
    }

    if (hasEmailPasswordIdentity) {
      return 'Email / Password';
    }

    return 'Unknown';
  }

  // ============================================================
  // SESSION INFO
  // ============================================================

  Map<String, String>
  getSessionInfo() {
    final User? user =
        currentUser;

    final Session? session =
        currentSession;

    return {
      'email':
      user?.email ??
          'Unknown',

      'user_id':
      user?.id ??
          'Unknown',

      'sign_in_method':
      signInMethod,

      'email_verified':
      isEmailVerified
          ? 'Verified'
          : 'Not verified',

      'session_active':
      session != null
          ? 'Yes'
          : 'No',
    };
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<UserProfile?>
  getCurrentProfile() async {
    final User? user =
        currentUser;

    if (user == null) {
      return null;
    }

    try {
      final Map<String, dynamic>?
      response =
      await _supabase
          .from(
        'profiles',
      )
          .select()
          .eq(
        'id',
        user.id,
      )
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return UserProfile.fromMap(
        response,
      );
    } catch (e) {
      throw Exception(
        'Unable to load profile: $e',
      );
    }
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final User? user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      await _supabase
          .from(
        'profiles',
      )
          .update({
        'full_name':
        fullName.trim(),

        'phone':
        phone.trim(),

        'updated_at':
        DateTime.now()
            .toIso8601String(),
      })
          .eq(
        'id',
        user.id,
      );

      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name':
            fullName.trim(),

            'phone':
            phone.trim(),
          },
        ),
      );
    } on AuthException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (e) {
      throw Exception(
        'Unable to update profile: $e',
      );
    }
  }

  // ============================================================
  // PROFILE IMAGE
  // ============================================================

  Future<String> uploadProfileImage(
      File imageFile,
      ) async {
    final User? user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final String extension =
      _fileExtension(
        imageFile.path,
      );

      final String storagePath =
          '${user.id}/profile.$extension';

      await _supabase.storage
          .from(
        avatarBucket,
      )
          .upload(
        storagePath,
        imageFile,
        fileOptions:
        const FileOptions(
          cacheControl:
          '3600',

          upsert:
          true,
        ),
      );

      await _supabase
          .from(
        'profiles',
      )
          .update({
        'profile_image_url':
        storagePath,

        'updated_at':
        DateTime.now()
            .toIso8601String(),
      })
          .eq(
        'id',
        user.id,
      );

      return storagePath;
    } catch (e) {
      throw Exception(
        'Unable to upload profile picture: $e',
      );
    }
  }

  Future<String?>
  getProfileImageUrl() async {
    final UserProfile? profile =
    await getCurrentProfile();

    if (profile == null) {
      return null;
    }

    final String? path =
        profile.profileImageUrl;

    if (path == null ||
        path.isEmpty) {
      return null;
    }

    if (path.startsWith(
      'http://',
    ) ||
        path.startsWith(
          'https://',
        )) {
      return path;
    }

    try {
      return await _supabase.storage
          .from(
        avatarBucket,
      )
          .createSignedUrl(
        path,
        3600,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ACCOUNT DELETION AFTER RE-AUTH
  // ============================================================

  Future<void>
  requestAccountDeletionAfterPassword({
    required String currentPassword,
  }) async {
    await reauthenticateWithPassword(
      currentPassword:
      currentPassword,
    );

    await _markAccountForDeletion();
  }

  Future<void>
  requestAccountDeletionAfterGoogle() async {
    await reauthenticateGoogle();

    await _markAccountForDeletion();
  }

  Future<void>
  _markAccountForDeletion() async {
    final User? user =
        currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      await _supabase
          .from(
        'profiles',
      )
          .update({
        'account_status':
        'pending_deletion',

        'updated_at':
        DateTime.now()
            .toIso8601String(),
      })
          .eq(
        'id',
        user.id,
      );

      await logout();
    } catch (e) {
      throw Exception(
        'Unable to request account deletion: $e',
      );
    }
  }

  // ============================================================
  // ROLE
  // ============================================================

  Future<String?>
  getCurrentUserRole() async {
    final UserProfile? profile =
    await getCurrentProfile();

    return profile?.role;
  }

  // ============================================================
  // ACCOUNT ACTIVE
  // ============================================================

  Future<bool>
  isAccountActive() async {
    final UserProfile? profile =
    await getCurrentProfile();

    return profile?.isActive ??
        false;
  }

  // ============================================================
  // FILE EXTENSION
  // ============================================================

  String _fileExtension(
      String path,
      ) {
    if (!path.contains('.')) {
      return 'jpg';
    }

    final String extension =
    path
        .split('.')
        .last
        .toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return extension;

      default:
        return 'jpg';
    }
  }
}