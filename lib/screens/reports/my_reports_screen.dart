import 'package:flutter/material.dart';

import '../../models/infrastructure_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

import '../citizen/infrastructure_map_screen.dart';
import '../citizen/profile_screen.dart';

import 'create_report_details_screen.dart';
import 'edit_report_screen.dart';
import 'report_detail_screen.dart';
import '../community/community_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({
    super.key,
  });

  @override
  State<MyReportsScreen> createState() =>
      _MyReportsScreenState();
}

class _MyReportsScreenState
    extends State<MyReportsScreen> {
  final ReportService reportService =
  ReportService();

  final TextEditingController searchController =
  TextEditingController();

  List<InfrastructureReport> reports = [];

  bool loading = true;

  String selectedCategory = 'All';
  String selectedPriority = 'All';
  String selectedStatus = 'All';
  String selectedSort = 'Newest';

  final List<String> categories = const [
    'All',
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  final List<String> priorities = const [
    'All',
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  final List<String> statuses = const [
    'All',
    'Pending',
    'Verified',
    'In Progress',
    'Completed',
    'Rejected',
  ];

  final List<String> sortOptions = const [
    'Newest',
    'Oldest',
    'Priority',
    'Status',
  ];

  @override
  void initState() {
    super.initState();

    searchController.addListener(
      _refreshFilters,
    );

    loadReports();
  }

  @override
  void dispose() {
    searchController.removeListener(
      _refreshFilters,
    );

    searchController.dispose();

    super.dispose();
  }

  void _refreshFilters() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> loadReports() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      final result =
      await reportService.getMyReports();

      if (!mounted) {
        return;
      }

      setState(() {
        reports = result;
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

  void showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  List<InfrastructureReport>
  get filteredReports {
    return reportService.applyFilters(
      reports: reports,
      searchQuery: searchController.text,
      category: selectedCategory,
      priority: selectedPriority,
      status: selectedStatus,
      sortBy: selectedSort,
    );
  }

  int countStatus(
      String status,
      ) {
    return reports
        .where(
          (report) =>
      report.status
          .trim()
          .toLowerCase()
          .replaceAll(
        ' ',
        '_',
      ) ==
          status,
    )
        .length;
  }

  bool get filtersActive {
    return searchController.text
        .trim()
        .isNotEmpty ||
        selectedCategory != 'All' ||
        selectedPriority != 'All' ||
        selectedStatus != 'All' ||
        selectedSort != 'Newest';
  }

  void resetFilters() {
    searchController.clear();

    setState(() {
      selectedCategory = 'All';
      selectedPriority = 'All';
      selectedStatus = 'All';
      selectedSort = 'Newest';
    });
  }

  Future<void> createReport() async {
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

    await loadReports();
  }

  Future<void> editReport(
      InfrastructureReport report,
      ) async {
    if (!reportService.canEditReport(
      report,
    )) {
      showMessage(
        'Only pending reports can be edited.',
      );

      return;
    }

    final changed =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditReportScreen(
              report: report,
            ),
      ),
    );

    if (changed == true) {
      await loadReports();
    }
  }

  Future<void> deleteReport(
      InfrastructureReport report,
      ) async {
    if (!reportService.canDeleteReport(
      report,
    )) {
      showMessage(
        'Only pending reports can be deleted.',
      );

      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
              ),
              SizedBox(width: 10),
              Text('Delete Report?'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${report.title}"?\n\n'
                'The report and its evidence images will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
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
              child: const Text(
                'Delete',
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
      await reportService.deleteReport(
        report.id,
      );

      if (!mounted) {
        return;
      }

      showMessage(
        'Report deleted successfully.',
      );

      await loadReports();
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

  Future<void> handleBottomNavigation(
      int index,
      ) async {
    switch (index) {
    // ========================================================
    // HOME
    // ========================================================
      case 0:
        Navigator.pop(
          context,
        );
        break;

    // ========================================================
    // REPORTS
    // ========================================================
      case 1:
      // Already on My Reports.
        break;

    // ========================================================
    // INFRASTRUCTURE MAP
    // ========================================================
      case 2:
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

        await loadReports();
        break;

    // ========================================================
    // COMMUNITY
    // ========================================================
      case 3:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const CommunityScreen(),
          ),
        );

        if (!mounted) {
          return;
        }

        await loadReports();
        break;

    // ========================================================
    // PROFILE
    // ========================================================
      case 4:
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

        await loadReports();
        break;
    }
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

  @override
  Widget build(
      BuildContext context,
      ) {
    final visibleReports =
        filteredReports;

    return Scaffold(
      backgroundColor:
      AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadReports,
                child: loading
                    ? const Center(
                  child:
                  CircularProgressIndicator(),
                )
                    : ListView(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding:
                  const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    24,
                  ),
                  children: [
                    // =====================================
                    // HEADER
                    // =====================================

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Reports',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                '${reports.length} total submission${reports.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color:
                                  AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 42,
                          height: 42,
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
                          child: IconButton(
                            onPressed:
                            createReport,
                            icon: const Icon(
                              Icons.add,
                              color:
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // =====================================
                    // SUMMARY
                    // =====================================

                    Row(
                      children: [
                        Expanded(
                          child: _SummaryBox(
                            value: reports.length
                                .toString(),
                            label: 'Total',
                            color:
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: _SummaryBox(
                            value: countStatus(
                              'in_progress',
                            ).toString(),
                            label: 'Active',
                            color:
                            const Color(
                              0xFF7C6FFF,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: _SummaryBox(
                            value: countStatus(
                              'completed',
                            ).toString(),
                            label: 'Done',
                            color:
                            AppColors.success,
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: _SummaryBox(
                            value: countStatus(
                              'pending',
                            ).toString(),
                            label: 'Pending',
                            color:
                            AppColors.warning,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // =====================================
                    // SEARCH
                    // =====================================

                    TextField(
                      controller:
                      searchController,
                      decoration:
                      InputDecoration(
                        hintText:
                        'Search title, location or reference',
                        hintStyle:
                        const TextStyle(
                          color:
                          AppColors.textSecondary,
                          fontSize: 10,
                        ),
                        prefixIcon:
                        const Icon(
                          Icons.search,
                          color:
                          AppColors.textSecondary,
                        ),
                        suffixIcon:
                        searchController.text
                            .isNotEmpty
                            ? IconButton(
                          onPressed: () {
                            searchController
                                .clear();
                          },
                          icon:
                          const Icon(
                            Icons.close,
                          ),
                        )
                            : null,
                        filled: true,
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
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // =====================================
                    // FILTER / SORT
                    // =====================================

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filter & Sort',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                        if (filtersActive)
                          TextButton.icon(
                            onPressed:
                            resetFilters,
                            icon: const Icon(
                              Icons.restart_alt,
                              size: 15,
                            ),
                            label: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterDropdown(
                          label: 'Category',
                          value:
                          selectedCategory,
                          items: categories,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              selectedCategory =
                                  value;
                            });
                          },
                        ),
                        _FilterDropdown(
                          label: 'Priority',
                          value:
                          selectedPriority,
                          items: priorities,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              selectedPriority =
                                  value;
                            });
                          },
                        ),
                        _FilterDropdown(
                          label: 'Status',
                          value:
                          selectedStatus,
                          items: statuses,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              selectedStatus =
                                  value;
                            });
                          },
                        ),
                        _FilterDropdown(
                          label: 'Sort',
                          value:
                          selectedSort,
                          items: sortOptions,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              selectedSort =
                                  value;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${visibleReports.length} report${visibleReports.length == 1 ? '' : 's'} found',
                            style: const TextStyle(
                              color:
                              AppColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        if (selectedSort !=
                            'Newest')
                          Text(
                            'Sorted by $selectedSort',
                            style:
                            const TextStyle(
                              color:
                              AppColors.primary,
                              fontSize: 8,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    if (visibleReports.isEmpty)
                      _EmptyReports(
                        filtersActive:
                        filtersActive,
                        onReset:
                        resetFilters,
                      ),

                    ...visibleReports.map(
                          (report) {
                        return Padding(
                          padding:
                          const EdgeInsets.only(
                            bottom: 11,
                          ),
                          child: _ReportCard(
                            report: report,
                            formatDate:
                            formatDate,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReportDetailScreen(
                                        reportId:
                                        report.id,
                                      ),
                                ),
                              );

                              if (!mounted) {
                                return;
                              }

                              await loadReports();
                            },
                            onEdit: reportService
                                .canEditReport(
                              report,
                            )
                                ? () {
                              editReport(
                                report,
                              );
                            }
                                : null,
                            onDelete: reportService
                                .canDeleteReport(
                              report,
                            )
                                ? () {
                              deleteReport(
                                report,
                              );
                            }
                                : null,
                          ),
                        );
                      },
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            ),

            // ===============================================
            // BOTTOM NAV
            // ===============================================

            Container(
              decoration:
              const BoxDecoration(
                color:
                AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color:
                    AppColors.border,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                type:
                BottomNavigationBarType.fixed,
                currentIndex: 1,
                backgroundColor:
                AppColors.surface,
                selectedItemColor:
                AppColors.primary,
                unselectedItemColor:
                AppColors.textSecondary,
                onTap:
                handleBottomNavigation,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.home_outlined,
                    ),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.description,
                    ),
                    label: 'Reports',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.map_outlined,
                    ),
                    label: 'Map',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.groups_outlined,
                    ),
                    label: 'Community',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.person_outline,
                    ),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SUMMARY
// ================================================================

class _SummaryBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      height: 64,
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
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
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
          Text(
            label,
            style:
            const TextStyle(
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

// ================================================================
// FILTER DROPDOWN
// ================================================================

class _FilterDropdown
    extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
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
          AppColors.border,
        ),
      ),
      child:
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor:
          AppColors.surface,
          hint: Text(label),
          icon:
          const Icon(
            Icons.keyboard_arrow_down,
            size: 17,
          ),
          items: items
              .map(
                (item) =>
                DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style:
                    const TextStyle(
                      fontSize: 9,
                    ),
                  ),
                ),
          )
              .toList(),
          onChanged:
          onChanged,
        ),
      ),
    );
  }
}

// ================================================================
// EMPTY
// ================================================================

class _EmptyReports extends StatelessWidget {
  final bool filtersActive;
  final VoidCallback onReset;

  const _EmptyReports({
    required this.filtersActive,
    required this.onReset,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 45,
        horizontal: 18,
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
          const Icon(
            Icons.description_outlined,
            color:
            AppColors.textSecondary,
            size: 48,
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            'No reports found',
            style:
            TextStyle(
              fontWeight:
              FontWeight.bold,
            ),
          ),
          if (filtersActive) ...[
            const SizedBox(
              height: 5,
            ),
            const Text(
              'Try changing your search or filters.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            OutlinedButton.icon(
              onPressed:
              onReset,
              icon: const Icon(
                Icons.restart_alt,
              ),
              label: const Text(
                'Reset Filters',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================================================================
// REPORT CARD
// ================================================================

class _ReportCard extends StatelessWidget {
  final InfrastructureReport report;

  final String Function(
      DateTime,
      ) formatDate;

  final VoidCallback onTap;

  final VoidCallback? onEdit;

  final VoidCallback? onDelete;

  const _ReportCard({
    required this.report,
    required this.formatDate,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  String get icon {
    switch (report.category) {
      case 'Road Damage':
        return '🛣️';
      case 'Street Light':
        return '💡';
      case 'Drainage':
        return '🌊';
      case 'Public Facility':
        return '🏗️';
      default:
        return '📌';
    }
  }

  String get statusText {
    switch (report.status) {
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

  Color get statusColor {
    switch (report.status) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  Color get priorityColor {
    switch (report.priority
        .trim()
        .toLowerCase()) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
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
        15,
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          15,
        ),
        onTap:
        onTap,
        child: Container(
          padding:
          const EdgeInsets.all(
            13,
          ),
          decoration:
          BoxDecoration(
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
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    alignment:
                    Alignment.center,
                    decoration:
                    BoxDecoration(
                      color:
                      statusColor
                          .withOpacity(
                        0.08,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        11,
                      ),
                      border:
                      Border.all(
                        color:
                        statusColor
                            .withOpacity(
                          0.55,
                        ),
                      ),
                    ),
                    child: Text(
                      icon,
                      style:
                      const TextStyle(
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 11,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                report.title,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration:
                              BoxDecoration(
                                color:
                                statusColor
                                    .withOpacity(
                                  0.12,
                                ),
                                borderRadius:
                                BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child: Text(
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
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            _MiniBadge(
                              text:
                              report.category,
                              color:
                              AppColors.primary,
                            ),
                            _MiniBadge(
                              text:
                              report.priority,
                              color:
                              priorityColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Text(
                    formatDate(
                      report.createdAt,
                    ),
                    style:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 8,
                    ),
                  ),
                  const Spacer(),
                  if (onEdit != null)
                    SizedBox(
                      height: 31,
                      child: TextButton.icon(
                        onPressed:
                        onEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 15,
                        ),
                        label: const Text(
                          'Edit',
                        ),
                      ),
                    ),
                  if (onDelete != null)
                    SizedBox(
                      height: 31,
                      child: TextButton.icon(
                        onPressed:
                        onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color:
                          AppColors.danger,
                          size: 15,
                        ),
                        label: const Text(
                          'Delete',
                          style:
                          TextStyle(
                            color:
                            AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (report.status !=
                  'pending') ...[
                const SizedBox(
                  height: 7,
                ),
                Row(
                  children: [
                    const Text(
                      'Progress',
                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize: 8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${report.progressPercentage}%',
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
                  height: 5,
                ),
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                  child:
                  LinearProgressIndicator(
                    value:
                    (report.progressPercentage /
                        100)
                        .clamp(
                      0.0,
                      1.0,
                    ),
                    minHeight: 4,
                    backgroundColor:
                    AppColors.border,
                    color:
                    statusColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// MINI BADGE
// ================================================================

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({
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
        horizontal: 7,
        vertical: 3,
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
            0.4,
          ),
        ),
      ),
      child: Text(
        text,
        style:
        TextStyle(
          color:
          color,
          fontSize: 7,
        ),
      ),
    );
  }
}