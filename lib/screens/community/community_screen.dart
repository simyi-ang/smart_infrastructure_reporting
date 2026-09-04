import 'package:flutter/material.dart';

import '../../models/community_report.dart';
import '../../services/community_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import 'community_report_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService service = CommunityService.instance;
  final LocationService locationService = LocationService();
  final TextEditingController searchController = TextEditingController();

  List<CommunityReport> reports = [];
  bool loading = true;
  bool detectingLocation = false;
  String? error;
  double? latitude;
  double? longitude;

  int selectedTab = 0;
  String selectedCategory = 'All';
  String selectedStatus = 'All';
  int radiusMetres = 5000;

  static const categories = [
    'All',
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  static const statuses = [
    'All',
    'Submitted',
    'Acknowledged',
    'In Progress',
    'Resolved',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _loadWithLocation();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

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

  Future<void> _loadWithLocation() async {
    setState(() => detectingLocation = true);

    try {
      final result = await locationService.getCurrentLocationWithAddress();
      latitude = result.latitude;
      longitude = result.longitude;
    } catch (_) {
      latitude = null;
      longitude = null;
    } finally {
      if (mounted) setState(() => detectingLocation = false);
    }

    await _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await service.getReports(
        latitude: latitude,
        longitude: longitude,
        radiusMetres: radiusMetres,
        category: selectedCategory == 'All' ? null : selectedCategory,
        status: selectedStatus == 'All' ? null : selectedStatus,
        sort: sort,
        limit: 60,
      );

      if (!mounted) return;

      setState(() {
        reports = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<CommunityReport> get visibleReports {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return reports;

    return reports.where((report) {
      return report.title.toLowerCase().contains(query) ||
          report.address.toLowerCase().contains(query) ||
          report.referenceNumber.toLowerCase().contains(query) ||
          report.category.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openReport(CommunityReport report) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityReportDetailScreen(
          reportId: report.id,
          currentLatitude: latitude,
          currentLongitude: longitude,
        ),
      ),
    );

    if (changed == true) {
      await _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleReports;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReports,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.groups_2_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Community',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Confirm and support infrastructure issues nearby',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: loading ? null : _loadReports,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search issue, address or report ID',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LocationBar(
                        hasLocation: latitude != null && longitude != null,
                        detecting: detectingLocation,
                        radiusMetres: radiusMetres,
                        onDetect: _loadWithLocation,
                        onRadiusChanged: (value) async {
                          setState(() => radiusMetres = value);
                          await _loadReports();
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (int i = 0; i < 4; i++)
                            ChoiceChip(
                              selected: selectedTab == i,
                              onSelected: (_) async {
                                setState(() => selectedTab = i);
                                await _loadReports();
                              },
                              label: Text(
                                const ['Nearby', 'Hot', 'Recent', 'Resolved'][i],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Drop(
                              value: selectedCategory,
                              items: categories,
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() => selectedCategory = value);
                                await _loadReports();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Drop(
                              value: selectedStatus,
                              items: statuses,
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() => selectedStatus = value);
                                await _loadReports();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        loading
                            ? 'Loading community reports...'
                            : '${visible.length} community report(s)',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loadReports,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (visible.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No matching community reports',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final report = visible[index];

                      return _CommunityCard(
                        report: report,
                        onTap: () => _openReport(report),
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

class _LocationBar extends StatelessWidget {
  final bool hasLocation;
  final bool detecting;
  final int radiusMetres;
  final Future<void> Function() onDetect;
  final ValueChanged<int> onRadiusChanged;

  const _LocationBar({
    required this.hasLocation,
    required this.detecting,
    required this.radiusMetres,
    required this.onDetect,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation ? Icons.my_location : Icons.location_off_outlined,
            color: hasLocation ? AppColors.primary : AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasLocation
                  ? 'Nearby radius ${(radiusMetres / 1000).toStringAsFixed(0)} km'
                  : 'Location unavailable — distance filtering disabled',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
          ),
          PopupMenuButton<int>(
            onSelected: onRadiusChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1000, child: Text('1 km')),
              PopupMenuItem(value: 3000, child: Text('3 km')),
              PopupMenuItem(value: 5000, child: Text('5 km')),
              PopupMenuItem(value: 10000, child: Text('10 km')),
            ],
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            onPressed: detecting ? null : onDetect,
            icon: detecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.gps_fixed),
          ),
        ],
      ),
    );
  }
}

class _Drop extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _Drop({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppColors.surface,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final CommunityReport report;
  final VoidCallback onTap;

  const _CommunityCard({
    required this.report,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.referenceNumber,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${report.category} · ${report.priority} · ${report.status}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${report.address}\n${report.distanceLabel}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric('${report.affectedCount}', 'Affected'),
                  _Metric('${report.stillExistsCount}', 'Still Exists'),
                  _Metric('${report.looksFixedCount}', 'Looks Fixed'),
                  _Metric('${report.contributionCount}', 'Evidence'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }
}
