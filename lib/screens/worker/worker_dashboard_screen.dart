import 'package:flutter/material.dart';

import '../../models/infrastructure_report.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import 'worker_manage_report_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    super.key,
  });

  @override
  State<WorkerDashboardScreen> createState() =>
      _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState
    extends State<WorkerDashboardScreen> {
  final ReportService reportService =
  ReportService();

  final AuthService authService =
  AuthService();

  List<InfrastructureReport> reports = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadReports();
  }

  Future<void> loadReports() async {
    try {
      final result =
      await reportService.getAllReports();

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
        content: Text(
          message,
        ),
      ),
    );
  }

  Future<void> logout() async {
    await authService.logout();

    if (!mounted) return;

    Navigator.of(context).popUntil(
          (route) => route.isFirst,
    );
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
          'Worker Reports',
        ),

        actions: [
          IconButton(
            onPressed:
            loadReports,

            icon:
            const Icon(
              Icons.refresh,
            ),
          ),

          IconButton(
            onPressed:
            logout,

            icon:
            const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      body:
      loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh:
        loadReports,

        child:
        ListView.builder(
          padding:
          const EdgeInsets.all(
            14,
          ),

          itemCount:
          reports.length,

          itemBuilder:
              (
              context,
              index,
              ) {
            final report =
            reports[index];

            return Padding(
              padding:
              const EdgeInsets.only(
                bottom:
                12,
              ),

              child:
              _WorkerReportCard(
                report:
                report,

                onManage:
                    () async {
                  final changed =
                  await Navigator.push<bool>(
                    context,

                    MaterialPageRoute(
                      builder:
                          (_) =>
                          WorkerManageReportScreen(
                            report:
                            report,
                          ),
                    ),
                  );

                  if (changed ==
                      true) {
                    await loadReports();
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkerReportCard
    extends StatelessWidget {
  final InfrastructureReport report;

  final VoidCallback onManage;

  const _WorkerReportCard({
    required this.report,
    required this.onManage,
  });

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

                  style:
                  const TextStyle(
                    fontSize:
                    14,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  9,

                  vertical:
                  5,
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

                child:
                Text(
                  statusText,

                  style:
                  TextStyle(
                    color:
                    statusColor,

                    fontSize:
                    8,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            8,
          ),

          Text(
            report.referenceNumber,

            style:
            const TextStyle(
              color:
              AppColors.primary,

              fontSize:
              10,
            ),
          ),

          const SizedBox(
            height:
            7,
          ),

          Text(
            '📍 ${report.address}',

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              10,
            ),
          ),

          const SizedBox(
            height:
            6,
          ),

          Text(
            'Category: ${report.category}',

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              10,
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
                LinearProgressIndicator(
                  value:
                  report.progressPercentage /
                      100,

                  minHeight:
                  5,

                  backgroundColor:
                  AppColors.border,

                  color:
                  statusColor,
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              Text(
                '${report.progressPercentage}%',

                style:
                const TextStyle(
                  color:
                  AppColors.primary,

                  fontSize:
                  10,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            12,
          ),

          SizedBox(
            width:
            double.infinity,

            child:
            ElevatedButton.icon(
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.primaryDark,
              ),

              onPressed:
              onManage,

              icon:
              const Icon(
                Icons.edit_outlined,
              ),

              label:
              const Text(
                'Manage Report',
              ),
            ),
          ),
        ],
      ),
    );
  }
}