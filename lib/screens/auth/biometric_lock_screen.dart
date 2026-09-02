import 'package:flutter/material.dart';

import '../../services/biometric_service.dart';
import '../../services/security_preferences_service.dart';
import '../../services/security_service.dart';
import '../../theme/app_colors.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget child;

  const BiometricLockScreen({
    super.key,
    required this.child,
  });

  @override
  State<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState
    extends State<BiometricLockScreen>
    with WidgetsBindingObserver {
  final BiometricService biometricService =
  BiometricService();

  final SecurityPreferencesService
  securityPreferencesService =
  SecurityPreferencesService();

  final SecurityService securityService =
  SecurityService();

  bool initializing = true;

  bool locked = false;

  bool authenticating = false;

  bool biometricEnabled = false;

  bool privacyProtected = false;

  String authenticationMessage = '';

  int autoLockSeconds = 60;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    _initializeSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );

    biometricService.stopAuthentication();

    super.dispose();
  }

  // ============================================================
  // INITIAL SECURITY CHECK
  // ============================================================

  Future<void> _initializeSecurity() async {
    bool enabled =
    await securityPreferencesService
        .isBiometricLockEnabled();

    int seconds =
    await securityPreferencesService
        .getAutoLockSeconds();

    // Refresh from Supabase when available.
    // If offline, continue using the local settings.
    try {
      final Map<String, dynamic>? remoteSettings =
      await securityService
          .getSecuritySettings();

      if (remoteSettings != null) {
        enabled =
            remoteSettings[
            'biometric_lock_enabled']
            as bool? ??
                enabled;

        seconds =
            remoteSettings[
            'auto_lock_seconds']
            as int? ??
                seconds;

        await securityPreferencesService
            .setBiometricLockEnabled(
          enabled,
        );

        await securityPreferencesService
            .setAutoLockSeconds(
          seconds,
        );
      }
    } catch (_) {
      // Keep local settings when remote access fails.
    }

    final DateTime? lastBackground =
    await securityPreferencesService
        .getLastBackgroundTime();

    bool shouldLock = false;

    if (enabled &&
        lastBackground != null) {
      shouldLock =
          _hasLockTimeExpired(
            lastBackground,
            seconds,
          );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      biometricEnabled = enabled;

      autoLockSeconds = seconds;

      locked = shouldLock;

      privacyProtected = false;

      authenticationMessage = '';

      initializing = false;
    });

    if (shouldLock) {
      WidgetsBinding.instance
          .addPostFrameCallback(
            (_) {
          _authenticate();
        },
      );
    }
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(
      state,
    );

    if (!biometricEnabled) {
      return;
    }

    // Android's system authentication prompt may itself trigger
    // lifecycle events. Ignore those while authentication is active.
    if (authenticating) {
      return;
    }

    if (state ==
        AppLifecycleState.inactive ||
        state ==
            AppLifecycleState.paused) {
      if (mounted) {
        setState(() {
          privacyProtected = true;
        });
      }

      securityPreferencesService
          .saveBackgroundTime();

      return;
    }

    if (state ==
        AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  // ============================================================
  // RESUME CHECK
  // ============================================================

  Future<void> _handleAppResume() async {
    if (!biometricEnabled ||
        authenticating) {
      return;
    }

    final DateTime? lastBackground =
    await securityPreferencesService
        .getLastBackgroundTime();

    if (lastBackground == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        privacyProtected = false;
      });

      return;
    }

    final int seconds =
    await securityPreferencesService
        .getAutoLockSeconds();

    final bool shouldLock =
    _hasLockTimeExpired(
      lastBackground,
      seconds,
    );

    if (!mounted) {
      return;
    }

    if (!shouldLock) {
      setState(() {
        privacyProtected = false;

        locked = false;

        authenticationMessage = '';
      });

      return;
    }

    setState(() {
      locked = true;

      privacyProtected = false;

      authenticationMessage = '';
    });

    await _authenticate();
  }

  // ============================================================
  // TIME CHECK
  // ============================================================

  bool _hasLockTimeExpired(
      DateTime backgroundTime,
      int seconds,
      ) {
    if (seconds == 0) {
      debugPrint(
        'SMARTCITY AUTO LOCK -> '
            'threshold=immediate',
      );

      return true;
    }

    final Duration elapsed =
    DateTime.now().difference(
      backgroundTime,
    );

    debugPrint(
      'SMARTCITY AUTO LOCK -> '
          'elapsed=${elapsed.inSeconds}s, '
          'threshold=${seconds}s',
    );

    return elapsed.inSeconds >=
        seconds;
  }

  // ============================================================
  // BIOMETRIC AUTHENTICATION
  // ============================================================

  Future<void> _authenticate() async {
    if (authenticating) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      authenticating = true;

      authenticationMessage =
      '';
    });

    try {
      final BiometricAuthResult result =
      await biometricService
          .authenticateSecurely(
        reason:
        'Verify your identity to unlock SmartCity',
      );

      if (!mounted) {
        return;
      }

      switch (result) {
        case BiometricAuthResult.success:
          await securityPreferencesService
              .clearBackgroundTime();

          await securityService
              .logActivity(
            'BIOMETRIC_UNLOCK_SUCCESS',
            'SmartCity was successfully unlocked using device authentication.',
          );

          if (!mounted) {
            return;
          }

          setState(() {
            locked = false;

            privacyProtected = false;

            authenticationMessage =
            '';
          });

          break;

        case BiometricAuthResult.unavailable:
          await securityService
              .logActivity(
            'BIOMETRIC_UNLOCK_FAILED',
            'Device authentication was unavailable.',
          );

          if (!mounted) {
            return;
          }

          setState(() {
            locked = true;

            privacyProtected = false;

            authenticationMessage =
            'Device authentication is currently unavailable.';
          });

          break;

        case BiometricAuthResult.cancelled:
          await securityService
              .logActivity(
            'BIOMETRIC_UNLOCK_CANCELLED',
            'SmartCity unlock authentication was cancelled.',
          );

          if (!mounted) {
            return;
          }

          setState(() {
            locked = true;

            privacyProtected = false;

            authenticationMessage =
            'Authentication was cancelled. Your SmartCity session remains locked.';
          });

          break;

        case BiometricAuthResult.failed:
          await securityService
              .logActivity(
            'BIOMETRIC_UNLOCK_FAILED',
            'SmartCity device authentication was unsuccessful.',
          );

          if (!mounted) {
            return;
          }

          setState(() {
            locked = true;

            privacyProtected = false;

            authenticationMessage =
            'Authentication was unsuccessful. Please try again.';
          });

          break;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        locked = true;

        privacyProtected = false;

        authenticationMessage =
        'Unable to complete device authentication. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          authenticating = false;
        });
      }
    }
  }

  // ============================================================
  // AUTO-LOCK LABEL
  // ============================================================

  String get _autoLockLabel {
    switch (autoLockSeconds) {
      case 0:
        return 'Immediately';

      case 60:
        return 'After 1 minute';

      case 300:
        return 'After 5 minutes';

      default:
        return '$autoLockSeconds seconds';
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    if (initializing) {
      return const Scaffold(
        backgroundColor:
        AppColors.background,

        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      children: [
        // --------------------------------------------------------
        // KEEP EXISTING PAGE / DASHBOARD MOUNTED
        // --------------------------------------------------------

        widget.child,

        // --------------------------------------------------------
        // PRIVACY SHIELD
        // --------------------------------------------------------

        if (privacyProtected)
          const Positioned.fill(
            child: Material(
              color:
              AppColors.background,

              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .center,

                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 72,
                        color:
                        AppColors.primary,
                      ),

                      SizedBox(
                        height: 20,
                      ),

                      Text(
                        'SmartCity',
                        style:
                        TextStyle(
                          fontSize: 26,
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      SizedBox(
                        height: 8,
                      ),

                      Text(
                        'Protected for your privacy',
                        style:
                        TextStyle(
                          color:
                          AppColors
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // --------------------------------------------------------
        // BIOMETRIC LOCK OVERLAY
        // --------------------------------------------------------

        if (biometricEnabled &&
            locked)
          Positioned.fill(
            child: Material(
              color:
              AppColors.background,

              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding:
                    const EdgeInsets
                        .all(
                      28,
                    ),

                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                      children: [
                        Container(
                          width: 110,
                          height: 110,

                          decoration:
                          BoxDecoration(
                            color:
                            AppColors
                                .surface,

                            borderRadius:
                            BorderRadius
                                .circular(
                              30,
                            ),

                            border:
                            Border.all(
                              color:
                              AppColors
                                  .border,
                            ),
                          ),

                          child:
                          const Icon(
                            Icons
                                .fingerprint,

                            size: 65,

                            color:
                            AppColors
                                .primary,
                          ),
                        ),

                        const SizedBox(
                          height: 28,
                        ),

                        const Text(
                          'SmartCity Locked',

                          textAlign:
                          TextAlign.center,

                          style:
                          TextStyle(
                            fontSize: 26,

                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        const Text(
                          'Verify your identity using fingerprint, face, or another authentication method supported by this device.',

                          textAlign:
                          TextAlign.center,

                          style:
                          TextStyle(
                            color:
                            AppColors
                                .textSecondary,

                            fontSize: 12,

                            height: 1.5,
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        Container(
                          width:
                          double.infinity,

                          padding:
                          const EdgeInsets
                              .all(
                            12,
                          ),

                          decoration:
                          BoxDecoration(
                            color:
                            AppColors
                                .surface,

                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),

                            border:
                            Border.all(
                              color:
                              AppColors
                                  .border,
                            ),
                          ),

                          child: Row(
                            children: [
                              const Icon(
                                Icons
                                    .timer_outlined,

                                size: 18,

                                color:
                                AppColors
                                    .primary,
                              ),

                              const SizedBox(
                                width: 9,
                              ),

                              Expanded(
                                child: Text(
                                  'Auto-lock: $_autoLockLabel',

                                  style:
                                  const TextStyle(
                                    color:
                                    AppColors
                                        .textSecondary,

                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (authenticationMessage
                            .isNotEmpty) ...[
                          const SizedBox(
                            height: 14,
                          ),

                          Container(
                            width:
                            double.infinity,

                            padding:
                            const EdgeInsets
                                .all(
                              12,
                            ),

                            decoration:
                            BoxDecoration(
                              color:
                              AppColors
                                  .surface,

                              borderRadius:
                              BorderRadius
                                  .circular(
                                12,
                              ),

                              border:
                              Border.all(
                                color:
                                AppColors
                                    .warning,
                              ),
                            ),

                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                              children: [
                                const Icon(
                                  Icons
                                      .info_outline,

                                  size: 19,

                                  color:
                                  AppColors
                                      .warning,
                                ),

                                const SizedBox(
                                  width: 9,
                                ),

                                Expanded(
                                  child: Text(
                                    authenticationMessage,

                                    style:
                                    const TextStyle(
                                      color:
                                      AppColors
                                          .textSecondary,

                                      fontSize: 11,

                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(
                          height: 30,
                        ),

                        SizedBox(
                          width:
                          double.infinity,

                          height: 52,

                          child:
                          ElevatedButton
                              .icon(
                            onPressed:
                            authenticating
                                ? null
                                : _authenticate,

                            icon:
                            const Icon(
                              Icons
                                  .lock_open,
                            ),

                            label:
                            Text(
                              authenticating
                                  ? 'Verifying...'
                                  : 'Unlock SmartCity',
                            ),
                          ),
                        ),

                        if (authenticating) ...[
                          const SizedBox(
                            height: 18,
                          ),

                          const LinearProgressIndicator(),
                        ],

                        const SizedBox(
                          height: 14,
                        ),

                        const Text(
                          'SmartCity does not store your fingerprint, face data, or device PIN. Verification is handled by your device.',

                          textAlign:
                          TextAlign.center,

                          style:
                          TextStyle(
                            color:
                            AppColors
                                .textSecondary,

                            fontSize: 9,

                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}