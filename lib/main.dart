import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_gate.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_colors.dart';

// ============================================================
// GLOBAL NAVIGATOR KEY
// ============================================================

final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

// ============================================================
// PASSWORD RECOVERY COORDINATOR
//
// A recovery deep link can be processed extremely early when
// SmartCity is opened from Gmail.
//
// If the Navigator is not ready yet, we remember the recovery
// request and navigate after Flutter finishes building.
// ============================================================

class PasswordRecoveryCoordinator {
  static bool pendingRecovery = false;

  static bool navigationActive = false;

  static void markRecoveryPending() {
    pendingRecovery = true;
  }

  static void clearRecovery() {
    pendingRecovery = false;
    navigationActive = false;
  }

  static void tryOpenResetPasswordScreen() {
    if (!pendingRecovery ||
        navigationActive) {
      return;
    }

    final NavigatorState? navigator =
        navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    navigationActive = true;

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
}

// ============================================================
// AUTH SUBSCRIPTION
// ============================================================

StreamSubscription<AuthState>?
globalAuthSubscription;

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // INITIALIZE SUPABASE
  // ==========================================================

  await Supabase.initialize(
    url:
    'https://mqdymgkgxshvkzentdmg.supabase.co',

    publishableKey:
    'sb_publishable_qGdkpnvxBaOWDs2WvU2xgQ_g98Vv__D',

    // PKCE is the current default for Supabase Flutter,
    // but declaring it explicitly makes the recovery flow
    // clear and predictable.
    authOptions:
    const FlutterAuthClientOptions(
      authFlowType:
      AuthFlowType.pkce,
    ),
  );

  // ==========================================================
  // LISTEN BEFORE runApp()
  //
  // Important:
  // The recovery callback may be processed while SmartCity is
  // starting from the Gmail deep link.
  //
  // Listening here means the recovery event cannot be missed
  // just because SmartCityApp.initState() has not run yet.
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

        onError:
            (
            Object error,
            StackTrace stackTrace,
            ) {
          debugPrint(
            'Supabase auth stream error: $error',
          );
        },
      );

  runApp(
    const SmartCityApp(),
  );
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

class _SmartCityAppState
    extends State<SmartCityApp> {
  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    // If the password recovery event happened before the
    // MaterialApp/Navigator existed, try navigation again once
    // the first Flutter frame is ready.
    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        PasswordRecoveryCoordinator
            .tryOpenResetPasswordScreen();
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
      // NORMAL STARTUP
      //
      // No normal session:
      // -> WelcomeScreen
      //
      // Existing session:
      // -> AuthGate
      //
      // Password recovery:
      // -> coordinator overrides this and opens
      //    ResetPasswordScreen.
      // ========================================================

      home:
      alreadyLoggedIn
          ? const AuthGate()
          : const WelcomeScreen(),
    );
  }
}