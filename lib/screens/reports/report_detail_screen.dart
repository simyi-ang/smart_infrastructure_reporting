import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/infrastructure_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<ReportDetailScreen> createState() =>
      _ReportDetailScreenState();
}

class _ReportDetailScreenState
    extends State<ReportDetailScreen> {
  final ReportService reportService =
  ReportService();

  InfrastructureReport? report;

  List<String> evidenceUrls = [];

  List<Map<String, dynamic>> statusHistory = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadReport();
  }

  Future<void> loadReport() async {
    try {
      final result =
      await reportService.getReportById(
        widget.reportId,
      );

      if (result == null) {
        throw Exception(
          'Report not found.',
        );
      }

      final images =
      await reportService
          .getReportSignedImageUrls(
        widget.reportId,
      );

      List<Map<String, dynamic>> history = [];

      try {
        history =
        await reportService
            .getReportStatusHistory(
          widget.reportId,
        );
      } catch (_) {
        // Older databases may not have history rows yet.
        // The screen still works using the current report status.
      }

      if (!mounted) return;

      setState(() {
        report = result;
        evidenceUrls = images;
        statusHistory = history;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }
  }

  String getStatusText(String status) {
    switch (status) {
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

  Color getStatusColor(String status) {
    switch (status) {
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

  String formatDate(DateTime date) {
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

  String formatDateTime(
      DateTime date,
      ) {
    final DateTime local =
    date.toLocal();

    String two(
        int value,
        ) {
      return value
          .toString()
          .padLeft(
        2,
        '0',
      );
    }

    return '${two(local.day)}/'
        '${two(local.month)}/'
        '${local.year} '
        '${two(local.hour)}:'
        '${two(local.minute)}';
  }

  Future<void> viewReportOnMap() async {
    final current =
        report;

    if (current == null) {
      return;
    }

    if (current.latitude == null ||
        current.longitude == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'This report does not have GPS coordinates.',
          ),
        ),
      );

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ReportMapScreen(
              title:
              current.title,
              referenceNumber:
              current.referenceNumber,
              address:
              current.address,
              latitude:
              current.latitude!,
              longitude:
              current.longitude!,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final current = report;

    if (current == null) {
      return const Scaffold(
        backgroundColor:
        AppColors.background,
        body: Center(
          child:
          Text(
            'Report not found.',
          ),
        ),
      );
    }

    final statusColor =
    getStatusColor(
      current.status,
    );

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body: SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.all(
            18,
          ),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,

            children: [
              // ==============================================
              // HEADER
              // ==============================================

              Row(
                children: [
                  Container(
                    decoration:
                    BoxDecoration(
                      color:
                      AppColors
                          .surface,

                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors
                            .border,
                      ),
                    ),

                    child:
                    IconButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },

                      icon:
                      const Icon(
                        Icons
                            .arrow_back,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                      children: [
                        const Text(
                          'Report Details',

                          style:
                          TextStyle(
                            fontSize:
                            22,

                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 2,
                        ),

                        Text(
                          current
                              .referenceNumber,

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
                    ),
                  ),

                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal:
                      10,

                      vertical:
                      6,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      statusColor
                          .withOpacity(
                        0.12,
                      ),

                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),

                      border:
                      Border.all(
                        color:
                        statusColor,
                      ),
                    ),

                    child:
                    Text(
                      '• ${getStatusText(current.status)}',

                      style:
                      TextStyle(
                        color:
                        statusColor,

                        fontSize:
                        9,

                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 18,
              ),

              // ==============================================
              // IMAGE
              // ==============================================

              if (evidenceUrls
                  .isNotEmpty)
                ClipRRect(
                  borderRadius:
                  BorderRadius
                      .circular(
                    17,
                  ),

                  child:
                  Image.network(
                    evidenceUrls
                        .first,

                    width:
                    double.infinity,

                    height:
                    190,

                    fit:
                    BoxFit.cover,

                    errorBuilder:
                        (
                        context,
                        error,
                        stackTrace,
                        ) {
                      return Container(
                        height:
                        190,

                        color:
                        AppColors
                            .surface,

                        alignment:
                        Alignment
                            .center,

                        child:
                        const Icon(
                          Icons
                              .broken_image_outlined,

                          color:
                          AppColors
                              .textSecondary,

                          size:
                          40,
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(
                height: 14,
              ),

              // ==============================================
              // TITLE
              // ==============================================

              Text(
                current.title,

                style:
                const TextStyle(
                  fontSize:
                  18,

                  fontWeight:
                  FontWeight
                      .bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                '📍 ${current.address}',

                style:
                const TextStyle(
                  color:
                  AppColors
                      .textSecondary,

                  fontSize:
                  11,
                ),
              ),

              if (current.latitude != null &&
                  current.longitude != null) ...[
                const SizedBox(
                  height: 10,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  child:
                  OutlinedButton.icon(
                    onPressed:
                    viewReportOnMap,
                    icon:
                    const Icon(
                      Icons.map_outlined,
                    ),
                    label:
                    const Text(
                      'View Report on Map',
                    ),
                  ),
                ),
              ],

              const SizedBox(
                height: 16,
              ),

              // ==============================================
              // INFO CARD
              // ==============================================

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
                  AppColors
                      .surface,

                  borderRadius:
                  BorderRadius
                      .circular(
                    16,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors
                        .border,
                  ),
                ),

                child:
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child:
                          _DetailItem(
                            label:
                            'CATEGORY',

                            value:
                            current
                                .category,
                          ),
                        ),

                        Expanded(
                          child:
                          _DetailItem(
                            label:
                            'PRIORITY',

                            value:
                            current
                                .priority,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                          _DetailItem(
                            label:
                            'SUBMITTED',

                            value:
                            formatDate(
                              current
                                  .createdAt,
                            ),
                          ),
                        ),

                        Expanded(
                          child:
                          _DetailItem(
                            label:
                            'DEPARTMENT',

                            value:
                            current
                                .assignedDepartment ??
                                'Not assigned',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Divider(
                      color:
                      AppColors
                          .border,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Row(
                      children: [
                        const Text(
                          'PROGRESS',

                          style:
                          TextStyle(
                            color:
                            AppColors
                                .textSecondary,

                            fontSize:
                            9,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          '${current.progressPercentage}%',

                          style:
                          const TextStyle(
                            color:
                            AppColors
                                .primary,

                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    ClipRRect(
                      borderRadius:
                      BorderRadius
                          .circular(
                        10,
                      ),

                      child:
                      LinearProgressIndicator(
                        value:
                        current.progressPercentage /
                            100,

                        minHeight:
                        5,

                        backgroundColor:
                        AppColors
                            .border,

                        color:
                        statusColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // ==============================================
              // DESCRIPTION
              // ==============================================

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
                  AppColors
                      .surface,

                  borderRadius:
                  BorderRadius
                      .circular(
                    16,
                  ),

                  border:
                  Border.all(
                    color:
                    AppColors
                        .border,
                  ),
                ),

                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    const Text(
                      'DESCRIPTION',

                      style:
                      TextStyle(
                        color:
                        AppColors
                            .textSecondary,

                        fontSize:
                        9,
                      ),
                    ),

                    const SizedBox(
                      height: 9,
                    ),

                    Text(
                      current
                          .description,

                      style:
                      const TextStyle(
                        height:
                        1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==============================================
              // TIMELINE
              // ==============================================

              const Text(
                'Timeline',

                style:
                TextStyle(
                  fontSize:
                  17,

                  fontWeight:
                  FontWeight
                      .bold,
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              if (statusHistory.isEmpty) ...[
                _TimelineItem(
                  complete:
                  true,

                  title:
                  'Report Submitted',

                  subtitle:
                  formatDate(
                    current.createdAt,
                  ),

                  description:
                  'Report submitted through SmartCity.',
                ),

                _TimelineItem(
                  complete:
                  current.status !=
                      'pending',

                  title:
                  'Current Status',

                  subtitle:
                  getStatusText(
                    current.status,
                  ),

                  description:
                  'Current workflow status from the report record.',

                  last:
                  true,
                ),
              ] else ...[
                ...List.generate(
                  statusHistory.length,
                      (index) {
                    final item =
                    statusHistory[index];

                    final String status =
                        item['status']
                            ?.toString() ??
                            'pending';

                    final DateTime date =
                        DateTime.tryParse(
                          item['created_at']
                              ?.toString() ??
                              '',
                        ) ??
                            current.createdAt;

                    final String description =
                    item['note']
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                        true
                        ? item['note'].toString()
                        : 'Report status updated.';

                    return _TimelineItem(
                      complete:
                      true,

                      title:
                      getStatusText(
                        status,
                      ),

                      subtitle:
                      formatDateTime(
                        date,
                      ),

                      description:
                      description,

                      last:
                      index ==
                          statusHistory.length -
                              1,
                    );
                  },
                ),
              ],

              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ReportMapScreen
    extends StatelessWidget {
  final String title;
  final String referenceNumber;
  final String address;
  final double latitude;
  final double longitude;

  const _ReportMapScreen({
    required this.title,
    required this.referenceNumber,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final LatLng reportPosition =
    LatLng(
      latitude,
      longitude,
    );

    return Scaffold(
      backgroundColor:
      AppColors.background,

      appBar:
      AppBar(
        backgroundColor:
        AppColors.surface,

        title:
        const Text(
          'Report Location',
        ),
      ),

      body:
      Column(
        children: [
          Expanded(
            child:
            GoogleMap(
              initialCameraPosition:
              CameraPosition(
                target:
                reportPosition,

                zoom:
                17,
              ),

              markers: {
                Marker(
                  markerId:
                  MarkerId(
                    referenceNumber,
                  ),

                  position:
                  reportPosition,

                  infoWindow:
                  InfoWindow(
                    title:
                    title,

                    snippet:
                    referenceNumber,
                  ),
                ),
              },

              zoomControlsEnabled:
              false,

              myLocationButtonEnabled:
              false,
            ),
          ),

          Container(
            width:
            double.infinity,

            padding:
            const EdgeInsets.all(
              16,
            ),

            decoration:
            const BoxDecoration(
              color:
              AppColors.surface,

              border:
              Border(
                top:
                BorderSide(
                  color:
                  AppColors.border,
                ),
              ),
            ),

            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,

                    fontSize:
                    14,
                  ),
                ),

                const SizedBox(
                  height:
                  5,
                ),

                Text(
                  referenceNumber,

                  style:
                  const TextStyle(
                    color:
                    AppColors.primary,

                    fontSize:
                    9,
                  ),
                ),

                const SizedBox(
                  height:
                  8,
                ),

                Text(
                  address,

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
                  '${latitude.toStringAsFixed(6)}, '
                      '${longitude.toStringAsFixed(6)}',

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

class _DetailItem
    extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment
          .start,

      children: [
        Text(
          label,

          style:
          const TextStyle(
            color:
            AppColors
                .textSecondary,

            fontSize:
            9,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          value,

          style:
          const TextStyle(
            fontWeight:
            FontWeight
                .bold,

            fontSize:
            12,
          ),
        ),
      ],
    );
  }
}

class _TimelineItem
    extends StatelessWidget {
  final bool complete;

  final String title;

  final String subtitle;

  final String description;

  final bool last;

  const _TimelineItem({
    required this.complete,
    required this.title,
    required this.subtitle,
    required this.description,
    this.last = false,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment
            .stretch,

        children: [
          SizedBox(
            width:
            32,

            child:
            Column(
              children: [
                Container(
                  width:
                  21,

                  height:
                  21,

                  decoration:
                  BoxDecoration(
                    color:
                    complete
                        ? AppColors
                        .primaryDark
                        : AppColors
                        .surface,

                    shape:
                    BoxShape
                        .circle,

                    border:
                    Border.all(
                      color:
                      complete
                          ? AppColors
                          .primary
                          : AppColors
                          .border,
                    ),
                  ),

                  child:
                  complete
                      ? const Icon(
                    Icons
                        .check,

                    size:
                    13,

                    color:
                    Colors
                        .white,
                  )
                      : null,
                ),

                if (!last)
                  Expanded(
                    child:
                    Container(
                      width:
                      2,

                      color:
                      complete
                          ? AppColors
                          .primaryDark
                          : AppColors
                          .border,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(
            width:
            8,
          ),

          Expanded(
            child:
            Padding(
              padding:
              const EdgeInsets
                  .only(
                bottom:
                18,
              ),

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,

                children: [
                  Text(
                    title,

                    style:
                    TextStyle(
                      color:
                      complete
                          ? Colors
                          .white
                          : AppColors
                          .textSecondary,

                      fontWeight:
                      FontWeight
                          .bold,

                      fontSize:
                      13,
                    ),
                  ),

                  const SizedBox(
                    height:
                    3,
                  ),

                  Text(
                    subtitle,

                    style:
                    const TextStyle(
                      color:
                      AppColors
                          .textSecondary,

                      fontSize:
                      10,
                    ),
                  ),

                  const SizedBox(
                    height:
                    7,
                  ),

                  Container(
                    width:
                    double.infinity,

                    padding:
                    const EdgeInsets
                        .all(
                      10,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      AppColors
                          .surface,

                      borderRadius:
                      BorderRadius
                          .circular(
                        10,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors
                            .border,
                      ),
                    ),

                    child:
                    Text(
                      description,

                      style:
                      const TextStyle(
                        color:
                        AppColors
                            .textSecondary,

                        fontSize:
                        10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}