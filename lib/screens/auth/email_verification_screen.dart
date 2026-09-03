import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/email_verification_security_service.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

// ================================================================
// EMAIL VERIFICATION SCREEN
//
// Registration is NOT considered complete simply because signUp()
// returned a User.
//
// SmartCity considers registration complete only when:
//
// emailConfirmedAt != null
//
// The verification status is checked server-side through:
//
// check-registration-email
//
// Flow:
//
// Register
//    ↓
// Pending verification
//    ↓
// Verification email
//    ↓
// User clicks link
//    ↓
// User returns here
//    ↓
// "I Have Verified My Email"
//    ↓
// Server confirms email_confirmed = true
//    ↓
// Account Creation Successful
//    ↓
// Login
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

  // ============================================================
  // STATE
  // ============================================================

  bool sending =
  false;

  bool checkingVerification =
  false;

  bool verificationCompleted =
  false;

  int resendCooldownSeconds =
  0;

  Timer? resendTimer;

  // ============================================================
  // CLEAN EMAIL
  // ============================================================

  String get cleanEmail =>
      widget.email
          .trim()
          .toLowerCase();

  // ============================================================
  // RESEND VERIFICATION EMAIL
  // ============================================================

  Future<void> resendEmail() async {
    if (
    sending ||
        checkingVerification ||
        resendCooldownSeconds >
            0
    ) {
      return;
    }

    try {
      setState(() {
        sending =
        true;
      });

      await Supabase.instance.client.auth
          .resend(
        type:
        OtpType.signup,

        email:
        cleanEmail,
      );

      if (!mounted) {
        return;
      }

      _startResendCooldown();

      showMessage(
        'Verification email sent. '
            'Please check your inbox.',
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
    } catch (_) {
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
  // RESEND COOLDOWN
  // ============================================================

  void _startResendCooldown() {
    resendTimer?.cancel();

    setState(() {
      resendCooldownSeconds =
      60;
    });

    resendTimer =
        Timer.periodic(
          const Duration(
            seconds:
            1,
          ),
              (
              timer,
              ) {
            if (!mounted) {
              timer.cancel();

              return;
            }

            if (
            resendCooldownSeconds <=
                1
            ) {
              timer.cancel();

              setState(() {
                resendCooldownSeconds =
                0;
              });

              return;
            }

            setState(() {
              resendCooldownSeconds--;
            });
          },
        );
  }

  // ============================================================
  // CHECK EMAIL VERIFICATION
  //
  // IMPORTANT:
  //
  // We do not trust the button tap itself.
  //
  // Clicking:
  //
  // "I Have Verified My Email"
  //
  // does NOT mark the account as verified.
  //
  // SmartCity asks the server whether Supabase has actually
  // confirmed this email.
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
      // SERVER-SIDE AUTH USER CHECK
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
      // ACCOUNT SHOULD EXIST
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
              'Please open the verification email and click the '
              'confirmation link first.',
        );

        return;
      }

      // ========================================================
      // VERIFIED
      //
      // THIS IS THE POINT WHERE SMARTCITY CONSIDERS THE
      // REGISTRATION SUCCESSFULLY COMPLETED.
      // ========================================================

      setState(() {
        verificationCompleted =
        true;
      });

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
  // ACCOUNT CREATED SUCCESSFULLY
  //
  // ONLY displayed after:
  //
  // result.emailConfirmed == true
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

          title:
          const Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Icon(
                Icons
                    .check_circle_outline,

                color:
                AppColors.success,

                size:
                27,
              ),

              SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Text(
                  'Account Created Successfully',
                ),
              ),
            ],
          ),

          content:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              Container(
                width:
                70,

                height:
                70,

                decoration:
                BoxDecoration(
                  color:
                  AppColors.success
                      .withOpacity(
                    0.10,
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
                  38,
                ),
              ),

              const SizedBox(
                height:
                18,
              ),

              const Text(
                'Your email address has been verified successfully.',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                8,
              ),

              const Text(
                'Your SmartCity account registration is now '
                    'complete. You can sign in using your email '
                    'and password.',

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
            ],
          ),

          actions: [
            SizedBox(
              width:
              double.infinity,

              child:
              ElevatedButton(
                style:
                ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  AppColors.primaryDark,
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // GO TO LOGIN
  // ============================================================

  Future<void> goToLogin() async {
    try {
      // ========================================================
      // DEFENSIVE SIGN OUT
      //
      // Registration should not carry an authenticated session
      // directly into the application.
      //
      // The citizen signs in normally after verification.
      // ========================================================

      if (
      Supabase.instance.client.auth
          .currentSession !=
          null
      ) {
        await Supabase.instance.client.auth
            .signOut();
      }
    } catch (_) {
      // A local sign-out problem should not trap the user
      // on the verification screen.
    }

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
  // RETURN TO LOGIN WITHOUT CLAIMING VERIFICATION
  //
  // Useful if the user wants to leave this screen.
  //
  // LoginScreen/AuthService will still reject the account if
  // emailConfirmedAt is null.
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
      return 'Too many verification emails were requested. '
          'Please wait before trying again.';
    }

    if (
    lower.contains(
      'already confirmed',
    )
    ) {
      return 'This email address has already been verified. '
          'Tap "I Have Verified My Email" to continue.';
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
    resendTimer?.cancel();

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
            resendCooldownSeconds ==
                0;

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body:
      SafeArea(
        child:
        Padding(
          padding:
          const EdgeInsets.all(
            26,
          ),

          child:
          Column(
            children: [
              const Spacer(),

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
                      : Icons
                      .mark_email_unread_outlined,

                  size:
                  48,

                  color:
                  verificationCompleted
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),

              const SizedBox(
                height:
                30,
              ),

              // =================================================
              // TITLE
              // =================================================

              const Text(
                'Verify Your Email',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  fontSize:
                  29,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                14,
              ),

              const Text(
                'We sent a confirmation email to',

                style:
                TextStyle(
                  color:
                  AppColors.textSecondary,
                ),
              ),

              const SizedBox(
                height:
                8,
              ),

              // =================================================
              // EMAIL
              // =================================================

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

              const SizedBox(
                height:
                25,
              ),

              // =================================================
              // REGISTRATION STATUS
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
                    15,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors.border,
                  ),
                ),

                child:
                const Column(
                  children: [
                    Icon(
                      Icons
                          .pending_actions_outlined,

                      color:
                      AppColors.warning,

                      size:
                      26,
                    ),

                    SizedBox(
                      height:
                      10,
                    ),

                    Text(
                      'Registration Pending Verification',

                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.bold,

                        fontSize:
                        15,
                      ),
                    ),

                    SizedBox(
                      height:
                      8,
                    ),

                    Text(
                      'Your registration is not complete yet. '
                          'Open your email and click the verification '
                          'link. Your SmartCity account will only '
                          'become active after your email address has '
                          'been verified.',

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
                    12,
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
                            '2. Click the confirmation link.\n'
                            '3. Return to SmartCity.\n'
                            '4. Tap "I Have Verified My Email".\n\n'
                            'If you do not see the email, check your '
                            'Spam or Junk folder.',

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

              const Spacer(),

              // =================================================
              // CHECK VERIFICATION BUTTON
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height:
                55,

                child:
                ElevatedButton.icon(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.primaryDark,

                    disabledBackgroundColor:
                    AppColors.primaryDark
                        .withOpacity(
                      0.5,
                    ),
                  ),

                  onPressed:
                  checkingVerification ||
                      sending
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
                      : resendCooldownSeconds >
                      0
                      ? 'Resend in '
                      '${resendCooldownSeconds}s'
                      : 'Resend verification email',
                ),
              ),

              // =================================================
              // BACK TO LOGIN
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
                10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}