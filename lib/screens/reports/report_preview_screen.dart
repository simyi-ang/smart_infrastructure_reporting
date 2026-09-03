import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/report_image_ai_analysis.dart';

import '../../services/connectivity_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

class ReportPreviewScreen
    extends StatefulWidget {
  final String category;
  final String priority;
  final String title;
  final String description;
  final List<File> evidenceImages;

  final String address;
  final String landmark;

  final double? latitude;
  final double? longitude;

  // ============================================================
  // AI SMART ASSIST RESULT
  //
  // Optional so the existing manual reporting flow remains
  // fully compatible when AI is unavailable or not used.
  // ============================================================
  final ReportImageAiAnalysis? aiAnalysis;

  const ReportPreviewScreen({
    super.key,
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    required this.evidenceImages,
    required this.address,
    required this.landmark,
    this.latitude,
    this.longitude,
    this.aiAnalysis,
  });

  @override
  State<ReportPreviewScreen> createState() =>
      _ReportPreviewScreenState();
}

class _ReportPreviewScreenState
    extends State<ReportPreviewScreen> {
  final ReportService reportService =
  ReportService();

  final ConnectivityService connectivityService =
  const ConnectivityService();

  bool submitting = false;

  double uploadProgress = 0;
  String uploadMessage = '';
  String? submissionError;

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> submitReport() async {
    if (submitting) {
      return;
    }

    setState(() {
      submitting = true;
      uploadProgress = 0.02;
      uploadMessage = 'Checking internet connection...';
      submissionError = null;
    });

    try {
      await connectivityService.requireInternetConnection();

      if (!mounted) {
        return;
      }

      setState(() {
        uploadProgress = 0.05;
        uploadMessage = 'Preparing submission...';
      });

      final result = await reportService.submitReport(
        title: widget.title,
        category: widget.category,
        priority: widget.priority,
        description: widget.description,
        address: widget.address,
        landmark: widget.landmark,
        latitude: widget.latitude,
        longitude: widget.longitude,
        evidenceImages: widget.evidenceImages,
        onProgress: (ReportUploadProgress progress) {
          if (!mounted) {
            return;
          }

          setState(() {
            uploadProgress = progress.progress.clamp(0.0, 1.0);
            uploadMessage = progress.message;
          });
        },
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                SizedBox(width: 10),
                Text('Report Submitted'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your infrastructure report was submitted successfully.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'REFERENCE NUMBER',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  result.referenceNumber,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.latitude != null &&
                    widget.longitude != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'GPS LOCATION',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.latitude!.toStringAsFixed(6)}, '
                        '${widget.longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil(
            (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message = e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      // Stay on the preview screen. All widget values and File objects
      // remain available, so the Citizen can retry without re-entering data.
      setState(() {
        submissionError = message;
        uploadMessage = 'Submission failed. Your report data is still here.';
        uploadProgress = 0;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
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

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.all(
                  20,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    // ==========================================
                    // HEADER
                    // ==========================================

                    Row(
                      children: [
                        IconButton(
                          onPressed:
                          submitting
                              ? null
                              : () {
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
                          width:
                          8,
                        ),

                        const Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [
                            Text(
                              'Preview Report',

                              style:
                              TextStyle(
                                fontSize:
                                22,

                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            Text(
                              'Review before submitting',

                              style:
                              TextStyle(
                                color:
                                AppColors.textSecondary,

                                fontSize:
                                12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    // ==========================================
                    // EVIDENCE
                    // ==========================================

                    if (widget
                        .evidenceImages
                        .isNotEmpty)
                      SizedBox(
                        height:
                        190,

                        child:
                        ListView.separated(
                          scrollDirection:
                          Axis.horizontal,

                          itemCount:
                          widget
                              .evidenceImages
                              .length,

                          separatorBuilder:
                              (
                              _,
                              __,
                              ) =>
                          const SizedBox(
                            width:
                            8,
                          ),

                          itemBuilder:
                              (
                              context,
                              index,
                              ) {
                            return ClipRRect(
                              borderRadius:
                              BorderRadius.circular(
                                16,
                              ),

                              child:
                              Image.file(
                                widget.evidenceImages[
                                index],

                                width:
                                270,

                                height:
                                190,

                                fit:
                                BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(
                      height:
                      16,
                    ),

                    // ==========================================
                    // DETAILS
                    // ==========================================

                    Container(
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
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          Text(
                            widget.title,

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
                            16,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child:
                                _InfoItem(
                                  label:
                                  'CATEGORY',

                                  value:
                                  widget.category,
                                ),
                              ),

                              const SizedBox(
                                width:
                                10,
                              ),

                              Expanded(
                                child:
                                _InfoItem(
                                  label:
                                  'PRIORITY',

                                  value:
                                  widget.priority,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height:
                            10,
                          ),

                          _InfoItem(
                            label:
                            'EVIDENCE',

                            value:
                            '${widget.evidenceImages.length} photo(s)',
                          ),

                          const SizedBox(
                            height:
                            18,
                          ),

                          const Divider(
                            color:
                            AppColors.border,
                          ),

                          const SizedBox(
                            height:
                            8,
                          ),

                          const Text(
                            'DESCRIPTION',

                            style:
                            TextStyle(
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
                            widget.description,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                      15,
                    ),

                    // ==========================================
                    // LOCATION
                    // ==========================================

                    Container(
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
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'LOCATION',

                            style:
                            TextStyle(
                              color:
                              AppColors.textSecondary,

                              fontSize:
                              10,
                            ),
                          ),

                          const SizedBox(
                            height:
                            7,
                          ),

                          Text(
                            '📍 ${widget.address}',

                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          if (widget.landmark
                              .isNotEmpty) ...[
                            const SizedBox(
                              height:
                              7,
                            ),

                            Text(
                              'Landmark: ${widget.landmark}',

                              style:
                              const TextStyle(
                                color:
                                AppColors.textSecondary,

                                fontSize:
                                11,
                              ),
                            ),
                          ],

                          if (widget.latitude != null &&
                              widget.longitude !=
                                  null) ...[
                            const SizedBox(
                              height:
                              12,
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
                                AppColors.success
                                    .withOpacity(
                                  0.07,
                                ),

                                borderRadius:
                                BorderRadius.circular(
                                  10,
                                ),

                                border:
                                Border.all(
                                  color:
                                  AppColors.success
                                      .withOpacity(
                                    0.45,
                                  ),
                                ),
                              ),

                              child:
                              Row(
                                children: [
                                  const Icon(
                                    Icons.gps_fixed,

                                    color:
                                    AppColors.success,

                                    size:
                                    16,
                                  ),

                                  const SizedBox(
                                    width:
                                    8,
                                  ),

                                  Expanded(
                                    child:
                                    Text(
                                      '${widget.latitude!.toStringAsFixed(6)}, '
                                          '${widget.longitude!.toStringAsFixed(6)}',

                                      style:
                                      const TextStyle(
                                        color:
                                        AppColors.textSecondary,

                                        fontSize:
                                        9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==============================================
            // SUBMISSION PROGRESS / RETRY
            // ==============================================

            if (submitting)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryDark,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            uploadMessage.isEmpty
                                ? 'Submitting report...'
                                : uploadMessage,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${(uploadProgress * 100).round()}%',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: uploadProgress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

            if (!submitting && submissionError != null)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Submission Not Sent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            submissionError!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Your entered details, images and location are preserved. '
                                'Reconnect and tap Retry Submission.',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ==============================================
            // BUTTONS
            // ==============================================

            Container(
              padding:
              const EdgeInsets.all(
                18,
              ),

              decoration:
              const BoxDecoration(
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
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed:
                    submitting
                        ? null
                        : () {
                      Navigator.pop(
                        context,
                      );
                    },

                    icon:
                    const Icon(
                      Icons.edit,
                    ),

                    label:
                    const Text(
                      'Edit',
                    ),
                  ),

                  const SizedBox(
                    width:
                    10,
                  ),

                  Expanded(
                    child:
                    ElevatedButton(
                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        AppColors.primaryDark,

                        minimumSize:
                        const Size.fromHeight(
                          54,
                        ),
                      ),

                      onPressed:
                      submitting
                          ? null
                          : submitReport,

                      child:
                      submitting
                          ? const SizedBox(
                        width: 22,
                        height: 22,

                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2.5,

                          color:
                          Colors.white,
                        ),
                      )
                          : Text(
                        submissionError == null
                            ? '✓ Submit Report'
                            : '↻ Retry Submission',
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
  }
}

// ================================================================
// INFO ITEM
// ================================================================

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        11,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.surfaceLight,

        borderRadius:
        BorderRadius.circular(
          11,
        ),
      ),

      child:
      Column(
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
            4,
          ),

          Text(
            value,

            style:
            const TextStyle(
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}