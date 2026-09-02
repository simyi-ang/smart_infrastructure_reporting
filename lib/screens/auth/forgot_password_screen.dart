import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

// ================================================================
// FORGOT PASSWORD SCREEN
//
// Flow:
//
// Enter email
//      ↓
// SmartCity / Supabase rate-limit checks
//      ↓
// Reset email requested
//      ↓
// Check Email
//      ↓
// 60-second resend cooldown
//      ↓
// User opens recovery link
//      ↓
// SmartCity Reset Password screen
//
// Security:
//
// - Generic response prevents account enumeration.
// - Email is masked after submission.
// - Supabase controls recovery-link validity.
// - SmartCity applies additional repeated-request protection.
// - All Back actions explicitly return to LoginScreen.
// ================================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

// ================================================================
// SCREEN STATES
// ================================================================

enum _ForgotPasswordViewState {
  enterEmail,
  emailSent,
  temporarilyBlocked,
}

// ================================================================
// FORGOT PASSWORD STATE
// ================================================================

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  // ============================================================
  // SERVICES / CONTROLLERS
  // ============================================================

  final TextEditingController emailController =
  TextEditingController();

  final AuthService authService =
  AuthService();

  // ============================================================
  // GENERAL UI STATE
  // ============================================================

  bool loading = false;

  // Prevent duplicate Login navigation caused by:
  //
  // - double tap
  // - top Back + system Back
  // - repeated callbacks
  bool navigatingToLogin = false;

  _ForgotPasswordViewState viewState =
      _ForgotPasswordViewState.enterEmail;

  String submittedEmail = '';

  // ============================================================
  // RESEND COOLDOWN
  // ============================================================

  static const int resendCooldownSeconds =
  60;

  int resendSecondsRemaining =
  0;

  Timer? resendTimer;

  // ============================================================
  // TEMPORARY SECURITY BLOCK
  // ============================================================

  int blockSecondsRemaining =
  0;

  Timer? blockTimer;

  // ============================================================
  // SEND RESET EMAIL
  // ============================================================

  Future<void> sendReset({
    bool resend = false,
  }) async {
    if (loading ||
        navigatingToLogin) {
      return;
    }

    // ==========================================================
    // RESEND COOLDOWN
    // ==========================================================

    if (resend &&
        resendSecondsRemaining > 0) {
      return;
    }

    final String email =
    resend
        ? submittedEmail
        : emailController.text
        .trim()
        .toLowerCase();

    // ==========================================================
    // EMPTY EMAIL
    // ==========================================================

    if (email.isEmpty) {
      showMessage(
        'Please enter your email address.',
      );

      return;
    }

    // ==========================================================
    // BASIC EMAIL VALIDATION
    // ==========================================================

    final RegExp emailPattern =
    RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailPattern.hasMatch(
      email,
    )) {
      showMessage(
        'Please enter a valid email address.',
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // ========================================================
      // SMARTCITY AUTH SERVICE
      //
      // AuthService handles:
      //
      // - SmartCity password-reset monitoring
      // - server-side repeated-request protection
      // - Supabase reset email
      // - recovery deep link
      // ========================================================

      final result =
      await authService
          .forgotPassword(
        email,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // REQUEST TEMPORARILY BLOCKED
      // ========================================================

      if (!result.allowed) {
        submittedEmail =
            email;

        final int seconds =
        result.retryAfterSeconds > 0
            ? result.retryAfterSeconds
            : 15 * 60;

        _startBlockCountdown(
          seconds,
        );

        setState(() {
          viewState =
              _ForgotPasswordViewState
                  .temporarilyBlocked;
        });

        return;
      }

      // ========================================================
      // REQUEST ACCEPTED
      //
      // The UI deliberately does not confirm whether the email
      // exists in SmartCity.
      //
      // This helps prevent account enumeration.
      // ========================================================

      submittedEmail =
          email;

      setState(() {
        viewState =
            _ForgotPasswordViewState
                .emailSent;
      });

      _startResendCountdown();

      // ========================================================
      // REPEATED-REQUEST PROTECTION ACTIVATED
      // ========================================================

      if (result.protectionActivated) {
        showMessage(
          'Password recovery protection is now active. '
              'Further repeated requests may be temporarily restricted.',
        );
      }
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
            ? 'Unable to process the password reset request.'
            : message,
      );
    } finally {
      if (mounted &&
          !navigatingToLogin) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // START 60-SECOND RESEND COUNTDOWN
  // ============================================================

  void _startResendCountdown() {
    resendTimer?.cancel();

    setState(() {
      resendSecondsRemaining =
          resendCooldownSeconds;
    });

    resendTimer =
        Timer.periodic(
          const Duration(
            seconds: 1,
          ),
              (
              Timer timer,
              ) {
            if (!mounted ||
                navigatingToLogin) {
              timer.cancel();

              return;
            }

            if (resendSecondsRemaining <= 1) {
              timer.cancel();

              setState(() {
                resendSecondsRemaining =
                0;
              });

              return;
            }

            setState(() {
              resendSecondsRemaining--;
            });
          },
        );
  }

  // ============================================================
  // START TEMPORARY BLOCK COUNTDOWN
  // ============================================================

  void _startBlockCountdown(
      int seconds,
      ) {
    blockTimer?.cancel();

    setState(() {
      blockSecondsRemaining =
          seconds;
    });

    blockTimer =
        Timer.periodic(
          const Duration(
            seconds: 1,
          ),
              (
              Timer timer,
              ) {
            if (!mounted ||
                navigatingToLogin) {
              timer.cancel();

              return;
            }

            if (blockSecondsRemaining <= 1) {
              timer.cancel();

              setState(() {
                blockSecondsRemaining =
                0;

                viewState =
                    _ForgotPasswordViewState
                        .enterEmail;
              });

              return;
            }

            setState(() {
              blockSecondsRemaining--;
            });
          },
        );
  }

  // ============================================================
  // MASK EMAIL
  //
  // Example:
  //
  // angsimyi36@gmail.com
  // ->
  // ang******@gmail.com
  // ============================================================

  String maskEmail(
      String email,
      ) {
    final List<String> parts =
    email.split(
      '@',
    );

    if (parts.length != 2) {
      return email;
    }

    final String username =
        parts.first;

    final String domain =
        parts.last;

    if (username.isEmpty) {
      return '***@$domain';
    }

    if (username.length == 1) {
      return '${username[0]}***@$domain';
    }

    final int visibleCharacters =
    username.length >= 5
        ? 3
        : 2;

    final String visible =
    username.substring(
      0,
      visibleCharacters,
    );

    return '$visible******@$domain';
  }

  // ============================================================
  // FORMAT MM:SS
  // ============================================================

  String formatDuration(
      int totalSeconds,
      ) {
    final int safeSeconds =
    totalSeconds < 0
        ? 0
        : totalSeconds;

    final int minutes =
        safeSeconds ~/ 60;

    final int seconds =
        safeSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // USE DIFFERENT EMAIL
  //
  // This does NOT leave Forgot Password.
  //
  // It simply returns from Check Email to the email-entry state.
  // ============================================================

  void editEmail() {
    if (loading ||
        navigatingToLogin) {
      return;
    }

    resendTimer?.cancel();

    setState(() {
      viewState =
          _ForgotPasswordViewState
              .enterEmail;

      resendSecondsRemaining =
      0;
    });
  }

  // ============================================================
  // GO DIRECTLY TO LOGIN
  //
  // Used from:
  //
  // - top-left Back arrow
  // - "Back to Login"
  // - Check Email
  // - Temporarily Blocked screen
  // - Android system Back
  //
  // IMPORTANT:
  //
  // We intentionally do NOT use Navigator.pop().
  //
  // The previous route may be:
  //
  // - Welcome
  // - another recovery route
  // - Check Email state
  //
  // Therefore LoginScreen is explicitly used as the destination.
  //
  // pushReplacement is used instead of pushAndRemoveUntil to
  // avoid temporarily creating an empty Navigator history.
  // ============================================================

  void goBack() {
    if (loading ||
        navigatingToLogin) {
      return;
    }

    navigatingToLogin =
    true;

    // ==========================================================
    // STOP ALL FORGOT-PASSWORD TIMERS
    // ==========================================================

    resendTimer?.cancel();

    blockTimer?.cancel();

    resendTimer =
    null;

    blockTimer =
    null;

    // ==========================================================
    // NAVIGATE ON NEXT FRAME
    //
    // This avoids navigation conflicts if this method was
    // triggered by Android's system Back callback.
    // ==========================================================

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        if (!mounted) {
          return;
        }

        Navigator.of(context)
            .pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
            const LoginScreen(),
          ),
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
        SnackBarBehavior.floating,

        content:
        Text(
          message,
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

    blockTimer?.cancel();

    emailController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return PopScope(
      // ========================================================
      // ANDROID SYSTEM BACK
      //
      // Prevent Flutter from automatically popping the current
      // recovery route.
      //
      // SmartCity handles the event and explicitly opens Login.
      // ========================================================

      canPop:
      false,

      onPopInvokedWithResult: (
          bool didPop,
          Object? result,
          ) {
        if (didPop) {
          return;
        }

        goBack();
      },

      child:
      Scaffold(
        backgroundColor:
        AppColors.background,

        body:
        SafeArea(
          child:
          AnimatedSwitcher(
            duration:
            const Duration(
              milliseconds:
              220,
            ),

            child:
            switch (viewState) {
              _ForgotPasswordViewState
                  .enterEmail =>
                  _buildEnterEmail(),

              _ForgotPasswordViewState
                  .emailSent =>
                  _buildCheckEmail(),

              _ForgotPasswordViewState
                  .temporarilyBlocked =>
                  _buildBlocked(),
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ENTER EMAIL VIEW
  // ============================================================

  Widget _buildEnterEmail() {
    return SingleChildScrollView(
      key:
      const ValueKey<String>(
        'enter-email',
      ),

      padding:
      const EdgeInsets.all(
        26,
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // =====================================================
          // BACK TO LOGIN
          // =====================================================

          IconButton(
            tooltip:
            'Back to Login',

            onPressed:
            loading ||
                navigatingToLogin
                ? null
                : goBack,

            icon:
            const Icon(
              Icons.arrow_back_rounded,
            ),
          ),

          const SizedBox(
            height:
            40,
          ),

          // =====================================================
          // ICON
          // =====================================================

          Container(
            width:
            64,

            height:
            64,

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
                16,
              ),

              border:
              Border.all(
                color:
                AppColors.primaryDark,
              ),
            ),

            child:
            const Icon(
              Icons.email_outlined,

              size:
              32,

              color:
              AppColors.primary,
            ),
          ),

          const SizedBox(
            height:
            26,
          ),

          // =====================================================
          // TITLE
          // =====================================================

          const Text(
            'Forgot Password',

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
            10,
          ),

          const Text(
            'Enter your email address and we will send '
                'password recovery instructions if an account exists.',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              14,

              height:
              1.45,
            ),
          ),

          const SizedBox(
            height:
            30,
          ),

          // =====================================================
          // SECURITY INFORMATION
          // =====================================================

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

              border:
              Border.all(
                color:
                AppColors.border,
              ),
            ),

            child:
            const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.security_outlined,

                  color:
                  AppColors.primary,

                  size:
                  20,
                ),

                SizedBox(
                  width:
                  10,
                ),

                Expanded(
                  child:
                  Text(
                    'For security, recovery links are temporary '
                        'and repeated requests may be restricted.',

                    style:
                    TextStyle(
                      color:
                      AppColors
                          .textSecondary,

                      fontSize:
                      12,

                      height:
                      1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            30,
          ),

          // =====================================================
          // EMAIL LABEL
          // =====================================================

          const Text(
            'EMAIL ADDRESS',

            style:
            TextStyle(
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
          ),

          const SizedBox(
            height:
            8,
          ),

          // =====================================================
          // EMAIL FIELD
          // =====================================================

          TextField(
            controller:
            emailController,

            enabled:
            !loading &&
                !navigatingToLogin,

            keyboardType:
            TextInputType
                .emailAddress,

            textInputAction:
            TextInputAction.done,

            autofillHints:
            const [
              AutofillHints.email,
            ],

            onSubmitted:
                (_) {
              if (!loading &&
                  !navigatingToLogin) {
                sendReset();
              }
            },

            decoration:
            InputDecoration(
              hintText:
              'your@email.com',

              prefixIcon:
              const Icon(
                Icons.email_outlined,

                color:
                AppColors
                    .textSecondary,

                size:
                19,
              ),

              filled:
              true,

              fillColor:
              AppColors.surface,

              contentPadding:
              const EdgeInsets
                  .symmetric(
                horizontal:
                14,

                vertical:
                16,
              ),

              enabledBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius
                    .circular(
                  14,
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
                BorderRadius
                    .circular(
                  14,
                ),

                borderSide:
                const BorderSide(
                  color:
                  AppColors.primary,

                  width:
                  1.4,
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
            24,
          ),

          // =====================================================
          // SEND RESET LINK
          // =====================================================

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
              loading ||
                  navigatingToLogin
                  ? null
                  : () {
                sendReset();
              },

              icon:
              loading
                  ? const SizedBox(
                width:
                20,

                height:
                20,

                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2.5,

                  color:
                  Colors.white,
                ),
              )
                  : const Icon(
                Icons.send_outlined,
              ),

              label:
              Text(
                loading
                    ? 'Sending...'
                    : 'Send Reset Link',

                style:
                const TextStyle(
                  fontSize:
                  15,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
            18,
          ),

          // =====================================================
          // BACK TO LOGIN
          // =====================================================

          Center(
            child:
            TextButton.icon(
              onPressed:
              loading ||
                  navigatingToLogin
                  ? null
                  : goBack,

              icon:
              const Icon(
                Icons.arrow_back_rounded,

                size:
                16,
              ),

              label:
              const Text(
                'Back to Login',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHECK EMAIL VIEW
  // ============================================================

  Widget _buildCheckEmail() {
    return SingleChildScrollView(
      key:
      const ValueKey<String>(
        'check-email',
      ),

      padding:
      const EdgeInsets.all(
        26,
      ),

      child:
      Column(
        children: [
          const SizedBox(
            height:
            55,
          ),

          // =====================================================
          // SUCCESS ICON
          // =====================================================

          Container(
            width:
            84,

            height:
            84,

            alignment:
            Alignment.center,

            decoration:
            BoxDecoration(
              color:
              AppColors.primary
                  .withOpacity(
                0.10,
              ),

              shape:
              BoxShape.circle,

              border:
              Border.all(
                color:
                AppColors.primaryDark,
              ),
            ),

            child:
            const Icon(
              Icons.mark_email_read_outlined,

              size:
              40,

              color:
              AppColors.primary,
            ),
          ),

          const SizedBox(
            height:
            26,
          ),

          const Text(
            'Check Your Email',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              fontSize:
              28,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            12,
          ),

          const Text(
            'If a SmartCity account exists for this email, '
                'password recovery instructions have been sent to:',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              14,

              height:
              1.45,
            ),
          ),

          const SizedBox(
            height:
            16,
          ),

          // =====================================================
          // MASKED EMAIL
          // =====================================================

          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal:
              18,

              vertical:
              12,
            ),

            decoration:
            BoxDecoration(
              color:
              AppColors.surface,

              borderRadius:
              BorderRadius.circular(
                14,
              ),

              border:
              Border.all(
                color:
                AppColors.border,
              ),
            ),

            child:
            Row(
              mainAxisSize:
              MainAxisSize.min,

              children: [
                const Icon(
                  Icons.email_outlined,

                  size:
                  18,

                  color:
                  AppColors.primary,
                ),

                const SizedBox(
                  width:
                  8,
                ),

                Flexible(
                  child:
                  Text(
                    maskEmail(
                      submittedEmail,
                    ),

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w600,

                      fontSize:
                      13,
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

          // =====================================================
          // RECOVERY LINK INFORMATION
          // =====================================================

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
              Colors.amber
                  .withOpacity(
                0.07,
              ),

              borderRadius:
              BorderRadius.circular(
                14,
              ),

              border:
              Border.all(
                color:
                Colors.amber
                    .withOpacity(
                  0.35,
                ),
              ),
            ),

            child:
            const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.schedule_outlined,

                  color:
                  Colors.amber,

                  size:
                  21,
                ),

                SizedBox(
                  width:
                  10,
                ),

                Expanded(
                  child:
                  Text(
                    'For your security, the recovery link is temporary. '
                        'Open the newest reset email promptly and complete '
                        'password recovery in SmartCity.',

                    style:
                    TextStyle(
                      color:
                      AppColors
                          .textSecondary,

                      fontSize:
                      12,

                      height:
                      1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            28,
          ),

          // =====================================================
          // INSTRUCTIONS
          // =====================================================

          const _RecoveryStep(
            number:
            '1',

            text:
            'Open the newest SmartCity password reset email.',
          ),

          const SizedBox(
            height:
            12,
          ),

          const _RecoveryStep(
            number:
            '2',

            text:
            'Tap the Reset Password link.',
          ),

          const SizedBox(
            height:
            12,
          ),

          const _RecoveryStep(
            number:
            '3',

            text:
            'SmartCity will open and ask you to create a new password.',
          ),

          const SizedBox(
            height:
            30,
          ),

          // =====================================================
          // RESEND
          // =====================================================

          const Text(
            'Didn\'t receive the email?',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              13,
            ),
          ),

          const SizedBox(
            height:
            10,
          ),

          if (resendSecondsRemaining >
              0)
            Row(
              mainAxisAlignment:
              MainAxisAlignment.center,

              children: [
                const Icon(
                  Icons
                      .hourglass_bottom_rounded,

                  size:
                  17,

                  color:
                  AppColors
                      .textSecondary,
                ),

                const SizedBox(
                  width:
                  7,
                ),

                Text(
                  'Resend available in '
                      '${formatDuration(resendSecondsRemaining)}',

                  style:
                  const TextStyle(
                    color:
                    AppColors
                        .textSecondary,

                    fontSize:
                    13,

                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width:
              double.infinity,

              height:
              50,

              child:
              OutlinedButton.icon(
                onPressed:
                loading ||
                    navigatingToLogin
                    ? null
                    : () {
                  sendReset(
                    resend:
                    true,
                  );
                },

                style:
                OutlinedButton
                    .styleFrom(
                  foregroundColor:
                  AppColors.primary,

                  side:
                  const BorderSide(
                    color:
                    AppColors.primary,
                  ),

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      13,
                    ),
                  ),
                ),

                icon:
                loading
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
                    AppColors
                        .primary,
                  ),
                )
                    : const Icon(
                  Icons.refresh,
                ),

                label:
                Text(
                  loading
                      ? 'Sending...'
                      : 'Resend Reset Link',
                ),
              ),
            ),

          const SizedBox(
            height:
            20,
          ),

          // =====================================================
          // USE DIFFERENT EMAIL
          // =====================================================

          TextButton.icon(
            onPressed:
            loading ||
                navigatingToLogin
                ? null
                : editEmail,

            icon:
            const Icon(
              Icons.edit_outlined,

              size:
              17,
            ),

            label:
            const Text(
              'Use a different email',
            ),
          ),

          const SizedBox(
            height:
            6,
          ),

          // =====================================================
          // BACK TO LOGIN
          // =====================================================

          TextButton.icon(
            onPressed:
            loading ||
                navigatingToLogin
                ? null
                : goBack,

            icon:
            const Icon(
              Icons.arrow_back_rounded,

              size:
              16,
            ),

            label:
            const Text(
              'Back to Login',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEMPORARILY BLOCKED VIEW
  // ============================================================

  Widget _buildBlocked() {
    return SingleChildScrollView(
      key:
      const ValueKey<String>(
        'blocked',
      ),

      padding:
      const EdgeInsets.all(
        26,
      ),

      child:
      Column(
        children: [
          const SizedBox(
            height:
            65,
          ),

          // =====================================================
          // BLOCK ICON
          // =====================================================

          Container(
            width:
            84,

            height:
            84,

            alignment:
            Alignment.center,

            decoration:
            BoxDecoration(
              color:
              Colors.red
                  .withOpacity(
                0.09,
              ),

              shape:
              BoxShape.circle,

              border:
              Border.all(
                color:
                Colors.red
                    .withOpacity(
                  0.60,
                ),
              ),
            ),

            child:
            const Icon(
              Icons
                  .security_update_warning_outlined,

              size:
              40,

              color:
              Colors.red,
            ),
          ),

          const SizedBox(
            height:
            26,
          ),

          const Text(
            'Too Many Reset Requests',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              fontSize:
              26,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            12,
          ),

          const Text(
            'Password recovery has been temporarily restricted '
                'because multiple reset requests were detected.',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              14,

              height:
              1.5,
            ),
          ),

          const SizedBox(
            height:
            28,
          ),

          // =====================================================
          // COUNTDOWN
          // =====================================================

          Container(
            width:
            double.infinity,

            padding:
            const EdgeInsets.all(
              20,
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
                AppColors.border,
              ),
            ),

            child:
            Column(
              children: [
                const Text(
                  'TRY AGAIN IN',

                  style:
                  TextStyle(
                    color:
                    AppColors
                        .textSecondary,

                    fontSize:
                    11,

                    fontWeight:
                    FontWeight.w600,

                    letterSpacing:
                    0.6,
                  ),
                ),

                const SizedBox(
                  height:
                  10,
                ),

                Text(
                  formatDuration(
                    blockSecondsRemaining,
                  ),

                  style:
                  const TextStyle(
                    color:
                    Colors.red,

                    fontSize:
                    34,

                    fontWeight:
                    FontWeight.bold,

                    letterSpacing:
                    1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            22,
          ),

          // =====================================================
          // SECURITY INFORMATION
          // =====================================================

          const Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.shield_outlined,

                color:
                AppColors.primary,

                size:
                19,
              ),

              SizedBox(
                width:
                9,
              ),

              Expanded(
                child:
                Text(
                  'This temporary restriction protects your account '
                      'from automated or repeated password-reset abuse. '
                      'Your account itself has not been disabled.',

                  style:
                  TextStyle(
                    color:
                    AppColors
                        .textSecondary,

                    fontSize:
                    12,

                    height:
                    1.45,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            32,
          ),

          // =====================================================
          // BACK TO LOGIN
          // =====================================================

          SizedBox(
            width:
            double.infinity,

            height:
            52,

            child:
            ElevatedButton.icon(
              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                AppColors.primaryDark,

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
              loading ||
                  navigatingToLogin
                  ? null
                  : goBack,

              icon:
              const Icon(
                Icons.arrow_back_rounded,
              ),

              label:
              const Text(
                'Back to Login',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// RECOVERY STEP
// ================================================================

class _RecoveryStep
    extends StatelessWidget {
  final String number;

  final String text;

  const _RecoveryStep({
    required this.number,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Container(
          width:
          27,

          height:
          27,

          alignment:
          Alignment.center,

          decoration:
          BoxDecoration(
            color:
            AppColors.primary
                .withOpacity(
              0.10,
            ),

            shape:
            BoxShape.circle,

            border:
            Border.all(
              color:
              AppColors.primaryDark,
            ),
          ),

          child:
          Text(
            number,

            style:
            const TextStyle(
              color:
              AppColors.primary,

              fontSize:
              12,

              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(
          width:
          11,
        ),

        Expanded(
          child:
          Padding(
            padding:
            const EdgeInsets.only(
              top:
              4,
            ),

            child:
            Text(
              text,

              style:
              const TextStyle(
                color:
                AppColors
                    .textSecondary,

                fontSize:
                12,

                height:
                1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}