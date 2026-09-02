import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_gate.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_colors.dart';

// ============================================================
// GLOBAL NAVIGATOR KEY
//
// Required so authentication events such as password recovery
// can navigate even when they occur outside a normal screen.
// ============================================================

final GlobalKey<NavigatorState>
navigatorKey =
GlobalKey<NavigatorState>();

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // SUPABASE INITIALIZATION
  // ==========================================================

  await Supabase.initialize(
    url:
    'https://mqdymgkgxshvkzentdmg.supabase.co',

    anonKey:
    'sb_publishable_qGdkpnvxBaOWDs2WvU2xgQ_g98Vv__D',
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
  StreamSubscription<AuthState>?
  authSubscription;

  bool recoveryNavigationActive =
  false;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    _listenForAuthenticationEvents();
  }

  // ============================================================
  // AUTHENTICATION EVENT LISTENER
  //
  // This listener is specifically important for:
  //
  // Forgot Password
  //      ↓
  // Recovery email
  //      ↓
  // User taps Reset Password
  //      ↓
  // Supabase verifies recovery request
  //      ↓
  // smartcity://reset-password
  //      ↓
  // SmartCity opens
  //      ↓
  // AuthChangeEvent.passwordRecovery
  //      ↓
  // ResetPasswordScreen
  //
  // Other normal authentication events continue to be handled
  // by AuthGate as before.
  // ============================================================

  void _listenForAuthenticationEvents() {
    authSubscription =
        Supabase.instance.client.auth
            .onAuthStateChange
            .listen(
              (
              AuthState authState,
              ) {
            final AuthChangeEvent event =
                authState.event;

            // ======================================================
            // PASSWORD RECOVERY
            // ======================================================

            if (event ==
                AuthChangeEvent
                    .passwordRecovery) {
              _openResetPasswordScreen();
            }
          },
        );
  }

  // ============================================================
  // OPEN RESET PASSWORD SCREEN
  // ============================================================

  void _openResetPasswordScreen() {
    // Prevent duplicate navigation if Supabase emits/replays
    // the recovery state while the screen is already opening.
    if (recoveryNavigationActive) {
      return;
    }

    recoveryNavigationActive =
    true;

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        final NavigatorState?
        navigator =
            navigatorKey.currentState;

        if (navigator == null) {
          recoveryNavigationActive =
          false;

          return;
        }

        // Remove the normal AuthGate / Welcome route so that
        // the user cannot accidentally leave password recovery
        // and expose an authenticated recovery session.
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                ResetPasswordScreen(
                  onFinished: () {
                    recoveryNavigationActive =
                    false;
                  },
                ),
          ),
              (route) => false,
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    authSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool alreadyLoggedIn =
        Supabase.instance.client.auth
            .currentSession !=
            null;

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
      // EXISTING SMARTCITY THEME
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
      // Existing behaviour is preserved:
      //
      // No Supabase session
      // -> Welcome Screen
      //
      // Existing valid session
      // -> AuthGate
      //
      // Password recovery is handled separately by the
      // authentication listener above.
      // ========================================================

      home:
      alreadyLoggedIn
          ? const AuthGate()
          : const WelcomeScreen(),
    );
  }
}