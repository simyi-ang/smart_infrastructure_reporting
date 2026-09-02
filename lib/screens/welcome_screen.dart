import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'auth/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
  });

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
            horizontal:
            28,
          ),

          child:
          Column(
            children: [
              const Spacer(
                flex:
                2,
              ),

              // =================================================
              // APP ICON
              // =================================================

              Container(
                width:
                108,

                height:
                108,

                decoration:
                BoxDecoration(
                  color:
                  AppColors.primary
                      .withOpacity(
                    0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    28,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors.primary
                        .withOpacity(
                      0.7,
                    ),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color:
                      AppColors.primary
                          .withOpacity(
                        0.12,
                      ),

                      blurRadius:
                      30,

                      spreadRadius:
                      5,
                    ),
                  ],
                ),

                child:
                const Center(
                  child:
                  Text(
                    '🏙️',

                    style:
                    TextStyle(
                      fontSize:
                      44,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                24,
              ),

              // =================================================
              // APP NAME
              // =================================================

              const Text(
                'SmartCity',

                style:
                TextStyle(
                  color:
                  AppColors.primary,

                  fontSize:
                  32,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                4,
              ),

              const Text(
                'I N F R A S T R U C T U R E   H U B',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  color:
                  AppColors
                      .textSecondary,

                  fontSize:
                  12,

                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                42,
              ),

              // =================================================
              // MAIN MESSAGE
              // =================================================

              const Text(
                'Report. Track.',

                style:
                TextStyle(
                  color:
                  AppColors
                      .textPrimary,

                  fontSize:
                  23,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                4,
              ),

              const Text(
                'Improve Your Community.',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  color:
                  AppColors.primary,

                  fontSize:
                  22,

                  fontWeight:
                  FontWeight.w500,
                ),
              ),

              const SizedBox(
                height:
                16,
              ),

              const Text(
                'Connecting citizens and authorities\n'
                    'for a smarter city.',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  color:
                  AppColors
                      .textSecondary,

                  fontSize:
                  15,

                  height:
                  1.5,
                ),
              ),

              const Spacer(),

              // =================================================
              // STATISTICS
              // =================================================

              Container(
                padding:
                const EdgeInsets.symmetric(
                  vertical:
                  18,

                  horizontal:
                  10,
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
                const Row(
                  children: [
                    Expanded(
                      child:
                      _Statistic(
                        value:
                        '12K+',

                        label:
                        'Reports Filed',
                      ),
                    ),

                    _Divider(),

                    Expanded(
                      child:
                      _Statistic(
                        value:
                        '94%',

                        label:
                        'Resolved',
                      ),
                    ),

                    _Divider(),

                    Expanded(
                      child:
                      _Statistic(
                        value:
                        '48h',

                        label:
                        'Avg. Response',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                44,
              ),

              // =================================================
              // GET STARTED
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height:
                58,

                child:
                DecoratedBox(
                  decoration:
                  BoxDecoration(
                    gradient:
                    const LinearGradient(
                      colors: [
                        AppColors.primaryDark,
                        Color(
                          0xFF16A39A,
                        ),
                      ],
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      17,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color:
                        AppColors.primary
                            .withOpacity(
                          0.20,
                        ),

                        blurRadius:
                        20,
                      ),
                    ],
                  ),

                  child:
                  ElevatedButton(
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.transparent,

                      shadowColor:
                      Colors.transparent,

                      foregroundColor:
                      Colors.white,

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          17,
                        ),
                      ),
                    ),

                    onPressed: () {
                      // Normal Login.
                      //
                      // First-time users are NOT automatically
                      // asked for biometric authentication here.
                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (_) =>
                          const LoginScreen(),
                        ),
                      );
                    },

                    child:
                    const Text(
                      'Get Started →',

                      style:
                      TextStyle(
                        fontSize:
                        17,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                18,
              ),

              // =================================================
              // ADMIN PORTAL
              // =================================================

              TextButton(
                onPressed: () {
                  // Existing behaviour preserved.
                  //
                  // Worker/Admin portal can be
                  // connected separately.
                },

                child:
                const Text(
                  'Admin Portal →',

                  style:
                  TextStyle(
                    color:
                    AppColors
                        .textSecondary,

                    fontSize:
                    14,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// STATISTIC
// ================================================================

class _Statistic
    extends StatelessWidget {
  final String value;

  final String label;

  const _Statistic({
    required this.value,
    required this.label,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Text(
          value,

          style:
          const TextStyle(
            color:
            AppColors.primary,

            fontSize:
            20,

            fontWeight:
            FontWeight.bold,
          ),
        ),

        const SizedBox(
          height:
          6,
        ),

        Text(
          label,

          textAlign:
          TextAlign.center,

          style:
          const TextStyle(
            color:
            AppColors
                .textSecondary,

            fontSize:
            11,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// DIVIDER
// ================================================================

class _Divider
    extends StatelessWidget {
  const _Divider();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      1,

      height:
      45,

      color:
      AppColors.border,
    );
  }
}