import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/email_verification_security_service.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

class EmailVerifiedSuccessScreen
    extends StatefulWidget {
  const EmailVerifiedSuccessScreen({
    super.key,
  });

  @override
  State<EmailVerifiedSuccessScreen>
  createState() =>
      _EmailVerifiedSuccessScreenState();
}

class _EmailVerifiedSuccessScreenState
    extends State<EmailVerifiedSuccessScreen> {
  final EmailVerificationSecurityService
  verificationSecurityService =
  EmailVerificationSecurityService();

  bool loading = false;

  // ============================================================
  // CONTINUE TO LOGIN
  // ============================================================

  Future<void> continueToLogin() async {
    if (loading) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final User? user =
          Supabase.instance.client.auth.currentUser;

      final String? email =
      user?.email?.trim().toLowerCase();

      // ========================================================
      // CLEAR LOCAL VERIFICATION SECURITY STATE
      // ========================================================

      if (
      email != null &&
          email.isNotEmpty
      ) {
        await verificationSecurityService
            .clear(
          email,
        );
      }

      // ========================================================
      // SIGN OUT
      //
      // Verification does not automatically log the citizen
      // into the application.
      //
      // They must use the normal login flow.
      // ========================================================

      try {
        await Supabase.instance.client.auth
            .signOut();
      } catch (_) {
        // Continue to login even if no session exists.
      }

      if (!mounted) {
        return;
      }

      // ========================================================
      // LOGIN SCREEN
      // ========================================================

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
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to continue. Please try again.',
          ),
        ),
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
          const EdgeInsets.symmetric(
            horizontal: 26,
            vertical: 24,
          ),

          child:
          Column(
            children: [
              const Spacer(),

              // ==================================================
              // SUCCESS ICON
              // ==================================================

              Container(
                width: 110,
                height: 110,

                decoration:
                BoxDecoration(
                  color:
                  AppColors.success
                      .withOpacity(
                    0.12,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    32,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors.success
                        .withOpacity(
                      0.30,
                    ),
                  ),
                ),

                child:
                const Icon(
                  Icons
                      .verified_rounded,

                  size: 58,

                  color:
                  AppColors.success,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                'Email Verified!',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  fontSize: 30,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // DESCRIPTION
              // ==================================================

              const Text(
                'Your email address has been verified successfully.',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  color:
                  AppColors
                      .textSecondary,

                  fontSize: 14,

                  height: 1.5,
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              // ==================================================
              // SUCCESS INFORMATION
              // ==================================================

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
                    18,
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
                          .check_circle_outline_rounded,

                      color:
                      AppColors.success,

                      size: 30,
                    ),

                    SizedBox(
                      height: 12,
                    ),

                    Text(
                      'Account Registration Complete',

                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(
                        fontSize: 16,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height: 9,
                    ),

                    Text(
                      'Your SmartCity account is now ready. '
                          'You can sign in using your registered '
                          'email address and password.',

                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(
                        color:
                        AppColors
                            .textSecondary,

                        fontSize: 13,

                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // SECURITY INFORMATION
              // ==================================================

              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.all(
                  16,
                ),

                decoration:
                BoxDecoration(
                  color:
                  AppColors.primary
                      .withOpacity(
                    0.07,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors.primary
                        .withOpacity(
                      0.20,
                    ),
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
                          .security_outlined,

                      size: 21,

                      color:
                      AppColors.primary,
                    ),

                    SizedBox(
                      width: 11,
                    ),

                    Expanded(
                      child:
                      Text(
                        'For your security, please sign in '
                            'normally after completing email '
                            'verification.',

                        style:
                        TextStyle(
                          color:
                          AppColors
                              .textSecondary,

                          fontSize: 12,

                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ==================================================
              // CONTINUE TO LOGIN
              // ==================================================

              SizedBox(
                width:
                double.infinity,

                height: 55,

                child:
                ElevatedButton.icon(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    AppColors
                        .primaryDark,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        15,
                      ),
                    ),
                  ),

                  onPressed:
                  loading
                      ? null
                      : continueToLogin,

                  icon:
                  loading
                      ? const SizedBox(
                    width: 19,
                    height: 19,

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
                        .login_rounded,
                  ),

                  label:
                  Text(
                    loading
                        ? 'Preparing Login...'
                        : 'Continue to Login',

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,

                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}