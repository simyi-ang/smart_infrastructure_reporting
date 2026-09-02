import 'package:flutter/material.dart';

import '../../models/infrastructure_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

class EditReportScreen extends StatefulWidget {
  final InfrastructureReport report;

  const EditReportScreen({
    super.key,
    required this.report,
  });

  @override
  State<EditReportScreen> createState() =>
      _EditReportScreenState();
}

class _EditReportScreenState
    extends State<EditReportScreen> {
  final ReportService reportService =
  ReportService();

  final _formKey =
  GlobalKey<FormState>();

  late TextEditingController titleController;

  late TextEditingController
  descriptionController;

  late TextEditingController
  addressController;

  late TextEditingController
  landmarkController;

  late String selectedCategory;

  late String selectedPriority;

  bool saving = false;

  final List<String> categories = [
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  final List<String> priorities = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  @override
  void initState() {
    super.initState();

    selectedCategory =
        widget.report.category;

    selectedPriority =
        widget.report.priority;

    titleController =
        TextEditingController(
          text: widget.report.title,
        );

    descriptionController =
        TextEditingController(
          text: widget.report.description,
        );

    addressController =
        TextEditingController(
          text: widget.report.address,
        );

    landmarkController =
        TextEditingController(
          text: widget.report.landmark ?? '',
        );
  }

  @override
  void dispose() {
    titleController.dispose();

    descriptionController.dispose();

    addressController.dispose();

    landmarkController.dispose();

    super.dispose();
  }

  Future<void> saveReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await reportService.updateReport(
        reportId:
        widget.report.id,

        title:
        titleController.text,

        category:
        selectedCategory,

        priority:
        selectedPriority,

        description:
        descriptionController.text,

        address:
        addressController.text,

        landmark:
        landmarkController.text,

        latitude:
        widget.report.latitude,

        longitude:
        widget.report.longitude,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
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

                child: Form(
                  key:
                  _formKey,

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [
                      // =========================================
                      // HEADER
                      // =========================================

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
                                Icons
                                    .arrow_back,
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
                              CrossAxisAlignment
                                  .start,

                              children: [
                                const Text(
                                  'Edit Report',

                                  style:
                                  TextStyle(
                                    fontSize:
                                    22,

                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),

                                Text(
                                  widget.report
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
                        ],
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      Container(
                        padding:
                        const EdgeInsets.all(
                          13,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          AppColors
                              .primary
                              .withOpacity(
                            0.08,
                          ),

                          borderRadius:
                          BorderRadius
                              .circular(
                            13,
                          ),

                          border:
                          Border.all(
                            color:
                            AppColors
                                .primaryDark,
                          ),
                        ),

                        child:
                        const Row(
                          children: [
                            Icon(
                              Icons
                                  .info_outline,

                              color:
                              AppColors
                                  .primary,

                              size:
                              19,
                            ),

                            SizedBox(
                              width:
                              10,
                            ),

                            Expanded(
                              child:
                              Text(
                                'You can edit this report because it is still pending review.',

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
                      ),

                      const SizedBox(
                        height:
                        24,
                      ),

                      const _Label(
                        'ISSUE CATEGORY',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      DropdownButtonFormField<String>(
                        value:
                        selectedCategory,

                        dropdownColor:
                        AppColors.surface,

                        decoration:
                        _decoration(),

                        items:
                        categories
                            .map(
                              (category) {
                            return DropdownMenuItem(
                              value:
                              category,

                              child:
                              Text(
                                category,
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
                            setState(
                                  () {
                                selectedCategory =
                                    value;
                              },
                            );
                          }
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      const _Label(
                        'PRIORITY',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      DropdownButtonFormField<String>(
                        value:
                        selectedPriority,

                        dropdownColor:
                        AppColors.surface,

                        decoration:
                        _decoration(),

                        items:
                        priorities
                            .map(
                              (priority) {
                            return DropdownMenuItem(
                              value:
                              priority,

                              child:
                              Text(
                                priority,
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
                            setState(
                                  () {
                                selectedPriority =
                                    value;
                              },
                            );
                          }
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      const _Label(
                        'REPORT TITLE',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      TextFormField(
                        controller:
                        titleController,

                        enabled:
                        !saving,

                        decoration:
                        _decoration(
                          hint:
                          'Report title',
                        ),

                        validator:
                            (value) {
                          if (value ==
                              null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Report title is required.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      const _Label(
                        'DESCRIPTION',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      TextFormField(
                        controller:
                        descriptionController,

                        enabled:
                        !saving,

                        minLines:
                        5,

                        maxLines:
                        8,

                        maxLength:
                        500,

                        decoration:
                        _decoration(
                          hint:
                          'Describe the issue',
                        ),

                        validator:
                            (value) {
                          if (value ==
                              null ||
                              value
                                  .trim()
                                  .length <
                                  10) {
                            return 'Please provide a more detailed description.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      const _Label(
                        'ADDRESS',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      TextFormField(
                        controller:
                        addressController,

                        enabled:
                        !saving,

                        decoration:
                        _decoration(
                          hint:
                          'Issue location',
                        ),

                        validator:
                            (value) {
                          if (value ==
                              null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Address is required.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height:
                        20,
                      ),

                      const _Label(
                        'ADDITIONAL LANDMARK',
                      ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      TextFormField(
                        controller:
                        landmarkController,

                        enabled:
                        !saving,

                        decoration:
                        _decoration(
                          hint:
                          'Optional landmark',
                        ),
                      ),

                      const SizedBox(
                        height:
                        25,
                      ),

                      Container(
                        padding:
                        const EdgeInsets.all(
                          13,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          AppColors.surface,

                          borderRadius:
                          BorderRadius
                              .circular(
                            13,
                          ),

                          border:
                          Border.all(
                            color:
                            AppColors
                                .border,
                          ),
                        ),

                        child:
                        const Row(
                          children: [
                            Icon(
                              Icons
                                  .photo_library_outlined,

                              color:
                              AppColors
                                  .textSecondary,
                            ),

                            SizedBox(
                              width:
                              10,
                            ),

                            Expanded(
                              child:
                              Text(
                                'Existing evidence photos will be kept. Evidence editing can be added separately.',

                                style:
                                TextStyle(
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
                    ],
                  ),
                ),
              ),
            ),

            // =============================================
            // SAVE
            // =============================================

            Container(
              padding:
              const EdgeInsets.all(
                18,
              ),

              decoration:
              const BoxDecoration(
                color:
                AppColors.background,

                border:
                Border(
                  top:
                  BorderSide(
                    color:
                    AppColors
                        .border,
                  ),
                ),
              ),

              child:
              SizedBox(
                width:
                double.infinity,

                height:
                54,

                child:
                ElevatedButton.icon(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    AppColors
                        .primaryDark,
                  ),

                  onPressed:
                  saving
                      ? null
                      : saveReport,

                  icon:
                  saving
                      ? const SizedBox(
                    width:
                    19,
                    height:
                    19,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color:
                      Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons
                        .save_outlined,
                  ),

                  label:
                  Text(
                    saving
                        ? 'Saving...'
                        : 'Save Changes',
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

class _Label extends StatelessWidget {
  final String text;

  const _Label(
      this.text,
      );

  @override
  Widget build(
      BuildContext context,
      ) {
    return Text(
      text,

      style:
      const TextStyle(
        color:
        Color(
          0xFFA9C7EF,
        ),

        fontSize:
        11,

        fontWeight:
        FontWeight.w600,
      ),
    );
  }
}

InputDecoration _decoration({
  String? hint,
}) {
  return InputDecoration(
    hintText:
    hint,

    hintStyle:
    const TextStyle(
      color:
      AppColors
          .textSecondary,
    ),

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

    errorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.danger,
      ),
    ),
  );
}