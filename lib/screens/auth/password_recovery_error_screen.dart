import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';

// ================================================================
// PASSWORD RECOVERY ERROR SCREEN
//
// Used when SmartCity receives a password-reset callback but
// Supabase cannot establish a valid recovery session.
//
// Possible causes:
//
// - reset link expired
// - reset link already used
// - invalid recovery token
// - malformed recovery callback
// - recovery verification ffluttailed
//
// SmartCity intentionally uses a general message because the
// application should not guess the exact server-side cause.
// ================================================================

class PasswordRecoveryErrorScreen
    extends StatelessWidget {
  const PasswordRecoveryErrorScreen({
    super.key,
  });

  // ============================================================
  // REQUEST NEW RESET LINK
  // ============================================================

  void requestNewLink(
      BuildContext context,
      ) {
    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
        const ForgotPasswordScreen(),
      ),
          (route) => false,
    );
  }

  // ============================================================
  // BACK TO LOGIN
  // ============================================================

  void backToLogin(
      BuildContext context,
      ) {
    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
        const LoginScreen(),
      ),
          (route) => false,
    );
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
        Center(
          child:
          SingleChildScrollView(
            padding:
            const EdgeInsets.all(
              26,
            ),

            child:
            Column(
              children: [
                // ===============================================
                // ERROR ICON
                // ===============================================

                Container(
                  width:
                  90,

                  height:
                  90,

                  alignment:
                  Alignment.center,

                  decoration:
                  BoxDecoration(
                    shape:
                    BoxShape.circle,

                    color:
                    Colors.red
                        .withOpacity(
                      0.09,
                    ),

                    border:
                    Border.all(
                      color:
                      Colors.red
                          .withOpacity(
                        0.55,
                      ),
                    ),
                  ),

                  child:
                  const Icon(
                    Icons.link_off_rounded,

                    size:
                    44,

                    color:
                    Colors.red,
                  ),
                ),

                const SizedBox(
                  height:
                  28,
                ),

                // ===============================================
                // TITLE
                // ===============================================

                const Text(
                  'Reset Link Expired or Invalid',

                  textAlign:
                  TextAlign.center,

                  style:
                  TextStyle(
                    fontSize:
                    27,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                  14,
                ),

                // ===============================================
                // DESCRIPTION
                // ===============================================

                const Text(
                  'This password reset link has expired, '
                      'has already been used, or could not be verified. '
                      'Request a new password reset link to continue.',

                  textAlign:
                  TextAlign.center,

                  style:
                  TextStyle(
                    color:
                    AppColors
                        .textSecondary,

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

                // ===============================================
                // SECURITY INFORMATION
                // ===============================================

                Container(
                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets.all(
                    15,
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
                      14,
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
                          'For your security, SmartCity does not allow '
                              'an expired or unverified recovery request '
                              'to modify your account password.',

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
                  30,
                ),

                // ===============================================
                // REQUEST NEW LINK
                // ===============================================

                SizedBox(
                  width:
                  double.infinity,

                  height:
                  54,

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
                        BorderRadius
                            .circular(
                          14,
                        ),
                      ),
                    ),

                    onPressed: () {
                      requestNewLink(
                        context,
                      );
                    },

                    icon:
                    const Icon(
                      Icons.refresh,
                    ),

                    label:
                    const Text(
                      'Request New Reset Link',

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

                // ===============================================
                // BACK TO LOGIN
                // ===============================================

                SizedBox(
                  width:
                  double.infinity,

                  height:
                  50,

                  child:
                  OutlinedButton.icon(
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
                          14,
                        ),
                      ),
                    ),

                    onPressed: () {
                      backToLogin(
                        context,
                      );
                    },

                    icon:
                    const Icon(
                      Icons.login,

                      size:
                      19,
                    ),

                    label:
                    const Text(
                      'Back to Login',
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                  18,
                ),

                // ===============================================
                // SECURITY FOOTNOTE
                // ===============================================

                const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,

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
                        'Your account password has not been changed.',

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}