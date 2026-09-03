import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_gate.dart';
import 'screens/auth/email_verified_success_screen.dart';
import 'screens/auth/password_recovery_error_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_colors.dart';

// ============================================================
// GLOBAL NAVIGATOR KEY
// ============================================================

final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

// ============================================================
// APP LINKS
//
// Handles:
//
// smartcity://reset-password
// smartcity://email-verified
//
// without printing sensitive callback parameters.
// ============================================================

final AppLinks appLinks =
AppLinks();

// ============================================================
// GLOBAL SUBSCRIPTIONS
// ============================================================

StreamSubscription<AuthState>?
globalAuthSubscription;

StreamSubscription<Uri>?
globalDeepLinkSubscription;

// ============================================================
// PASSWORD RECOVERY COORDINATOR
//
// Handles:
//
// VALID:
// smartcity://reset-password
// +
// AuthChangeEvent.passwordRecovery
// → ResetPasswordScreen
//
// INVALID / EXPIRED:
// callback received
// but no passwordRecovery event
// → PasswordRecoveryErrorScreen
// ============================================================

class PasswordRecoveryCoordinator {
  // ==========================================================
  // VALID RECOVERY EVENT PENDING
  // ==========================================================

  static bool pendingRecovery =
  false;

  // ==========================================================
  // NAVIGATION ACTIVE
  // ==========================================================

  static bool navigationActive =
  false;

  // ==========================================================
  // CALLBACK RECEIVED
  // ==========================================================

  static bool recoveryCallbackReceived =
  false;

  // ==========================================================
  // VALIDATION TIMER
  // ==========================================================

  static Timer? validationTimer;

  // ==========================================================
  // NAVIGATOR RETRY TIMER
  // ==========================================================

  static Timer? navigatorRetryTimer;

  // ==========================================================
  // PASSWORD RECOVERY CALLBACK RECEIVED
  // ==========================================================

  static void markCallbackReceived() {
    recoveryCallbackReceived =
    true;

    validationTimer?.cancel();

    validationTimer =
        Timer(
          const Duration(
            seconds: 3,
          ),
              () {
            // ====================================================
            // VALID EVENT ALREADY RECEIVED
            // ====================================================

            if (
            !recoveryCallbackReceived ||
                pendingRecovery
            ) {
              return;
            }

            // ====================================================
            // NO VALID PASSWORD-RECOVERY EVENT
            //
            // Do NOT rely only on currentSession.
            //
            // AuthChangeEvent.passwordRecovery is the authoritative
            // recovery signal.
            // ====================================================

            openRecoveryError();
          },
        );
  }

  // ==========================================================
  // VALID SUPABASE PASSWORD RECOVERY EVENT
  // ==========================================================

  static void markRecoveryPending() {
    validationTimer?.cancel();

    validationTimer =
    null;

    navigatorRetryTimer?.cancel();

    navigatorRetryTimer =
    null;

    recoveryCallbackReceived =
    false;

    pendingRecovery =
    true;

    navigationActive =
    false;
  }

  // ==========================================================
  // CLEAR RECOVERY STATE
  // ==========================================================

  static void clearRecovery() {
    validationTimer?.cancel();

    validationTimer =
    null;

    navigatorRetryTimer?.cancel();

    navigatorRetryTimer =
    null;

    pendingRecovery =
    false;

    navigationActive =
    false;

    recoveryCallbackReceived =
    false;
  }

  // ==========================================================
  // OPEN RESET PASSWORD SCREEN
  // ==========================================================

