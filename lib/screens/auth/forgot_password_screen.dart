import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final TextEditingController emailController =
  TextEditingController();

  final AuthService authService =
  AuthService();

  bool loading = false;

  // ============================================================
  // SEND PASSWORD RESET EMAIL
  // ============================================================

  Future<void> sendReset() async {
    if (loading) {
      return;
    }

    final String email =
    emailController.text
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
      // AUTH SERVICE
      //
      // AuthService.forgotPassword() will be updated so that
      // Supabase redirects the recovery link back into SmartCity:
      //
      // smartcity://reset-password
      // ========================================================

      await authService
          .forgotPassword(
        email,
      );

      if (!mounted) {
        return;
      }

      showMessage(
        'Password reset email sent. '
            'Open the email and tap Reset Password to continue in SmartCity.',
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
        message.isEmpty
            ? 'Unable to send password reset email.'
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
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              // =================================================
              // BACK
              // =================================================

              IconButton(
                onPressed:
                loading
                    ? null
                    : () {
                  Navigator.pop(
                    context,
                  );
                },

                icon:
                const Icon(
                  Icons.arrow_back,
                ),
              ),

              const SizedBox(
                height:
                40,
              ),

              // =================================================
              // ICON
              // =================================================

              const Icon(
                Icons.email_outlined,

                size:
                42,

                color:
                AppColors.primary,
              ),

              const SizedBox(
                height:
                26,
              ),

              // =================================================
              // TITLE
              // =================================================

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
                'Enter your email to receive a password reset link',

                style:
                TextStyle(
                  color:
                  AppColors
                      .textSecondary,
                ),
              ),

              const SizedBox(
                height:
                35,
              ),

              // =================================================
              // EMAIL
              // =================================================

              TextField(
                controller:
                emailController,

                enabled:
                !loading,

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
                  if (!loading) {
                    sendReset();
                  }
                },

                decoration:
                InputDecoration(
                  hintText:
                  'your@email.com',

                  filled:
                  true,

                  fillColor:
                  AppColors.surface,

                  enabledBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
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
                    BorderRadius.circular(
                      14,
                    ),

                    borderSide:
                    const BorderSide(
                      color:
                      AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                24,
              ),

              // =================================================
              // CONTINUE
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height:
                55,

                child:
                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors
                        .primaryDark,
                  ),

                  onPressed:
                  loading
                      ? null
                      : sendReset,

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
                      : const Text(
                    'Continue →',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}