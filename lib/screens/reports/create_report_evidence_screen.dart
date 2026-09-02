import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_compression_service.dart';
import '../../theme/app_colors.dart';
import 'create_report_location_screen.dart';

class CreateReportEvidenceScreen extends StatefulWidget {
  final String category;
  final String priority;
  final String title;
  final String description;

  const CreateReportEvidenceScreen({
    super.key,
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
  });

  @override
  State<CreateReportEvidenceScreen> createState() =>
      _CreateReportEvidenceScreenState();
}

class _CreateReportEvidenceScreenState
    extends State<CreateReportEvidenceScreen> {
  final ImagePicker picker = ImagePicker();

  final ImageCompressionService compressionService =
  const ImageCompressionService();

  final List<File> evidenceImages = [];

  bool loadingImage = false;

  int totalCompressedBytes = 0;
  int compressedImageCount = 0;

  String compressionMessage =
      'Evidence images are optimized before upload.';

  Future<void> takePhoto() async {
    try {
      setState(() {
        loadingImage = true;
        compressionMessage = 'Preparing photo...';
      });

      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (image == null) {
        return;
      }

      await _addAndCompressFile(
        File(image.path),
      );
    } catch (e) {
      showMessage(
        'Unable to open camera: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingImage = false;
        });
      }
    }
  }

  Future<void> pickGalleryImages() async {
    try {
      setState(() {
        loadingImage = true;
        compressionMessage = 'Preparing selected images...';
      });

      final List<XFile> images =
      await picker.pickMultiImage(
        imageQuality: 95,
      );

      if (images.isEmpty) {
        return;
      }

      for (int index = 0;
      index < images.length;
      index++) {
        if (mounted) {
          setState(() {
            compressionMessage =
            'Optimizing image ${index + 1} of ${images.length}...';
          });
        }

        await _addAndCompressFile(
          File(images[index].path),
        );
      }
    } catch (e) {
      showMessage(
        'Unable to open gallery: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingImage = false;

          if (evidenceImages.isNotEmpty) {
            compressionMessage =
            '$compressedImageCount image(s) compressed before upload.';
          }
        });
      }
    }
  }

  Future<void> _addAndCompressFile(
      File originalFile,
      ) async {
    final ImageCompressionResult result =
    await compressionService.compressEvidenceImage(
      originalFile,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      evidenceImages.add(result.file);
      totalCompressedBytes += result.compressedBytes;

      if (result.compressed) {
        compressedImageCount++;
      }

      compressionMessage = result.compressed
          ? 'Image optimized: '
          '${compressionService.formatBytes(result.originalBytes)} → '
          '${compressionService.formatBytes(result.compressedBytes)} '
          '(${result.savedPercentage.toStringAsFixed(0)}% smaller)'
          : 'Image ready for upload.';
    });
  }

  Future<void> removeImage(int index) async {
    if (index < 0 ||
        index >= evidenceImages.length) {
      return;
    }

    final File file = evidenceImages[index];
    final int currentBytes = await file.length();

    setState(() {
      evidenceImages.removeAt(index);
      totalCompressedBytes =
          (totalCompressedBytes - currentBytes).clamp(0, 1 << 62);
    });

    await compressionService.deleteTemporaryCompressedFile(
      file,
    );
  }

  void continueToLocation() {
    if (evidenceImages.isEmpty) {
      showMessage(
        'Please add at least one evidence image.',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateReportLocationScreen(
              category: widget.category,
              priority: widget.priority,
              title: widget.title,
              description:
              widget.description,
              evidenceImages:
              evidenceImages,
            ),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                                  context);
                            },

                            icon:
                            const Icon(
                              Icons.arrow_back,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 14,
                        ),

                        const Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            Text(
                              'Report Issue',
                              style:
                              TextStyle(
                                fontSize: 22,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            Text(
                              'Help improve your community',
                              style:
                              TextStyle(
                                color:
                                AppColors
                                    .textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const _EvidenceProgress(),

                    const SizedBox(
                      height: 22,
                    ),

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
                        const Color(
                          0xFF10253E,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          15,
                        ),

                        border:
                        Border.all(
                          color:
                          const Color(
                            0xFF375B91,
                          ),
                        ),
                      ),

                      child: const Row(
                        children: [
                          Text(
                            '✨',
                            style:
                            TextStyle(
                              fontSize: 25,
                            ),
                          ),

                          SizedBox(
                            width: 12,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                              children: [
                                Text(
                                  'Smart Assist Available',
                                  style:
                                  TextStyle(
                                    color:
                                    Color(
                                      0xFF8F80FF,
                                    ),
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),

                                SizedBox(
                                  height: 3,
                                ),

                                Text(
                                  'AI analysis will be added later',
                                  style:
                                  TextStyle(
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
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10253E),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF375B91),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.compress_outlined,
                            color: AppColors.primary,
                            size: 25,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Image Optimization',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loadingImage
                                      ? compressionMessage
                                      : evidenceImages.isEmpty
                                      ? 'Evidence images are compressed before upload to reduce file size.'
                                      : '$compressionMessage\nPrepared size: '
                                      '${compressionService.formatBytes(totalCompressedBytes)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width:
                      double.infinity,

                      height: 190,

                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.surface,

                        borderRadius:
                        BorderRadius
                            .circular(
                          18,
                        ),

                        border:
                        Border.all(
                          color:
                          AppColors
                              .primaryDark,
                          width: 1.5,
                        ),
                      ),

                      child: const Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                        children: [
                          Icon(
                            Icons
                                .cloud_upload_outlined,
                            size: 48,
                            color:
                            AppColors
                                .primary,
                          ),

                          SizedBox(
                            height: 10,
                          ),

                          Text(
                            'Upload Evidence',
                            style:
                            TextStyle(
                              fontSize: 16,
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),

                          SizedBox(
                            height: 6,
                          ),

                          Text(
                            'Take a photo or choose from gallery',
                            style:
                            TextStyle(
                              color:
                              AppColors
                                  .textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                          OutlinedButton
                              .icon(
                            onPressed:
                            loadingImage
                                ? null
                                : takePhoto,

                            icon:
                            const Icon(
                              Icons
                                  .camera_alt_outlined,
                            ),

                            label:
                            const Text(
                              'Take Photo',
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child:
                          OutlinedButton
                              .icon(
                            onPressed:
                            loadingImage
                                ? null
                                : pickGalleryImages,

                            icon:
                            const Icon(
                              Icons
                                  .photo_library_outlined,
                            ),

                            label:
                            const Text(
                              'Gallery',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    if (evidenceImages
                        .isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,

                        physics:
                        const NeverScrollableScrollPhysics(),

                        itemCount:
                        evidenceImages
                            .length,

                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing:
                          9,
                          mainAxisSpacing: 9,
                        ),

                        itemBuilder:
                            (
                            context,
                            index,
                            ) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child:
                                ClipRRect(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    12,
                                  ),

                                  child:
                                  Image.file(
                                    evidenceImages[
                                    index],
                                    fit: BoxFit
                                        .cover,
                                  ),
                                ),
                              ),

                              Positioned(
                                right: 4,
                                top: 4,

                                child:
                                GestureDetector(
                                  onTap: () {
                                    removeImage(
                                      index,
                                    );
                                  },

                                  child:
                                  Container(
                                    padding:
                                    const EdgeInsets
                                        .all(
                                      4,
                                    ),

                                    decoration:
                                    const BoxDecoration(
                                      color:
                                      Colors
                                          .black54,
                                      shape:
                                      BoxShape
                                          .circle,
                                    ),

                                    child:
                                    const Icon(
                                      Icons.close,
                                      size: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            Padding(
              padding:
              const EdgeInsets.all(
                18,
              ),

              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(
                          context);
                    },

                    child:
                    const Text(
                      'Back',
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                    ElevatedButton(
                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        AppColors
                            .primaryDark,

                        minimumSize:
                        const Size
                            .fromHeight(
                          54,
                        ),
                      ),

                      onPressed:
                      continueToLocation,

                      child:
                      const Text(
                        'Continue →',
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

class _EvidenceProgress
    extends StatelessWidget {
  const _EvidenceProgress();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Divider(
                thickness: 4,
                color:
                AppColors.success,
              ),

              Text(
                '✓ Details',
                style:
                TextStyle(
                  color:
                  AppColors.success,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Column(
            children: [
              Divider(
                thickness: 4,
                color:
                AppColors.primary,
              ),

              Text(
                'Evidence',
                style:
                TextStyle(
                  color:
                  AppColors.primary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Column(
            children: [
              Divider(
                thickness: 4,
                color:
                AppColors.border,
              ),

              Text(
                'Location',
                style:
                TextStyle(
                  color: AppColors
                      .textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}