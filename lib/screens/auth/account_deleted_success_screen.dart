import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'auth_gate.dart';

// ============================================================
// ACCOUNT DELETED SUCCESS SCREEN
// ============================================================

class AccountDeletedSuccessScreen
    extends StatelessWidget {
  const AccountDeletedSuccessScreen({
    super.key,
  });

  // ============================================================
  // RETURN TO LOGIN
  // ============================================================

  void _returnToLogin(
      BuildContext context,
      ) {
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
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return PopScope(
      canPop: false,

      child: Scaffold(
        backgroundColor:
        AppColors.background,

        body: SafeArea(
          child: Center(
            child:
            SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),

              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [
                  // ============================================
                  // SUCCESS ICON
                  // ============================================

                  Container(
                    width: 94,
                    height: 94,

                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,

                      color:
                      AppColors.success
                          .withOpacity(
                        0.10,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors.success
                            .withOpacity(
                          0.55,
                        ),

                        width: 1.5,
                      ),
                    ),

                    child:
                    const Icon(
                      Icons
                          .check_rounded,

                      color:
                      AppColors.success,

                      size: 48,
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  // ============================================
                  // TITLE
                  // ============================================

                  const Text(
                    'Account Deleted',
                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(
                      color:
                      Colors.white,

                      fontSize: 25,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  const Text(
                    'Your SmartCity account has been permanently deleted.',
                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(
                      color:
                      AppColors
                          .textSecondary,

                      fontSize: 12,

                      height: 1.5,
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  // ============================================
                  // INFORMATION CARD
                  // ============================================

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
                        AppColors.border,
                      ),
                    ),

                    child:
                    const Column(
                      children: [
                        _DeletedInfoRow(
                          icon:
                          Icons
                              .person_remove_outlined,

                          title:
                          'Account Removed',

                          description:
                          'Your SmartCity authentication account has been removed.',
                        ),

                        SizedBox(
                          height: 18,
                        ),

                        Divider(
                          color:
                          AppColors.border,
                          height: 1,
                        ),

                        SizedBox(
                          height: 18,
                        ),

                        _DeletedInfoRow(
                          icon:
                          Icons
                              .logout_rounded,

                          title:
                          'Session Ended',

                          description:
                          'Your previous SmartCity session is no longer active.',
                        ),

                        SizedBox(
                          height: 18,
                        ),

                        Divider(
                          color:
                          AppColors.border,
                          height: 1,
                        ),

                        SizedBox(
                          height: 18,
                        ),

                        _DeletedInfoRow(
                          icon:
                          Icons
                              .security_outlined,

                          title:
                          'Device Access Cleared',

                          description:
                          'Remembered account and Quick Login information on this device have been cleared.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  // ============================================
                  // FINAL NOTICE
                  // ============================================

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

                      border:
                      Border.all(
                        color:
                        AppColors.primary
                            .withOpacity(
                          0.25,
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
                              .info_outline_rounded,

                          color:
                          AppColors.primary,

                          size: 19,
                        ),

                        SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child:
                          Text(
                            'If you want to use SmartCity again, you can create a new account from the Login screen.',

                            style:
                            TextStyle(
                              color:
                              AppColors
                                  .textSecondary,

                              fontSize: 10,

                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // ============================================
                  // RETURN TO LOGIN
                  // ============================================

                  SizedBox(
                    width:
                    double.infinity,

                    height: 52,

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
                            14,
                          ),
                        ),
                      ),

                      onPressed:
                          () {
                        _returnToLogin(
                          context,
                        );
                      },

                      icon:
                      const Icon(
                        Icons
                            .login_rounded,
                      ),

                      label:
                      const Text(
                        'Return to Login',

                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  const Text(
                    'Thank you for using SmartCity.',
                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(
                      color:
                      AppColors
                          .textSecondary,

                      fontSize: 10,
                    ),
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

// ============================================================
// DELETED INFORMATION ROW
// ============================================================

class _DeletedInfoRow
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String description;

  const _DeletedInfoRow({
    required this.icon,
    required this.title,
    required this.description,
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
          width: 38,
          height: 38,

          decoration:
          BoxDecoration(
            color:
            AppColors.success
                .withOpacity(
              0.08,
            ),

            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),

          child:
          Icon(
            icon,

            color:
            AppColors.success,

            size: 19,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style:
                const TextStyle(
                  color:
                  Colors.white,

                  fontSize: 12,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                description,

                style:
                const TextStyle(
                  color:
                  AppColors
                      .textSecondary,

                  fontSize: 9,

                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
