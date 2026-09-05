import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../models/infrastructure_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

// ================================================================
// REPORT DETAIL SCREEN
//
// Supports:
// - report details
// - multiple report_images
// - multiple report_evidence videos
// - private signed URLs
// - image preview + zoom
// - video playback
// - GPS map
// - report status timeline
//
// IMPORTANT:
// Photos and videos intentionally remain in their existing tables:
//
// Photos:
// report_images
//
// Videos:
// report_evidence
//
// This preserves the current image AI architecture.
// ================================================================

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
  // ============================================================
  // SERVICES
  // ============================================================

  final ReportService reportService =
  ReportService();

  // ============================================================
  // REPORT
  // ============================================================

  InfrastructureReport? report;

  // ============================================================
  // EVIDENCE
  // ============================================================

  final List<String> evidenceImageUrls =
  <String>[];

  final List<Map<String, dynamic>>
  evidenceVideos =
  <Map<String, dynamic>>[];

  int get totalEvidenceCount =>
      evidenceImageUrls.length +
          evidenceVideos.length;

  // ============================================================
  // STATUS HISTORY
  // ============================================================

  final List<Map<String, dynamic>>
  statusHistory =
  <Map<String, dynamic>>[];

  // ============================================================
  // STATE
  // ============================================================

  bool loading =
  true;

  String? loadingError;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    loadReport();
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> loadReport() async {
    if (mounted) {
      setState(() {
        loading =
        true;

        loadingError =
        null;
      });
    }

    try {
      // ========================================================
      // REPORT
      // ========================================================

      final InfrastructureReport? result =
      await reportService
          .getSharedReportById(
        widget.reportId,
      );

      if (result == null) {
        throw Exception(
          'Report not found.',
        );
      }

      // ========================================================
      // IMAGES
      //
      // Do not fail the whole report if evidence loading fails.
      // ========================================================

      List<String> images =
      <String>[];

      try {
        images =
        await reportService
            .getReportSignedImageUrls(
          widget.reportId,
        );
      } catch (_) {
        // Keep report usable.
      }

      // ========================================================
      // VIDEOS
      // ========================================================

      List<Map<String, dynamic>>
      videos =
      <Map<String, dynamic>>[];

      try {
        videos =
        await reportService
            .getReportVideoEvidence(
          widget.reportId,
        );
      } catch (_) {
        // Keep report usable.
      }

      // ========================================================
      // STATUS HISTORY
      // ========================================================

      List<Map<String, dynamic>>
      history =
      <Map<String, dynamic>>[];

      try {
        history =
        await reportService
            .getReportStatusHistory(
          widget.reportId,
        );
      } catch (_) {
        // Older databases or reports can still use
        // current report.status.
      }

      if (!mounted) {
        return;
      }

      setState(() {
        report =
            result;

        evidenceImageUrls
          ..clear()
          ..addAll(
            images,
          );

        evidenceVideos
          ..clear()
          ..addAll(
            videos,
          );

        statusHistory
          ..clear()
          ..addAll(
            history,
          );

        loading =
        false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message =
      _cleanError(
        e,
      );

      setState(() {
        loading =
        false;

        loadingError =
            message;
      });

      _showMessage(
        message,
      );
    }
  }

  // ============================================================
  // ERROR CLEANER
  // ============================================================

  String _cleanError(
      Object error,
      ) {
    return error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    )
        .trim();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String getStatusText(
      String status,
      ) {
    switch (status) {
      case 'verified':
        return 'VERIFIED';

      case 'in_progress':
        return 'IN PROGRESS';

      case 'completed':
        return 'COMPLETED';

      case 'rejected':
        return 'REJECTED';

      case 'pending':
      default:
        return 'PENDING';
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color getStatusColor(
      String status,
      ) {
    switch (status) {
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
  // DATE
  // ============================================================

  String formatDate(
      DateTime date,
      ) {
    const List<String> months =
    <String>[
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

    final DateTime local =
    date.toLocal();

    return '${local.day} '
        '${months[local.month - 1]} '
        '${local.year}';
  }

  // ============================================================
  // DATE + TIME
  // ============================================================

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

  // ============================================================
  // MAP
  // ============================================================

  Future<void> viewReportOnMap() async {
    final InfrastructureReport?
    current =
        report;

    if (current == null) {
      return;
    }

    if (current.latitude == null ||
        current.longitude == null) {
      _showMessage(
        'This report does not have GPS coordinates.',
      );

      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder:
            (
            BuildContext context,
            ) {
          return _ReportMapScreen(
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
          );
        },
      ),
    );
  }

  // ============================================================
  // IMAGE VIEWER
  // ============================================================

  Future<void> _openImageViewer({
    required int initialIndex,
  }) async {
    if (evidenceImageUrls.isEmpty) {
      return;
    }

    int selectedIndex =
    initialIndex.clamp(
      0,
      evidenceImageUrls.length - 1,
    );

    await showDialog<void>(
      context:
      context,

      barrierColor:
      Colors.black87,

      builder:
          (
          BuildContext dialogContext,
          ) {
        return StatefulBuilder(
          builder:
              (
              BuildContext context,
              StateSetter setDialogState,
              ) {
            final String url =
            evidenceImageUrls[
            selectedIndex];

            return Dialog(
              backgroundColor:
              Colors.transparent,

              insetPadding:
              const EdgeInsets.all(
                12,
              ),

              child:
              Container(
                constraints:
                BoxConstraints(
                  maxHeight:
                  MediaQuery.of(
                    context,
                  ).size.height *
                      0.88,
                ),

                decoration:
                BoxDecoration(
                  color:
                  AppColors.surface,

                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                ),

                clipBehavior:
                Clip.antiAlias,

                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  children: [
                    // ==========================================
                    // HEADER
                    // ==========================================

                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(
                        16,
                        8,
                        6,
                        8,
                      ),

                      child:
                      Row(
                        children: [
                          Expanded(
                            child:
                            Text(
                              'Photo ${selectedIndex + 1} '
                                  'of ${evidenceImageUrls.length}',

                              style:
                              const TextStyle(
                                fontSize:
                                13,

                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed:
                                () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },

                            icon:
                            const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(
                      height:
                      1,

                      color:
                      AppColors.border,
                    ),

                    // ==========================================
                    // IMAGE
                    // ==========================================

                    Flexible(
                      child:
                      Container(
                        width:
                        double.infinity,

                        color:
                        Colors.black,

                        alignment:
                        Alignment.center,

                        child:
                        InteractiveViewer(
                          minScale:
                          0.8,

                          maxScale:
                          5,

                          child:
                          Image.network(
                            url,

                            fit:
                            BoxFit.contain,

                            loadingBuilder:
                                (
                                BuildContext context,
                                Widget child,
                                ImageChunkEvent?
                                loadingProgress,
                                ) {
                              if (loadingProgress ==
                                  null) {
                                return child;
                              }

                              return const SizedBox(
                                height:
                                320,

                                child:
                                Center(
                                  child:
                                  CircularProgressIndicator(),
                                ),
                              );
                            },

                            errorBuilder:
                                (
                                BuildContext context,
                                Object error,
                                StackTrace?
                                stackTrace,
                                ) {
                              return const SizedBox(
                                height:
                                320,

                                child:
                                Center(
                                  child:
                                  Icon(
                                    Icons
                                        .broken_image_outlined,

                                    color:
                                    AppColors
                                        .textSecondary,

                                    size:
                                    46,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // ==========================================
                    // IMAGE NAVIGATION
                    // ==========================================

                    if (evidenceImageUrls.length >
                        1)
                      Padding(
                        padding:
                        const EdgeInsets.all(
                          10,
                        ),

                        child:
                        Row(
                          children: [
                            Expanded(
                              child:
                              OutlinedButton.icon(
                                onPressed:
                                selectedIndex <=
                                    0
                                    ? null
                                    : () {
                                  setDialogState(
                                        () {
                                      selectedIndex--;
                                    },
                                  );
                                },

                                icon:
                                const Icon(
                                  Icons
                                      .chevron_left_rounded,
                                ),

                                label:
                                const Text(
                                  'Previous',
                                ),
                              ),
                            ),

                            const SizedBox(
                              width:
                              10,
                            ),

                            Expanded(
                              child:
                              OutlinedButton.icon(
                                onPressed:
                                selectedIndex >=
                                    evidenceImageUrls.length -
                                        1
                                    ? null
                                    : () {
                                  setDialogState(
                                        () {
                                      selectedIndex++;
                                    },
                                  );
                                },

                                icon:
                                const Icon(
                                  Icons
                                      .chevron_right_rounded,
                                ),

                                label:
                                const Text(
                                  'Next',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // VIDEO VIEWER
  // ============================================================

  Future<void> _openVideoViewer({
    required Map<String, dynamic> video,
    required int index,
  }) async {
    final String url =
        video['signed_url']
            ?.toString()
            .trim() ??
            '';

    if (url.isEmpty) {
      _showMessage(
        'This evidence video is unavailable.',
      );

      return;
    }

    final Uri? uri =
    Uri.tryParse(
      url,
    );

    if (uri == null) {
      _showMessage(
        'This evidence video has an invalid URL.',
      );

      return;
    }

    final VideoPlayerController
    controller =
    VideoPlayerController.networkUrl(
      uri,
    );

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await showDialog<void>(
        context:
        context,

        barrierColor:
        Colors.black87,

        builder:
            (
            BuildContext context,
            ) {
          return _ReportVideoDialog(
            controller:
            controller,

            title:
            'Video ${index + 1}',
          );
        },
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to play this evidence video.',
        );
      }
    } finally {
      try {
        await controller.dispose();
      } catch (_) {
        // Ignore cleanup failure.
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    // ==========================================================
    // LOADING
    // ==========================================================

    if (loading) {
      return const Scaffold(
        backgroundColor:
        AppColors.background,

        body:
        SafeArea(
          child:
          Center(
            child:
            CircularProgressIndicator(),
          ),
        ),
      );
    }

    // ==========================================================
    // REPORT FAILED
    // ==========================================================

    final InfrastructureReport?
    current =
        report;

    if (current == null) {
      return Scaffold(
        backgroundColor:
        AppColors.background,

        body:
        SafeArea(
          child:
          Center(
            child:
            Padding(
              padding:
              const EdgeInsets.all(
                24,
              ),

              child:
              Column(
                mainAxisSize:
                MainAxisSize.min,

                children: [
                  const Icon(
                    Icons
                        .error_outline_rounded,

                    color:
                    AppColors.textSecondary,

                    size:
                    44,
                  ),

                  const SizedBox(
                    height:
                    12,
                  ),

                  Text(
                    loadingError ??
                        'Report not found.',

                    textAlign:
                    TextAlign.center,

                    style:
                    const TextStyle(
                      color:
                      AppColors
                          .textSecondary,
                    ),
                  ),

                  const SizedBox(
                    height:
                    14,
                  ),

                  FilledButton.icon(
                    onPressed:
                    loadReport,

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
          ),
        ),
      );
    }

    final Color statusColor =
    getStatusColor(
      current.status,
    );

    // ==========================================================
    // SCREEN
    // ==========================================================

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body:
      SafeArea(
        child:
        RefreshIndicator(
          onRefresh:
          loadReport,

          child:
          SingleChildScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding:
            const EdgeInsets.all(
              18,
            ),

            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

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
                        'Back',

                        onPressed:
                            () {
                          Navigator.pop(
                            context,
                          );
                        },

                        icon:
                        const Icon(
                          Icons.arrow_back,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                      12,
                    ),

                    Expanded(
                      child:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'Report Details',

                            style:
                            TextStyle(
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
                      const EdgeInsets.symmetric(
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
                        BorderRadius.circular(
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
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  18,
                ),

                // ==============================================
                // EVIDENCE
                // ==============================================

                _ReportEvidenceSection(
                  imageUrls:
                  evidenceImageUrls,

                  videos:
                  evidenceVideos,

                  onOpenImage:
                      (
                      int index,
                      ) {
                    _openImageViewer(
                      initialIndex:
                      index,
                    );
                  },

                  onOpenVideo:
                      (
                      Map<String, dynamic>
                      video,

                      int index,
                      ) {
                    _openVideoViewer(
                      video:
                      video,

                      index:
                      index,
                    );
                  },
                ),

                const SizedBox(
                  height:
                  18,
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
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                  5,
                ),

                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    const Icon(
                      Icons
                          .location_on_outlined,

                      size:
                      16,

                      color:
                      AppColors.primary,
                    ),

                    const SizedBox(
                      width:
                      4,
                    ),

                    Expanded(
                      child:
                      Text(
                        current.address,

                        style:
                        const TextStyle(
                          color:
                          AppColors
                              .textSecondary,

                          fontSize:
                          11,

                          height:
                          1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                // ==============================================
                // LANDMARK
                // ==============================================

                if (current.landmark != null &&
                    current.landmark!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(
                    height:
                    6,
                  ),

                  Text(
                    'Landmark: ${current.landmark}',

                    style:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,

                      fontSize:
                      10,
                    ),
                  ),
                ],

                // ==============================================
                // MAP
                // ==============================================

                if (current.latitude !=
                    null &&
                    current.longitude !=
                        null) ...[
                  const SizedBox(
                    height:
                    11,
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
                  height:
                  16,
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
                    children: [
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          Expanded(
                            child:
                            _DetailItem(
                              label:
                              'CATEGORY',

                              value:
                              current.category,
                            ),
                          ),

                          const SizedBox(
                            width:
                            12,
                          ),

                          Expanded(
                            child:
                            _DetailItem(
                              label:
                              'PRIORITY',

                              value:
                              current.priority,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                        15,
                      ),

                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

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

                          const SizedBox(
                            width:
                            12,
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
                        height:
                        16,
                      ),

                      const Divider(
                        color:
                        AppColors.border,
                      ),

                      const SizedBox(
                        height:
                        10,
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
                              AppColors.primary,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                        7,
                      ),

                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          10,
                        ),

                        child:
                        LinearProgressIndicator(
                          value:
                          (current.progressPercentage /
                              100)
                              .clamp(
                            0.0,
                            1.0,
                          ),

                          minHeight:
                          5,

                          backgroundColor:
                          AppColors.border,

                          color:
                          statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height:
                  15,
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
                        height:
                        9,
                      ),

                      Text(
                        current.description,

                        style:
                        const TextStyle(
                          height:
                          1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height:
                  20,
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
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                  15,
                ),

                if (statusHistory.isEmpty) ...[
                  _TimelineItem(
                    complete:
                    true,

                    title:
                    'Report Submitted',

                    subtitle:
                    formatDateTime(
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
                        (
                        int index,
                        ) {
                      final Map<String, dynamic>
                      item =
                      statusHistory[
                      index];

                      final String status =
                          item['status']
                              ?.toString()
                              .trim() ??
                              'pending';

                      final DateTime date =
                          DateTime.tryParse(
                            item['created_at']
                                ?.toString() ??
                                '',
                          ) ??
                              current.createdAt;

                      final String note =
                          item['note']
                              ?.toString()
                              .trim() ??
                              '';

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
                        note.isNotEmpty
                            ? note
                            : 'Report status updated.',

                        last:
                        index ==
                            statusHistory.length -
                                1,
                      );
                    },
                  ),
                ],

                const SizedBox(
                  height:
                  30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// REPORT EVIDENCE SECTION
// ================================================================

class _ReportEvidenceSection
    extends StatelessWidget {
  final List<String> imageUrls;

  final List<Map<String, dynamic>>
  videos;

  final ValueChanged<int>
  onOpenImage;

  final void Function(
      Map<String, dynamic> video,
      int index,
      ) onOpenVideo;

  const _ReportEvidenceSection({
    required this.imageUrls,
    required this.videos,
    required this.onOpenImage,
    required this.onOpenVideo,
  });

  int get totalCount =>
      imageUrls.length +
          videos.length;

  @override
  Widget build(
      BuildContext context,
      ) {
    // ==========================================================
    // NO EVIDENCE
    // ==========================================================

    if (totalCount == 0) {
      return Container(
        width:
        double.infinity,

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

        child:
        const Row(
          children: [
            Icon(
              Icons
                  .collections_outlined,

              color:
              AppColors.textSecondary,
            ),

            SizedBox(
              width:
              10,
            ),

            Expanded(
              child:
              Text(
                'No evidence is available for this report.',

                style:
                TextStyle(
                  color:
                  AppColors
                      .textSecondary,

                  fontSize:
                  11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // EVIDENCE
    // ==========================================================

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        // ======================================================
        // HEADER
        // ======================================================

        Row(
          children: [
            const Icon(
              Icons
                  .collections_outlined,

              color:
              AppColors.primary,

              size:
              19,
            ),

            const SizedBox(
              width:
              8,
            ),

            const Expanded(
              child:
              Text(
                'Evidence',

                style:
                TextStyle(
                  fontSize:
                  16,

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
                AppColors.primary
                    .withOpacity(
                  0.10,
                ),

                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),

              child:
              Text(
                '$totalCount item'
                    '${totalCount == 1 ? '' : 's'}',

                style:
                const TextStyle(
                  color:
                  AppColors.primary,

                  fontSize:
                  9,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height:
          12,
        ),

        // ======================================================
        // PHOTOS
        // ======================================================

        if (imageUrls.isNotEmpty) ...[
          _EvidenceSubheader(
            title:
            'PHOTOS',

            count:
            imageUrls.length,
          ),

          const SizedBox(
            height:
            8,
          ),

          SizedBox(
            height:
            155,

            child:
            ListView.separated(
              scrollDirection:
              Axis.horizontal,

              itemCount:
              imageUrls.length,

              separatorBuilder:
                  (
                  BuildContext context,
                  int index,
                  ) {
                return const SizedBox(
                  width:
                  10,
                );
              },

              itemBuilder:
                  (
                  BuildContext context,
                  int index,
                  ) {
                return _EvidenceImageCard(
                  url:
                  imageUrls[index],

                  index:
                  index,

                  onTap:
                      () {
                    onOpenImage(
                      index,
                    );
                  },
                );
              },
            ),
          ),
        ],

        // ======================================================
        // SPACE BETWEEN IMAGE + VIDEO
        // ======================================================

        if (imageUrls.isNotEmpty &&
            videos.isNotEmpty)
          const SizedBox(
            height:
            18,
          ),

        // ======================================================
        // VIDEOS
        // ======================================================

        if (videos.isNotEmpty) ...[
          _EvidenceSubheader(
            title:
            'VIDEOS',

            count:
            videos.length,
          ),

          const SizedBox(
            height:
            8,
          ),

          ...List.generate(
            videos.length,
                (
                int index,
                ) {
              return Padding(
                padding:
                EdgeInsets.only(
                  bottom:
                  index ==
                      videos.length -
                          1
                      ? 0
                      : 9,
                ),

                child:
                _EvidenceVideoCard(
                  video:
                  videos[index],

                  index:
                  index,

                  onTap:
                      () {
                    onOpenVideo(
                      videos[index],
                      index,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ================================================================
// EVIDENCE SUBHEADER
// ================================================================

class _EvidenceSubheader
    extends StatelessWidget {
  final String title;

  final int count;

  const _EvidenceSubheader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      children: [
        Text(
          title,

          style:
          const TextStyle(
            color:
            AppColors.textSecondary,

            fontSize:
            9,

            fontWeight:
            FontWeight.bold,

            letterSpacing:
            0.4,
          ),
        ),

        const Spacer(),

        Text(
          '$count',

          style:
          const TextStyle(
            color:
            AppColors.textSecondary,

            fontSize:
            9,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// IMAGE CARD
// ================================================================

class _EvidenceImageCard
    extends StatelessWidget {
  final String url;

  final int index;

  final VoidCallback onTap;

  const _EvidenceImageCard({
    required this.url,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      onTap:
      onTap,

      child:
      SizedBox(
        width:
        190,

        child:
        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            14,
          ),

          child:
          Stack(
            fit:
            StackFit.expand,

            children: [
              // ==================================================
              // IMAGE
              // ==================================================

              Container(
                color:
                AppColors.surface,

                child:
                Image.network(
                  url,

                  fit:
                  BoxFit.cover,

                  loadingBuilder:
                      (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent?
                      loadingProgress,
                      ) {
                    if (loadingProgress ==
                        null) {
                      return child;
                    }

                    return const Center(
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                      ),
                    );
                  },

                  errorBuilder:
                      (
                      BuildContext context,
                      Object error,
                      StackTrace?
                      stackTrace,
                      ) {
                    return const Center(
                      child:
                      Icon(
                        Icons
                            .broken_image_outlined,

                        color:
                        AppColors
                            .textSecondary,

                        size:
                        35,
                      ),
                    );
                  },
                ),
              ),

              // ==================================================
              // LABEL
              // ==================================================

              Positioned(
                left:
                8,

                bottom:
                8,

                child:
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
                    Colors.black54,

                    borderRadius:
                    BorderRadius.circular(
                      8,
                    ),
                  ),

                  child:
                  Text(
                    'Photo ${index + 1}',

                    style:
                    const TextStyle(
                      color:
                      Colors.white,

                      fontSize:
                      9,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // ==================================================
              // ZOOM ICON
              // ==================================================

              const Positioned(
                top:
                8,

                right:
                8,

                child:
                CircleAvatar(
                  radius:
                  14,

                  backgroundColor:
                  Colors.black54,

                  child:
                  Icon(
                    Icons
                        .zoom_in_rounded,

                    color:
                    Colors.white,

                    size:
                    16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// VIDEO CARD
// ================================================================

class _EvidenceVideoCard
    extends StatelessWidget {
  final Map<String, dynamic>
  video;

  final int index;

  final VoidCallback onTap;

  const _EvidenceVideoCard({
    required this.video,
    required this.index,
    required this.onTap,
  });

  // ============================================================
  // FILE NAME
  // ============================================================

  String get fileName {
    final String name =
        video['original_file_name']
            ?.toString()
            .trim() ??
            '';

    return name.isEmpty
        ? 'Evidence video'
        : name;
  }

  // ============================================================
  // DURATION
  // ============================================================

  String get durationText {
    final dynamic raw =
    video['duration_seconds'];

    double? seconds;

    if (raw is num) {
      seconds =
          raw.toDouble();
    } else {
      seconds =
          double.tryParse(
            raw?.toString() ??
                '',
          );
    }

    if (seconds == null ||
        seconds <= 0) {
      return 'Short evidence video';
    }

    final int total =
    seconds.round();

    final int minutes =
        total ~/ 60;

    final int remaining =
        total % 60;

    return '$minutes:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final String thumbnail =
        video['thumbnail_signed_url']
            ?.toString()
            .trim() ??
            '';

    return Material(
      color:
      Colors.transparent,

      child:
      InkWell(
        onTap:
        onTap,

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        child:
        Container(
          padding:
          const EdgeInsets.all(
            10,
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
              // ==================================================
              // VIDEO THUMBNAIL
              // ==================================================

              Container(
                width:
                82,

                height:
                64,

                clipBehavior:
                Clip.antiAlias,

                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFF10253E,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child:
                Stack(
                  fit:
                  StackFit.expand,

                  children: [
                    if (thumbnail.isNotEmpty)
                      Image.network(
                        thumbnail,

                        fit:
                        BoxFit.cover,

                        errorBuilder:
                            (
                            BuildContext context,
                            Object error,
                            StackTrace?
                            stackTrace,
                            ) {
                          return const SizedBox();
                        },
                      ),

                    Container(
                      color:
                      Colors.black26,
                    ),

                    const Center(
                      child:
                      CircleAvatar(
                        radius:
                        18,

                        backgroundColor:
                        Colors.black54,

                        child:
                        Icon(
                          Icons
                              .play_arrow_rounded,

                          color:
                          Colors.white,

                          size:
                          24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width:
                12,
              ),

              // ==================================================
              // VIDEO INFO
              // ==================================================

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Video ${index + 1}',

                      style:
                      const TextStyle(
                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      4,
                    ),

                    Text(
                      fileName,

                      maxLines:
                      1,

                      overflow:
                      TextOverflow.ellipsis,

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
                      height:
                      6,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .schedule_rounded,

                          color:
                          AppColors
                              .textSecondary,

                          size:
                          13,
                        ),

                        const SizedBox(
                          width:
                          4,
                        ),

                        Flexible(
                          child:
                          Text(
                            durationText,

                            overflow:
                            TextOverflow.ellipsis,

                            style:
                            const TextStyle(
                              color:
                              AppColors
                                  .textSecondary,

                              fontSize:
                              9,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width:
                          10,
                        ),

                        const Text(
                          'Tap to play',

                          style:
                          TextStyle(
                            color:
                            AppColors.primary,

                            fontSize:
                            9,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width:
                6,
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,

                color:
                AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// VIDEO DIALOG
// ================================================================

class _ReportVideoDialog
    extends StatefulWidget {
  final VideoPlayerController
  controller;

  final String title;

  const _ReportVideoDialog({
    required this.controller,
    required this.title,
  });

  @override
  State<_ReportVideoDialog>
  createState() =>
      _ReportVideoDialogState();
}

class _ReportVideoDialogState
    extends State<_ReportVideoDialog> {
  VideoPlayerController get controller =>
      widget.controller;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    controller.addListener(
      _videoChanged,
    );
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    controller.removeListener(
      _videoChanged,
    );

    super.dispose();
  }

  // ============================================================
  // VIDEO UPDATE
  // ============================================================

  void _videoChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatDuration(
      Duration duration,
      ) {
    final int minutes =
        duration.inMinutes;

    final int seconds =
        duration.inSeconds %
            60;

    return '$minutes:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> _togglePlayback() async {
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >=
          controller.value.duration) {
        await controller.seekTo(
          Duration.zero,
        );
      }

      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final Duration position =
        controller.value.position;

    final Duration duration =
        controller.value.duration;

    final double aspectRatio =
    controller.value.aspectRatio >
        0
        ? controller
        .value
        .aspectRatio
        : 16 / 9;

    return Dialog(
      backgroundColor:
      AppColors.surface,

      insetPadding:
      const EdgeInsets.all(
        16,
      ),

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),

      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              10,
              6,
              8,
            ),

            child:
            Row(
              children: [
                Expanded(
                  child:
                  Text(
                    widget.title,

                    style:
                    const TextStyle(
                      fontSize:
                      14,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  tooltip:
                  'Close',

                  onPressed:
                      () async {
                    await controller.pause();

                    if (context.mounted) {
                      Navigator.pop(
                        context,
                      );
                    }
                  },

                  icon:
                  const Icon(
                    Icons.close_rounded,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height:
            1,

            color:
            AppColors.border,
          ),

          // ======================================================
          // VIDEO
          // ======================================================

          AspectRatio(
            aspectRatio:
            aspectRatio,

            child:
            ColoredBox(
              color:
              Colors.black,

              child:
              VideoPlayer(
                controller,
              ),
            ),
          ),

          // ======================================================
          // PROGRESS
          // ======================================================

          VideoProgressIndicator(
            controller,

            allowScrubbing:
            true,

            padding:
            const EdgeInsets.symmetric(
              vertical:
              9,

              horizontal:
              14,
            ),
          ),

          // ======================================================
          // CONTROLS
          // ======================================================

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              12,
              0,
              12,
              12,
            ),

            child:
            Row(
              children: [
                IconButton(
                  tooltip:
                  controller
                      .value
                      .isPlaying
                      ? 'Pause'
                      : 'Play',

                  onPressed:
                  _togglePlayback,

                  icon:
                  Icon(
                    controller
                        .value
                        .isPlaying
                        ? Icons
                        .pause_circle_filled_rounded
                        : Icons
                        .play_circle_fill_rounded,

                    color:
                    AppColors.primary,

                    size:
                    38,
                  ),
                ),

                const SizedBox(
                  width:
                  5,
                ),

                Expanded(
                  child:
                  Text(
                    '${_formatDuration(position)} / '
                        '${_formatDuration(duration)}',

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

                IconButton(
                  tooltip:
                  'Replay',

                  onPressed:
                      () async {
                    await controller.seekTo(
                      Duration.zero,
                    );

                    await controller.play();

                    if (mounted) {
                      setState(() {});
                    }
                  },

                  icon:
                  const Icon(
                    Icons.replay_rounded,

                    color:
                    AppColors.primary,
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

// ================================================================
// REPORT MAP SCREEN
// ================================================================

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

              markers:
              <Marker>{
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
                    AppColors
                        .textSecondary,

                    fontSize:
                    10,

                    height:
                    1.4,
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
                    AppColors
                        .textSecondary,

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

// ================================================================
// DETAIL ITEM
// ================================================================

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
      CrossAxisAlignment.start,

      children: [
        Text(
          label,

          style:
          const TextStyle(
            color:
            AppColors.textSecondary,

            fontSize:
            9,
          ),
        ),

        const SizedBox(
          height:
          5,
        ),

        Text(
          value,

          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,

            fontSize:
            12,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// TIMELINE ITEM
// ================================================================

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
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,

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
                        ? AppColors.primaryDark
                        : AppColors.surface,

                    shape:
                    BoxShape.circle,

                    border:
                    Border.all(
                      color:
                      complete
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),

                  child:
                  complete
                      ? const Icon(
                    Icons.check,
                    size:
                    13,
                    color:
                    Colors.white,
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
                          ? AppColors.primaryDark
                          : AppColors.border,
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
              const EdgeInsets.only(
                bottom:
                18,
              ),

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style:
                    TextStyle(
                      color:
                      complete
                          ? Colors.white
                          : AppColors
                          .textSecondary,

                      fontWeight:
                      FontWeight.bold,

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
                    const EdgeInsets.all(
                      10,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.surface,

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
                    Text(
                      description,

                      style:
                      const TextStyle(
                        color:
                        AppColors
                            .textSecondary,

                        fontSize:
                        10,

                        height:
                        1.4,
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