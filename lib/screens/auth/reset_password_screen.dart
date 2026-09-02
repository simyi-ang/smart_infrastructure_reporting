import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

// ================================================================
// RESET PASSWORD SCREEN
//
// Used after Supabase verifies a password-recovery email link.
//
// Flow:
//
// Recovery email
//      ↓
// Supabase verifies recovery token
//      ↓
// SmartCity deep link
//      ↓
// ResetPasswordScreen
//      ↓
// Validate new password
//      ↓
// Update Supabase password
//      ↓
// End recovery session
//      ↓
// Return to Login
// ================================================================

class ResetPasswordScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const ResetPasswordScreen({
    super.key,
    this.onFinished,
  });

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> formKey =
  GlobalKey<FormState>();

  final TextEditingController newPasswordController =
  TextEditingController();

  final TextEditingController confirmPasswordController =
  TextEditingController();

  final AuthService authService =
  AuthService();

  bool loading = false;

  bool hideNewPassword = true;

  bool hideConfirmPassword = true;

  // ============================================================
  // PASSWORD REQUIREMENTS
  // ============================================================

  bool get hasMinimumLength =>
      newPasswordController.text.length >= 8;

  bool get hasRecommendedLength =>
      newPasswordController.text.length >= 12;

  bool get hasUppercase =>
      RegExp(
        r'[A-Z]',
      ).hasMatch(
        newPasswordController.text,
      );

  bool get hasLowercase =>
      RegExp(
        r'[a-z]',
      ).hasMatch(
        newPasswordController.text,
      );

  bool get hasNumber =>
      RegExp(
        r'[0-9]',
      ).hasMatch(
        newPasswordController.text,
      );

  bool get hasSpecialCharacter =>
      RegExp(
        r'[!@#$%^&*(),.?":{}|<>]',
      ).hasMatch(
        newPasswordController.text,
      );

  // ============================================================
  // ALL REQUIRED RULES SATISFIED
  // ============================================================

  bool get passwordRequirementsSatisfied =>
      hasMinimumLength &&
          hasUppercase &&
          hasLowercase &&
          hasNumber &&
          hasSpecialCharacter;

  // ============================================================
  // PASSWORD STRENGTH SCORE
  //
  // This is a USER-FACING strength indicator.
  //
  // 0      = Empty
  // 1 - 2  = Weak
  // 3 - 4  = Medium
  // 5+     = Strong
  //
  // The actual password acceptance rules are still enforced
  // separately by validatePassword().
  // ============================================================

  int get passwordStrengthScore {
    final String password =
        newPasswordController.text;

    if (password.isEmpty) {
      return 0;
    }

    int score = 0;

    if (password.length >= 8) {
      score++;
    }

    if (hasUppercase &&
        hasLowercase) {
      score++;
    }

    if (hasNumber) {
      score++;
    }

    if (hasSpecialCharacter) {
      score++;
    }

    if (password.length >= 12) {
      score++;
    }

    return score;
  }

  // ============================================================
  // PASSWORD STRENGTH LABEL
  // ============================================================

  String get passwordStrengthLabel {
    final int score =
        passwordStrengthScore;

    if (score == 0) {
      return 'Not entered';
    }

    if (score <= 2) {
      return 'Weak';
    }

    if (score <= 4) {
      return 'Medium';
    }

    return 'Strong';
  }

  // ============================================================
  // PASSWORD STRENGTH COLOR
  //
  // Weak   = Red
  // Medium = Yellow / Amber
  // Strong = Green
  // ============================================================

  Color get passwordStrengthColor {
    final int score =
        passwordStrengthScore;

    if (score == 0) {
      return AppColors.textSecondary;
    }

    if (score <= 2) {
      return Colors.red;
    }

    if (score <= 4) {
      return Colors.amber;
    }

    return Colors.green;
  }

  // ============================================================
  // PASSWORD STRENGTH PROGRESS
  // ============================================================

  double get passwordStrengthProgress {
    final int score =
        passwordStrengthScore;

    if (score == 0) {
      return 0.0;
    }

    return score / 5;
  }

  // ============================================================
  // CONFIRM PASSWORD STATUS
  // ============================================================

  bool get passwordsMatch =>
      confirmPasswordController
          .text
          .isNotEmpty &&
          confirmPasswordController.text ==
              newPasswordController.text;

  // ============================================================
  // PASSWORD VALIDATION
  //
  // These are the mandatory password rules.
  // ============================================================

  String? validatePassword(
      String? value,
      ) {
    final String password =
        value ?? '';

    if (password.isEmpty) {
      return 'Password is required.';
    }

    if (password.length < 8) {
      return 'Use at least 8 characters.';
    }

    if (!RegExp(
      r'[A-Z]',
    ).hasMatch(password)) {
      return 'Add at least one uppercase letter.';
    }

    if (!RegExp(
      r'[a-z]',
    ).hasMatch(password)) {
      return 'Add at least one lowercase letter.';
    }

    if (!RegExp(
      r'[0-9]',
    ).hasMatch(password)) {
      return 'Add at least one number.';
    }

    if (!RegExp(
      r'[!@#$%^&*(),.?":{}|<>]',
    ).hasMatch(password)) {
      return 'Add at least one special character.';
    }

    return null;
  }

  // ============================================================
  // UPDATE PASSWORD
  // ============================================================

  Future<void> updatePassword() async {
    if (loading) {
      return;
    }

    // ==========================================================
    // VALIDATE FORM
    // ==========================================================

    if (!(formKey.currentState
        ?.validate() ??
        false)) {
      return;
    }

    final String newPassword =
        newPasswordController.text;

    final String confirmPassword =
        confirmPasswordController.text;

    // ==========================================================
    // PASSWORD CONFIRMATION
    // ==========================================================

    if (newPassword !=
        confirmPassword) {
      showMessage(
        'Passwords do not match.',
      );

      return;
    }

    // ==========================================================
    // REQUIRED PASSWORD RULES
    // ==========================================================

    if (!passwordRequirementsSatisfied) {
      showMessage(
        'Please complete all password requirements.',
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // ========================================================
      // UPDATE PASSWORD THROUGH AUTH SERVICE
      //
      // AuthService verifies the recovery session, updates the
      // Supabase password and records PASSWORD_CHANGED.
      // ========================================================

      final UserResponse response =
      await authService
          .updateRecoveredPassword(
        newPassword:
        newPassword,
      );

      if (response.user == null) {
        throw Exception(
          'Unable to update password.',
        );
      }

      // ========================================================
      // PASSWORD MANAGER
      //
      // SmartCity never stores the raw password in
      // SharedPreferences.
      //
      // Android/iOS password managers may offer to securely
      // save/update the new credential.
      // ========================================================

      TextInput.finishAutofillContext(
        shouldSave: true,
      );

      // ========================================================
      // CLEAR PASSWORD FIELDS
      // ========================================================

      newPasswordController.clear();

      confirmPasswordController.clear();

      if (!mounted) {
        return;
      }

      // ========================================================
      // SUCCESS DIALOG
      // ========================================================

      await showDialog<void>(
        context:
        context,

        barrierDismissible:
        false,

        builder:
            (dialogContext) {
          return AlertDialog(
            backgroundColor:
            AppColors.surface,

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                18,
              ),
            ),

            title:
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,

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
                    'Password Updated',
                  ),
                ),
              ],
            ),

            content:
            const Text(
              'Your SmartCity password has been changed successfully. '
                  'For security, your recovery session will now end. '
                  'Sign in again using your new password.',
            ),

            actions: [
              ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  AppColors.primaryDark,

                  foregroundColor:
                  Colors.white,
                ),

                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },

                child:
                const Text(
                  'Continue to Login',
                ),
              ),
            ],
          );
        },
      );

      // ========================================================
      // END TEMPORARY RECOVERY SESSION
      // ========================================================

      try {
        await authService
            .endRecoverySession();
      } catch (_) {
        // Navigation must still continue even if local
        // recovery-session cleanup encounters a problem.
      }

      // ========================================================
      // CLEAR MAIN RECOVERY COORDINATOR
      // ========================================================

      widget.onFinished
          ?.call();

      if (!mounted) {
        return;
      }

      // ========================================================
      // RETURN TO LOGIN
      //
      // All previous recovery routes are removed.
      // ========================================================

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
          const LoginScreen(),
        ),
            (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      _handleRecoveryError(
        e.message,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      _handleRecoveryError(
        message.trim().isEmpty
            ? 'Unable to update password.'
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
// BACK TO LOGIN FROM PASSWORD RECOVERY
//
// Used when the user presses:
//
// - the top-left Back button
// - Android system Back
//
// IMPORTANT:
//
// ResetPasswordScreen was already opened by the recovery
// coordinator using route replacement / route clearing.
//
// Therefore we DO NOT use pushAndRemoveUntil here.
//
// Using pushReplacement avoids temporarily emptying the
// Navigator history, which can cause:
//
// Navigator assertion:
// '_history.isNotEmpty': is not true
//
// Flow:
//
// ResetPasswordScreen
//      ↓
// Clear recovery coordinator state
//      ↓
// End Supabase recovery session
//      ↓
// Replace current screen with LoginScreen
// ============================================================

  Future<void> backToLogin() async {
    if (loading) {
      return;
    }

    setState(() {
      loading = true;
    });

    // ==========================================================
    // CLEAR RECOVERY COORDINATOR FIRST
    //
    // Prevent main.dart from trying to reopen the
    // ResetPasswordScreen after sign-out.
    // ==========================================================

    widget.onFinished?.call();

    // ==========================================================
    // END TEMPORARY RECOVERY SESSION
    // ==========================================================

    try {
      await authService.endRecoverySession();
    } catch (e) {
      // Recovery-session cleanup failure must not trap the user
      // inside the Reset Password screen.
      debugPrint(
        'Recovery session cleanup failed: $e',
      );
    }

    if (!mounted) {
      return;
    }

    // ==========================================================
    // REPLACE RESET PASSWORD WITH LOGIN
    //
    // Do NOT use:
    //
    // pushAndRemoveUntil(... false)
    //
    // here because ResetPasswordScreen is already effectively
    // the root recovery route.
    // ==========================================================

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
        const LoginScreen(),
      ),
    );
  }

  // ============================================================
  // RECOVERY ERROR HANDLER
  // ============================================================

  void _handleRecoveryError(
      String message,
      ) {
    final String normalized =
    message.toLowerCase();

    if (normalized.contains(
      'expired',
    ) ||
        normalized.contains(
          'invalid',
        ) ||
        normalized.contains(
          'session',
        ) ||
        normalized.contains(
          'otp_expired',
        )) {
      showMessage(
        'This password reset session has expired or is no longer valid. '
            'Please request a new password reset link.',
      );

      return;
    }

    showMessage(
      message,
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
    newPasswordController.dispose();

    confirmPasswordController.dispose();

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
      // ==========================================================
      // ANDROID SYSTEM BACK
      //
      // Prevent Flutter from popping the recovery route itself.
      // SmartCity handles the Back action manually and safely
      // redirects to LoginScreen.
      // ==========================================================

      canPop: false,

      onPopInvokedWithResult: (
          bool didPop,
          Object? result,
          ) {
        if (didPop) {
          return;
        }

        if (!loading) {
          backToLogin();
        }
      },

      child:
      Scaffold(
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
            AutofillGroup(
              child:
              Form(
                key:
                formKey,

                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    // ===========================================
                    // BACK TO LOGIN
                    // ===========================================

                    Align(
                      alignment:
                      Alignment.centerLeft,

                      child:
                      IconButton(
                        tooltip:
                        'Back to Login',

                        onPressed:
                        loading
                            ? null
                            : () {
                          backToLogin();
                        },

                        icon:
                        const Icon(
                          Icons.arrow_back_rounded,

                          color:
                          Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      18,
                    ),

                    // ===========================================
                    // ICON
                    // ===========================================

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
                        AppColors
                            .primary
                            .withOpacity(
                          0.10,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          16,
                        ),

                        border:
                        Border.all(
                          color:
                          AppColors
                              .primaryDark,
                        ),
                      ),

                      child:
                      const Icon(
                        Icons
                            .lock_reset_outlined,

                        color:
                        AppColors
                            .primary,

                        size:
                        34,
                      ),
                    ),

                    const SizedBox(
                      height:
                      26,
                    ),

                    // ===========================================
                    // TITLE
                    // ===========================================

                    const Text(
                      'Reset Password',

                      style:
                      TextStyle(
                        fontSize:
                        29,

                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      10,
                    ),

                    const Text(
                      'Create a secure new password for your SmartCity account.',

                      style:
                      TextStyle(
                        color:
                        AppColors
                            .textSecondary,

                        fontSize:
                        14,

                        height:
                        1.4,
                      ),
                    ),

                    const SizedBox(
                      height:
                      28,
                    ),

                    // ===========================================
                    // SECURITY INFORMATION
                    // ===========================================

                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets
                          .all(
                        14,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        AppColors
                            .primary
                            .withOpacity(
                          0.06,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          13,
                        ),

                        border:
                        Border.all(
                          color:
                          AppColors
                              .border,
                        ),
                      ),

                      child:
                      const Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [
                          Icon(
                            Icons
                                .shield_outlined,

                            color:
                            AppColors
                                .primary,

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
                              'Your new password must contain at least '
                                  '8 characters, including uppercase, lowercase, '
                                  'a number and a special character.',

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
                      25,
                    ),

                    // ===========================================
                    // NEW PASSWORD
                    // ===========================================

                    const _FieldLabel(
                      'NEW PASSWORD',
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    TextFormField(
                      controller:
                      newPasswordController,

                      enabled:
                      !loading,

                      obscureText:
                      hideNewPassword,

                      textInputAction:
                      TextInputAction
                          .next,

                      autofillHints:
                      const [
                        AutofillHints
                            .newPassword,
                      ],

                      // =========================================
                      // LIVE STRENGTH UPDATE
                      // =========================================

                      onChanged: (_) {
                        setState(() {});
                      },

                      decoration:
                      _inputDecoration(
                        hint:
                        'Enter new password',

                        prefixIcon:
                        Icons
                            .lock_outline,

                        suffix:
                        IconButton(
                          tooltip:
                          hideNewPassword
                              ? 'Show password'
                              : 'Hide password',

                          onPressed:
                          loading
                              ? null
                              : () {
                            setState(
                                  () {
                                hideNewPassword =
                                !hideNewPassword;
                              },
                            );
                          },

                          icon:
                          Icon(
                            hideNewPassword
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
                      validatePassword,
                    ),

                    const SizedBox(
                      height:
                      14,
                    ),

                    // ===========================================
                    // PASSWORD STRENGTH
                    // ===========================================

                    Row(
                      children: [
                        const Text(
                          'Password strength',

                          style:
                          TextStyle(
                            color:
                            AppColors
                                .textSecondary,

                            fontSize:
                            12,

                            fontWeight:
                            FontWeight
                                .w500,
                          ),
                        ),

                        const Spacer(),

                        AnimatedSwitcher(
                          duration:
                          const Duration(
                            milliseconds:
                            180,
                          ),

                          child:
                          Text(
                            passwordStrengthLabel,

                            key:
                            ValueKey<String>(
                              passwordStrengthLabel,
                            ),

                            style:
                            TextStyle(
                              color:
                              passwordStrengthColor,

                              fontSize:
                              12,

                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    // ===========================================
                    // RED / YELLOW / GREEN BAR
                    // ===========================================

                    ClipRRect(
                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),

                      child:
                      LinearProgressIndicator(
                        value:
                        passwordStrengthProgress,

                        minHeight:
                        8,

                        backgroundColor:
                        AppColors.border,

                        valueColor:
                        AlwaysStoppedAnimation<
                            Color>(
                          passwordStrengthColor,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      17,
                    ),

                    // ===========================================
                    // LIVE PASSWORD REQUIREMENTS
                    // ===========================================

                    _PasswordRequirement(
                      satisfied:
                      hasMinimumLength,

                      text:
                      'At least 8 characters',
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    _PasswordRequirement(
                      satisfied:
                      hasUppercase,

                      text:
                      'One uppercase letter (A-Z)',
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    _PasswordRequirement(
                      satisfied:
                      hasLowercase,

                      text:
                      'One lowercase letter (a-z)',
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    _PasswordRequirement(
                      satisfied:
                      hasNumber,

                      text:
                      'One number (0-9)',
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    _PasswordRequirement(
                      satisfied:
                      hasSpecialCharacter,

                      text:
                      'One special character (!@#\$...)',
                    ),

                    // ===========================================
                    // OPTIONAL STRONG PASSWORD RECOMMENDATION
                    // ===========================================

                    if (passwordRequirementsSatisfied &&
                        !hasRecommendedLength) ...[
                      const SizedBox(
                        height:
                        12,
                      ),

                      const Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [
                          Icon(
                            Icons
                                .info_outline,

                            size:
                            16,

                            color:
                            Colors.amber,
                          ),

                          SizedBox(
                            width:
                            7,
                          ),

                          Expanded(
                            child:
                            Text(
                              'Your password meets the required rules. '
                                  'Using 12 or more characters will make it stronger.',

                              style:
                              TextStyle(
                                color:
                                Colors.amber,

                                fontSize:
                                11,

                                height:
                                1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(
                      height:
                      27,
                    ),

                    // ===========================================
                    // CONFIRM PASSWORD
                    // ===========================================

                    const _FieldLabel(
                      'CONFIRM NEW PASSWORD',
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    TextFormField(
                      controller:
                      confirmPasswordController,

                      enabled:
                      !loading,

                      obscureText:
                      hideConfirmPassword,

                      textInputAction:
                      TextInputAction
                          .done,

                      autofillHints:
                      const [
                        AutofillHints
                            .newPassword,
                      ],

                      // =========================================
                      // LIVE MATCH STATUS
                      // =========================================

                      onChanged: (_) {
                        setState(() {});
                      },

                      onFieldSubmitted:
                          (_) {
                        if (!loading) {
                          updatePassword();
                        }
                      },

                      decoration:
                      _inputDecoration(
                        hint:
                        'Confirm new password',

                        prefixIcon:
                        Icons
                            .lock_reset_outlined,

                        suffix:
                        IconButton(
                          tooltip:
                          hideConfirmPassword
                              ? 'Show password'
                              : 'Hide password',

                          onPressed:
                          loading
                              ? null
                              : () {
                            setState(
                                  () {
                                hideConfirmPassword =
                                !hideConfirmPassword;
                              },
                            );
                          },

                          icon:
                          Icon(
                            hideConfirmPassword
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
                          return 'Please confirm your new password.';
                        }

                        if (value !=
                            newPasswordController
                                .text) {
                          return 'Passwords do not match.';
                        }

                        return null;
                      },
                    ),

                    // ===========================================
                    // LIVE PASSWORD MATCH
                    // ===========================================

                    if (confirmPasswordController
                        .text
                        .isNotEmpty) ...[
                      const SizedBox(
                        height:
                        10,
                      ),

                      AnimatedSwitcher(
                        duration:
                        const Duration(
                          milliseconds:
                          180,
                        ),

                        child:
                        Row(
                          key:
                          ValueKey<bool>(
                            passwordsMatch,
                          ),

                          children: [
                            Icon(
                              passwordsMatch
                                  ? Icons
                                  .check_circle
                                  : Icons
                                  .cancel,

                              size:
                              17,

                              color:
                              passwordsMatch
                                  ? Colors
                                  .green
                                  : Colors
                                  .red,
                            ),

                            const SizedBox(
                              width:
                              7,
                            ),

                            Text(
                              passwordsMatch
                                  ? 'Passwords match'
                                  : 'Passwords do not match',

                              style:
                              TextStyle(
                                color:
                                passwordsMatch
                                    ? Colors
                                    .green
                                    : Colors
                                    .red,

                                fontSize:
                                12,

                                fontWeight:
                                FontWeight
                                    .w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(
                      height:
                      28,
                    ),

                    // ===========================================
                    // UPDATE PASSWORD
                    // ===========================================

                    SizedBox(
                      width:
                      double.infinity,

                      height:
                      56,

                      child:
                      ElevatedButton
                          .icon(
                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          AppColors
                              .primaryDark,

                          foregroundColor:
                          Colors.white,

                          disabledBackgroundColor:
                          AppColors
                              .primaryDark
                              .withOpacity(
                            0.45,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                          ),
                        ),

                        // Keep the button enabled until submission
                        // so Form validation can explain missing
                        // requirements to the user.
                        onPressed:
                        loading
                            ? null
                            : updatePassword,

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
                          Icons
                              .lock_reset,
                        ),

                        label:
                        Text(
                          loading
                              ? 'Updating Password...'
                              : 'Update Password',

                          style:
                          const TextStyle(
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
                      16,
                    ),

                    // ===========================================
                    // SECURITY FOOTNOTE
                    // ===========================================

                    const Center(
                      child:
                      Row(
                        mainAxisSize:
                        MainAxisSize.min,

                        children: [
                          Icon(
                            Icons
                                .verified_user_outlined,

                            size:
                            14,

                            color:
                            AppColors
                                .textSecondary,
                          ),

                          SizedBox(
                            width:
                            6,
                          ),

                          Flexible(
                            child:
                            Text(
                              'SmartCity never stores your raw password.',

                              textAlign:
                              TextAlign
                                  .center,

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
                      25,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// PASSWORD REQUIREMENT
//
// Displays live password-rule feedback.
// ================================================================

class _PasswordRequirement
    extends StatelessWidget {
  final bool satisfied;

  final String text;

  const _PasswordRequirement({
    required this.satisfied,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds:
        180,
      ),

      child:
      Row(
        children: [
          Container(
            width:
            20,

            height:
            20,

            alignment:
            Alignment.center,

            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,

              color:
              satisfied
                  ? Colors.green
                  .withOpacity(
                0.12,
              )
                  : Colors
                  .transparent,

              border:
              Border.all(
                color:
                satisfied
                    ? Colors.green
                    : AppColors
                    .border,
              ),
            ),

            child:
            Icon(
              satisfied
                  ? Icons.check
                  : Icons.close,

              size:
              13,

              color:
              satisfied
                  ? Colors.green
                  : AppColors
                  .textSecondary,
            ),
          ),

          const SizedBox(
            width:
            9,
          ),

          Expanded(
            child:
            Text(
              text,

              style:
              TextStyle(
                color:
                satisfied
                    ? Colors.green
                    : AppColors
                    .textSecondary,

                fontSize:
                12,

                fontWeight:
                satisfied
                    ? FontWeight
                    .w600
                    : FontWeight
                    .normal,
              ),
            ),
          ),
        ],
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