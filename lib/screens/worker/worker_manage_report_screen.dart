import 'package:flutter/material.dart';

import '../../models/infrastructure_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

class WorkerManageReportScreen
    extends StatefulWidget {
  final InfrastructureReport report;

  const WorkerManageReportScreen({
    super.key,
    required this.report,
  });

  @override
  State<WorkerManageReportScreen>
  createState() =>
      _WorkerManageReportScreenState();
}

class _WorkerManageReportScreenState
    extends State<WorkerManageReportScreen> {
  final ReportService reportService =
  ReportService();

  late String selectedStatus;

  late int progress;

  String? selectedDepartment;

  DateTime? estimatedCompletion;

  bool saving = false;

  final List<String> statuses = [
    'pending',
    'verified',
    'in_progress',
    'completed',
    'rejected',
  ];

  final List<String> departments = [
    'Jabatan Kerja Raya',
    'TNB / DBKL',
    'DBKL',
    'Dewan Bandaraya KL',
    'Local Authority',
  ];

  @override
  void initState() {
    super.initState();

    selectedStatus =
        widget.report.status;

    progress =
        widget.report.progressPercentage;

    selectedDepartment =
        widget.report.assignedDepartment;

    estimatedCompletion =
        widget.report.estimatedCompletion;
  }

  String statusLabel(
      String status,
      ) {
    switch (status) {
      case 'pending':
        return 'Pending';

      case 'verified':
        return 'Verified';

      case 'in_progress':
        return 'In Progress';

      case 'completed':
        return 'Completed';

      case 'rejected':
        return 'Rejected';

      default:
        return status;
    }
  }

  void applyRecommendedProgress(
      String status,
      ) {
    setState(() {
      selectedStatus = status;

      switch (status) {
        case 'pending':
          progress = 10;
          break;

        case 'verified':
          progress = 30;
          break;

        case 'in_progress':
          progress = 75;
          break;

        case 'completed':
          progress = 100;
          break;

        case 'rejected':
          progress = 0;
          break;
      }
    });
  }

  Future<void> selectDate() async {
    final now = DateTime.now();

    final result =
    await showDatePicker(
      context:
      context,

      initialDate:
      estimatedCompletion ??
          now.add(
            const Duration(
              days: 7,
            ),
          ),

      firstDate:
      now,

      lastDate:
      now.add(
        const Duration(
          days: 365,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      estimatedCompletion =
          result;
    });
  }

  Future<void> save() async {
    if (selectedStatus ==
        'in_progress' &&
        selectedDepartment ==
            null) {
      showMessage(
        'Please assign a department.',
      );

      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await reportService
          .updateReportWorkflow(
        reportId:
        widget.report.id,

        status:
        selectedStatus,

        progressPercentage:
        progress,

        assignedDepartment:
        selectedDepartment,

        estimatedCompletion:
        estimatedCompletion,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text(
            'Report updated successfully.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
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
          saving = false;
        });
      }
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
        content:
        Text(
          message,
        ),
      ),
    );
  }

  String formatDate(
      DateTime? date,
      ) {
    if (date == null) {
      return 'Not set';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      body:
      SafeArea(
        child:
        Column(
          children: [
            Expanded(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.all(
                  20,
                ),

                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed:
                          saving
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

                        Expanded(
                          child:
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [
                              const Text(
                                'Manage Report',

                                style:
                                TextStyle(
                                  fontSize:
                                  22,

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),

                              Text(
                                widget.report
                                    .referenceNumber,

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
                      ],
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    Container(
                      width:
                      double.infinity,

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
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          Text(
                            widget.report.title,

                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight.bold,

                              fontSize:
                              15,
                            ),
                          ),

                          const SizedBox(
                            height:
                            6,
                          ),

                          Text(
                            widget.report.description,

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
                            8,
                          ),

                          Text(
                            '📍 ${widget.report.address}',

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

                    const SizedBox(
                      height:
                      22,
                    ),

                    const Text(
                      'STATUS',

                      style:
                      TextStyle(
                        color:
                        Color(
                          0xFFA9C7EF,
                        ),

                        fontSize:
                        11,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    DropdownButtonFormField<String>(
                      value:
                      selectedStatus,

                      dropdownColor:
                      AppColors.surface,

                      decoration:
                      _inputDecoration(),

                      items:
                      statuses
                          .map(
                            (status) {
                          return DropdownMenuItem(
                            value:
                            status,

                            child:
                            Text(
                              statusLabel(
                                status,
                              ),
                            ),
                          );
                        },
                      ).toList(),

                      onChanged:
                      saving
                          ? null
                          : (value) {
                        if (value !=
                            null) {
                          applyRecommendedProgress(
                            value,
                          );
                        }
                      },
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    const Text(
                      'ASSIGNED DEPARTMENT',

                      style:
                      TextStyle(
                        color:
                        Color(
                          0xFFA9C7EF,
                        ),

                        fontSize:
                        11,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    DropdownButtonFormField<String>(
                      value:
                      selectedDepartment,

                      dropdownColor:
                      AppColors.surface,

                      decoration:
                      _inputDecoration(
                        hint:
                        'Choose department',
                      ),

                      items:
                      departments
                          .map(
                            (department) {
                          return DropdownMenuItem(
                            value:
                            department,

                            child:
                            Text(
                              department,
                            ),
                          );
                        },
                      ).toList(),

                      onChanged:
                      saving
                          ? null
                          : (value) {
                        setState(() {
                          selectedDepartment =
                              value;
                        });
                      },
                    ),

                    const SizedBox(
                      height:
                      22,
                    ),

                    Row(
                      children: [
                        const Text(
                          'PROGRESS',

                          style:
                          TextStyle(
                            color:
                            Color(
                              0xFFA9C7EF,
                            ),

                            fontSize:
                            11,

                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          '$progress%',

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

                    Slider(
                      value:
                      progress.toDouble(),

                      min:
                      0,

                      max:
                      100,

                      divisions:
                      20,

                      activeColor:
                      AppColors.primary,

                      onChanged:
                      saving
                          ? null
                          : (value) {
                        setState(() {
                          progress =
                              value.round();
                        });
                      },
                    ),

                    const SizedBox(
                      height:
                      15,
                    ),

                    const Text(
                      'ESTIMATED COMPLETION',

                      style:
                      TextStyle(
                        color:
                        Color(
                          0xFFA9C7EF,
                        ),

                        fontSize:
                        11,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    InkWell(
                      onTap:
                      saving
                          ? null
                          : selectDate,

                      child:
                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets.symmetric(
                          horizontal:
                          14,

                          vertical:
                          16,
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
                            const Icon(
                              Icons.calendar_month_outlined,

                              color:
                              AppColors.primary,
                            ),

                            const SizedBox(
                              width:
                              10,
                            ),

                            Text(
                              formatDate(
                                estimatedCompletion,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding:
              const EdgeInsets.all(
                18,
              ),

              child:
              SizedBox(
                width:
                double.infinity,

                height:
                54,

                child:
                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.primaryDark,
                  ),

                  onPressed:
                  saving
                      ? null
                      : save,

                  child:
                  saving
                      ? const CircularProgressIndicator(
                    color:
                    Colors.white,
                  )
                      : const Text(
                    'Save Update',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  String? hint,
}) {
  return InputDecoration(
    hintText:
    hint,

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
  );
}