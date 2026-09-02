import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import 'login_screen.dart';

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
  final GlobalKey<FormState> formKey =
  GlobalKey<FormState>();

  final TextEditingController
  newPasswordController =
  TextEditingController();

  final TextEditingController
  confirmPasswordController =
  TextEditingController();

  bool loading = false;

  bool hideNewPassword = true;

  bool hideConfirmPassword = true;

  // ============================================================
  // PASSWORD VALIDATION
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

    if (!(formKey.currentState
        ?.validate() ??
        false)) {
      return;
    }

    final String newPassword =
        newPasswordController.text;

    final String confirmPassword =
        confirmPasswordController.text;

    if (newPassword !=
        confirmPassword) {
      showMessage(
        'Passwords do not match.',
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // ========================================================
      // UPDATE SUPABASE PASSWORD
      //
      // The recovery email establishes a temporary recovery
      // session. Because that session is already active here,
      // updateUser() can save the new password.
      // ========================================================

      final UserResponse response =
      await Supabase
          .instance
          .client
          .auth
          .updateUser(
        UserAttributes(
          password:
          newPassword,
        ),
      );

      if (response.user == null) {
        throw Exception(
          'Unable to update password.',
        );
      }

      // ========================================================
      // PASSWORD MANAGER
      //
      // SmartCity does NOT store the raw password in
      // SharedPreferences.
      //
      // This lets Android/iOS password managers offer to save
      // or update the credential securely.
      // ========================================================

      TextInput.finishAutofillContext(
        shouldSave: true,
      );

      // ========================================================
      // CLEAR INPUTS
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

            title:
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color:
                  AppColors.success,
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
                  'You can now sign in using your new password.',
            ),

            actions: [
              ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  AppColors.primaryDark,
                ),

                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },

                child:
                const Text(
                  'Continue',
                ),
              ),
            ],
          );
        },
      );

      // ========================================================
      // SIGN OUT RECOVERY SESSION
      //
      // After password reset, end the temporary recovery
      // session so the user returns to a normal login state.
      // ========================================================

      try {
        await Supabase
            .instance
            .client
            .auth
            .signOut();
      } catch (_) {
        // Navigation should still continue even if local
        // recovery-session cleanup fails.
      }

      widget.onFinished
          ?.call();

      if (!mounted) {
        return;
      }

      // ========================================================
      // RETURN TO LOGIN
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

      showMessage(
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

      showMessage(
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
      canPop:
      false,

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
                  CrossAxisAlignment.start,

                  children: [
                    const SizedBox(
                      height:
                      30,
                    ),

                    // =================================================
                    // ICON
                    // =================================================

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
                        Icons.lock_reset_outlined,

                        color:
                        AppColors.primary,

                        size:
                        34,
                      ),
                    ),

                    const SizedBox(
                      height:
                      26,
                    ),

                    // =================================================
                    // TITLE
                    // =================================================

                    const Text(
                      'Reset Password',

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
                      'Create a new password for your SmartCity account.',

                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,

                        fontSize:
                        14,

                        height:
                        1.4,
                      ),
                    ),

                    const SizedBox(
                      height:
                      34,
                    ),

                    // =================================================
                    // SECURITY NOTE
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
                            Icons.shield_outlined,

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
                              'Use at least 8 characters with uppercase, lowercase, number, and special character.',

                              style:
                              TextStyle(
                                color:
                                AppColors.textSecondary,

                                fontSize:
                                10,

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
                      25,
                    ),

                    // =================================================
                    // NEW PASSWORD
                    // =================================================

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
                      TextInputAction.next,

                      autofillHints:
                      const [
                        AutofillHints.newPassword,
                      ],

                      decoration:
                      _inputDecoration(
                        hint:
                        'Enter new password',

                        prefixIcon:
                        Icons.lock_outline,

                        suffix:
                        IconButton(
                          onPressed: () {
                            setState(() {
                              hideNewPassword =
                              !hideNewPassword;
                            });
                          },

                          icon:
                          Icon(
                            hideNewPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,

                            color:
                            AppColors.textSecondary,
                          ),
                        ),
                      ),

                      validator:
                      validatePassword,
                    ),

                    const SizedBox(
                      height:
                      18,
                    ),

                    // =================================================
                    // CONFIRM PASSWORD
                    // =================================================

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
                      TextInputAction.done,

                      autofillHints:
                      const [
                        AutofillHints.newPassword,
                      ],

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
                        Icons.lock_reset_outlined,

                        suffix:
                        IconButton(
                          onPressed: () {
                            setState(() {
                              hideConfirmPassword =
                              !hideConfirmPassword;
                            });
                          },

                          icon:
                          Icon(
                            hideConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,

                            color:
                            AppColors.textSecondary,
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
                            newPasswordController.text) {
                          return 'Passwords do not match.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height:
                      26,
                    ),

                    // =================================================
                    // UPDATE PASSWORD
                    // =================================================

                    SizedBox(
                      width:
                      double.infinity,

                      height:
                      56,

                      child:
                      ElevatedButton.icon(
                        style:
                        ElevatedButton.styleFrom(
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
                          Icons.lock_reset,
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
                            FontWeight.bold,
                          ),
                        ),
                      ),
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