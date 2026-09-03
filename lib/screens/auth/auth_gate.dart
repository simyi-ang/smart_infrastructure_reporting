import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

// Added from friend's version
import '../../services/quick_lock_service.dart';

import '../admin/admin_dashboard_screen.dart';
import '../citizen/citizen_dashboard_screen.dart';

// KEEP YOUR VERSION
import '../worker/worker_main_screen.dart';

// Added from friend's version
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

  // Added from friend's version
  final QuickLockService
  quickLockService =
  QuickLockService();

  StreamSubscription<AuthState>?
  authSubscription;

  int authRefreshKey = 0;

  @override
  void initState() {
    super.initState();

    // IMPORTANT:
    // Rebuild this gate whenever Supabase signs in, signs out,
    // refreshes the session, or changes the authenticated user.
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

  @override
  void dispose() {
    authSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final User? user =
        authService.currentUser;

    // ==========================================================
    // NOT LOGGED IN
    // ==========================================================

    if (user == null) {
      return const LoginScreen();
    }

    // ==========================================================
    // LOGGED IN -> LOAD PROFILE + ROLE
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
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child:
              CircularProgressIndicator(),
            ),
          );
        }

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
                      size: 42,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Unable to load account.\n\n'
                          '${snapshot.error}',
                      textAlign:
                      TextAlign.center,
                    ),
                    const SizedBox(
                      height: 16,
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
                      size: 42,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'Unable to find your SmartCity profile.',
                      textAlign:
                      TextAlign.center,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    OutlinedButton(
                      onPressed:
                          () async {
                        try {
                          // Added from friend's version
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
                      size: 42,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'This account is currently unavailable.',
                      textAlign:
                      TextAlign.center,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    OutlinedButton(
                      onPressed:
                          () async {
                        try {
                          // Added from friend's version
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

        // Changed slightly so we can apply the biometric/
        // quick-lock security screen AFTER deciding dashboard.
        late final Widget dashboard;

        switch (
        profile.role
            .trim()
            .toLowerCase()) {
          case 'admin':
            dashboard =
            const AdminDashboardScreen();
            break;

          case 'worker':
          // KEEP YOUR VERSION
            dashboard =
                WorkerMainScreen();
            break;

          case 'citizen':
            dashboard =
            const CitizenDashboardScreen();
            break;

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
                        size: 42,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      Text(
                        'Invalid user role: '
                            '${profile.role}',
                        textAlign:
                        TextAlign.center,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      OutlinedButton(
                        onPressed:
                            () async {
                          try {
                            // Added from friend's version
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
        // QUICK LOGIN / QUICK LOCK SECURITY CHECK
        // Added from friend's version
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
            // ==================================================

            final bool manualQuickLock =
                isLocked &&
                    lockReason ==
                        QuickLockService
                            .manualLockReason;

            // ==================================================
            // RETURN TO LOGIN
            // ==================================================

            final bool returnToLogin =
                isLocked &&
                    lockReason ==
                        QuickLockService
                            .returnToLoginReason;

            // ==================================================
            // APP REOPEN / STARTUP QUICK LOGIN
            // ==================================================

            final bool startupQuickLogin =
                quickLoginEnabled &&
                    !quickLockService
                        .isVerifiedForCurrentRun;

            // ==================================================
            // REQUIRE LOGIN / QUICK LOGIN
            // ==================================================

            if (manualQuickLock ||
                returnToLogin ||
                startupQuickLogin) {
              return LoginScreen(
                quickLockMode:
                true,

                allowBackToWelcome:
                !manualQuickLock,
              );
            }

            // ==================================================
            // AUTHENTICATED + VERIFIED
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