  static void tryOpenResetPasswordScreen() {
    if (
    !pendingRecovery ||
        navigationActive
    ) {
      return;
    }

    final NavigatorState? navigator =
        navigatorKey.currentState;

    // ========================================================
    // NAVIGATOR NOT READY
    // ========================================================

    if (navigator == null) {
      navigatorRetryTimer?.cancel();

      navigatorRetryTimer =
          Timer(
            const Duration(
              milliseconds: 250,
            ),
                () {
              tryOpenResetPasswordScreen();
            },
          );

      return;
    }

    navigatorRetryTimer?.cancel();

    navigatorRetryTimer =
    null;

    navigationActive =
    true;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (_) =>
            ResetPasswordScreen(
              onFinished: () {
                clearRecovery();
              },
            ),
      ),
          (
          route,
          ) =>
      false,
    );
  }

  // ==========================================================
  // OPEN INVALID / EXPIRED RECOVERY SCREEN
  // ==========================================================

  static void openRecoveryError() {
    final NavigatorState? navigator =
        navigatorKey.currentState;

    if (navigator == null) {
      navigatorRetryTimer?.cancel();

      navigatorRetryTimer =
          Timer(
            const Duration(
              milliseconds: 250,
            ),
                () {
              openRecoveryError();
            },
          );

      return;
    }

    validationTimer?.cancel();

    validationTimer =
    null;

    navigatorRetryTimer?.cancel();

    navigatorRetryTimer =
    null;

    pendingRecovery =
    false;

    recoveryCallbackReceived =
    false;

    navigationActive =
    true;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (_) =>
        const PasswordRecoveryErrorScreen(),
      ),
          (
          route,
          ) =>
      false,
    );
  }
}

// ============================================================
// EMAIL VERIFICATION COORDINATOR
//
// Handles:
//
// smartcity://email-verified
//
// SECURITY:
//
// Receiving the URI alone does NOT prove that verification
// succeeded.
//
// SmartCity requires:
//
// currentUser != null
// AND
// currentUser.emailConfirmedAt != null
//
// before showing EmailVerifiedSuccessScreen.
// ============================================================

class EmailVerificationCoordinator {
  // ==========================================================
  // CALLBACK RECEIVED
  // ==========================================================

  static bool callbackReceived =
  false;

  // ==========================================================
  // SUPABASE VERIFICATION CONFIRMED
  // ==========================================================

  static bool verificationConfirmed =
  false;

  // ==========================================================
  // NAVIGATION ACTIVE
  // ==========================================================

  static bool navigationActive =
  false;

  // ==========================================================
  // TIMERS
  // ==========================================================

  static Timer? validationTimer;

  static Timer? navigatorRetryTimer;

  // ==========================================================
  // EMAIL VERIFICATION CALLBACK RECEIVED
  // ==========================================================

  static void markCallbackReceived() {
    callbackReceived =
    true;

    navigationActive =
    false;

    validationTimer?.cancel();

    // ========================================================
    // Supabase may already have processed the callback before
    // app_links delivers the URI.
    // ========================================================

    _checkCurrentUserVerification();

    // ========================================================
    // Give Supabase several seconds to process PKCE callback.
    //
    // Unlike password recovery, we do NOT display success simply
    // because the URI was received.
    // ========================================================

    validationTimer =
        Timer.periodic(
          const Duration(
            milliseconds: 500,
          ),
              (
              timer,
              ) {
            if (
            verificationConfirmed
            ) {
              timer.cancel();

              return;
            }

            _checkCurrentUserVerification();
          },
        );

    // Stop polling after a short validation period.
    Timer(
      const Duration(
        seconds: 5,
      ),
          () {
        validationTimer?.cancel();

        validationTimer =
        null;
      },
    );
  }

  // ==========================================================
  // AUTH EVENT RECEIVED
  //
  // Called from Supabase auth-state listener.
  // ==========================================================

  static void handleAuthState(
      AuthState authState,
      ) {
    if (!callbackReceived) {
      return;
    }

    final User? user =
        authState.session?.user ??
            Supabase.instance.client.auth
                .currentUser;

    if (
    user != null &&
        user.emailConfirmedAt !=
            null
    ) {
      markVerificationConfirmed();
    }
  }

  // ==========================================================
  // CHECK CURRENT USER
  // ==========================================================

  static void _checkCurrentUserVerification() {
    if (!callbackReceived) {
      return;
    }

    final User? user =
        Supabase.instance.client.auth
            .currentUser;

    if (
    user != null &&
        user.emailConfirmedAt !=
            null
    ) {
      markVerificationConfirmed();
    }
  }

