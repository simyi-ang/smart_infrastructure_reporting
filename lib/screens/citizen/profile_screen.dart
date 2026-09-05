import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/infrastructure_report.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/citizen_dashboard_service.dart';
import '../../theme/app_colors.dart';

import '../auth/auth_gate.dart';
import '../reports/my_reports_screen.dart';
import 'account_activity_screen.dart';
import 'infrastructure_map_screen.dart';
import 'security_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final AuthService authService =
  AuthService();

  final CitizenDashboardService dashboardService =
  CitizenDashboardService();

  final ImagePicker imagePicker =
  ImagePicker();

  UserProfile? profile;

  String? profileImageUrl;

  CitizenDashboardStats stats =
  CitizenDashboardStats.empty();

  List<InfrastructureReport> recentReports =
  [];

  bool loading = true;
  bool uploadingPhoto = false;

  int selectedNavigationIndex = 4;

  @override
  void initState() {
    super.initState();

    loadProfile();
  }

  // ============================================================
  // LOAD PROFILE + CONTRIBUTION DATA
  // ============================================================

  Future<void> loadProfile() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      final results =
      await Future.wait<dynamic>(
        [
          authService.getCurrentProfile(),
          authService.getProfileImageUrl(),
          dashboardService.loadDashboard(),
        ],
      );

      if (!mounted) {
        return;
      }

      final UserProfile? loadedProfile =
      results[0] as UserProfile?;

      final String? imageUrl =
      results[1] as String?;

      final CitizenDashboardData dashboardData =
      results[2] as CitizenDashboardData;

      setState(() {
        profile = loadedProfile;
        profileImageUrl = imageUrl;

        stats =
            dashboardData.stats;

        recentReports =
            dashboardData.recentReports;

        loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // PROFILE COMPLETION
  // ============================================================

  int get profileCompletion {
    final UserProfile? current =
        profile;

    if (current == null) {
      return 0;
    }

    int completed = 0;
    const int total = 4;

    if (current.fullName.trim().isNotEmpty) {
      completed++;
    }

    if (current.email.trim().isNotEmpty) {
      completed++;
    }

    if (current.phone.trim().isNotEmpty) {
      completed++;
    }

    if (profileImageUrl != null &&
        profileImageUrl!.trim().isNotEmpty) {
      completed++;
    }

    return ((completed / total) * 100).round();
  }

  // ============================================================
  // LEVEL / ACHIEVEMENTS
  // ============================================================

  int get communityLevel {
    return (stats.contributionPoints ~/ 100) + 1;
  }

  int get currentLevelStartPoints {
    return (communityLevel - 1) * 100;
  }

  int get nextLevelPointsTarget {
    return communityLevel * 100;
  }

  double get levelProgress {
    final int range =
        nextLevelPointsTarget -
            currentLevelStartPoints;

    if (range <= 0) {
      return 0;
    }

    final int progress =
        stats.contributionPoints -
            currentLevelStartPoints;

    return (progress / range).clamp(
      0.0,
      1.0,
    );
  }

  bool get communityHelperUnlocked =>
      stats.totalReports >= 10;

  bool get verifiedReporterUnlocked =>
      stats.verifiedReports >= 5 ||
          stats.completedReports >= 5;

  bool get infrastructureGuardianUnlocked =>
      stats.completedReports >= 10;

  // ============================================================
  // PROFILE IMAGE
  // ============================================================

  Future<void> choosePhotoSource() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(
              18,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const Text(
                  'Profile Picture',
                  style:
                  TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                ListTile(
                  leading:
                  const Icon(
                    Icons.camera_alt_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Take Photo',
                  ),
                  subtitle:
                  const Text(
                    'Use your camera',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    pickProfilePicture(
                      ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading:
                  const Icon(
                    Icons.photo_library_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Choose from Gallery',
                  ),
                  subtitle:
                  const Text(
                    'Select an existing photo',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    pickProfilePicture(
                      ImageSource.gallery,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> pickProfilePicture(
      ImageSource source,
      ) async {
    if (uploadingPhoto) {
      return;
    }

    try {
      final XFile? selected =
      await imagePicker.pickImage(
        source:
        source,
        imageQuality:
        75,
        maxWidth:
        1000,
        maxHeight:
        1000,
      );

      if (selected == null) {
        return;
      }

      setState(() {
        uploadingPhoto = true;
      });

      await authService.uploadProfileImage(
        File(
          selected.path,
        ),
      );

      await loadProfile();

      if (!mounted) {
        return;
      }

      showMessage(
        'Profile picture updated successfully.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingPhoto = false;
        });
      }
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  Future<void> editProfile() async {
    final UserProfile? current =
        profile;

    if (current == null) {
      return;
    }

    final bool? changed =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(
              profile:
              current,
            ),
      ),
    );

    if (changed == true) {
      await loadProfile();

      if (!mounted) {
        return;
      }

      showMessage(
        'Profile updated successfully.',
      );
    }
  }

  // ============================================================
  // SECURITY / ACTIVITY
  // ============================================================

  Future<void> openSecurity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const SecurityScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await loadProfile();
  }

  Future<void> openAccountActivity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const AccountActivityScreen(),
      ),
    );
  }

  // ============================================================
  // HELP
  // ============================================================

  Future<void> openHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,
          title:
          const Row(
            children: [
              Icon(
                Icons.help_outline,
                color:
                AppColors.primary,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                'Help & Support',
              ),
            ],
          ),
          content:
          const Text(
            'For account access problems, password issues, '
                'report submission errors or profile assistance, '
                'contact the SmartCity support/administrator assigned '
                'for this application.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
              const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> logout() async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,
          title:
          const Text(
            'Sign Out?',
          ),
          content:
          const Text(
            'Are you sure you want to sign out of your SmartCity account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
              const Text(
                'Sign Out',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await authService.logout();

      if (!mounted) {
        return;
      }

      // IMPORTANT:
      // Clear every authenticated screen from the navigation stack.
      // A fresh AuthGate will see that Supabase.currentUser is null
      // and immediately show LoginScreen.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
          const AuthGate(),
        ),
            (route) =>
        false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Future<void> handleNavigation(
      int index,
      ) async {
    setState(() {
      selectedNavigationIndex =
          index;
    });

    switch (index) {
      case 0:
        Navigator.pop(
          context,
        );
        break;

      case 1:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const MyReportsScreen(),
          ),
        );

        if (mounted) {
          setState(() {
            selectedNavigationIndex = 4;
          });
        }
        break;

      case 2:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const InfrastructureMapScreen(),
          ),
        );

        if (mounted) {
          setState(() {
            selectedNavigationIndex = 4;
          });
        }
        break;

      case 3:
        if (mounted) {
          showMessage(
            'Community is outside the current approved scope.',
          );

          setState(() {
            selectedNavigationIndex = 4;
          });
        }
        break;

      case 4:
        break;
    }
  }

  // ============================================================
  // TEXT / FORMAT
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

  String initials(
      String name,
      ) {
    final List<String> parts =
    name
        .trim()
        .split(
      RegExp(
        r'\s+',
      ),
    )
        .where(
          (part) =>
      part.isNotEmpty,
    )
        .toList();

    if (parts.isEmpty) {
      return 'C';
    }

    if (parts.length == 1) {
      return parts.first[0]
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }

  String get firstName {
    final String name =
        profile?.fullName.trim() ?? '';

    if (name.isEmpty) {
      return 'Citizen';
    }

    return name
        .split(
      RegExp(
        r'\s+',
      ),
    )
        .first;
  }

  String formatDate(
      DateTime date,
      ) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  String statusText(
      String status,
      ) {
    switch (status
        .trim()
        .toLowerCase()
        .replaceAll(
      ' ',
      '_',
    )) {
      case 'verified':
        return 'Report Verified';

      case 'in_progress':
        return 'Report In Progress';

      case 'completed':
        return 'Report Completed';

      case 'rejected':
        return 'Report Rejected';

      default:
        return 'Report Submitted';
    }
  }

  IconData statusIcon(
      String status,
      ) {
    switch (status
        .trim()
        .toLowerCase()
        .replaceAll(
      ' ',
      '_',
    )) {
      case 'verified':
        return Icons.verified_outlined;

      case 'in_progress':
        return Icons.engineering_outlined;

      case 'completed':
        return Icons.check_circle_outline;

      case 'rejected':
        return Icons.cancel_outlined;

      default:
        return Icons.description_outlined;
    }
  }

  Color statusColor(
      String status,
      ) {
    switch (status
        .trim()
        .toLowerCase()
        .replaceAll(
      ' ',
      '_',
    )) {
      case 'completed':
        return AppColors.success;

      case 'rejected':
        return AppColors.danger;

      case 'pending':
        return AppColors.warning;

      default:
        return AppColors.primary;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    if (loading) {
      return const Scaffold(
        backgroundColor:
        AppColors.background,
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    final UserProfile? current =
        profile;

    if (current == null) {
      return Scaffold(
        backgroundColor:
        AppColors.background,
        body: SafeArea(
          child: Center(
            child: ElevatedButton(
              onPressed:
              loadProfile,
              child:
              const Text(
                'Reload Profile',
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh:
          loadProfile,

          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding:
            const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              28,
            ),

            children: [
              // =================================================
              // HEADER
              // =================================================

              const Text(
                'Profile',

                style:
                TextStyle(
                  fontSize: 23,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                firstName,

                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // =================================================
              // PROFILE IDENTITY CARD
              // =================================================

              Container(
                padding:
                const EdgeInsets.all(
                  16,
                ),

                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFF083340,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    17,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors.primaryDark,
                  ),
                ),

                child: Row(
                  children: [
                    GestureDetector(
                      onTap:
                      uploadingPhoto
                          ? null
                          : choosePhotoSource,

                      child: Stack(
                        clipBehavior:
                        Clip.none,

                        children: [
                          Container(
                            width: 68,
                            height: 68,

                            decoration:
                            BoxDecoration(
                              shape:
                              BoxShape.circle,

                              border:
                              Border.all(
                                color:
                                AppColors.primary,
                                width: 2,
                              ),
                            ),

                            child:
                            ClipOval(
                              child:
                              profileImageUrl != null
                                  ? Image.network(
                                profileImageUrl!,
                                fit:
                                BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) =>
                                    _AvatarFallback(
                                      initials:
                                      initials(
                                        current.fullName,
                                      ),
                                    ),
                              )
                                  : _AvatarFallback(
                                initials:
                                initials(
                                  current.fullName,
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            right: -1,
                            bottom: 2,

                            child:
                            Container(
                              width: 18,
                              height: 18,

                              decoration:
                              BoxDecoration(
                                color:
                                AppColors.success,

                                shape:
                                BoxShape.circle,

                                border:
                                Border.all(
                                  color:
                                  const Color(
                                    0xFF083340,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          if (uploadingPhoto)
                            Positioned.fill(
                              child:
                              Container(
                                alignment:
                                Alignment.center,

                                decoration:
                                const BoxDecoration(
                                  color:
                                  Color(
                                    0x77000000,
                                  ),

                                  shape:
                                  BoxShape.circle,
                                ),

                                child:
                                const SizedBox(
                                  width: 20,
                                  height: 20,

                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 15,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          Text(
                            current.fullName.isEmpty
                                ? 'SmartCity Citizen'
                                : current.fullName,

                            style:
                            const TextStyle(
                              fontSize: 16,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            '${current.email}'
                                '${current.phone.trim().isEmpty ? '' : ' • ${current.phone}'}',

                            maxLines: 2,

                            overflow:
                            TextOverflow.ellipsis,

                            style:
                            const TextStyle(
                              color:
                              AppColors.textSecondary,
                              fontSize: 9,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          Wrap(
                            spacing: 7,
                            runSpacing: 6,

                            children: [
                              _Badge(
                                icon:
                                Icons.emoji_events_outlined,

                                label:
                                'Community Guardian',

                                color:
                                AppColors.warning,
                              ),

                              _Badge(
                                label:
                                'Level $communityLevel',

                                color:
                                AppColors.success,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              // =================================================
              // IMPACT SCORE
              // =================================================

              Container(
                padding:
                const EdgeInsets.all(
                  16,
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

                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 82,
                          height: 82,

                          child: Stack(
                            alignment:
                            Alignment.center,

                            children: [
                              SizedBox(
                                width: 70,
                                height: 70,

                                child:
                                CircularProgressIndicator(
                                  value:
                                  (stats.impactScore / 100)
                                      .clamp(
                                    0.0,
                                    1.0,
                                  ),

                                  strokeWidth: 7,

                                  backgroundColor:
                                  AppColors.border,

                                  color:
                                  AppColors.primary,
                                ),
                              ),

                              Column(
                                mainAxisSize:
                                MainAxisSize.min,

                                children: [
                                  Text(
                                    '${stats.impactScore}',

                                    style:
                                    const TextStyle(
                                      color:
                                      AppColors.primary,

                                      fontSize: 18,

                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),

                                  const Text(
                                    'SCORE',

                                    style:
                                    TextStyle(
                                      color:
                                      AppColors.textSecondary,
                                      fontSize: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 15,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [
                              const Text(
                                'Impact Score',

                                style:
                                TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              _ProgressLine(
                                label:
                                'Reports Filed',

                                value:
                                '${stats.totalReports}',

                                progress:
                                (stats.totalReports / 20)
                                    .clamp(
                                  0.0,
                                  1.0,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              _ProgressLine(
                                label:
                                'Verified / Completed',

                                value:
                                '${stats.verifiedReports + stats.completedReports}',

                                progress:
                                ((stats.verifiedReports +
                                    stats.completedReports) /
                                    12)
                                    .clamp(
                                  0.0,
                                  1.0,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              _ProgressLine(
                                label:
                                'Profile Completion',

                                value:
                                '$profileCompletion%',

                                progress:
                                profileCompletion / 100,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    const Divider(
                      color:
                      AppColors.border,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Progress to Level ${communityLevel + 1}',

                            style:
                            const TextStyle(
                              color:
                              AppColors.textSecondary,
                              fontSize: 8,
                            ),
                          ),
                        ),

                        Text(
                          '${stats.contributionPoints} / '
                              '$nextLevelPointsTarget pts',

                          style:
                          const TextStyle(
                            color:
                            AppColors.primary,
                            fontSize: 9,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),

                      child:
                      LinearProgressIndicator(
                        value:
                        levelProgress,

                        minHeight: 5,

                        backgroundColor:
                        AppColors.border,

                        color:
                        AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // =================================================
              // STATS
              // =================================================

              Row(
                children: [
                  Expanded(
                    child:
                    _ProfileStatCard(
                      icon:
                      '📋',

                      value:
                      '${stats.totalReports}',

                      label:
                      'Reports',

                      color:
                      AppColors.primary,
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                    _ProfileStatCard(
                      icon:
                      '⭐',

                      value:
                      '${stats.contributionPoints}',

                      label:
                      'Points',

                      color:
                      AppColors.warning,
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                    _ProfileStatCard(
                      icon:
                      '🏆',

                      value:
                      stats.citizenRank == 0
                          ? '-'
                          : '#${stats.citizenRank}',

                      label:
                      'City Rank',

                      color:
                      const Color(
                        0xFF8E7BFF,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 17,
              ),

              // =================================================
              // ACHIEVEMENTS
              // =================================================

              const Text(
                'Achievements',

                style:
                TextStyle(
                  fontSize: 13,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 9,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    _AchievementCard(
                      emoji:
                      '🏆',

                      title:
                      'Guardian',

                      subtitle:
                      'Level $communityLevel',

                      unlocked:
                      stats.totalReports > 0,
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                    _AchievementCard(
                      emoji:
                      '🌱',

                      title:
                      'Community Helper',

                      subtitle:
                      '10 reports',

                      unlocked:
                      communityHelperUnlocked,
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                    _AchievementCard(
                      emoji:
                      '✅',

                      title:
                      'Verified Reporter',

                      subtitle:
                      '5 verified',

                      unlocked:
                      verifiedReporterUnlocked,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    _AchievementCard(
                      emoji:
                      '⚡',

                      title:
                      'Active Citizen',

                      subtitle:
                      'First report',

                      unlocked:
                      stats.totalReports >= 1,
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                    _AchievementCard(
                      emoji:
                      '🎯',

                      title:
                      'Problem Solver',

                      subtitle:
                      '10 completed',

                      unlocked:
                      infrastructureGuardianUnlocked,
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  const Expanded(
                    child:
                    _AchievementCard(
                      emoji:
                      '⚙️',

                      title:
                      'More Soon',

                      subtitle:
                      'Keep helping',

                      unlocked:
                      false,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 19,
              ),

              // =================================================
              // RECENT ACTIVITY
              // =================================================

              const Text(
                'Recent Activity',

                style:
                TextStyle(
                  fontSize: 13,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 9,
              ),

              Container(
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

                child: recentReports.isEmpty
                    ? const Padding(
                  padding:
                  EdgeInsets.all(
                    18,
                  ),

                  child: Center(
                    child: Text(
                      'No report activity yet.',

                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ),
                )
                    : Column(
                  children:
                  recentReports
                      .take(
                    4,
                  )
                      .map(
                        (report) =>
                        _ActivityRow(
                          icon:
                          statusIcon(
                            report.status,
                          ),

                          iconColor:
                          statusColor(
                            report.status,
                          ),

                          title:
                          statusText(
                            report.status,
                          ),

                          subtitle:
                          report.title,

                          date:
                          formatDate(
                            report.createdAt,
                          ),
                        ),
                  )
                      .toList(),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // =================================================
              // SETTINGS
              // =================================================

              Container(
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

                child: Column(
                  children: [
                    _SettingsTile(
                      icon:
                      Icons.edit_outlined,

                      iconColor:
                      AppColors.primary,

                      title:
                      'Edit Profile',

                      onTap:
                      editProfile,
                    ),

                    _SettingsTile(
                      icon:
                      Icons.security_outlined,

                      iconColor:
                      AppColors.warning,

                      title:
                      'Security & Password',

                      onTap:
                      openSecurity,
                    ),

                    _SettingsTile(
                      icon:
                      Icons.history,

                      iconColor:
                      AppColors.success,

                      title:
                      'Account Activity',

                      onTap:
                      openAccountActivity,
                    ),

                    _SettingsTile(
                      icon:
                      Icons.verified_user_outlined,

                      iconColor:
                      profileCompletion == 100
                          ? AppColors.success
                          : AppColors.warning,

                      title:
                      'Profile Completion',

                      trailingText:
                      '$profileCompletion%',

                      onTap:
                      profileCompletion == 100
                          ? null
                          : editProfile,
                    ),

                    _SettingsTile(
                      icon:
                      Icons.help_outline,

                      iconColor:
                      const Color(
                        0xFFFF4F79,
                      ),

                      title:
                      'Help & Support',

                      onTap:
                      openHelp,

                      showDivider:
                      false,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              // =================================================
              // SIGN OUT
              // =================================================

              SizedBox(
                height: 49,

                child:
                OutlinedButton.icon(
                  onPressed:
                  logout,

                  style:
                  OutlinedButton.styleFrom(
                    backgroundColor:
                    AppColors.danger.withValues(
                      alpha: 0.08,
                    ),

                    side:
                    BorderSide(
                      color:
                      AppColors.danger.withValues(
                        alpha: 0.45,
                      ),
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        13,
                      ),
                    ),
                  ),

                  icon:
                  const Icon(
                    Icons.logout,
                    color:
                    AppColors.danger,
                    size: 18,
                  ),

                  label:
                  const Text(
                    'Sign Out',

                    style:
                    TextStyle(
                      color:
                      AppColors.danger,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Center(
                child: Text(
                  'Member since '
                      '${current.createdAt == null ? 'N/A' : formatDate(current.createdAt!)}',

                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar:
      BottomNavigationBar(
        type:
        BottomNavigationBarType.fixed,

        currentIndex:
        selectedNavigationIndex,

        backgroundColor:
        AppColors.surface,

        selectedItemColor:
        AppColors.primary,

        unselectedItemColor:
        AppColors.textSecondary,

        onTap:
        handleNavigation,

        items:
        const [
          BottomNavigationBarItem(
            icon:
            Icon(
              Icons.home_outlined,
            ),
            activeIcon:
            Icon(
              Icons.home,
            ),
            label:
            'Home',
          ),
          BottomNavigationBarItem(
            icon:
            Icon(
              Icons.description_outlined,
            ),
            activeIcon:
            Icon(
              Icons.description,
            ),
            label:
            'Reports',
          ),
          BottomNavigationBarItem(
            icon:
            Icon(
              Icons.map_outlined,
            ),
            activeIcon:
            Icon(
              Icons.map,
            ),
            label:
            'Map',
          ),
          BottomNavigationBarItem(
            icon:
            Icon(
              Icons.groups_outlined,
            ),
            activeIcon:
            Icon(
              Icons.groups,
            ),
            label:
            'Community',
          ),
          BottomNavigationBarItem(
            icon:
            Icon(
              Icons.person_outline,
            ),
            activeIcon:
            Icon(
              Icons.person,
            ),
            label:
            'Profile',
          ),
        ],
      ),
    );
  }
}

// =================================================================
// AVATAR FALLBACK
// =================================================================

class _AvatarFallback
    extends StatelessWidget {
  final String initials;

  const _AvatarFallback({
    required this.initials,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      alignment:
      Alignment.center,

      decoration:
      const BoxDecoration(
        color:
        AppColors.primaryDark,
        shape:
        BoxShape.circle,
      ),

      child: Text(
        initials,

        style:
        const TextStyle(
          color:
          Colors.white,
          fontSize: 21,
          fontWeight:
          FontWeight.bold,
        ),
      ),
    );
  }
}

// =================================================================
// BADGE
// =================================================================

class _Badge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;

  const _Badge({
    this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),

      decoration:
      BoxDecoration(
        color:
        color.withValues(
          alpha: 0.08,
        ),

        borderRadius:
        BorderRadius.circular(
          20,
        ),

        border:
        Border.all(
          color:
          color.withValues(
            alpha: 0.5,
          ),
        ),
      ),

      child: Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color:
              color,
              size: 11,
            ),
            const SizedBox(
              width: 4,
            ),
          ],
          Text(
            label,

            style:
            TextStyle(
              color:
              color,
              fontSize: 7,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// PROGRESS LINE
// =================================================================

class _ProgressLine
    extends StatelessWidget {
  final String label;
  final String value;
  final double progress;

  const _ProgressLine({
    required this.label,
    required this.value,
    required this.progress,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,

                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 8,
                ),
              ),
            ),
            Text(
              value,

              style:
              const TextStyle(
                color:
                AppColors.primary,
                fontSize: 8,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 4,
        ),
        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            10,
          ),
          child:
          LinearProgressIndicator(
            value:
            progress.clamp(
              0.0,
              1.0,
            ),
            minHeight: 4,
            backgroundColor:
            AppColors.border,
            color:
            AppColors.primary,
          ),
        ),
      ],
    );
  }
}

// =================================================================
// PROFILE STAT CARD
// =================================================================

class _ProfileStatCard
    extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;

  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      height: 95,

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

      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,

        children: [
          Text(
            icon,
            style:
            const TextStyle(
              fontSize: 18,
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            value,

            style:
            TextStyle(
              color:
              color,
              fontSize: 19,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            label,

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// ACHIEVEMENT
// =================================================================

class _AchievementCard
    extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool unlocked;

  const _AchievementCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.unlocked,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Opacity(
      opacity:
      unlocked ? 1 : 0.38,

      child: Container(
        height: 91,

        padding:
        const EdgeInsets.all(
          8,
        ),

        decoration:
        BoxDecoration(
          color:
          AppColors.surface,

          borderRadius:
          BorderRadius.circular(
            12,
          ),

          border:
          Border.all(
            color:
            unlocked
                ? AppColors.primaryDark
                : AppColors.border,
          ),
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            Text(
              emoji,
              style:
              const TextStyle(
                fontSize: 18,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              title,

              maxLines: 2,

              textAlign:
              TextAlign.center,

              overflow:
              TextOverflow.ellipsis,

              style:
              TextStyle(
                color:
                unlocked
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 8,
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 3,
            ),
            Text(
              subtitle,

              maxLines: 1,

              overflow:
              TextOverflow.ellipsis,

              style:
              const TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// RECENT ACTIVITY ROW
// =================================================================

class _ActivityRow
    extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String date;

  const _ActivityRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.date,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        12,
      ),

      decoration:
      const BoxDecoration(
        border:
        Border(
          bottom:
          BorderSide(
            color:
            AppColors.border,
          ),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,

            alignment:
            Alignment.center,

            decoration:
            BoxDecoration(
              color:
              iconColor.withValues(
                alpha: 0.08,
              ),

              borderRadius:
              BorderRadius.circular(
                9,
              ),
            ),

            child: Icon(
              icon,
              color:
              iconColor,
              size: 18,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                  const TextStyle(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  subtitle,

                  maxLines: 1,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Text(
            date,

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// SETTINGS TILE
// =================================================================

class _SettingsTile
    extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;
  final bool showDivider;
  final String? trailingText;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.showDivider = true,
    this.trailingText,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return InkWell(
      onTap:
      onTap,

      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),

        decoration:
        BoxDecoration(
          border:
          showDivider
              ? const Border(
            bottom:
            BorderSide(
              color:
              AppColors.border,
            ),
          )
              : null,
        ),

        child: Row(
          children: [
            Icon(
              icon,
              color:
              iconColor,
              size: 18,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Text(
                title,

                style:
                const TextStyle(
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),

            if (trailingText != null)
              Text(
                trailingText!,

                style:
                const TextStyle(
                  color:
                  AppColors.primary,
                  fontSize: 9,
                  fontWeight:
                  FontWeight.bold,
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                color:
                AppColors.textSecondary,
                size: 17,
              ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// EDIT PROFILE SCREEN
// =================================================================

class EditProfileScreen
    extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  final AuthService authService =
  AuthService();

  final GlobalKey<FormState> formKey =
  GlobalKey<FormState>();

  late final TextEditingController
  nameController;

  late final TextEditingController
  phoneController;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(
          text:
          widget.profile.fullName,
        );

    phoneController =
        TextEditingController(
          text:
          widget.profile.phone,
        );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();

    super.dispose();
  }

  Future<void> save() async {
    if (!(formKey.currentState
        ?.validate() ??
        false)) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await authService.updateProfile(
        fullName:
        nameController.text,
        phone:
        phoneController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      appBar:
      AppBar(
        backgroundColor:
        AppColors.surface,

        title:
        const Text(
          'Edit Profile',
        ),
      ),

      body: Form(
        key:
        formKey,

        child: ListView(
          padding:
          const EdgeInsets.all(
            20,
          ),

          children: [
            const Text(
              'FULL NAME',

              style:
              TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 11,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            TextFormField(
              controller:
              nameController,

              enabled:
              !saving,

              textInputAction:
              TextInputAction.next,

              decoration:
              _profileInput(
                hint:
                'Your full name',
                icon:
                Icons.person_outline,
              ),

              validator:
                  (value) {
                final String name =
                    value?.trim() ?? '';

                if (name.isEmpty) {
                  return 'Full name is required.';
                }

                if (name.length < 2) {
                  return 'Full name is too short.';
                }

                if (name.length > 100) {
                  return 'Full name is too long.';
                }

                // Must contain at least one real letter.
                if (!RegExp(
                  r"[A-Za-zÀ-ÖØ-öø-ÿĀ-ž\u4E00-\u9FFF]",
                  unicode: true,
                ).hasMatch(
                  name,
                )) {
                  return 'Enter a valid full name.';
                }

                // Numbers should not be allowed in a person's name.
                if (RegExp(
                  r'\d',
                ).hasMatch(
                  name,
                )) {
                  return 'Full name cannot contain numbers.';
                }

                // Allow:
                // letters
                // spaces
                // apostrophes
                // hyphens
                // periods
                //
                // Examples:
                // Lee Mei Ling
                // Nur Aisyah
                // O'Connor
                // Tan Wei-Jie
                if (!RegExp(
                  r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-ž\u4E00-\u9FFF\s.'’-]+$",
                  unicode: true,
                ).hasMatch(
                  name,
                )) {
                  return 'Full name contains invalid characters.';
                }

                // Prevent excessive repeated characters such as:
                // aaaaaaaa
                if (RegExp(
                  r'(.)\1{4,}',
                  caseSensitive: false,
                ).hasMatch(
                  name,
                )) {
                  return 'Enter a valid full name.';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'PHONE NUMBER',

              style:
              TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 11,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            TextFormField(
              controller:
              phoneController,

              enabled:
              !saving,

              keyboardType:
              TextInputType.phone,

              textInputAction:
              TextInputAction.done,

              autofillHints:
              const <String>[
                AutofillHints.telephoneNumber,
              ],

              decoration:
              _profileInput(
                hint:
                'e.g. 0123456789 or +60123456789',

                icon:
                Icons.phone_outlined,
              ),

              validator:
                  (value) {
                final String rawPhone =
                    value?.trim() ?? '';

                // ----------------------------------------------------------
                // REQUIRED
                // ----------------------------------------------------------

                if (rawPhone.isEmpty) {
                  return 'Phone number is required.';
                }

                // ----------------------------------------------------------
                // ONLY ALLOW PHONE CHARACTERS
                //
                // Accept:
                // +60 12-345 6789
                // 012-345 6789
                // 03-1234 5678
                //
                // Reject:
                // abc123
                // 0123#456
                // ----------------------------------------------------------

                if (!RegExp(
                  r'^[0-9+\-\s()]+$',
                ).hasMatch(
                  rawPhone,
                )) {
                  return 'Phone number contains invalid characters.';
                }

                // ----------------------------------------------------------
                // NORMALIZE
                //
                // +60 12-345 6789
                // becomes
                // +60123456789
                // ----------------------------------------------------------

                String normalizedPhone =
                rawPhone.replaceAll(
                  RegExp(
                    r'[\s\-()]',
                  ),
                  '',
                );

                // ----------------------------------------------------------
                // PLUS SIGN RULE
                // ----------------------------------------------------------

                if (normalizedPhone.contains(
                  '+',
                )) {
                  if (!normalizedPhone.startsWith(
                    '+',
                  )) {
                    return 'The + symbol must be at the beginning.';
                  }

                  if ('+'.allMatches(
                    normalizedPhone,
                  ).length >
                      1) {
                    return 'Enter a valid phone number.';
                  }
                }

                // ----------------------------------------------------------
                // MALAYSIA INTERNATIONAL FORMAT
                //
                // +601XXXXXXXX
                // +601XXXXXXXXX
                //
                // Malaysian mobile prefixes use 01.
                // ----------------------------------------------------------

                final bool malaysiaMobileInternational =
                RegExp(
                  r'^\+601\d{8,9}$',
                ).hasMatch(
                  normalizedPhone,
                );

                // ----------------------------------------------------------
                // MALAYSIA LOCAL MOBILE FORMAT
                //
                // 01XXXXXXXX
                // 01XXXXXXXXX
                // ----------------------------------------------------------

                final bool malaysiaMobileLocal =
                RegExp(
                  r'^01\d{8,9}$',
                ).hasMatch(
                  normalizedPhone,
                );

                // ----------------------------------------------------------
                // MALAYSIA LANDLINE - LOCAL
                //
                // Examples:
                // 03XXXXXXXX
                // 04XXXXXXX
                // 05XXXXXXX
                // 06XXXXXXX
                // 07XXXXXXX
                // 08XXXXXXX
                // 09XXXXXXX
                // ----------------------------------------------------------

                final bool malaysiaLandlineLocal =
                RegExp(
                  r'^0[3-9]\d{7,8}$',
                ).hasMatch(
                  normalizedPhone,
                );

                // ----------------------------------------------------------
                // MALAYSIA LANDLINE - INTERNATIONAL
                //
                // Example:
                // +60312345678
                // ----------------------------------------------------------

                final bool malaysiaLandlineInternational =
                RegExp(
                  r'^\+60[3-9]\d{7,8}$',
                ).hasMatch(
                  normalizedPhone,
                );

                // ----------------------------------------------------------
                // FINAL VALIDATION
                // ----------------------------------------------------------

                final bool validPhone =
                    malaysiaMobileLocal ||
                        malaysiaMobileInternational ||
                        malaysiaLandlineLocal ||
                        malaysiaLandlineInternational;

                if (!validPhone) {
                  return 'Enter a valid Malaysian phone number.';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 24,
            ),

            SizedBox(
              height: 52,

              child:
              ElevatedButton(
                onPressed:
                saving
                    ? null
                    : save,

                child:
                saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                    Colors.white,
                  ),
                )
                    : const Text(
                  'Save Changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// INPUT DECORATION
// =================================================================

InputDecoration _profileInput({
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    hintText:
    hint,

    prefixIcon:
    Icon(
      icon,
      color:
      AppColors.textSecondary,
    ),

    filled:
    true,

    fillColor:
    AppColors.surface,

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
