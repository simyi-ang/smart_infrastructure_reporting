import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/email_verification_security_service.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

// ================================================================
// EMAIL VERIFICATION SCREEN
//
// FEATURES
//
// - 5-minute SmartCity verification window
// - live expiry countdown
// - persistent expiry across app restart
// - 60-second minimum resend interval
// - maximum resend attempts
// - 15-minute temporary resend block
// - server-side email confirmation check
// - designed expired state
// - designed verified-success state
//
// IMPORTANT:
//
// The 5-minute window here is SmartCity application-level
// enforcement.
//
// Supabase still validates the real confirmation token.
// Server-side token expiry configuration is handled separately.
// ================================================================

class EmailVerificationScreen
    extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen>
  createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final AuthService authService =
  AuthService();

  final EmailVerificationSecurityService
  verificationSecurityService =
  EmailVerificationSecurityService();

  // ============================================================
  // STATE
  // ============================================================

  bool sending =
  false;

  bool checkingVerification =
  false;

  bool verificationCompleted =
  false;

  bool verificationExpired =
  false;

  bool resendBlocked =
  false;

  int resendAttempts =
  0;

  Duration verificationRemaining =
      Duration.zero;

  Duration resendBlockRemaining =
      Duration.zero;

  Timer? statusTimer;

  // ============================================================
  // CLEAN EMAIL
  // ============================================================

  String get cleanEmail =>
      widget.email
          .trim()
          .toLowerCase();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadSecurityStatus();

    statusTimer =
        Timer.periodic(
          const Duration(
            seconds: 1,
          ),
              (
              _,
              ) {
            _loadSecurityStatus();
          },
        );
  }

  // ============================================================
  // LOAD SECURITY STATUS
  // ============================================================

  Future<void>
  _loadSecurityStatus() async {
    final EmailVerificationSecurityStatus
    status =
    await verificationSecurityService
        .getStatus(
      cleanEmail,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      verificationExpired =
          status.verificationExpired;

      verificationRemaining =
          status.verificationRemaining;

      resendBlocked =
          status.resendBlocked;

      resendBlockRemaining =
          status.resendBlockRemaining;

      resendAttempts =
          status.resendAttempts;
    });
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String formatDuration(
      Duration duration,
      ) {
    final int totalSeconds =
    duration.inSeconds < 0
        ? 0
        : duration.inSeconds;

    final int minutes =
        totalSeconds ~/ 60;

    final int seconds =
        totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CHECK VERIFICATION
  // ============================================================

  Future<void>
  checkVerificationStatus() async {
    if (
    checkingVerification ||
        sending
    ) {
      return;
    }

    setState(() {
      checkingVerification =
      true;
    });

    try {
      // ========================================================
      // SMARTCITY 5-MINUTE WINDOW CHECK
      // ========================================================

      final bool validWindow =
      await verificationSecurityService
          .isVerificationWindowValid(
        cleanEmail,
      );

      if (!validWindow) {
        if (!mounted) {
          return;
        }

        setState(() {
          verificationExpired =
          true;
        });

        showMessage(
          'This verification request has expired. '
              'Please request a new verification email.',
        );

        return;
      }

      // ========================================================
      // SERVER-SIDE AUTH CHECK
      // ========================================================

      final RegistrationEmailCheckResult
      result =
      await authService
          .checkRegistrationEmail(
        cleanEmail,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // ACCOUNT NOT FOUND
      // ========================================================

      if (!result.exists) {
        showMessage(
          'Registration information could not be found. '
              'Please register again.',
        );

        return;
      }

      // ========================================================
      // NOT VERIFIED
      // ========================================================

      if (!result.emailConfirmed) {
        setState(() {
          verificationCompleted =
          false;
        });

        showMessage(
          'Your email has not been verified yet. '
              'Open the verification email and click '
              'the confirmation link first.',
        );

        return;
      }

      // ========================================================
      // VERIFIED
      // ========================================================

      setState(() {
        verificationCompleted =
        true;
      });

      // ========================================================
      // CLEAR VERIFICATION SECURITY STATE
      // ========================================================

      await verificationSecurityService
          .clear(
        cleanEmail,
      );

      await showAccountCreatedSuccess();

      if (!mounted) {
        return;
      }

      await goToLogin();
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message =
      e
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      )
          .trim();

      showMessage(
        message.isEmpty
            ? 'Unable to check email verification. '
            'Please try again.'
            : message,
      );
    } finally {
      if (mounted) {
        setState(() {
          checkingVerification =
          false;
        });
      }
    }
  }

  // ============================================================
  // RESEND VERIFICATION EMAIL
  // ============================================================

  Future<void> resendEmail() async {
    if (
    sending ||
        checkingVerification
    ) {
      return;
    }

    try {
      setState(() {
        sending =
        true;
      });

      // ========================================================
      // SMARTCITY SECURITY CHECK
      // ========================================================

      final EmailVerificationResendResult
      securityResult =
      await verificationSecurityService
          .checkResendAllowed(
        cleanEmail,
      );

      if (!securityResult.allowed) {
        if (!mounted) {
          return;
        }

        await _loadSecurityStatus();

        showMessage(
          securityResult.message ??
              'Verification email resend is currently unavailable.',
        );

        return;
      }

      // ========================================================
      // SUPABASE RESEND
      // ========================================================

      await Supabase.instance.client.auth
          .resend(
        type:
        OtpType.signup,

        email:
        cleanEmail,
      );

      // ========================================================
      // SUCCESSFUL RESEND
      //
      // Start new 5-minute verification window.
      // ========================================================

      await verificationSecurityService
          .recordSuccessfulResend(
        cleanEmail,
      );

      await _loadSecurityStatus();

      if (!mounted) {
        return;
      }

      showMessage(
        'A new verification email was sent. '
            'The new verification window is valid for 5 minutes.',
        success:
        true,
      );
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        _formatAuthError(
          e.message,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to resend the verification email. '
            'Please try again later.',
      );
    } finally {
      if (mounted) {
        setState(() {
          sending =
          false;
        });
      }
    }
  }

  // ============================================================
  // VERIFIED SUCCESS DIALOG
  // ============================================================

  Future<void>
  showAccountCreatedSuccess() async {
    await showDialog<void>(
      context:
      context,

      barrierDismissible:
      false,

      builder:
          (
          dialogContext,
          ) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              22,
            ),
          ),

          content:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              Container(
                width:
                82,

                height:
                82,

                decoration:
                BoxDecoration(
                  color:
                  AppColors.success
                      .withOpacity(
                    0.12,
                  ),

                  shape:
                  BoxShape.circle,
                ),

                child:
                const Icon(
                  Icons
                      .verified_outlined,

                  color:
                  AppColors.success,

                  size:
                  45,
                ),
              ),

              const SizedBox(
                height:
                20,
              ),

              const Text(
                'Email Verified Successfully',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  fontSize:
                  21,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                10,
              ),

              const Text(
                'Your email address has been verified and '
                    'your SmartCity account registration is now complete.',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  color:
                  AppColors.textSecondary,

                  height:
                  1.5,
                ),
              ),

              const SizedBox(
                height:
                22,
              ),

              SizedBox(
                width:
                double.infinity,

                height:
                48,

                child:
                ElevatedButton(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    AppColors.primaryDark,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        13,
                      ),
                    ),
                  ),

                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },

                  child:
                  const Text(
                    'Continue to Login',

                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> goToLogin() async {
    try {
      if (
      Supabase.instance.client.auth
          .currentSession !=
          null
      ) {
        await Supabase.instance.client.auth
            .signOut();
      }
    } catch (_) {}

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,

      MaterialPageRoute(
        builder:
            (_) =>
        const LoginScreen(),
      ),

          (
          route,
          ) =>
      false,
    );
  }

  // ============================================================
  // BACK TO LOGIN
  // ============================================================

  Future<void> backToLogin() async {
    await goToLogin();
  }

  // ============================================================
  // AUTH ERROR
  // ============================================================

  String _formatAuthError(
      String message,
      ) {
    final String lower =
    message.toLowerCase();

    if (
    lower.contains(
      'rate',
    ) ||
        lower.contains(
          'too many',
        )
    ) {
      return 'Too many verification email requests. '
          'Please wait before trying again.';
    }

    if (
    lower.contains(
      'already confirmed',
    )
    ) {
      return 'This email address has already been verified. '
          'Tap "I Have Verified My Email".';
    }

    return message;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
      String message, {
        bool success = false,
      }) {
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        behavior:
        SnackBarBehavior.floating,

        duration:
        const Duration(
          seconds:
          4,
        ),

        backgroundColor:
        success
            ? AppColors.success
            : AppColors.danger,

        content:
        Row(
          children: [
            Icon(
              success
                  ? Icons
                  .check_circle_outline
                  : Icons
                  .error_outline,

              color:
              Colors.white,
            ),

            const SizedBox(
              width:
              10,
            ),

            Expanded(
              child:
              Text(
                message,

                style:
                const TextStyle(
                  color:
                  Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    statusTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool canResend =
        !sending &&
            !checkingVerification &&
            !resendBlocked;

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body:
      SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.all(
            26,
          ),

          child:
          Column(
            children: [
              const SizedBox(
                height:
                45,
              ),

              // =================================================
              // ICON
              // =================================================

              Container(
                width:
                95,

                height:
                95,

                decoration:
                BoxDecoration(
                  color:
                  verificationCompleted
                      ? AppColors.success
                      .withOpacity(
                    0.12,
                  )
                      : verificationExpired
                      ? AppColors.danger
                      .withOpacity(
                    0.10,
                  )
                      : AppColors.primary
                      .withOpacity(
                    0.12,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    25,
                  ),
                ),

                child:
                Icon(
                  verificationCompleted
                      ? Icons
                      .verified_outlined
                      : verificationExpired
                      ? Icons
                      .timer_off_outlined
                      : Icons
                      .mark_email_unread_outlined,

                  size:
                  48,

                  color:
                  verificationCompleted
                      ? AppColors.success
                      : verificationExpired
                      ? AppColors.danger
                      : AppColors.primary,
                ),
              ),

              const SizedBox(
                height:
                28,
              ),

              // =================================================
              // TITLE
              // =================================================

              Text(
                verificationExpired
                    ? 'Verification Expired'
                    : 'Verify Your Email',

                textAlign:
                TextAlign.center,

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
                12,
              ),

              Text(
                verificationExpired
                    ? 'Request a new verification email to continue.'
                    : 'We sent a verification email to',

                textAlign:
                TextAlign.center,

                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,
                ),
              ),

              if (
              !verificationExpired
              ) ...[
                const SizedBox(
                  height:
                  8,
                ),

                Text(
                  cleanEmail,

                  textAlign:
                  TextAlign.center,

                  style:
                  const TextStyle(
                    color:
                    AppColors.primary,

                    fontWeight:
                    FontWeight.bold,

                    fontSize:
                    15,
                  ),
                ),
              ],

              const SizedBox(
                height:
                22,
              ),

              // =================================================
              // VERIFICATION TIMER
              // =================================================

              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.all(
                  18,
                ),

                decoration:
                BoxDecoration(
                  color:
                  AppColors.surface,

                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),

                  border:
                  Border.all(
                    color:
                    verificationExpired
                        ? AppColors.danger
                        .withOpacity(
                      0.55,
                    )
                        : AppColors.border,
                  ),
                ),

                child:
                Column(
                  children: [
                    Icon(
                      verificationExpired
                          ? Icons
                          .timer_off_outlined
                          : Icons.timer_outlined,

                      color:
                      verificationExpired
                          ? AppColors.danger
                          : AppColors.warning,

                      size:
                      27,
                    ),

                    const SizedBox(
                      height:
                      9,
                    ),

                    Text(
                      verificationExpired
                          ? 'Verification window expired'
                          : 'Verification link expires in',

                      style:
                      TextStyle(
                        color:
                        verificationExpired
                            ? AppColors.danger
                            : AppColors.textSecondary,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    Text(
                      verificationExpired
                          ? '00:00'
                          : formatDuration(
                        verificationRemaining,
                      ),

                      style:
                      TextStyle(
                        color:
                        verificationExpired
                            ? AppColors.danger
                            : AppColors.primary,

                        fontSize:
                        31,

                        fontWeight:
                        FontWeight.bold,

                        letterSpacing:
                        1.5,
                      ),
                    ),

                    const SizedBox(
                      height:
                      7,
                    ),

                    Text(
                      verificationExpired
                          ? 'For security, request a new verification email.'
                          : 'Complete email verification before the timer reaches zero.',

                      textAlign:
                      TextAlign.center,

                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,

                        fontSize:
                        11,

                        height:
                        1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                14,
              ),

              // =================================================
              // INSTRUCTIONS
              // =================================================

              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.all(
                  14,
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
                ),

                child:
                const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Icon(
                      Icons.info_outline,

                      color:
                      AppColors.primary,

                      size:
                      18,
                    ),

                    SizedBox(
                      width:
                      9,
                    ),

                    Expanded(
                      child:
                      Text(
                        '1. Open the verification email.\n'
                            '2. Tap the confirmation link.\n'
                            '3. Return to SmartCity.\n'
                            '4. Tap "I Have Verified My Email".\n\n'
                            'Check Spam or Junk if the email is missing.',

                        style:
                        TextStyle(
                          color:
                          AppColors.textSecondary,

                          fontSize:
                          11,

                          height:
                          1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                25,
              ),

              // =================================================
              // VERIFY BUTTON
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height:
                55,

                child:
                ElevatedButton.icon(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    AppColors.primaryDark,

                    disabledBackgroundColor:
                    AppColors.primaryDark
                        .withOpacity(
                      0.45,
                    ),
                  ),

                  onPressed:
                  checkingVerification ||
                      sending ||
                      verificationExpired
                      ? null
                      : checkVerificationStatus,

                  icon:
                  checkingVerification
                      ? const SizedBox(
                    width:
                    18,

                    height:
                    18,

                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,

                      color:
                      Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons
                        .verified_user_outlined,
                  ),

                  label:
                  Text(
                    checkingVerification
                        ? 'Checking Verification...'
                        : 'I Have Verified My Email',

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                12,
              ),

              // =================================================
              // RESEND BLOCK STATUS
              // =================================================

              if (resendBlocked)
                Container(
                  width:
                  double.infinity,

                  margin:
                  const EdgeInsets.only(
                    bottom:
                    10,
                  ),

                  padding:
                  const EdgeInsets.all(
                    12,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    AppColors.danger
                        .withOpacity(
                      0.08,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),

                    border:
                    Border.all(
                      color:
                      AppColors.danger
                          .withOpacity(
                        0.40,
                      ),
                    ),
                  ),

                  child:
                  Row(
                    children: [
                      const Icon(
                        Icons
                            .lock_clock_outlined,

                        color:
                        AppColors.danger,

                        size:
                        19,
                      ),

                      const SizedBox(
                        width:
                        9,
                      ),

                      Expanded(
                        child:
                        Text(
                          'Too many resend requests. '
                              'Try again in '
                              '${formatDuration(resendBlockRemaining)}.',

                          style:
                          const TextStyle(
                            color:
                            AppColors.textSecondary,

                            fontSize:
                            11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // =================================================
              // RESEND
              // =================================================

              TextButton.icon(
                onPressed:
                canResend
                    ? resendEmail
                    : null,

                icon:
                sending
                    ? const SizedBox(
                  width:
                  16,

                  height:
                  16,

                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                  ),
                )
                    : const Icon(
                  Icons
                      .forward_to_inbox_outlined,
                ),

                label:
                Text(
                  sending
                      ? 'Sending...'
                      : resendBlocked
                      ? 'Resend temporarily blocked'
                      : verificationExpired
                      ? 'Send New Verification Email'
                      : 'Resend Verification Email',
                ),
              ),

              const SizedBox(
                height:
                4,
              ),

              // =================================================
              // RESEND COUNT
              // =================================================

              Text(
                'Verification resend requests: '
                    '$resendAttempts / '
                    '${EmailVerificationSecurityService.maxResendAttempts}',

                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,

                  fontSize:
                  10,
                ),
              ),

              const SizedBox(
                height:
                5,
              ),

              // =================================================
              // LOGIN
              // =================================================

              TextButton(
                onPressed:
                checkingVerification ||
                    sending
                    ? null
                    : backToLogin,

                child:
                const Text(
                  'Back to Login',
                ),
              ),

              const SizedBox(
                height:
                15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}