  // ==========================================================
  // VERIFICATION CONFIRMED
  // ==========================================================

  static void markVerificationConfirmed() {
    if (verificationConfirmed) {
      return;
    }

    verificationConfirmed =
    true;

    validationTimer?.cancel();

    validationTimer =
    null;

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        tryOpenVerificationSuccessScreen();
      },
    );
  }

  // ==========================================================
  // OPEN VERIFIED SUCCESS SCREEN
  // ==========================================================

  static void
  tryOpenVerificationSuccessScreen() {
    if (
    !callbackReceived ||
        !verificationConfirmed ||
        navigationActive
    ) {
      return;
    }

    final NavigatorState? navigator =
        navigatorKey.currentState;

    // ========================================================
    // COLD START:
    // Navigator may not exist yet.
    // ========================================================

    if (navigator == null) {
      navigatorRetryTimer?.cancel();

      navigatorRetryTimer =
          Timer(
            const Duration(
              milliseconds: 250,
            ),
                () {
              tryOpenVerificationSuccessScreen();
            },
          );

      return;
    }

    navigatorRetryTimer?.cancel();

    navigatorRetryTimer =
    null;

    navigationActive =
    true;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (_) =>
        const EmailVerifiedSuccessScreen(),
      ),
          (
          route,
          ) =>
      false,
    );
  }

  // ==========================================================
  // CLEAR VERIFICATION STATE
  // ==========================================================

  static void clearVerification() {
    validationTimer?.cancel();

    validationTimer =
    null;

    navigatorRetryTimer?.cancel();

    navigatorRetryTimer =
    null;

    callbackReceived =
    false;

    verificationConfirmed =
    false;

    navigationActive =
    false;
  }
}

// ============================================================
// HANDLE INCOMING SMARTCITY URI
// ============================================================

void handleIncomingUri(
    Uri uri,
    ) {
  // ==========================================================
  // SAFE DEBUG OUTPUT
  //
  // Never print the full URI because auth callbacks can contain
  // security-sensitive query parameters.
  // ==========================================================

  debugPrint(
    'SmartCity deep link received: '
        '${uri.scheme}://${uri.host}',
  );

  // ==========================================================
  // ONLY SMARTCITY LINKS
  // ==========================================================

  if (
  uri.scheme !=
      'smartcity'
  ) {
    return;
  }

  // ==========================================================
  // PASSWORD RECOVERY
  //
  // smartcity://reset-password
  // ==========================================================

  if (
  uri.host ==
      'reset-password'
  ) {
    PasswordRecoveryCoordinator
        .markCallbackReceived();

    return;
  }

  // ==========================================================
  // EMAIL VERIFICATION
  //
  // smartcity://email-verified
  // ==========================================================

  if (
  uri.host ==
      'email-verified'
  ) {
    EmailVerificationCoordinator
        .markCallbackReceived();

    return;
  }

  // ==========================================================
  // UNKNOWN SMARTCITY URI
  // ==========================================================

  debugPrint(
    'Unknown SmartCity deep-link destination.',
  );
}

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized();

  // ==========================================================
  // INITIALIZE SUPABASE
  // ==========================================================

  await Supabase.initialize(
    url:
    'https://mqdymgkgxshvkzentdmg.supabase.co',

    publishableKey:
    'sb_publishable_qGdkpnvxBaOWDs2WvU2xgQ_g98Vv__D',

    // ========================================================
    // PKCE AUTH
    //
    // Used by:
    //
    // - password recovery
    // - email verification
    // ========================================================

    authOptions:
    const FlutterAuthClientOptions(
      authFlowType:
      AuthFlowType.pkce,
    ),
  );

  // ==========================================================
  // AUTH STATE LISTENER
  // ==========================================================

  globalAuthSubscription =
      Supabase.instance.client.auth
          .onAuthStateChange
          .listen(
            (
            AuthState authState,
            ) {
          final AuthChangeEvent event =
              authState.event;

          debugPrint(
            'SmartCity auth event: $event',
          );

          // ======================================================
          // VALID PASSWORD RECOVERY
          // ======================================================

          if (
          event ==
              AuthChangeEvent
                  .passwordRecovery
          ) {
            PasswordRecoveryCoordinator
                .markRecoveryPending();

            WidgetsBinding.instance
                .addPostFrameCallback(
                  (_) {
                PasswordRecoveryCoordinator
                    .tryOpenResetPasswordScreen();
              },
            );

            return;
          }

          // ======================================================
          // EMAIL VERIFICATION
          //
          // The verification coordinator only acts if the
          // email-verified deep link was actually received.
          // ======================================================

          EmailVerificationCoordinator
              .handleAuthState(
            authState,
          );
        },

        onError: (
            Object error,
            StackTrace stackTrace,
            ) {
          debugPrint(
            'Supabase auth stream error: $error',
          );
        },
      );

  // ==========================================================
  // LIVE DEEP LINK LISTENER
  // ==========================================================

  globalDeepLinkSubscription =
      appLinks.uriLinkStream.listen(
            (
            Uri uri,
            ) {
          handleIncomingUri(
            uri,
          );
        },

        onError: (
            Object error,
            ) {
          debugPrint(
            'SmartCity deep link error: $error',
          );
        },
      );

  // ==========================================================
  // START APP
  // ==========================================================

  runApp(
    const SmartCityApp(),
  );

  // ==========================================================
  // COLD-START DEEP LINK
  //
  // Important when Gmail starts SmartCity from a completely
  // closed state.
  // ==========================================================

  try {
    final Uri? initialUri =
    await appLinks
        .getInitialLink();

    if (initialUri != null) {
      handleIncomingUri(
        initialUri,
      );
    }
  } catch (e) {
    debugPrint(
      'Unable to read initial SmartCity deep link: $e',
    );
  }
}

