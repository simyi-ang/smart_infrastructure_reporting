import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';

// ============================================================
// ACCOUNT ALREADY EXISTS SCREEN
//
// Shown when registration detects that the email address is
// already registered.
//
// This screen DOES NOT create another account.
// ============================================================

class AccountAlreadyExistsScreen
    extends StatelessWidget {
  final String email;

  const AccountAlreadyExistsScreen({
    super.key,
    required this.email,
  });

  // ==========================================================
  // GO TO LOGIN
  // ==========================================================

  void goToLogin(
      BuildContext context,
      ) {
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

  // ==========================================================
  // GO TO FORGOT PASSWORD
  // ==========================================================

  void goToForgotPassword(
      BuildContext context,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
        const ForgotPasswordScreen(),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final String cleanEmail =
    email
        .trim()
        .toLowerCase();

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
                  AppColors.danger
                      .withOpacity(
                    0.10,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    25,
                  ),
                ),

                child:
                const Icon(
                  Icons.person_off_outlined,

                  size:
                  48,

                  color:
                  AppColors.danger,
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
                'Account Already Exists',

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
                14,
              ),

              const Text(
                'An account is already registered with',

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
              // INFORMATION CARD
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
                          .info_outline,

                      color:
                      AppColors.primary,

                      size:
                      24,
                    ),

                    SizedBox(
                      height:
                      10,
                    ),

                    Text(
                      'You cannot create another SmartCity account '
                          'using the same email address.',

                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.bold,

                        height:
                        1.4,
                      ),
                    ),

                    SizedBox(
                      height:
                      8,
                    ),

                    Text(
                      'Please sign in using your existing account. '
                          'If you cannot remember your password, use '
                          'Forgot Password to recover access.',

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
                  AppColors.warning
                      .withOpacity(
                    0.06,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors.warning
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
                      Icons
                          .security_outlined,

                      color:
                      AppColors.warning,

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
                        'For account security, SmartCity does not '
                            'allow duplicate registration using the same '
                            'email address.',

                        style:
                        TextStyle(
                          color:
                          AppColors.textSecondary,

                          fontSize:
                          11,

                          height:
                          1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // =================================================
              // LOGIN BUTTON
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
                  ),

                  onPressed:
                      () {
                    goToLogin(
                      context,
                    );
                  },

                  icon:
                  const Icon(
                    Icons.login,
                  ),

                  label:
                  const Text(
                    'Go to Login',

                    style:
                    TextStyle(
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
              // FORGOT PASSWORD BUTTON
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height:
                50,

                child:
                OutlinedButton.icon(
                  onPressed:
                      () {
                    goToForgotPassword(
                      context,
                    );
                  },

                  icon:
                  const Icon(
                    Icons
                        .lock_reset_outlined,
                  ),

                  label:
                  const Text(
                    'Forgot Password',
                  ),
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