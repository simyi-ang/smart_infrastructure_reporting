import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'create_report_evidence_screen.dart';

class CreateReportDetailsScreen extends StatefulWidget {
  const CreateReportDetailsScreen({super.key});

  @override
  State<CreateReportDetailsScreen> createState() =>
      _CreateReportDetailsScreenState();
}

class _CreateReportDetailsScreenState
    extends State<CreateReportDetailsScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String? selectedCategory;
  String? selectedPriority;

  final List<Map<String, String>> categories = [
    {
      'name': 'Road Damage',
      'icon': '🛣️',
    },
    {
      'name': 'Street Light',
      'icon': '💡',
    },
    {
      'name': 'Drainage',
      'icon': '🌊',
    },
    {
      'name': 'Public Facility',
      'icon': '🏗️',
    },
    {
      'name': 'Other',
      'icon': '📌',
    },
  ];

  final List<String> priorities = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void continueToEvidence() {
    if (selectedCategory == null) {
      showMessage(
        'Please select an issue category.',
      );
      return;
    }

    if (selectedPriority == null) {
      showMessage(
        'Please select a priority level.',
      );
      return;
    }

    if (titleController.text.trim().isEmpty) {
      showMessage(
        'Please enter a report title.',
      );
      return;
    }

    if (descriptionController.text.trim().length < 10) {
      showMessage(
        'Please provide a more detailed description.',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateReportEvidenceScreen(
          category: selectedCategory!,
          priority: selectedPriority!,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
        ),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'Low':
        return const Color(0xFF2EE6A6);

      case 'Medium':
        return const Color(0xFFFFC62E);

      case 'High':
        return const Color(0xFFFF7A32);

      case 'Critical':
        return const Color(0xFFFF526D);

      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Issue',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Help improve your community',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Progress
                    const _ProgressHeader(
                      currentStep: 1,
                    ),

                    const SizedBox(height: 26),

                    const Text(
                      'ISSUE CATEGORY',
                      style: _sectionTitle,
                    ),

                    const SizedBox(height: 12),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.05,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final category = categories[index];

                        final String name =
                            category['name'] ?? '';

                        final String icon =
                            category['icon'] ?? '';

                        final bool selected =
                            selectedCategory == name;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCategory = name;
                            });
                          },
                          child: AnimatedContainer(
                            duration:
                            const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withOpacity(0.12)
                                  : AppColors.surface,
                              borderRadius:
                              BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Text(
                                  icon,
                                  style: const TextStyle(
                                    fontSize: 28,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 26),

                    const Text(
                      'PRIORITY LEVEL',
                      style: _sectionTitle,
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: priorities.map(
                            (priority) {
                          final bool selected =
                              selectedPriority == priority;

                          final Color color =
                          getPriorityColor(priority);

                          return Expanded(
                            child: Padding(
                              padding:
                              const EdgeInsets.only(right: 7),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedPriority = priority;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(
                                    milliseconds: 160,
                                  ),
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(
                                      selected ? 0.17 : 0.08,
                                    ),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? color
                                          : color.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Text(
                                    priority,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'REPORT TITLE',
                      style: _sectionTitle,
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: titleController,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hint:
                        'e.g., Large pothole on Jalan Ampang',
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'DESCRIPTION',
                      style: _sectionTitle,
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: descriptionController,
                      maxLength: 500,
                      minLines: 5,
                      maxLines: 7,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: _inputDecoration(
                        hint:
                        'Describe the issue in detail. Include size, severity, and any safety concerns...',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                18,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: continueToEvidence,
                  child: const Text(
                    'Continue →',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

const TextStyle _sectionTitle = TextStyle(
  color: Color(0xFFA9C7EF),
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
);

InputDecoration _inputDecoration({
  required String hint,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppColors.textSecondary,
    ),
    filled: true,
    fillColor: AppColors.surface,
    counterStyle: const TextStyle(
      color: AppColors.textSecondary,
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: AppColors.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: AppColors.primary,
        width: 1.5,
      ),
    ),
  );
}

class _ProgressHeader extends StatelessWidget {
  final int currentStep;

  const _ProgressHeader({
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProgressItem(
          label: 'Details',
          active: currentStep >= 1,
          complete: currentStep > 1,
        ),
        _ProgressItem(
          label: 'Evidence',
          active: currentStep >= 2,
          complete: currentStep > 2,
        ),
        _ProgressItem(
          label: 'Location',
          active: currentStep >= 3,
          complete: false,
        ),
      ],
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final String label;
  final bool active;
  final bool complete;

  const _ProgressItem({
    required this.label,
    required this.active,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(
              horizontal: 4,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : AppColors.border,
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            complete ? '✓ $label' : label,
            style: TextStyle(
              color: active
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}