// ============================================================
// SMARTCITY APP
// ============================================================

class SmartCityApp
    extends StatefulWidget {
  const SmartCityApp({
    super.key,
  });

  @override
  State<SmartCityApp> createState() =>
      _SmartCityAppState();
}

// ============================================================
// SMARTCITY APP STATE
// ============================================================

class _SmartCityAppState
    extends State<SmartCityApp> {
  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        // ====================================================
        // PASSWORD RECOVERY MAY HAVE ARRIVED BEFORE NAVIGATOR
        // ====================================================

        PasswordRecoveryCoordinator
            .tryOpenResetPasswordScreen();

        // ====================================================
        // EMAIL VERIFICATION MAY HAVE ARRIVED BEFORE NAVIGATOR
        // ====================================================

        EmailVerificationCoordinator
            .tryOpenVerificationSuccessScreen();
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final Session? session =
        Supabase.instance.client.auth
            .currentSession;

    final bool alreadyLoggedIn =
        session != null;

    return MaterialApp(
      // ========================================================
      // GLOBAL NAVIGATION
      // ========================================================

      navigatorKey:
      navigatorKey,

      debugShowCheckedModeBanner:
      false,

      title:
      'SmartCity',

      // ========================================================
      // THEME
      // ========================================================

      theme:
      ThemeData(
        brightness:
        Brightness.dark,

        scaffoldBackgroundColor:
        AppColors.background,

        colorScheme:
        const ColorScheme.dark(
          primary:
          AppColors.primary,

          surface:
          AppColors.surface,
        ),
      ),

      // ========================================================
      // NORMAL APPLICATION STARTUP
      //
      // No normal session
      // → WelcomeScreen
      //
      // Existing normal session
      // → AuthGate
      //
      // Password recovery callback
      // → coordinator overrides navigation
      //
      // Email verification callback
      // → coordinator verifies Supabase confirmation first
      // → EmailVerifiedSuccessScreen
      // ========================================================

      home:
      alreadyLoggedIn
          ? const AuthGate()
          : const WelcomeScreen(),
    );
  }
}