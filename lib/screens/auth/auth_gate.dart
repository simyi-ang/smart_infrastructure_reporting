import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/quick_lock_service.dart';

import '../admin/admin_dashboard_screen.dart';
import '../citizen/citizen_dashboard_screen.dart';
import '../worker/worker_dashboard_screen.dart';

import 'biometric_lock_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
  });

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState
    extends State<AuthGate> {
  final AuthService authService =
  AuthService();

  final QuickLockService
  quickLockService =
  QuickLockService();

  StreamSubscription<AuthState>?
  authSubscription;

  int authRefreshKey = 0;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Rebuild the authentication gate whenever Supabase:
    //
    // - signs a user in
    // - signs a user out
    // - refreshes a session
    // - changes the authenticated user
    //
    // This works for BOTH:
    //
    // Email / Password
    // Google Sign-In
    authSubscription =
        Supabase.instance.client.auth
            .onAuthStateChange
            .listen(
              (
              AuthState authState,
              ) {
            if (!mounted) {
              return;
            }

            setState(() {
              authRefreshKey++;
            });
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
    final User? user =
        authService.currentUser;

    // ==========================================================
    // NO AUTHENTICATED SUPABASE SESSION
    //
    // FIRST-TIME USER:
    //
    // Welcome
    // -> Login
    // -> Email / Password OR Google
    //
    // No biometric login is forced here.
    // ==========================================================

    if (user == null) {
      return const LoginScreen();
    }

    // ==========================================================
    // AUTHENTICATED USER -> LOAD PROFILE
    // ==========================================================

    return FutureBuilder(
      key: ValueKey(
        '${user.id}-$authRefreshKey',
      ),

      future:
      authService.getCurrentProfile(),

      builder:
          (
          context,
          snapshot,
          ) {
        // ======================================================
        // PROFILE LOADING
        // ======================================================

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child:
              CircularProgressIndicator(),
            ),
          );
        }

        // ======================================================
        // PROFILE LOAD ERROR
        // ======================================================

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding:
                const EdgeInsets.all(
                  25,
                ),

                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.error_outline,

                      size:
                      42,
                    ),

                    const SizedBox(
                      height:
                      12,
                    ),

                    Text(
                      'Unable to load account.\n\n'
                          '${snapshot.error}',

                      textAlign:
                      TextAlign.center,
                    ),

                    const SizedBox(
                      height:
                      16,
                    ),

                    OutlinedButton.icon(
                      onPressed: () {
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          authRefreshKey++;
                        });
                      },

                      icon:
                      const Icon(
                        Icons.refresh,
                      ),

                      label:
                      const Text(
                        'Retry',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile =
            snapshot.data;

        // ======================================================
        // PROFILE NOT FOUND
        // ======================================================

        if (profile == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding:
                const EdgeInsets.all(
                  25,
                ),

                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons
                          .person_off_outlined,

                      size:
                      42,
                    ),

                    const SizedBox(
                      height:
                      12,
                    ),

                    const Text(
                      'Unable to find your SmartCity profile.',

                      textAlign:
                      TextAlign.center,
                    ),

                    const SizedBox(
                      height:
                      16,
                    ),

                    OutlinedButton(
                      onPressed:
                          () async {
                        try {
                          await quickLockService
                              .clearForFullSignOut();

                          await authService
                              .logout();
                        } catch (_) {}
                      },

                      child:
                      const Text(
                        'Return to Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ======================================================
        // ACCOUNT DISABLED
        // ======================================================

        if (!profile.isActive) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding:
                const EdgeInsets.all(
                  25,
                ),

                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.block_outlined,

                      size:
                      42,
                    ),

                    const SizedBox(
                      height:
                      12,
                    ),

                    const Text(
                      'This account is currently unavailable.',

                      textAlign:
                      TextAlign.center,
                    ),

                    const SizedBox(
                      height:
                      16,
                    ),

                    OutlinedButton(
                      onPressed:
                          () async {
                        try {
                          await quickLockService
                              .clearForFullSignOut();

                          await authService
                              .logout();
                        } catch (_) {}
                      },

                      child:
                      const Text(
                        'Return to Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ======================================================
        // ROLE-BASED ROUTING
        // ======================================================

        late final Widget dashboard;

        switch (
        profile.role
            .trim()
            .toLowerCase()) {
        // ====================================================
        // ADMIN
        // ====================================================

          case 'admin':
            dashboard =
            const AdminDashboardScreen();

            break;

        // ====================================================
        // WORKER
        // ====================================================

          case 'worker':
            dashboard =
            const WorkerDashboardScreen();

            break;

        // ====================================================
        // CITIZEN
        // ====================================================

          case 'citizen':
            dashboard =
            const CitizenDashboardScreen();

            break;

        // ====================================================
        // INVALID ROLE
        // ====================================================

          default:
            return Scaffold(
              body: Center(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    25,
                  ),

                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,

                    children: [
                      const Icon(
                        Icons
                            .warning_amber_rounded,

                        size:
                        42,
                      ),

                      const SizedBox(
                        height:
                        12,
                      ),

                      Text(
                        'Invalid user role: '
                            '${profile.role}',

                        textAlign:
                        TextAlign.center,
                      ),

                      const SizedBox(
                        height:
                        16,
                      ),

                      OutlinedButton(
                        onPressed:
                            () async {
                          try {
                            await quickLockService
                                .clearForFullSignOut();

                            await authService
                                .logout();
                          } catch (_) {}
                        },

                        child:
                        const Text(
                          'Return to Login',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
        }

        // ======================================================
        // QUICK LOGIN SECURITY CHECK
        //
        // IMPORTANT:
        //
        // This check happens only AFTER Supabase already has
        // an authenticated user.
        //
        // Therefore:
        //
        // Email Login success
        // -> markVerifiedForCurrentRun()
        // -> AuthGate
        // -> Dashboard
        //
        // Google Login success
        // -> markVerifiedForCurrentRun()
        // -> AuthGate
        // -> Dashboard
        //
        // NO second biometric prompt.
        // ======================================================

        return FutureBuilder<List<dynamic>>(
          key: ValueKey(
            'quick-security-'
                '${user.id}-'
                '$authRefreshKey',
          ),

          future:
          Future.wait<dynamic>([
            quickLockService
                .isLocked(),

            quickLockService
                .isQuickLoginEnabled(),

            quickLockService
                .getLockReason(),
          ]),

          builder:
              (
              context,
              quickSnapshot,
              ) {
            // ==================================================
            // SECURITY STATUS LOADING
            // ==================================================

            if (quickSnapshot
                .connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              );
            }

            // ==================================================
            // SAFE DEFAULT VALUES
            // ==================================================

            final List<dynamic> values =
                quickSnapshot.data ??
                    <dynamic>[
                      false,
                      false,
                      null,
                    ];

            final bool isLocked =
                values[0] as bool? ??
                    false;

            final bool quickLoginEnabled =
                values[1] as bool? ??
                    false;

            final String? lockReason =
            values[2] as String?;

            // ==================================================
            // MANUAL QUICK LOCK
            //
            // User explicitly pressed:
            //
            // Security -> Quick Lock
            //
            // Back navigation must NOT bypass the lock.
            // ==================================================

            final bool manualQuickLock =
                isLocked &&
                    lockReason ==
                        QuickLockService
                            .manualLockReason;

            // ==================================================
            // SIGN OUT TO LOGIN
            //
            // Supabase session remains alive.
            //
            // Login page can offer:
            //
            // - Quick Login
            // - Email / Password
            // - Google
            //
            // Login back button may return to WelcomeScreen.
            // ==================================================

            final bool returnToLogin =
                isLocked &&
                    lockReason ==
                        QuickLockService
                            .returnToLoginReason;

            // ==================================================
            // APP REOPEN
            //
            // When the application process is restarted:
            //
            // _verifiedForCurrentRun = false
            //
            // If Quick Login is enabled and the existing
            // Supabase session remains available, require
            // identity verification before showing dashboard.
            // ==================================================

            final bool startupQuickLogin =
                quickLoginEnabled &&
                    !quickLockService
                        .isVerifiedForCurrentRun;

            // ==================================================
            // REQUIRE LOGIN / QUICK LOGIN SCREEN
            // ==================================================

            if (manualQuickLock ||
                returnToLogin ||
                startupQuickLogin) {
              return LoginScreen(
                quickLockMode:
                true,

                // We will add this parameter in the next
                // LoginScreen update.
                //
                // true:
                // Login Back -> Welcome Screen
                //
                // false:
                // Back disabled because manual Quick Lock
                // must not be bypassed.
                allowBackToWelcome:
                !manualQuickLock,
              );
            }

            // ==================================================
            // AUTHENTICATED + VERIFIED
            //
            // Existing biometric auto-lock remains unchanged.
            // ==================================================

            return BiometricLockScreen(
              child:
              dashboard,
            );
          },
        );
      },
    );
  }
}