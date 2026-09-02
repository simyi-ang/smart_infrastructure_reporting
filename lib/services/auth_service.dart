import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class AuthService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

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
  // REGISTER
  // ============================================================

  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signUp(
        email:
        email.trim().toLowerCase(),

        password:
        password,

        data: {
          'full_name':
          fullName.trim(),

          'phone':
          phone.trim(),
        },
      );
    } on AuthException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (_) {
      throw Exception(
        'Unable to create account.',
      );
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth
          .signInWithPassword(
        email:
        email.trim().toLowerCase(),

        password:
        password,
      );
    } on AuthException catch (e) {
      throw Exception(
        e.message,
      );
    } catch (_) {
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
  // ============================================================

  Future<void> forgotPassword(
      String email,
      ) async {
    final String cleanEmail =
    email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      throw Exception(
        'Please enter your email address.',
      );
    }

    try {
      await _supabase.auth
          .resetPasswordForEmail(
        cleanEmail,

        // IMPORTANT:
        // After the user verifies the recovery link,
        // Supabase redirects back into the SmartCity app
        // instead of localhost:3000.
        redirectTo:
        'smartcity://reset-password',
      );
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

      if (message.trim().isEmpty) {
        throw Exception(
          'Unable to send password reset email.',
        );
      }

      throw Exception(
        message,
      );
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