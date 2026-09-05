import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/community_report.dart';
import '../../services/community_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import 'community_report_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
  });

  @override
  State<CommunityScreen> createState() =>
      _CommunityScreenState();
}

class _CommunityScreenState
    extends State<CommunityScreen>
    with WidgetsBindingObserver {
  final CommunityService service =
      CommunityService.instance;

  final LocationService locationService =
  LocationService();

  final TextEditingController searchController =
  TextEditingController();

  List<CommunityReport> reports =
  <CommunityReport>[];

  bool loading = true;
  bool refreshing = false;
  bool detectingLocation = false;

  String? error;

  double? latitude;
  double? longitude;

  int selectedTab = 0;

  String selectedCategory = 'All';
  String selectedStatus = 'All';

  int radiusMetres = 5000;

  DateTime? lastUpdatedAt;

  Timer? refreshTimer;

  static const List<String> categories = [
    'All',
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  static const List<String> statuses = [
    'All',
    'Submitted',
    'Acknowledged',
    'In Progress',
    'Resolved',
    'Completed',
  ];

  static const List<String> tabs = [
    'Nearby',
    'Hot',
    'Recent',
    'Resolved',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    _loadWithLocation();

    refreshTimer =
        Timer.periodic(
          const Duration(
            seconds: 20,
          ),
              (_) async {
            if (!mounted ||
                loading ||
                refreshing ||
                detectingLocation) {
              return;
            }

            await _loadReports(
              silent: true,
            );
          },
        );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();

    WidgetsBinding.instance.removeObserver(
      this,
    );

    searchController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state ==
        AppLifecycleState.resumed) {
      _loadReports(
        silent: true,
      );
    }
  }

  // ============================================================
  // SORT
  // ============================================================

  String get sort {
    switch (selectedTab) {
      case 1:
        return 'hot';

      case 2:
        return 'recent';

      case 3:
        return 'resolved';

      default:
        return 'nearby';
    }
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> _loadWithLocation() async {
    if (mounted) {
      setState(() {
        detectingLocation =
        true;
      });
    }

    try {
      final result =
      await locationService
          .getCurrentLocationWithAddress();

      latitude =
          result.latitude;

      longitude =
          result.longitude;
    } catch (_) {
      latitude = null;
      longitude = null;
    } finally {
      if (mounted) {
        setState(() {
          detectingLocation =
          false;
        });
      }
    }

    await _loadReports();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadReports({
    bool silent = false,
  }) async {
    if (!mounted) {
      return;
    }

    if (silent) {
      setState(() {
        refreshing =
        true;
      });
    } else {
      setState(() {
        loading =
        true;

        error =
        null;
      });
    }

    try {
      String? status;

      if (selectedTab == 3) {
        status =
        'Resolved';
      } else {
        status =
        selectedStatus ==
            'All'
            ? null
            : selectedStatus;
      }

      final result =
      await service.getReports(
        latitude:
        latitude,
        longitude:
        longitude,
        radiusMetres:
        radiusMetres,
        category:
        selectedCategory ==
            'All'
            ? null
            : selectedCategory,
        status:
        status,
        sort:
        sort,
        limit:
        60,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        reports =
            result;

        loading =
        false;

        refreshing =
        false;

        error =
        null;

        lastUpdatedAt =
            DateTime.now();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading =
        false;

        refreshing =
        false;

        if (!silent) {
          error =
              e
                  .toString()
                  .replaceFirst(
                'Exception: ',
                '',
              );
        }
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<CommunityReport>
  get visibleReports {
    final String query =
    searchController.text
        .trim()
        .toLowerCase();

    if (query.isEmpty) {
      return reports;
    }

    return reports.where(
          (
          report,
          ) {
        return report.title
            .toLowerCase()
            .contains(
          query,
        ) ||
            report.address
                .toLowerCase()
                .contains(
              query,
            ) ||
            report.referenceNumber
                .toLowerCase()
                .contains(
              query,
            ) ||
            report.category
                .toLowerCase()
                .contains(
              query,
            ) ||
            report.status
                .toLowerCase()
                .contains(
              query,
            );
      },
    ).toList();
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  int get activeReports {
    return reports.where(
          (
          report,
          ) {
        final status =
        report.status
            .trim()
            .toLowerCase();

        return status !=
            'resolved' &&
            status !=
                'completed';
      },
    ).length;
  }

  int get affectedCount {
    return reports.fold(
      0,
          (
          total,
          report,
          ) =>
      total +
          report.affectedCount,
    );
  }

  int get evidenceCount {
    return reports.fold(
      0,
          (
          total,
          report,
          ) =>
      total +
          report.contributionCount,
    );
  }

  bool get hasFilters {
    return selectedCategory !=
        'All' ||
        selectedStatus !=
            'All' ||
        radiusMetres !=
            5000;
  }

  String get syncText {
    if (refreshing) {
      return 'Updating';
    }

    if (lastUpdatedAt ==
        null) {
      return 'Sync';
    }

    final difference =
    DateTime.now().difference(
      lastUpdatedAt!,
    );

    if (difference.inSeconds <
        20) {
      return 'Live';
    }

    if (difference.inMinutes <
        1) {
      return '${difference.inSeconds}s';
    }

    return '${difference.inMinutes}m';
  }

  // ============================================================
  // OPEN REPORT
  // ============================================================

  Future<void> _openReport(
      CommunityReport report,
      ) async {
    final changed =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
            CommunityReportDetailScreen(
              reportId:
              report.id,
              currentLatitude:
              latitude,
              currentLongitude:
              longitude,
            ),
      ),
    );

    if (changed == true) {
      await _loadReports(
        silent: true,
      );
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  Future<void> _showFilters() async {
    String draftCategory =
        selectedCategory;

    String draftStatus =
        selectedStatus;

    int draftRadius =
        radiusMetres;

    final apply =
    await showModalBottomSheet<bool>(
      context:
      context,

      isScrollControlled:
      true,

      backgroundColor:
      AppColors.surface,

      showDragHandle:
      true,

      builder:
          (
          sheetContext,
          ) {
        return StatefulBuilder(
          builder:
              (
              context,
              setSheetState,
              ) {
            return SafeArea(
              child:
              Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  4,
                  18,
                  20,
                ),

                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color:
                          AppColors.primary,
                        ),

                        SizedBox(
                          width: 9,
                        ),

                        Text(
                          'Filter Community',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontSize:
                            17,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    const Text(
                      'Choose the issues you want to see.',
                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize:
                        9,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Category',
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children:
                      categories.map(
                            (
                            item,
                            ) {
                          return ChoiceChip(
                            selected:
                            draftCategory ==
                                item,

                            label:
                            Text(
                              item,
                            ),

                            onSelected:
                                (_) {
                              setSheetState(
                                    () {
                                  draftCategory =
                                      item;
                                },
                              );
                            },
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    if (selectedTab !=
                        3) ...[
                      const Text(
                        'Status',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children:
                        statuses.map(
                              (
                              item,
                              ) {
                            return ChoiceChip(
                              selected:
                              draftStatus ==
                                  item,

                              label:
                              Text(
                                item,
                              ),

                              onSelected:
                                  (_) {
                                setSheetState(
                                      () {
                                    draftStatus =
                                        item;
                                  },
                                );
                              },
                            );
                          },
                        ).toList(),
                      ),

                      const SizedBox(
                        height: 18,
                      ),
                    ],

                    Row(
                      children: [
                        const Expanded(
                          child:
                          Text(
                            'Nearby radius',
                            style:
                            TextStyle(
                              color:
                              Colors.white,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ),

                        Text(
                          '${(draftRadius / 1000).toStringAsFixed(0)} km',
                          style:
                          const TextStyle(
                            color:
                            AppColors.primary,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    Slider(
                      value:
                      draftRadius
                          .toDouble(),

                      min: 1000,

                      max: 10000,

                      divisions: 9,

                      label:
                      '${(draftRadius / 1000).toStringAsFixed(0)} km',

                      onChanged:
                          (
                          value,
                          ) {
                        setSheetState(
                              () {
                            draftRadius =
                                value.round();
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                          OutlinedButton(
                            onPressed:
                                () {
                              setSheetState(
                                    () {
                                  draftCategory =
                                  'All';

                                  draftStatus =
                                  'All';

                                  draftRadius =
                                  5000;
                                },
                              );
                            },

                            child:
                            const Text(
                              'Reset',
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          flex: 2,

                          child:
                          ElevatedButton.icon(
                            onPressed:
                                () {
                              Navigator.pop(
                                sheetContext,
                                true,
                              );
                            },

                            icon:
                            const Icon(
                              Icons.check_rounded,
                            ),

                            label:
                            const Text(
                              'Apply Filters',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (apply != true) {
      return;
    }

    setState(() {
      selectedCategory =
          draftCategory;

      selectedStatus =
          draftStatus;

      radiusMetres =
          draftRadius;
    });

    await _loadReports();
  }

  Future<void> _resetFilters() async {
    setState(() {
      selectedCategory =
      'All';

      selectedStatus =
      'All';

      radiusMetres =
      5000;
    });

    await _loadReports();
  }

  // ============================================================
  // TAB ICON
  // ============================================================

  IconData _tabIcon(
      int index,
      ) {
    switch (index) {
      case 1:
        return Icons
            .local_fire_department_outlined;

      case 2:
        return Icons
            .schedule_rounded;

      case 3:
        return Icons
            .verified_outlined;

      default:
        return Icons
            .near_me_outlined;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final visible =
        visibleReports;

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body:
      SafeArea(
        child:
        RefreshIndicator(
          onRefresh:
              () =>
              _loadReports(
                silent: true,
              ),

          child:
          CustomScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            slivers: [
              SliverToBoxAdapter(
                child:
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    8,
                  ),

                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      // =============================
                      // HEADER
                      // =============================

                      Row(
                        children: [
                          _HeaderButton(
                            icon:
                            Icons
                                .arrow_back_rounded,

                            tooltip:
                            'Back to Dashboard',

                            onTap:
                                () {
                              Navigator.pop(
                                context,
                              );
                            },
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Container(
                            width: 42,
                            height: 42,

                            decoration:
                            BoxDecoration(
                              color:
                              AppColors.primary
                                  .withOpacity(
                                0.10,
                              ),

                              borderRadius:
                              BorderRadius.circular(
                                12,
                              ),
                            ),

                            child:
                            const Icon(
                              Icons
                                  .groups_2_outlined,

                              color:
                              AppColors.primary,
                            ),
                          ),

                          const SizedBox(
                            width: 11,
                          ),

                          const Expanded(
                            child:
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,

                              children: [
                                Text(
                                  'Community',

                                  style:
                                  TextStyle(
                                    color:
                                    Colors.white,

                                    fontSize:
                                    21,

                                    fontWeight:
                                    FontWeight.w800,
                                  ),
                                ),

                                Text(
                                  'See what is happening around you',

                                  style:
                                  TextStyle(
                                    color:
                                    AppColors.textSecondary,

                                    fontSize:
                                    9,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          InkWell(
                            onTap:
                            refreshing
                                ? null
                                : () {
                              _loadReports(
                                silent:
                                true,
                              );
                            },

                            borderRadius:
                            BorderRadius.circular(
                              20,
                            ),

                            child:
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),

                              decoration:
                              BoxDecoration(
                                color:
                                AppColors.surface,

                                borderRadius:
                                BorderRadius.circular(
                                  20,
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
                                  refreshing
                                      ? const SizedBox(
                                    width: 13,
                                    height: 13,

                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth:
                                      2,
                                    ),
                                  )
                                      : const Icon(
                                    Icons.sync_rounded,

                                    size: 14,

                                    color:
                                    AppColors.primary,
                                  ),

                                  const SizedBox(
                                    width: 4,
                                  ),

                                  Text(
                                    syncText,

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
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // =============================
                      // INTRO
                      // =============================

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
                            0.05,
                          ),

                          borderRadius:
                          BorderRadius.circular(
                            13,
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
                          CrossAxisAlignment.start,

                          children: [
                            Icon(
                              Icons
                                  .info_outline_rounded,

                              color:
                              AppColors.primary,

                              size: 17,
                            ),

                            SizedBox(
                              width: 8,
                            ),

                            Expanded(
                              child:
                              Text(
                                'Find nearby infrastructure issues, '
                                    'confirm if you are affected, check progress '
                                    'and contribute useful current evidence.',

                                style:
                                TextStyle(
                                  color:
                                  AppColors.textSecondary,

                                  fontSize:
                                  9,

                                  height:
                                  1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // =============================
                      // OVERVIEW
                      // =============================

                      if (!loading &&
                          error ==
                              null)
                        _OverviewCard(
                          reports:
                          reports.length,

                          active:
                          activeReports,

                          affected:
                          affectedCount,

                          evidence:
                          evidenceCount,
                        ),

                      if (!loading &&
                          error ==
                              null)
                        const SizedBox(
                          height: 14,
                        ),

                      // =============================
                      // SEARCH
                      // =============================

                      TextField(
                        controller:
                        searchController,

                        onChanged:
                            (_) {
                          setState(
                                () {},
                          );
                        },

                        decoration:
                        InputDecoration(
                          hintText:
                          'Search issue, address or report ID',

                          prefixIcon:
                          const Icon(
                            Icons.search_rounded,
                          ),

                          suffixIcon:
                          searchController.text
                              .trim()
                              .isEmpty
                              ? null
                              : IconButton(
                            onPressed:
                                () {
                              searchController
                                  .clear();

                              setState(
                                    () {},
                              );
                            },

                            icon:
                            const Icon(
                              Icons.close_rounded,
                            ),
                          ),

                          filled: true,

                          fillColor:
                          AppColors.surface,

                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),

                            borderSide:
                            BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // =============================
                      // LOCATION
                      // =============================

                      _LocationCard(
                        hasLocation:
                        latitude !=
                            null &&
                            longitude !=
                                null,

                        detecting:
                        detectingLocation,

                        radius:
                        radiusMetres,

                        onTap:
                        _loadWithLocation,
                      ),

                      const SizedBox(
                        height: 13,
                      ),

                      // =============================
                      // TABS
                      // =============================

                      SizedBox(
                        height: 40,

                        child:
                        ListView.separated(
                          scrollDirection:
                          Axis.horizontal,

                          itemCount:
                          tabs.length,

                          separatorBuilder:
                              (
                              context,
                              index,
                              ) =>
                          const SizedBox(
                            width: 8,
                          ),

                          itemBuilder:
                              (
                              context,
                              index,
                              ) {
                            return ChoiceChip(
                              avatar:
                              Icon(
                                _tabIcon(
                                  index,
                                ),

                                size: 15,
                              ),

                              selected:
                              selectedTab ==
                                  index,

                              label:
                              Text(
                                tabs[index],
                              ),

                              onSelected:
                                  (_) async {
                                setState(() {
                                  selectedTab =
                                      index;
                                });

                                await _loadReports();
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // =============================
                      // FILTER
                      // =============================

                      Row(
                        children: [
                          Expanded(
                            child:
                            OutlinedButton.icon(
                              onPressed:
                              _showFilters,

                              icon:
                              const Icon(
                                Icons.tune_rounded,
                              ),

                              label:
                              Text(
                                hasFilters
                                    ? 'Filters Applied'
                                    : 'Filter Reports',
                              ),
                            ),
                          ),

                          if (hasFilters) ...[
                            const SizedBox(
                              width: 8,
                            ),

                            IconButton(
                              tooltip:
                              'Reset Filters',

                              onPressed:
                              _resetFilters,

                              icon:
                              const Icon(
                                Icons
                                    .restart_alt_rounded,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        loading
                            ? 'Finding community reports...'
                            : '${visible.length} report${visible.length == 1 ? '' : 's'} found',

                        style:
                        const TextStyle(
                          color:
                          AppColors.textSecondary,

                          fontSize:
                          10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===============================
              // LOADING
              // ===============================

              if (loading)
                const SliverFillRemaining(
                  hasScrollBody:
                  false,

                  child:
                  _LoadingState(),
                )

              // ===============================
              // ERROR
              // ===============================

              else if (error !=
                  null)
                SliverFillRemaining(
                  hasScrollBody:
                  false,

                  child:
                  _ErrorState(
                    message:
                    error!,

                    onRetry:
                    _loadReports,
                  ),
                )

              // ===============================
              // EMPTY
              // ===============================

              else if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody:
                    false,

                    child:
                    _EmptyState(
                      hasSearch:
                      searchController.text
                          .trim()
                          .isNotEmpty,

                      hasFilter:
                      hasFilters,

                      clearSearch:
                          () {
                        searchController.clear();

                        setState(
                              () {},
                        );
                      },

                      resetFilter:
                      _resetFilters,
                    ),
                  )

                // ===============================
                // REPORT LIST
                // ===============================

                else
                  SliverPadding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      20,
                      5,
                      20,
                      30,
                    ),

                    sliver:
                    SliverList.separated(
                      itemCount:
                      visible.length,

                      separatorBuilder:
                          (
                          context,
                          index,
                          ) =>
                      const SizedBox(
                        height: 12,
                      ),

                      itemBuilder:
                          (
                          context,
                          index,
                          ) {
                        final report =
                        visible[index];

                        return _CommunityCard(
                          report:
                          report,

                          onTap:
                              () {
                            _openReport(
                              report,
                            );
                          },
                        );
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HEADER BUTTON
// ============================================================

class _HeaderButton
    extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width: 42,
      height: 42,

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
        tooltip,

        onPressed:
        onTap,

        icon:
        Icon(
          icon,

          size: 20,
        ),
      ),
    );
  }
}

// ============================================================
// OVERVIEW
// ============================================================

class _OverviewCard
    extends StatelessWidget {
  final int reports;
  final int active;
  final int affected;
  final int evidence;

  const _OverviewCard({
    required this.reports,
    required this.active,
    required this.affected,
    required this.evidence,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 12,
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

      child:
      Row(
        children: [
          _SummaryMetric(
            value:
            reports,
            label:
            'Reports',
            icon:
            Icons.article_outlined,
          ),

          _SummaryMetric(
            value:
            active,
            label:
            'Active',
            icon:
            Icons
                .pending_actions_outlined,
          ),

          _SummaryMetric(
            value:
            affected,
            label:
            'Affected',
            icon:
            Icons.groups_outlined,
          ),

          _SummaryMetric(
            value:
            evidence,
            label:
            'Evidence',
            icon:
            Icons
                .collections_outlined,
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric
    extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;

  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Expanded(
      child:
      Column(
        children: [
          Icon(
            icon,

            color:
            AppColors.primary,

            size: 17,
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            '$value',

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize:
              13,

              fontWeight:
              FontWeight.w800,
            ),
          ),

          Text(
            label,

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

// ============================================================
// LOCATION CARD
// ============================================================

class _LocationCard
    extends StatelessWidget {
  final bool hasLocation;
  final bool detecting;
  final int radius;
  final Future<void> Function() onTap;

  const _LocationCard({
    required this.hasLocation,
    required this.detecting,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        11,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.surface,

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
      Row(
        children: [
          Icon(
            hasLocation
                ? Icons.my_location_rounded
                : Icons.location_off_outlined,

            color:
            hasLocation
                ? AppColors.primary
                : AppColors.textSecondary,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  hasLocation
                      ? 'Nearby reports enabled'
                      : 'Location unavailable',

                  style:
                  const TextStyle(
                    color:
                    Colors.white,

                    fontSize: 9,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                Text(
                  hasLocation
                      ? 'Within ${(radius / 1000).toStringAsFixed(0)} km of your location'
                      : 'You can still browse community reports.',

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

          TextButton(
            onPressed:
            detecting
                ? null
                : onTap,

            child:
            detecting
                ? const SizedBox(
              width: 15,
              height: 15,

              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
              ),
            )
                : Text(
              hasLocation
                  ? 'Update'
                  : 'Detect',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REPORT CARD
// ============================================================

class _CommunityCard
    extends StatelessWidget {
  final CommunityReport report;
  final VoidCallback onTap;

  const _CommunityCard({
    required this.report,
    required this.onTap,
  });

  String get communityMessage {
    if (report.stillExistsCount >
        report.looksFixedCount *
            2) {
      return 'Community reports that this issue still exists';
    }

    if (report.looksFixedCount >
        report.stillExistsCount *
            2) {
      return 'Community increasingly reports improvement';
    }

    if (report.affectedCount >=
        5) {
      return 'Several citizens are affected by this issue';
    }

    if (report.contributionCount >
        0) {
      return 'Supporting community evidence is available';
    }

    return 'Open this report to view or contribute an update';
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color:
      AppColors.surface,

      borderRadius:
      BorderRadius.circular(
        16,
      ),

      child:
      InkWell(
        borderRadius:
        BorderRadius.circular(
          16,
        ),

        onTap:
        onTap,

        child:
        Container(
          padding:
          const EdgeInsets.all(
            14,
          ),

          decoration:
          BoxDecoration(
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
              Row(
                children: [
                  Expanded(
                    child:
                    Text(
                      report.title,

                      maxLines: 2,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        color:
                        Colors.white,

                        fontSize: 14,

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.primary
                          .withOpacity(
                        0.09,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),

                    child:
                    Text(
                      report.status,

                      style:
                      const TextStyle(
                        color:
                        AppColors.primary,

                        fontSize: 7,

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                report.referenceNumber,

                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,

                  fontSize: 8,
                ),
              ),

              const SizedBox(
                height: 9,
              ),

              Text(
                '${report.category} · '
                    '${report.priority} · '
                    '${report.distanceLabel}',

                style:
                const TextStyle(
                  color:
                  AppColors.primary,

                  fontSize: 8,

                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                report.address,

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
                height: 12,
              ),

              Row(
                children: [
                  _CommunityMetric(
                    report.affectedCount,
                    'Affected',
                  ),

                  _CommunityMetric(
                    report.stillExistsCount,
                    'Still Exists',
                  ),

                  _CommunityMetric(
                    report.looksFixedCount,
                    'Looks Fixed',
                  ),

                  _CommunityMetric(
                    report.contributionCount,
                    'Evidence',
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),

                      child:
                      LinearProgressIndicator(
                        minHeight: 6,

                        value:
                        (report
                            .progressPercentage
                            .clamp(
                          0,
                          100,
                        ) /
                            100)
                            .toDouble(),

                        backgroundColor:
                        AppColors.border,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Text(
                    '${report.progressPercentage.clamp(0, 100)}%',

                    style:
                    const TextStyle(
                      color:
                      AppColors.primary,

                      fontSize: 9,

                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.all(
                  9,
                ),

                decoration:
                BoxDecoration(
                  color:
                  AppColors.background
                      .withOpacity(
                    0.5,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child:
                Row(
                  children: [
                    const Icon(
                      Icons.insights_outlined,

                      color:
                      AppColors.primary,

                      size: 14,
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Expanded(
                      child:
                      Text(
                        communityMessage,

                        style:
                        const TextStyle(
                          color:
                          AppColors.textSecondary,

                          fontSize: 8,
                        ),
                      ),
                    ),

                    const Icon(
                      Icons
                          .chevron_right_rounded,

                      color:
                      AppColors.textSecondary,

                      size: 17,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityMetric
    extends StatelessWidget {
  final int value;
  final String label;

  const _CommunityMetric(
      this.value,
      this.label,
      );

  @override
  Widget build(
      BuildContext context,
      ) {
    return Expanded(
      child:
      Column(
        children: [
          Text(
            '$value',

            style:
            const TextStyle(
              color:
              Colors.white,

              fontWeight:
              FontWeight.w800,

              fontSize: 12,
            ),
          ),

          Text(
            label,

            textAlign:
            TextAlign.center,

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

// ============================================================
// LOADING
// ============================================================

class _LoadingState
    extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const Center(
      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          CircularProgressIndicator(),

          SizedBox(
            height: 12,
          ),

          Text(
            'Finding community activity...',

            style:
            TextStyle(
              color:
              Colors.white,

              fontWeight:
              FontWeight.w600,
            ),
          ),

          SizedBox(
            height: 4,
          ),

          Text(
            'Checking nearby reports and updates',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorState
    extends StatelessWidget {
  final String message;
  final Future<void> Function({
  bool silent,
  }) onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          28,
        ),

        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            const Icon(
              Icons.cloud_off_outlined,

              size: 42,

              color:
              AppColors.textSecondary,
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Community is temporarily unavailable',

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                Colors.white,

                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              message,

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                AppColors.textSecondary,

                fontSize: 9,

                height: 1.4,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            OutlinedButton.icon(
              onPressed:
                  () {
                onRetry();
              },

              icon:
              const Icon(
                Icons.refresh_rounded,
              ),

              label:
              const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY
// ============================================================

class _EmptyState
    extends StatelessWidget {
  final bool hasSearch;
  final bool hasFilter;

  final VoidCallback clearSearch;

  final Future<void> Function()
  resetFilter;

  const _EmptyState({
    required this.hasSearch,
    required this.hasFilter,
    required this.clearSearch,
    required this.resetFilter,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          28,
        ),

        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            const Icon(
              Icons
                  .travel_explore_outlined,

              size: 42,

              color:
              AppColors.primary,
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'No matching reports',

              style:
              TextStyle(
                color:
                Colors.white,

                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              hasSearch
                  ? 'Try another search phrase or clear your search.'
                  : hasFilter
                  ? 'Try widening the area or resetting your filters.'
                  : 'No community reports are available right now.',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                AppColors.textSecondary,

                fontSize: 9,

                height: 1.4,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            if (hasSearch)
              OutlinedButton.icon(
                onPressed:
                clearSearch,

                icon:
                const Icon(
                  Icons.clear_rounded,
                ),

                label:
                const Text(
                  'Clear Search',
                ),
              )
            else if (hasFilter)
              OutlinedButton.icon(
                onPressed:
                resetFilter,

                icon:
                const Icon(
                  Icons
                      .restart_alt_rounded,
                ),

                label:
                const Text(
                  'Reset Filters',
                ),
              ),
          ],
        ),
      ),
    );
  }
}