import 'package:flutter/material.dart';

import '../../models/login_activity.dart';
import '../../services/login_activity_service.dart';
import '../../theme/app_colors.dart';

class AccountActivityScreen
    extends StatefulWidget {
  const AccountActivityScreen({
    super.key,
  });

  @override
  State<AccountActivityScreen> createState() =>
      _AccountActivityScreenState();
}

class _AccountActivityScreenState
    extends State<AccountActivityScreen> {
  final LoginActivityService
  activityService =
  LoginActivityService();

  List<LoginActivity> activities =
  [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadActivity();
  }

  Future<void> loadActivity() async {
    try {
      final result =
      await activityService
          .getMyLoginActivity();

      if (!mounted) {
        return;
      }

      setState(() {
        activities =
            result;
        loading =
        false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading =
        false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            e.toString(),
          ),
        ),
      );
    }
  }

  String formatDate(
      DateTime date,
      ) {
    final local =
    date.toLocal();

    String twoDigits(
        int value,
        ) {
      return value
          .toString()
          .padLeft(
        2,
        '0',
      );
    }

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  IconData platformIcon(
      String platform,
      ) {
    switch (platform) {
      case 'Android':
        return Icons.android;

      case 'iOS':
        return Icons.phone_iphone;

      case 'Windows':
        return Icons.computer;

      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                6,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
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
                    width: 5,
                  ),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Activity',
                          style:
                          TextStyle(
                            fontSize:
                            22,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        Text(
                          'Recent login activity',
                          style:
                          TextStyle(
                            color:
                            AppColors
                                .textSecondary,
                            fontSize:
                            11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed:
                    loadActivity,
                    icon:
                    const Icon(
                      Icons.refresh,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            // ==================================================
            // BODY
            // ==================================================

            Expanded(
              child:
              loading
                  ? const Center(
                child:
                CircularProgressIndicator(),
              )
                  : RefreshIndicator(
                onRefresh:
                loadActivity,
                child:
                activities
                    .isEmpty
                    ? ListView(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  children:
                  const [
                    SizedBox(
                      height:
                      180,
                    ),
                    Icon(
                      Icons
                          .history,
                      size:
                      55,
                      color:
                      AppColors
                          .textSecondary,
                    ),
                    SizedBox(
                      height:
                      10,
                    ),
                    Center(
                      child:
                      Text(
                        'No login activity yet.',
                      ),
                    ),
                  ],
                )
                    : ListView.separated(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding:
                  const EdgeInsets.all(
                    16,
                  ),
                  itemCount:
                  activities.length,
                  separatorBuilder:
                      (
                      _,
                      __,
                      ) =>
                  const SizedBox(
                    height:
                    10,
                  ),
                  itemBuilder:
                      (
                      context,
                      index,
                      ) {
                    final activity =
                    activities[index];

                    return _ActivityCard(
                      activity:
                      activity,
                      formattedDate:
                      formatDate(
                        activity.createdAt,
                      ),
                      icon:
                      platformIcon(
                        activity.platform,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard
    extends StatelessWidget {
  final LoginActivity activity;

  final String formattedDate;

  final IconData icon;

  const _ActivityCard({
    required this.activity,
    required this.formattedDate,
    required this.icon,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        14,
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
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment:
            Alignment.center,
            decoration:
            BoxDecoration(
              color:
              AppColors.primary
                  .withOpacity(
                0.08,
              ),
              borderRadius:
              BorderRadius.circular(
                12,
              ),
              border:
              Border.all(
                color:
                AppColors.primaryDark,
              ),
            ),
            child: Icon(
              icon,
              color:
              AppColors.primary,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child:
                      Text(
                        'Successful Login',
                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize:
                          13,
                        ),
                      ),
                    ),

                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        8,
                        vertical:
                        4,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.success
                            .withOpacity(
                          0.1,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                      ),
                      child:
                      const Text(
                        'SUCCESS',
                        style:
                        TextStyle(
                          color:
                          AppColors.success,
                          fontSize:
                          7,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  activity.loginMethod,
                  style:
                  const TextStyle(
                    color:
                    AppColors.primary,
                    fontSize:
                    10,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  '${activity.deviceInfo} • ${activity.platform}',
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize:
                    9,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  formattedDate,
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize:
                    9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}