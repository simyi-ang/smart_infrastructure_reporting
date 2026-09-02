import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressionResult {
  final File file;
  final int originalBytes;
  final int compressedBytes;
  final bool compressed;

  const ImageCompressionResult({
    required this.file,
    required this.originalBytes,
    required this.compressedBytes,
    required this.compressed,
  });

  int get savedBytes =>
      originalBytes - compressedBytes;

  double get savedPercentage {
    if (originalBytes <= 0) {
      return 0;
    }
    return (savedBytes / originalBytes) * 100;
  }
}

class ImageCompressionService {
  const ImageCompressionService();

  Future<ImageCompressionResult> compressEvidenceImage(
      File originalFile,
      ) async {
    final int originalBytes =
    await originalFile.length();

    if (originalBytes <= 250 * 1024) {
      return ImageCompressionResult(
        file: originalFile,
        originalBytes: originalBytes,
        compressedBytes: originalBytes,
        compressed: false,
      );
    }

    final String targetPath =
        '${originalFile.parent.path}/smartcity_compressed_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg';

    try {
      final XFile? compressedXFile =
      await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        minWidth: 1600,
        minHeight: 1600,
        quality: 72,
        format: CompressFormat.jpeg,
        keepExif: true,
        autoCorrectionAngle: true,
      );

      if (compressedXFile == null) {
        return ImageCompressionResult(
          file: originalFile,
          originalBytes: originalBytes,
          compressedBytes: originalBytes,
          compressed: false,
        );
      }

      final File compressedFile =
      File(compressedXFile.path);
      final int compressedBytes =
      await compressedFile.length();

      if (compressedBytes >= originalBytes) {
        await _safeDelete(compressedFile);
        return ImageCompressionResult(
          file: originalFile,
          originalBytes: originalBytes,
          compressedBytes: originalBytes,
          compressed: false,
        );
      }

      return ImageCompressionResult(
        file: compressedFile,
        originalBytes: originalBytes,
        compressedBytes: compressedBytes,
        compressed: true,
      );
    } catch (_) {
      return ImageCompressionResult(
        file: originalFile,
        originalBytes: originalBytes,
        compressedBytes: originalBytes,
        compressed: false,
      );
    }
  }

  Future<void> deleteTemporaryCompressedFile(
      File file,
      ) async {
    if (!file.path.contains('smartcity_compressed_')) {
      return;
    }
    await _safeDelete(file);
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final double kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final double mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}
