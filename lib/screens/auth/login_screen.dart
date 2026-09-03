import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/login_activity_service.dart';
import '../../services/login_security_service.dart';
import '../../services/quick_lock_service.dart';
import '../../services/remembered_account_service.dart';
import '../../theme/app_colors.dart';

import '../welcome_screen.dart';
import 'email_verification_screen.dart';

import 'auth_gate.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool quickLockMode;

  // true:
  // Normal login / Sign Out to Login / startup Quick Login
  // -> Back -> Welcome
  //
  // false:
  // Manual Quick Lock
  // -> Back disabled
  final bool allowBackToWelcome;

  const LoginScreen({
    super.key,
    this.quickLockMode = false,
    this.allowBackToWelcome = true,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final AuthService authService =
  AuthService();

  final LoginActivityService
  loginActivityService =
  LoginActivityService();

  final LoginSecurityService
  loginSecurityService =
  LoginSecurityService();

  final BiometricService
  biometricService =
  BiometricService();

  final QuickLockService
  quickLockService =
  QuickLockService();

  final RememberedAccountService
  rememberedAccountService =
  RememberedAccountService();

  final GlobalKey<FormState> formKey =
  GlobalKey<FormState>();

  final TextEditingController
  emailController =
  TextEditingController();

  final TextEditingController
  passwordController =
  TextEditingController();

  bool loading = false;

  bool hidePassword = true;

  bool blocked = false;

  DateTime? blockedUntil;

  int failedAttempts = 0;

  Timer? countdownTimer;

  bool rememberAccount = false;

  String? rememberedGoogleEmail;

  String? rememberedGoogleName;

  bool rememberedAccountLoading =
  true;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    emailController.addListener(
      _emailChanged,
    );

    _loadRememberedAccount();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    countdownTimer?.cancel();

    emailController.removeListener(
      _emailChanged,
    );

    emailController.dispose();

    passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // BACK TO WELCOME
  // ============================================================

  void goBackToWelcome() {
    if (loading) {
      return;
    }

    if (!widget.allowBackToWelcome) {
      return;
    }

    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
        const WelcomeScreen(),
      ),
          (route) => false,
    );
  }

  // ============================================================
  // EMAIL CHANGED
  // ============================================================

  void _emailChanged() {
    checkLoginSecurity();
  }

  // ============================================================
  // LOAD REMEMBERED ACCOUNT
  // ============================================================

  Future<void>
  _loadRememberedAccount() async {
    try {
      final bool enabled =
      await rememberedAccountService
          .isRememberAccountEnabled();

      final String? email =
      await rememberedAccountService
          .getRememberedEmail();

      final String? googleEmail =
      await rememberedAccountService
          .getRememberedGoogleEmail();

      final String? googleName =
      await rememberedAccountService
          .getRememberedGoogleName();

      if (!mounted) {
        return;
      }

      if (enabled &&
          email != null &&
          email.isNotEmpty &&
          emailController.text.isEmpty) {
        emailController.text =
            email;
      }

      setState(() {
        rememberAccount =
            enabled;

        rememberedGoogleEmail =
        enabled
            ? googleEmail
            : null;

        rememberedGoogleName =
        enabled
            ? googleName
            : null;

        rememberedAccountLoading =
        false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        rememberedAccountLoading =
        false;
      });
    }
  }

  // ============================================================
  // REMEMBER ACCOUNT
  // ============================================================

  Future<void> _setRememberAccount(
      bool enabled,
      ) async {
    if (loading) {
      return;
    }

    setState(() {
      rememberAccount =
          enabled;
    });

    try {
      await rememberedAccountService
          .setRememberAccount(
        enabled,
      );

      if (enabled) {
        final String email =
        emailController.text
            .trim()
            .toLowerCase();

        if (email.isNotEmpty) {
          await rememberedAccountService
              .rememberEmail(
            email,
          );
        }
      } else {
        if (!mounted) {
          return;
        }

        setState(() {
          rememberedGoogleEmail =
          null;

          rememberedGoogleName =
          null;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        rememberAccount =
        !enabled;
      });

      showMessage(
        'Unable to update remembered account settings.',
      );
    }
  }

  // ============================================================
  // CHECK LOGIN SECURITY
  // ============================================================

  Future<void>
  checkLoginSecurity() async {
    final String email =
    emailController.text
        .trim()
        .toLowerCase();

    if (email.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        blocked = false;

        blockedUntil = null;

        failedAttempts = 0;
      });

      countdownTimer?.cancel();

      return;
    }

    final status =
    await loginSecurityService
        .getStatus(
      email,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      blocked =
          status.isBlocked;

      blockedUntil =
          status.blockedUntil;

      failedAttempts =
          status.failedAttempts;
    });

    if (status.isBlocked) {
      startCountdown();
    } else {
      countdownTimer?.cancel();
    }
  }

  // ============================================================
  // BLOCK COUNTDOWN
  // ============================================================

  void startCountdown() {
    countdownTimer?.cancel();

    countdownTimer =
        Timer.periodic(
          const Duration(
            seconds: 1,
          ),
              (_) async {
            final DateTime? until =
                blockedUntil;

            if (until == null) {
              return;
            }

            if (DateTime.now()
                .isAfter(
              until,
            )) {
              countdownTimer?.cancel();

              await loginSecurityService
                  .resetAttempts(
                emailController.text
                    .trim()
                    .toLowerCase(),
              );

              if (!mounted) {
                return;
              }

              setState(() {
                blocked = false;

                blockedUntil = null;

                failedAttempts = 0;
              });

              return;
            }

            if (mounted) {
              setState(() {});
            }
          },
        );
  }

  // ============================================================
  // BLOCK TIME
  // ============================================================

  String get blockTimeText {
    final DateTime? until =
        blockedUntil;

    if (until == null) {
      return '';
    }

    final Duration remaining =
    until.difference(
      DateTime.now(),
    );

    if (remaining.isNegative) {
      return '00:00';
    }

    final int minutes =
        remaining.inMinutes;

    final int seconds =
        remaining.inSeconds %
            60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // EMAIL / PASSWORD LOGIN
  // ============================================================

  Future<void> login() async {
    if (loading) {
      return;
    }

    if (!(formKey.currentState
        ?.validate() ??
        false)) {
      return;
    }

    final String email =
    emailController.text
        .trim()
        .toLowerCase();

    final status =
    await loginSecurityService
        .getStatus(
      email,
    );

    if (status.isBlocked) {
      if (!mounted) {
        return;
      }

      setState(() {
        blocked =
        true;

        blockedUntil =
            status.blockedUntil;

        failedAttempts =
            status.failedAttempts;
      });

      startCountdown();

      showMessage(
        'Too many failed login attempts. '
            'Please try again in $blockTimeText.',
      );

      return;
    }

    setState(() {
      loading =
      true;
    });

    try {
      final response =
      await authService.login(
        email:
        email,

        password:
        passwordController.text,
      );

      final user =
          response.user;

      if (user == null) {
        throw Exception(
          'Unable to sign in.',
        );
      }

      // ========================================================
      // SECOND UI-LEVEL VERIFICATION CHECK
      // ========================================================

      final bool hasEmailIdentity =
          user.identities?.any(
                (
                identity,
                ) =>
            identity.provider ==
                'email',
          ) ??
              false;

      if (
      hasEmailIdentity &&
          user.emailConfirmedAt ==
              null
      ) {
        await authService.logout();

        if (!mounted) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                EmailVerificationScreen(
                  email:
                  email,
                ),
          ),
        );

        return;
      }

      // ========================================================
      // RESET FAILED ATTEMPTS
      // ========================================================

      await loginSecurityService
          .resetAttempts(
        email,
      );

      // ========================================================
      // REMEMBER ACCOUNT
      // ========================================================

      if (rememberAccount) {
        await rememberedAccountService
            .setRememberAccount(
          true,
        );

        await rememberedAccountService
            .rememberEmail(
          email,
        );
      }

      // ========================================================
      // PASSWORD MANAGER
      // ========================================================

      TextInput.finishAutofillContext(
        shouldSave:
        true,
      );

      // ========================================================
      // CLEAR QUICK LOCK ONLY AFTER SUCCESS
      // ========================================================

      if (widget.quickLockMode) {
        await quickLockService
            .clearQuickLockState();
      }

      quickLockService
          .markVerifiedForCurrentRun();

      // ========================================================
      // ACTIVITY
      // ========================================================

      await loginActivityService
          .recordLogin(
        loginMethod:
        'Email / Password',
      );

      if (!mounted) {
        return;
      }

      goToAuthGate();
    } catch (e) {
      final String message =
      e
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      )
          .trim();

      // ========================================================
      // EMAIL NOT VERIFIED
      //
      // IMPORTANT:
      // This is NOT a failed password attempt.
      // Do NOT increment login-security failures.
      // ========================================================

      if (
      message ==
          'EMAIL_NOT_VERIFIED' ||
          message
              .toLowerCase()
              .contains(
            'email not confirmed',
          )
      ) {
        try {
          await authService.logout();
        } catch (_) {}

        if (!mounted) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                EmailVerificationScreen(
                  email:
                  email,
                ),
          ),
        );

        showMessage(
          'Please verify your email before signing in.',
        );

        return;
      }

      // ========================================================
      // REAL FAILED LOGIN
      // ========================================================

      final failedStatus =
      await loginSecurityService
          .recordFailedAttempt(
        email,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        blocked =
            failedStatus.isBlocked;

        blockedUntil =
            failedStatus.blockedUntil;

        failedAttempts =
            failedStatus.failedAttempts;
      });

      if (failedStatus.isBlocked) {
        startCountdown();

        showMessage(
          'Too many failed login attempts. '
              'Login has been temporarily blocked for 5 minutes.',
        );
      } else {
        final int remaining =
            LoginSecurityService
                .maxFailedAttempts -
                failedStatus
                    .failedAttempts;

        showMessage(
          'Invalid email or password. '
              '$remaining attempt'
              '${remaining == 1 ? '' : 's'} remaining.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading =
          false;
        });
      }
    }
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> googleLogin() async {
    if (loading) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // ========================================================
      // GOOGLE AUTHENTICATION FIRST
      //
      // IMPORTANT:
      //
      // DO NOT clear Quick Lock before this succeeds.
      // DO NOT mark the current run verified before this succeeds.
      // ========================================================

      final response =
      await authService
          .signInWithGoogle();

      if (response.user == null) {
        throw Exception(
          'Unable to sign in with Google.',
        );
      }

      // ========================================================
      // GOOGLE ACCOUNT INFORMATION
      // ========================================================

      final String? googleEmail =
          response.user?.email;

      String? googleName =
      response.user
          ?.userMetadata?[
      'full_name'
      ]
          ?.toString();

      googleName ??=
          response.user
              ?.userMetadata?[
          'name'
          ]
              ?.toString();

      // ========================================================
      // REMEMBER GOOGLE ACCOUNT
      // ========================================================

      if (rememberAccount &&
          googleEmail != null &&
          googleEmail.isNotEmpty) {
        await rememberedAccountService
            .setRememberAccount(
          true,
        );

        await rememberedAccountService
            .rememberGoogleAccount(
          email:
          googleEmail,

          name:
          googleName,
        );
      }

      if (mounted &&
          rememberAccount) {
        setState(() {
          rememberedGoogleEmail =
              googleEmail;

          rememberedGoogleName =
              googleName;
        });
      }

      // ========================================================
      // GOOGLE SUCCEEDED -> NOW CLEAR QUICK LOCK
      //
      // If Google was cancelled or failed, execution never
      // reaches here, so SmartCity remains locked.
      // ========================================================

      if (widget.quickLockMode) {
        await quickLockService
            .clearQuickLockState();
      }

      // Google authentication itself already proves identity.
      // Do NOT request biometric again immediately.
      quickLockService
          .markVerifiedForCurrentRun();

      // ========================================================
      // LOGIN ACTIVITY
      // ========================================================

      await loginActivityService
          .recordLogin(
        loginMethod:
        'Google',
      );

      if (!mounted) {
        return;
      }

      goToAuthGate();
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      showMessage(
        message.trim().isEmpty
            ? 'Unable to sign in with Google.'
            : message,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // QUICK LOGIN
  // ============================================================

  Future<void> quickLogin() async {
    if (loading) {
      return;
    }

    if (!widget.quickLockMode) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // ========================================================
      // EXISTING SUPABASE SESSION REQUIRED
      // ========================================================

      final currentUser =
          authService.currentUser;

      if (currentUser == null) {
        await quickLockService
            .clearQuickLockState();

        quickLockService
            .requireVerificationAgain();

        if (!mounted) {
          return;
        }

        showMessage(
          'Your session has expired. '
              'Please sign in again.',
        );

        goToAuthGate();

        return;
      }

      // ========================================================
      // QUICK LOGIN MUST BE ENABLED
      // ========================================================

      final bool quickEnabled =
      await quickLockService
          .isQuickLoginEnabled();

      if (!quickEnabled) {
        await quickLockService
            .clearQuickLockState();

        quickLockService
            .requireVerificationAgain();

        if (!mounted) {
          return;
        }

        showMessage(
          'Quick Login is not enabled '
              'for this account.',
        );

        goToAuthGate();

        return;
      }

      // ========================================================
      // DEVICE AUTHENTICATION
      // ========================================================

      final BiometricAuthResult result =
      await biometricService
          .authenticateSecurely(
        reason:
        'Verify your identity to unlock SmartCity',
      );

      switch (result) {
        case BiometricAuthResult.success:
          await quickLockService
              .unlock();

          quickLockService
              .markVerifiedForCurrentRun();

          await loginActivityService
              .recordLogin(
            loginMethod:
            'Quick Login',
          );

          if (!mounted) {
            return;
          }

          goToAuthGate();

          break;

        case BiometricAuthResult.cancelled:
          if (!mounted) {
            return;
          }

          showMessage(
            'Quick Login verification was cancelled.',
          );

          break;

        case BiometricAuthResult.unavailable:
          if (!mounted) {
            return;
          }

          showMessage(
            'Device authentication is unavailable.',
          );

          break;

        case BiometricAuthResult.failed:
          if (!mounted) {
            return;
          }

          showMessage(
            'Identity verification was unsuccessful.',
          );

          break;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to complete Quick Login.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // AUTH GATE
  // ============================================================

  void goToAuthGate() {
    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
        const AuthGate(),
      ),
          (route) => false,
    );
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  void openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const ForgotPasswordScreen(),
      ),
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  void openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const RegisterScreen(),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  String? validateEmail(
      String? value,
      ) {
    final String email =
        value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email address is required.';
    }

    final RegExp emailPattern =
    RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailPattern.hasMatch(
      email,
    )) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool loginDisabled =
        loading || blocked;

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body:
      SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(
            horizontal:
            24,

            vertical:
            28,
          ),

          child:
          AutofillGroup(
            child:
            Form(
              key:
              formKey,

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  // =================================================
                  // BACK
                  // =================================================

                  Container(
                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.surface,

                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors.border,
                      ),
                    ),

                    child:
                    IconButton(
                      onPressed:
                      loading ||
                          !widget
                              .allowBackToWelcome
                          ? null
                          : goBackToWelcome,

                      icon:
                      const Icon(
                        Icons.arrow_back,

                        color:
                        AppColors
                            .textSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    22,
                  ),

                  // =================================================
                  // ICON
                  // =================================================

                  Container(
                    width:
                    58,

                    height:
                    58,

                    alignment:
                    Alignment.center,

                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.primary
                          .withOpacity(
                        0.10,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        15,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors
                            .primaryDark,
                      ),
                    ),

                    child:
                    const Text(
                      '🔐',

                      style:
                      TextStyle(
                        fontSize:
                        28,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    24,
                  ),

                  // =================================================
                  // HEADING
                  // =================================================

                  Text(
                    widget.quickLockMode
                        ? 'SmartCity Locked'
                        : 'Welcome back',

                    style:
                    const TextStyle(
                      fontSize:
                      29,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                    6,
                  ),

                  Text(
                    widget.quickLockMode
                        ? 'Unlock with device authentication or use another sign-in method'
                        : 'Sign in to your SmartCity account',

                    style:
                    const TextStyle(
                      color:
                      AppColors
                          .textSecondary,

                      fontSize:
                      14,
                    ),
                  ),

                  const SizedBox(
                    height:
                    26,
                  ),

                  // =================================================
                  // QUICK LOGIN
                  // =================================================

                  if (widget.quickLockMode) ...[
                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets.all(
                        13,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.primary
                            .withOpacity(
                          0.06,
                        ),

                        borderRadius:
                        BorderRadius.circular(
                          13,
                        ),

                        border:
                        Border.all(
                          color:
                          AppColors
                              .primaryDark,
                        ),
                      ),

                      child:
                      Column(
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons
                                    .fingerprint,

                                color:
                                AppColors
                                    .primary,

                                size:
                                24,
                              ),

                              SizedBox(
                                width:
                                10,
                              ),

                              Expanded(
                                child:
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                                  children: [
                                    Text(
                                      'Quick Login',

                                      style:
                                      TextStyle(
                                        fontSize:
                                        12,

                                        fontWeight:
                                        FontWeight
                                            .bold,
                                      ),
                                    ),

                                    SizedBox(
                                      height:
                                      3,
                                    ),

                                    Text(
                                      'Use fingerprint, supported face authentication, or device PIN to continue.',

                                      style:
                                      TextStyle(
                                        color:
                                        AppColors
                                            .textSecondary,

                                        fontSize:
                                        9,

                                        height:
                                        1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height:
                            13,
                          ),

                          SizedBox(
                            width:
                            double.infinity,

                            height:
                            50,

                            child:
                            ElevatedButton.icon(
                              style:
                              ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                AppColors
                                    .primaryDark,

                                foregroundColor:
                                Colors.white,

                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    13,
                                  ),
                                ),
                              ),

                              onPressed:
                              loading
                                  ? null
                                  : quickLogin,

                              icon:
                              const Icon(
                                Icons.fingerprint,
                              ),

                              label:
                              Text(
                                loading
                                    ? 'Verifying...'
                                    : 'Unlock with Quick Login',

                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                      22,
                    ),

                    const Row(
                      children: [
                        Expanded(
                          child:
                          Divider(
                            color:
                            AppColors.border,
                          ),
                        ),

                        Padding(
                          padding:
                          EdgeInsets.symmetric(
                            horizontal:
                            12,
                          ),

                          child:
                          Text(
                            'or sign in another way',

                            style:
                            TextStyle(
                              color:
                              AppColors
                                  .textSecondary,

                              fontSize:
                              11,
                            ),
                          ),
                        ),

                        Expanded(
                          child:
                          Divider(
                            color:
                            AppColors.border,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                      22,
                    ),
                  ],

                  // =================================================
                  // BLOCK WARNING
                  // =================================================

                  if (blocked) ...[
                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets.all(
                        13,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.danger
                            .withOpacity(
                          0.07,
                        ),

                        borderRadius:
                        BorderRadius.circular(
                          13,
                        ),

                        border:
                        Border.all(
                          color:
                          AppColors.danger,
                        ),
                      ),

                      child:
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [
                          const Icon(
                            Icons
                                .lock_clock_outlined,

                            color:
                            AppColors.danger,
                          ),

                          const SizedBox(
                            width:
                            10,
                          ),

                          Expanded(
                            child:
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                              children: [
                                const Text(
                                  'Login Temporarily Blocked',

                                  style:
                                  TextStyle(
                                    color:
                                    AppColors
                                        .danger,

                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                  4,
                                ),

                                Text(
                                  'Too many failed attempts. '
                                      'Try again in $blockTimeText.',

                                  style:
                                  const TextStyle(
                                    color:
                                    AppColors
                                        .textSecondary,

                                    fontSize:
                                    10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),
                  ],

                  // =================================================
                  // EMAIL
                  // =================================================

                  const _FieldLabel(
                    'EMAIL ADDRESS',
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  TextFormField(
                    controller:
                    emailController,

                    enabled:
                    !loading,

                    keyboardType:
                    TextInputType
                        .emailAddress,

                    textInputAction:
                    TextInputAction.next,

                    autofillHints:
                    const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],

                    decoration:
                    _inputDecoration(
                      hint:
                      'you@example.com',

                      prefixIcon:
                      Icons.email_outlined,
                    ),

                    validator:
                    validateEmail,
                  ),

                  const SizedBox(
                    height:
                    18,
                  ),

                  // =================================================
                  // PASSWORD
                  // =================================================

                  const _FieldLabel(
                    'PASSWORD',
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  TextFormField(
                    controller:
                    passwordController,

                    enabled:
                    !loginDisabled,

                    obscureText:
                    hidePassword,

                    textInputAction:
                    TextInputAction.done,

                    autofillHints:
                    const [
                      AutofillHints.password,
                    ],

                    onFieldSubmitted:
                        (_) {
                      if (!loginDisabled) {
                        login();
                      }
                    },

                    decoration:
                    _inputDecoration(
                      hint:
                      '••••••••',

                      prefixIcon:
                      Icons.lock_outline,

                      suffix:
                      IconButton(
                        onPressed: () {
                          setState(() {
                            hidePassword =
                            !hidePassword;
                          });
                        },

                        icon:
                        Icon(
                          hidePassword
                              ? Icons
                              .visibility_outlined
                              : Icons
                              .visibility_off_outlined,

                          color:
                          AppColors
                              .textSecondary,
                        ),
                      ),
                    ),

                    validator:
                        (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Password is required.';
                      }

                      return null;
                    },
                  ),

                  // =================================================
                  // REMEMBER ACCOUNT
                  // =================================================

                  CheckboxListTile(
                    contentPadding:
                    EdgeInsets.zero,

                    controlAffinity:
                    ListTileControlAffinity
                        .leading,

                    value:
                    rememberAccount,

                    title:
                    const Text(
                      'Remember my account',

                      style:
                      TextStyle(
                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    subtitle:
                    const Text(
                      'Remember your email and Google account. Passwords are handled securely by your device password manager.',

                      style:
                      TextStyle(
                        color:
                        AppColors
                            .textSecondary,

                        fontSize:
                        9,

                        height:
                        1.4,
                      ),
                    ),

                    onChanged:
                    loading ||
                        rememberedAccountLoading
                        ? null
                        : (
                        bool? value,
                        ) {
                      _setRememberAccount(
                        value ??
                            false,
                      );
                    },
                  ),

                  // =================================================
                  // FAILED ATTEMPTS
                  // =================================================

                  if (!blocked &&
                      failedAttempts >
                          0) ...[
                    const SizedBox(
                      height:
                      8,
                    ),

                    Text(
                      'Failed attempts: '
                          '$failedAttempts / '
                          '${LoginSecurityService.maxFailedAttempts}',

                      style:
                      const TextStyle(
                        color:
                        AppColors.warning,

                        fontSize:
                        10,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height:
                    7,
                  ),

                  Align(
                    alignment:
                    Alignment.centerRight,

                    child:
                    TextButton(
                      onPressed:
                      loading
                          ? null
                          : openForgotPassword,

                      child:
                      const Text(
                        'Forgot password?',

                        style:
                        TextStyle(
                          color:
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    12,
                  ),

                  // =================================================
                  // SIGN IN
                  // =================================================

                  SizedBox(
                    width:
                    double.infinity,

                    height:
                    56,

                    child:
                    ElevatedButton(
                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        AppColors
                            .primaryDark,

                        foregroundColor:
                        Colors.white,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),

                      onPressed:
                      loginDisabled
                          ? null
                          : login,

                      child:
                      loading
                          ? const SizedBox(
                        width:
                        22,

                        height:
                        22,

                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2.5,

                          color:
                          Colors.white,
                        ),
                      )
                          : blocked
                          ? Text(
                        'Blocked $blockTimeText',
                      )
                          : const Text(
                        'Sign In',

                        style:
                        TextStyle(
                          fontSize:
                          15,

                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    24,
                  ),

                  // =================================================
                  // DIVIDER
                  // =================================================

                  const Row(
                    children: [
                      Expanded(
                        child:
                        Divider(
                          color:
                          AppColors.border,
                        ),
                      ),

                      Padding(
                        padding:
                        EdgeInsets.symmetric(
                          horizontal:
                          12,
                        ),

                        child:
                        Text(
                          'or continue with',

                          style:
                          TextStyle(
                            color:
                            AppColors
                                .textSecondary,

                            fontSize:
                            11,
                          ),
                        ),
                      ),

                      Expanded(
                        child:
                        Divider(
                          color:
                          AppColors.border,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                    22,
                  ),

                  // =================================================
                  // GOOGLE
                  // =================================================

                  SizedBox(
                    width:
                    double.infinity,

                    height:
                    54,

                    child:
                    OutlinedButton(
                      style:
                      OutlinedButton
                          .styleFrom(
                        foregroundColor:
                        Colors.white,

                        backgroundColor:
                        AppColors.surface,

                        side:
                        const BorderSide(
                          color:
                          AppColors.border,
                        ),

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            13,
                          ),
                        ),
                      ),

                      onPressed:
                      loading
                          ? null
                          : googleLogin,

                      child:
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,

                        children: [
                          const Text(
                            'G',

                            style:
                            TextStyle(
                              color:
                              Color(
                                0xFF4285F4,
                              ),

                              fontSize:
                              20,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            width:
                            12,
                          ),

                          Flexible(
                            child:
                            Text(
                              rememberedGoogleEmail !=
                                  null &&
                                  rememberedGoogleEmail!
                                      .isNotEmpty
                                  ? 'Continue with $rememberedGoogleEmail'
                                  : 'Sign in with Google',

                              maxLines:
                              1,

                              overflow:
                              TextOverflow
                                  .ellipsis,

                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    26,
                  ),

                  // =================================================
                  // PDPA
                  // =================================================

                  Container(
                    width:
                    double.infinity,

                    padding:
                    const EdgeInsets.all(
                      13,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.surface,

                      borderRadius:
                      BorderRadius.circular(
                        13,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors.border,
                      ),
                    ),

                    child:
                    const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.shield_outlined,

                          color:
                          AppColors.primary,

                          size:
                          15,
                        ),

                        SizedBox(
                          width:
                          7,
                        ),

                        Flexible(
                          child:
                          Text(
                            'Your data is protected under PDPA 2010',

                            textAlign:
                            TextAlign.center,

                            style:
                            TextStyle(
                              color:
                              AppColors
                                  .textSecondary,

                              fontSize:
                              10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height:
                    26,
                  ),

                  // =================================================
                  // REGISTER
                  // =================================================

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,

                    children: [
                      const Text(
                        "Don't have an account? ",

                        style:
                        TextStyle(
                          color:
                          AppColors
                              .textSecondary,

                          fontSize:
                          13,
                        ),
                      ),

                      GestureDetector(
                        onTap:
                        loading
                            ? null
                            : openRegister,

                        child:
                        const Text(
                          'Create Account',

                          style:
                          TextStyle(
                            color:
                            AppColors.primary,

                            fontSize:
                            13,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                    20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// FIELD LABEL
// ================================================================

class _FieldLabel
    extends StatelessWidget {
  final String text;

  const _FieldLabel(
      this.text,
      );

  @override
  Widget build(
      BuildContext context,
      ) {
    return Text(
      text,

      style:
      const TextStyle(
        color:
        Color(
          0xFFA9C7EF,
        ),

        fontSize:
        11,

        fontWeight:
        FontWeight.w600,

        letterSpacing:
        0.4,
      ),
    );
  }
}

// ================================================================
// INPUT DECORATION
// ================================================================

InputDecoration _inputDecoration({
  required String hint,
  required IconData prefixIcon,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText:
    hint,

    hintStyle:
    const TextStyle(
      color:
      AppColors.textSecondary,
    ),

    prefixIcon:
    Icon(
      prefixIcon,

      color:
      AppColors.textSecondary,

      size:
      19,
    ),

    suffixIcon:
    suffix,

    filled:
    true,

    fillColor:
    AppColors.surface,

    contentPadding:
    const EdgeInsets.symmetric(
      horizontal:
      14,

      vertical:
      16,
    ),

    enabledBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.border,
      ),
    ),

    focusedBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.primary,

        width:
        1.4,
      ),
    ),

    errorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.danger,
      ),
    ),

    focusedErrorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.danger,
      ),
    ),
  );
}