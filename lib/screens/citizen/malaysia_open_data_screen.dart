import 'package:flutter/material.dart';

import '../../models/malaysia_open_data.dart';
import '../../services/malaysia_open_data_service.dart';
import '../../theme/app_colors.dart';

class MalaysiaOpenDataScreen
    extends StatefulWidget {
  const MalaysiaOpenDataScreen({
    super.key,
  });

  @override
  State<MalaysiaOpenDataScreen> createState() =>
      _MalaysiaOpenDataScreenState();
}

class _MalaysiaOpenDataScreenState
    extends State<MalaysiaOpenDataScreen> {
  final MalaysiaOpenDataService service =
  MalaysiaOpenDataService();

  MalaysiaOpenDataSummary? summary;

  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    loadData();
  }

  Future<void> loadData() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final result =
      await service
          .getPublicTransportSummary();

      if (!mounted) {
        return;
      }

      setState(() {
        summary = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        errorMessage =
            e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      AppColors.background,
      appBar: AppBar(
        backgroundColor:
        AppColors.surface,
        title:
        const Text(
          'Malaysia Open Data',
        ),
        actions: [
          IconButton(
            onPressed:
            loading
                ? null
                : loadData,
            icon:
            const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh:
        loadData,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.all(
            16,
          ),
          children: [
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
                  AppColors.primaryDark,
                ),
              ),
              child:
              const Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        color:
                        AppColors.primary,
                      ),
                      SizedBox(
                        width: 9,
                      ),
                      Expanded(
                        child: Text(
                          'Malaysian Government Open Data',
                          style:
                          TextStyle(
                            fontSize: 14,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 7,
                  ),
                  Text(
                    'Official public transport infrastructure data used '
                        'to support the SmartCity application and SDG 9.',
                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 10,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            if (loading)
              const Padding(
                padding:
                EdgeInsets.symmetric(
                  vertical: 100,
                ),
                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              )
            else if (errorMessage != null)
              _ErrorCard(
                message:
                errorMessage!,
                onRetry:
                loadData,
              )
            else if (summary != null)
                _OpenDataContent(
                  summary:
                  summary!,
                  service:
                  service,
                ),
          ],
        ),
      ),
    );
  }
}

class _OpenDataContent
    extends StatelessWidget {
  final MalaysiaOpenDataSummary summary;
  final MalaysiaOpenDataService service;

  const _OpenDataContent({
    required this.summary,
    required this.service,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final latest =
        summary.latest;

    final change =
        summary.dailyChangePercentage;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
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
              16,
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
              const Text(
                'Daily Public Transport Ridership',
                style:
                TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                'Latest available data • '
                    '${service.formatDate(latest.date)}',
                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 9,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              Text(
                service.formatNumber(
                  latest.totalTrips,
                ),
                style:
                const TextStyle(
                  color:
                  AppColors.primary,
                  fontSize: 30,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              const Text(
                'public transport trips',
                style:
                TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 9,
                ),
              ),
              if (change != null) ...[
                const SizedBox(
                  height: 9,
                ),
                Text(
                  '${change >= 0 ? '+' : ''}'
                      '${change.toStringAsFixed(1)}% vs previous available day',
                  style:
                  TextStyle(
                    color:
                    change >= 0
                        ? AppColors.success
                        : AppColors.warning,
                    fontSize: 9,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        Row(
          children: [
            Expanded(
              child:
              _MetricCard(
                icon:
                Icons.directions_bus_outlined,
                label:
                'Bus Trips',
                value:
                service.formatNumber(
                  latest.busTotal,
                ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child:
              _MetricCard(
                icon:
                Icons.train_outlined,
                label:
                'Rail Trips',
                value:
                service.formatNumber(
                  latest.railTotal,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 22,
        ),

        const Text(
          'Busiest Services',
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

        ...latest.topServices.map(
              (entry) =>
              Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 8,
                ),
                child:
                _ServiceRow(
                  name:
                  entry.key,
                  trips:
                  service.formatNumber(
                    entry.value,
                  ),
                  fraction:
                  latest.totalTrips > 0
                      ? entry.value /
                      latest.totalTrips
                      : 0,
                ),
              ),
        ),

        const SizedBox(
          height: 16,
        ),

        Container(
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
              14,
            ),
            border:
            Border.all(
              color:
              AppColors.border,
            ),
          ),
          child:
          const Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Dataset Information',
                style:
                TextStyle(
                  fontSize: 12,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              _InfoRow(
                label:
                'Dataset',
                value:
                'Daily Public Transport Ridership',
              ),
              _InfoRow(
                label:
                'Portal',
                value:
                'data.gov.my',
              ),
              _InfoRow(
                label:
                'Sources',
                value:
                'Prasarana Malaysia & Ministry of Transport',
              ),
              _InfoRow(
                label:
                'Licence',
                value:
                'Creative Commons Attribution 4.0',
              ),
              _InfoRow(
                label:
                'Note',
                value:
                'Values are numbers of trips, not unique passengers.',
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 18,
        ),
      ],
    );
  }
}

class _MetricCard
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
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
        14,
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
      child: Column(
        children: [
          Icon(
            icon,
            color:
            AppColors.primary,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            value,
            style:
            const TextStyle(
              color:
              AppColors.primary,
              fontSize: 17,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 3,
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

class _ServiceRow
    extends StatelessWidget {
  final String name;
  final String trips;
  final double fraction;

  const _ServiceRow({
    required this.name,
    required this.trips,
    required this.fraction,
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
              Text(
                trips,
                style:
                const TextStyle(
                  color:
                  AppColors.primary,
                  fontSize: 10,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            child:
            LinearProgressIndicator(
              value:
              fraction.clamp(
                0.0,
                1.0,
              ),
              minHeight:
              5,
              backgroundColor:
              AppColors.border,
              color:
              AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style:
              const TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
              const TextStyle(
                fontSize: 9,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
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
          14,
        ),
        border:
        Border.all(
          color:
          AppColors.warning,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color:
            AppColors.warning,
            size: 38,
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            message,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          OutlinedButton.icon(
            onPressed:
            onRetry,
            icon:
            const Icon(
              Icons.refresh,
            ),
            label:
            const Text(
              'Retry',
            ),
          ),
        ],
      ),
    );
  }
}
