import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_gate.dart';
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
// Used to detect:
// smartcity://reset-password
//
// even when Supabase cannot establish a valid recovery session
// because the link is expired, invalid, or already used.
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
// Handles both:
//
// 1. VALID recovery
//    → AuthChangeEvent.passwordRecovery
//    → ResetPasswordScreen
//
// 2. INVALID / EXPIRED recovery
//    → deep link arrives
//    → no passwordRecovery event
//    → PasswordRecoveryErrorScreen
// ============================================================

class PasswordRecoveryCoordinator {
  // ==========================================================
  // VALID RECOVERY EVENT PENDING
  // ==========================================================

  static bool pendingRecovery =
  false;

  // ==========================================================
  // NAVIGATION ALREADY ACTIVE
  // ==========================================================

  static bool navigationActive =
  false;

  // ==========================================================
  // A RECOVERY CALLBACK HAS ARRIVED
  //
  // This does NOT mean it is valid yet.
  // ==========================================================

  static bool recoveryCallbackReceived =
  false;

  // ==========================================================
  // FALLBACK VALIDATION TIMER
  //
  // Gives Supabase a short period to process the recovery
  // callback before SmartCity decides that it is invalid.
  // ==========================================================

  static Timer? validationTimer;

  // ==========================================================
  // NAVIGATOR RETRY TIMER
  //
  // Used when the deep link arrives before MaterialApp has
  // created its Navigator.
  // ==========================================================

  static Timer? navigatorRetryTimer;

  // ==========================================================
  // RECOVERY CALLBACK RECEIVED
  //
  // Called by app_links when Android delivers:
  //
  // smartcity://reset-password
  //
  // For a valid recovery link, Supabase should emit:
  //
  // AuthChangeEvent.passwordRecovery
  //
  // shortly afterward.
  //
  // If that does not happen, SmartCity shows the generic
  // expired/invalid recovery screen.
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
            // ======================================================
            // VALID RECOVERY ALREADY RECEIVED
            // ======================================================

            if (!recoveryCallbackReceived ||
                pendingRecovery) {
              return;
            }

            // ======================================================
            // NO VALID PASSWORD-RECOVERY EVENT
            //
            // Do NOT rely only on currentSession here.
            //
            // A user might already have some unrelated session.
            // The authoritative signal for password recovery is
            // AuthChangeEvent.passwordRecovery.
            // ======================================================

            openRecoveryError();
          },
        );
  }

  // ==========================================================
  // VALID SUPABASE RECOVERY EVENT
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

    // Reset this so valid recovery navigation is allowed.
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
    if (!pendingRecovery ||
        navigationActive) {
      return;
    }

    final NavigatorState? navigator =
        navigatorKey.currentState;

    // ========================================================
    // NAVIGATOR NOT READY YET
    //
    // This can happen when Gmail opens SmartCity from a cold
    // start and the auth event arrives very early.
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
        builder: (_) =>
            ResetPasswordScreen(
              onFinished: () {
                clearRecovery();
              },
            ),
      ),
          (route) => false,
    );
  }

  // ==========================================================
  // OPEN RECOVERY ERROR SCREEN
  //
  // Used when SmartCity receives the recovery callback but
  // Supabase does not emit passwordRecovery.
  //
  // The link may be:
  //
  // - expired
  // - already used
  // - invalid
  // - malformed
  // - unable to be verified
  //
  // We intentionally show a general message rather than
  // pretending SmartCity knows the exact cause.
  // ==========================================================

  static void openRecoveryError() {
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
        builder: (_) =>
        const PasswordRecoveryErrorScreen(),
      ),
          (route) => false,
    );
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
  // Do not print the complete recovery URI because it may
  // contain security-sensitive query parameters.
  // ==========================================================

  debugPrint(
    'SmartCity deep link received: '
        '${uri.scheme}://${uri.host}',
  );

  // ==========================================================
  // PASSWORD RECOVERY CALLBACK
  //
  // Expected:
  //
  // smartcity://reset-password
  // ==========================================================

  if (uri.scheme ==
      'smartcity' &&
      uri.host ==
          'reset-password') {
    PasswordRecoveryCoordinator
        .markCallbackReceived();
  }
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
    // PKCE AUTH FLOW
    //
    // Used by SmartCity recovery deep linking.
    // ========================================================

    authOptions:
    const FlutterAuthClientOptions(
      authFlowType:
      AuthFlowType.pkce,
    ),
  );

  // ==========================================================
  // AUTH STATE LISTENER
  //
  // This is the authoritative VALID RECOVERY signal.
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

          if (event ==
              AuthChangeEvent
                  .passwordRecovery) {
            PasswordRecoveryCoordinator
                .markRecoveryPending();

            WidgetsBinding.instance
                .addPostFrameCallback(
                  (_) {
                PasswordRecoveryCoordinator
                    .tryOpenResetPasswordScreen();
              },
            );
          }
        },

        // ========================================================
        // AUTH STREAM ERROR
        // ========================================================

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
  // DEEP LINK LISTENER
  //
  // Important:
  //
  // This runs independently from the Supabase auth listener.
  //
  // Therefore SmartCity still knows that a recovery link was
  // opened even when the link cannot create a valid Supabase
  // recovery session.
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
  // START APPLICATION
  // ==========================================================

  runApp(
    const SmartCityApp(),
  );

  // ==========================================================
  // COLD-START INITIAL LINK
  //
  // Some app_links versions/platform situations expose the
  // launch URI separately from the live stream.
  //
  // Reading it here makes cold-start recovery more reliable.
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
        // ======================================================
        // RECOVERY EVENT MAY HAVE ARRIVED BEFORE NAVIGATOR
        // ======================================================

        PasswordRecoveryCoordinator
            .tryOpenResetPasswordScreen();

        // ======================================================
        // INVALID CALLBACK MAY ALSO HAVE ARRIVED EARLY
        //
        // The coordinator's own retry mechanism handles the
        // eventual error navigation.
        // ======================================================
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
      // No session
      // → WelcomeScreen
      //
      // Existing normal session
      // → AuthGate
      //
      // Valid recovery
      // → PasswordRecoveryCoordinator overrides routing and
      //   opens ResetPasswordScreen
      //
      // Expired / invalid recovery
      // → PasswordRecoveryCoordinator opens
      //   PasswordRecoveryErrorScreen
      // ========================================================

      home:
      alreadyLoggedIn
          ? const AuthGate()
          : const WelcomeScreen(),
    );

  }
}