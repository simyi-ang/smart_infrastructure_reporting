import 'package:flutter/material.dart';

import '../../models/infrastructure_report.dart';
import '../../models/malaysia_open_data.dart';

import '../../services/auth_service.dart';
import '../../services/citizen_dashboard_service.dart';
import '../../services/malaysia_open_data_service.dart';

import '../../theme/app_colors.dart';

import '../reports/create_report_details_screen.dart';
import '../reports/my_reports_screen.dart';

import 'infrastructure_map_screen.dart';
import 'malaysia_open_data_screen.dart';
import 'profile_screen.dart';

class CitizenDashboardScreen
    extends StatefulWidget {
  const CitizenDashboardScreen({
    super.key,
  });

  @override
  State<CitizenDashboardScreen> createState() =>
      _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState
    extends State<CitizenDashboardScreen> {
  final CitizenDashboardService dashboardService =
  CitizenDashboardService();

  final AuthService authService =
  AuthService();

  final MalaysiaOpenDataService openDataService =
  MalaysiaOpenDataService();

  CitizenDashboardStats stats =
  CitizenDashboardStats.empty();

  List<InfrastructureReport> recentReports =
  [];

  MalaysiaOpenDataSummary? openDataSummary;

  bool loading = true;
  bool loadingOpenData = true;

  String? openDataError;

  String citizenName =
      'Citizen';

  int selectedNavigationIndex = 0;

  @override
  void initState() {
    super.initState();

    loadDashboard();
    loadOpenData();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> loadDashboard() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      final profile =
      await authService
          .getCurrentProfile();

      final CitizenDashboardData data =
      await dashboardService
          .loadDashboard();

      if (!mounted) {
        return;
      }

      setState(() {
        if (profile != null &&
            profile.fullName
                .trim()
                .isNotEmpty) {
          citizenName =
              profile.fullName.trim();
        }

        stats =
            data.stats;

        recentReports =
            data.recentReports;

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
  // MALAYSIA GOVERNMENT OPEN DATA
  // ============================================================

  Future<void> loadOpenData() async {
    if (mounted) {
      setState(() {
        loadingOpenData = true;
        openDataError = null;
      });
    }

    try {
      final MalaysiaOpenDataSummary result =
      await openDataService
          .getPublicTransportSummary();

      if (!mounted) {
        return;
      }

      setState(() {
        openDataSummary = result;
        loadingOpenData = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingOpenData = false;
        openDataError =
            e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  Future<void> openMalaysiaOpenData() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const MalaysiaOpenDataScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await loadOpenData();
  }

  // ============================================================
  // CREATE REPORT
  // ============================================================

  Future<void> openCreateReport() async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
        const CreateReportDetailsScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await loadDashboard();
  }

  // ============================================================
  // MY REPORTS
  // ============================================================

  Future<void> openMyReports() async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
        const MyReportsScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await loadDashboard();
  }

  // ============================================================
  // INFRASTRUCTURE MAP
  // ============================================================

  Future<void> openInfrastructureMap() async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
        const InfrastructureMapScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      selectedNavigationIndex = 0;
    });

    await loadDashboard();
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> openProfile() async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
        const ProfileScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      selectedNavigationIndex = 0;
    });

    await loadDashboard();
  }

  // ============================================================
  // COMMUNITY
  // ============================================================

  void openCommunity() {
    showMessage(
      'Community feature is not included in the approved scope.',
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void handleNavigation(
      int index,
      ) {
    setState(() {
      selectedNavigationIndex =
          index;
    });

    switch (index) {
      case 0:
        break;

      case 1:
        openMyReports();
        break;

      case 2:
        openInfrastructureMap();
        break;

      case 3:
        openCommunity();

        Future.delayed(
          const Duration(
            milliseconds: 200,
          ),
              () {
            if (mounted) {
              setState(() {
                selectedNavigationIndex =
                0;
              });
            }
          },
        );

        break;

      case 4:
        openProfile();
        break;
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
        content: Text(
          message,
        ),
      ),
    );
  }

  // ============================================================
  // GREETING
  // ============================================================

  String get greeting {
    final int hour =
        DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning,';
    }

    if (hour < 18) {
      return 'Good afternoon,';
    }

    return 'Good evening,';
  }

  // ============================================================
  // DISPLAY NAME
  // ============================================================

  String get displayName {
    if (citizenName
        .trim()
        .isEmpty) {
      return 'Citizen';
    }

    return citizenName;
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String get initials {
    final List<String> parts =
    citizenName
        .trim()
        .split(
      RegExp(
        r'\s+',
      ),
    )
        .where(
          (
          String value,
          ) =>
      value.isNotEmpty,
    )
        .toList();

    if (parts.isEmpty) {
      return 'C';
    }

    if (parts.length == 1) {
      return parts.first
          .substring(
        0,
        1,
      )
          .toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
        '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  // ============================================================
  // COMMUNITY LEVEL
  // ============================================================

  int get communityLevel {
    return (stats.contributionPoints ~/
        100) +
        1;
  }

  // ============================================================
  // POINTS TO NEXT LEVEL
  // ============================================================

  int get nextLevelPoints {
    const int levelSize =
    100;

    final int currentPoints =
        stats.contributionPoints;

    final int remainder =
        currentPoints %
            levelSize;

    if (remainder == 0 &&
        currentPoints > 0) {
      return levelSize;
    }

    return levelSize -
        remainder;
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String reportStatusText(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'VERIFIED';

      case 'in_progress':
        return 'IN PROGRESS';

      case 'completed':
        return 'COMPLETED';

      case 'rejected':
        return 'REJECTED';

      default:
        return 'PENDING';
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color reportStatusColor(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;

      case 'pending':
        return AppColors.warning;

      case 'rejected':
        return AppColors.danger;

      case 'verified':
      case 'in_progress':
      default:
        return AppColors.primary;
    }
  }

  // ============================================================
  // CATEGORY ICON
  // ============================================================

  String categoryIcon(
      String category,
      ) {
    switch (category.toLowerCase()) {
      case 'road damage':
        return '🛣️';

      case 'street light':
        return '💡';

      case 'drainage':
        return '🌊';

      case 'public facility':
        return '🏗️';

      default:
        return '📌';
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

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh:
          loadDashboard,

          child: loading
              ? ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            children:
            const [
              SizedBox(
                height: 300,
              ),

              Center(
                child:
                CircularProgressIndicator(),
              ),
            ],
          )
              : ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding:
            const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),

            children: [
              // ==========================================
              // HEADER
              // ==========================================

              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,

                    alignment:
                    Alignment.center,

                    decoration:
                    const BoxDecoration(
                      color:
                      AppColors.primaryDark,

                      shape:
                      BoxShape.circle,
                    ),

                    child:
                    Text(
                      initials,

                      style:
                      const TextStyle(
                        color:
                        Colors.white,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 11,
                  ),

                  Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          greeting,

                          style:
                          const TextStyle(
                            color:
                            AppColors.textSecondary,

                            fontSize: 10,
                          ),
                        ),

                        Text(
                          displayName,

                          maxLines: 1,

                          overflow:
                          TextOverflow.ellipsis,

                          style:
                          const TextStyle(
                            fontSize: 15,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
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
                        AppColors.border,
                      ),
                    ),

                    child:
                    IconButton(
                      tooltip:
                      'Refresh',

                      onPressed:
                      loading
                          ? null
                          : loadDashboard,

                      icon:
                      const Icon(
                        Icons.refresh,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              // ==========================================
              // IMPACT SCORE
              // ==========================================

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
                  const Color(
                    0xFF083340,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors.primaryDark,
                  ),
                ),

                child: Row(
                  children: [
                    SizedBox(
                      width: 95,
                      height: 95,

                      child: Stack(
                        alignment:
                        Alignment.center,

                        children: [
                          SizedBox(
                            width: 85,
                            height: 85,

                            child:
                            CircularProgressIndicator(
                              value:
                              (stats.impactScore /
                                  100)
                                  .clamp(
                                0.0,
                                1.0,
                              ),

                              strokeWidth:
                              8,

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

                                  fontSize: 21,

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

                                  fontSize: 7,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 17,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'Your Impact Score',

                            style:
                            TextStyle(
                              fontSize: 15,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          const Text(
                            'Helping improve your community',

                            style:
                            TextStyle(
                              color:
                              AppColors.textSecondary,

                              fontSize: 10,
                            ),
                          ),

                          const SizedBox(
                            height: 13,
                          ),

                          Wrap(
                            spacing: 7,
                            runSpacing: 7,

                            children: [
                              _SmallBadge(
                                icon:
                                Icons.star_outline,

                                text:
                                '${stats.contributionPoints} pts',

                                color:
                                AppColors.success,
                              ),

                              _SmallBadge(
                                icon:
                                Icons.emoji_events_outlined,

                                text:
                                stats.citizenRank == 0
                                    ? 'Unranked'
                                    : 'Rank #${stats.citizenRank}',

                                color:
                                AppColors.primary,
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
                height: 22,
              ),

              // ==========================================
              // QUICK ACTIONS
              // ==========================================

              const Text(
                'Quick Actions',

                style:
                TextStyle(
                  fontSize: 14,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 11,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    _QuickActionCard(
                      emoji:
                      '📝',

                      title:
                      'Report Issue',

                      subtitle:
                      'Submit a new report',

                      onTap:
                      openCreateReport,
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                    _QuickActionCard(
                      emoji:
                      '🗺️',

                      title:
                      'Infrastructure Map',

                      subtitle:
                      'View nearby issues',

                      onTap:
                      openInfrastructureMap,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    _QuickActionCard(
                      emoji:
                      '📊',

                      title:
                      'My Reports',

                      subtitle:
                      '${stats.totalReports} submitted',

                      onTap:
                      openMyReports,
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                    _QuickActionCard(
                      emoji:
                      '👤',

                      title:
                      'Profile',

                      subtitle:
                      'Account & security',

                      onTap:
                      openProfile,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 20,
              ),

              // ==========================================
              // CONTRIBUTION
              // ==========================================

              Container(
                padding:
                const EdgeInsets.all(
                  15,
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
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Your Contribution',

                      style:
                      TextStyle(
                        fontSize: 13,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 17,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                          _ContributionItem(
                            icon:
                            '📋',

                            value:
                            '${stats.totalReports}',

                            label:
                            'Reports',
                          ),
                        ),

                        Container(
                          height: 45,
                          width: 1,

                          color:
                          AppColors.border,
                        ),

                        Expanded(
                          child:
                          _ContributionItem(
                            icon:
                            '⭐',

                            value:
                            '${stats.contributionPoints}',

                            label:
                            'Points',
                          ),
                        ),

                        Container(
                          height: 45,
                          width: 1,

                          color:
                          AppColors.border,
                        ),

                        Expanded(
                          child:
                          _ContributionItem(
                            icon:
                            '🏆',

                            value:
                            stats.citizenRank == 0
                                ? '-'
                                : '#${stats.citizenRank}',

                            label:
                            'Ranking',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 15,
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
                          child:
                          _MiniStatistic(
                            title:
                            'Pending',

                            value:
                            stats.pendingReports,

                            color:
                            AppColors.warning,
                          ),
                        ),

                        Expanded(
                          child:
                          _MiniStatistic(
                            title:
                            'Verified',

                            value:
                            stats.verifiedReports,

                            color:
                            AppColors.primary,
                          ),
                        ),

                        Expanded(
                          child:
                          _MiniStatistic(
                            title:
                            'Active',

                            value:
                            stats.inProgressReports,

                            color:
                            AppColors.primary,
                          ),
                        ),

                        Expanded(
                          child:
                          _MiniStatistic(
                            title:
                            'Done',

                            value:
                            stats.completedReports,

                            color:
                            AppColors.success,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets.all(
                        10,
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
                          10,
                        ),
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .military_tech_outlined,

                            color:
                            AppColors.primary,

                            size: 17,
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child:
                            Text(
                              'Community Guardian • '
                                  'Level $communityLevel • '
                                  '$nextLevelPoints pts to next level',

                              style:
                              const TextStyle(
                                color:
                                AppColors.textSecondary,

                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              // ==========================================
              // MALAYSIA GOVERNMENT OPEN DATA
              // ==========================================

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
                  AppColors.surface,

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
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Container(
                          width:
                          38,

                          height:
                          38,

                          decoration:
                          BoxDecoration(
                            color:
                            AppColors.primary
                                .withOpacity(
                              0.08,
                            ),

                            borderRadius:
                            BorderRadius.circular(
                              10,
                            ),
                          ),

                          child:
                          const Icon(
                            Icons.account_balance_outlined,

                            color:
                            AppColors.primary,

                            size:
                            20,
                          ),
                        ),

                        const SizedBox(
                          width:
                          10,
                        ),

                        const Expanded(
                          child:
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [
                              Text(
                                'Malaysia Open Data',

                                style:
                                TextStyle(
                                  fontSize:
                                  13,

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),

                              SizedBox(
                                height:
                                2,
                              ),

                              Text(
                                'Official transport infrastructure data',

                                style:
                                TextStyle(
                                  color:
                                  AppColors.textSecondary,

                                  fontSize:
                                  8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          tooltip:
                          'Refresh open data',

                          onPressed:
                          loadingOpenData
                              ? null
                              : loadOpenData,

                          icon:
                          const Icon(
                            Icons.refresh,

                            size:
                            18,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                      13,
                    ),

                    if (loadingOpenData)
                      const Padding(
                        padding:
                        EdgeInsets.symmetric(
                          vertical:
                          14,
                        ),

                        child:
                        Center(
                          child:
                          CircularProgressIndicator(),
                        ),
                      )
                    else if (openDataSummary != null) ...[
                      Text(
                        openDataService.formatNumber(
                          openDataSummary!
                              .latest
                              .totalTrips,
                        ),

                        style:
                        const TextStyle(
                          color:
                          AppColors.primary,

                          fontSize:
                          22,

                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height:
                        2,
                      ),

                      Text(
                        'public transport trips • '
                            '${openDataService.formatDate(openDataSummary!.latest.date)}',

                        style:
                        const TextStyle(
                          color:
                          AppColors.textSecondary,

                          fontSize:
                          8,
                        ),
                      ),

                      const SizedBox(
                        height:
                        12,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                            _OpenDataMiniMetric(
                              icon:
                              Icons.directions_bus_outlined,

                              label:
                              'Bus',

                              value:
                              openDataService.formatNumber(
                                openDataSummary!
                                    .latest
                                    .busTotal,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width:
                            8,
                          ),

                          Expanded(
                            child:
                            _OpenDataMiniMetric(
                              icon:
                              Icons.train_outlined,

                              label:
                              'Rail',

                              value:
                              openDataService.formatNumber(
                                openDataSummary!
                                    .latest
                                    .railTotal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        openDataError ??
                            'Government Open Data is temporarily unavailable.',

                        style:
                        const TextStyle(
                          color:
                          AppColors.textSecondary,

                          fontSize:
                          9,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height:
                      12,
                    ),

                    SizedBox(
                      width:
                      double.infinity,

                      child:
                      OutlinedButton.icon(
                        onPressed:
                        openMalaysiaOpenData,

                        icon:
                        const Icon(
                          Icons.open_in_new,

                          size:
                          16,
                        ),

                        label:
                        const Text(
                          'View Government Open Data',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      6,
                    ),

                    const Text(
                      'Source: data.gov.my • Prasarana Malaysia • Ministry of Transport',

                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,

                        fontSize:
                        7,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                22,
              ),

              // ==========================================
              // RECENT ACTIVITY
              // ==========================================

              Row(
                children: [
                  const Expanded(
                    child:
                    Text(
                      'Recent Activity',

                      style:
                      TextStyle(
                        fontSize: 14,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed:
                    openMyReports,

                    child:
                    const Text(
                      'See all →',

                      style:
                      TextStyle(
                        color:
                        AppColors.primary,

                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 5,
              ),

              if (recentReports.isEmpty)
                Container(
                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets.symmetric(
                    vertical: 35,
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
                        Icons.assignment_outlined,

                        size: 40,

                        color:
                        AppColors.textSecondary,
                      ),

                      SizedBox(
                        height: 8,
                      ),

                      Text(
                        'No reports yet',

                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      SizedBox(
                        height: 4,
                      ),

                      Text(
                        'Submit your first infrastructure report.',

                        style:
                        TextStyle(
                          color:
                          AppColors.textSecondary,

                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...recentReports.map(
                      (
                      InfrastructureReport report,
                      ) {
                    return Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 10,
                      ),

                      child:
                      _RecentReportCard(
                        report:
                        report,

                        icon:
                        categoryIcon(
                          report.category,
                        ),

                        statusText:
                        reportStatusText(
                          report.status,
                        ),

                        statusColor:
                        reportStatusColor(
                          report.status,
                        ),

                        onTap:
                        openMyReports,
                      ),
                    );
                  },
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
        currentIndex:
        selectedNavigationIndex,

        onTap:
        handleNavigation,

        backgroundColor:
        AppColors.surface,

        selectedItemColor:
        AppColors.primary,

        unselectedItemColor:
        AppColors.textSecondary,

        type:
        BottomNavigationBarType.fixed,

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
// QUICK ACTION CARD
// =================================================================

class _QuickActionCard
    extends StatelessWidget {
  final String emoji;

  final String title;

  final String subtitle;

  final VoidCallback onTap;

  const _QuickActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color:
      Colors.transparent,

      child: InkWell(
        onTap:
        onTap,

        borderRadius:
        BorderRadius.circular(
          15,
        ),

        child: Container(
          height: 120,

          padding:
          const EdgeInsets.all(
            13,
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
              AppColors.primaryDark,
            ),
          ),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                emoji,

                style:
                const TextStyle(
                  fontSize: 24,
                ),
              ),

              const Spacer(),

              Text(
                title,

                style:
                const TextStyle(
                  fontSize: 12,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                subtitle,

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
      ),
    );
  }
}

// =================================================================
// CONTRIBUTION ITEM
// =================================================================

class _ContributionItem
    extends StatelessWidget {
  final String icon;

  final String value;

  final String label;

  const _ContributionItem({
    required this.icon,
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
          icon,

          style:
          const TextStyle(
            fontSize: 18,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          value,

          style:
          const TextStyle(
            color:
            AppColors.primary,

            fontSize: 20,

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
    );
  }
}

// =================================================================
// MINI STATISTIC
// =================================================================

class _MiniStatistic
    extends StatelessWidget {
  final String title;

  final int value;

  final Color color;

  const _MiniStatistic({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Text(
          '$value',

          style:
          TextStyle(
            color:
            color,

            fontSize: 16,

            fontWeight:
            FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 3,
        ),

        Text(
          title,

          style:
          const TextStyle(
            color:
            AppColors.textSecondary,

            fontSize: 8,
          ),
        ),
      ],
    );
  }
}

// =================================================================
// SMALL BADGE
// =================================================================

class _SmallBadge
    extends StatelessWidget {
  final IconData icon;

  final String text;

  final Color color;

  const _SmallBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),

      decoration:
      BoxDecoration(
        color:
        color.withOpacity(
          0.08,
        ),

        borderRadius:
        BorderRadius.circular(
          20,
        ),

        border:
        Border.all(
          color:
          color.withOpacity(
            0.6,
          ),
        ),
      ),

      child: Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          Icon(
            icon,

            color:
            color,

            size: 12,
          ),

          const SizedBox(
            width: 4,
          ),

          Text(
            text,

            style:
            TextStyle(
              color:
              color,

              fontSize: 8,

              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// OPEN DATA MINI METRIC
// =================================================================

class _OpenDataMiniMetric
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OpenDataMiniMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        10,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.primary
            .withOpacity(
          0.05,
        ),

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),

      child:
      Row(
        children: [
          Icon(
            icon,

            color:
            AppColors.primary,

            size:
            17,
          ),

          const SizedBox(
            width:
            7,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  value,

                  maxLines:
                  1,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    color:
                    AppColors.primary,

                    fontSize:
                    11,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                Text(
                  label,

                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,

                    fontSize:
                    7,
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

// =================================================================
// RECENT REPORT CARD
// =================================================================

class _RecentReportCard
    extends StatelessWidget {
  final InfrastructureReport report;

  final String icon;

  final String statusText;

  final Color statusColor;

  final VoidCallback onTap;

  const _RecentReportCard({
    required this.report,
    required this.icon,
    required this.statusText,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color:
      Colors.transparent,

      child: InkWell(
        onTap:
        onTap,

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        child: Container(
          padding:
          const EdgeInsets.all(
            12,
          ),

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

          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,

                alignment:
                Alignment.center,

                decoration:
                BoxDecoration(
                  color:
                  statusColor.withOpacity(
                    0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),

                  border:
                  Border.all(
                    color:
                    statusColor.withOpacity(
                      0.5,
                    ),
                  ),
                ),

                child:
                Text(
                  icon,

                  style:
                  const TextStyle(
                    fontSize: 20,
                  ),
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
                      report.title,

                      maxLines: 1,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        fontSize: 11,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      '📍 ${report.address}',

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

                    const SizedBox(
                      height: 6,
                    ),

                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        statusColor.withOpacity(
                          0.1,
                        ),

                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                      ),

                      child:
                      Text(
                        statusText,

                        style:
                        TextStyle(
                          color:
                          statusColor,

                          fontSize: 7,

                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,

                color:
                AppColors.textSecondary,

                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}