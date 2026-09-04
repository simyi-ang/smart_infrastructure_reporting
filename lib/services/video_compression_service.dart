import 'dart:io';

import 'package:video_compress/video_compress.dart';

class VideoCompressionResult {
  final File file;
  final int originalBytes;
  final int compressedBytes;
  final bool compressed;

  const VideoCompressionResult({
    required this.file,
    required this.originalBytes,
    required this.compressedBytes,
    required this.compressed,
  });

  double get savedPercentage {
    if (originalBytes <= 0) {
      return 0;
    }

    final double saved =
        ((originalBytes - compressedBytes) / originalBytes) * 100;

    return saved.clamp(0, 100);
  }
}

class VideoCompressionService {
  const VideoCompressionService();

  Future<VideoCompressionResult> compressEvidenceVideo(
      File originalFile,
      ) async {
    if (!await originalFile.exists()) {
      throw Exception(
        'The selected video is no longer available.',
      );
    }

    final int originalBytes =
    await originalFile.length();

    MediaInfo? mediaInfo;

    try {
      mediaInfo = await VideoCompress.compressVideo(
        originalFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      final String? compressedPath =
          mediaInfo?.path;

      if (compressedPath == null ||
          compressedPath.trim().isEmpty) {
        return VideoCompressionResult(
          file: originalFile,
          originalBytes: originalBytes,
          compressedBytes: originalBytes,
          compressed: false,
        );
      }

      final File compressedFile =
      File(compressedPath);

      if (!await compressedFile.exists()) {
        return VideoCompressionResult(
          file: originalFile,
          originalBytes: originalBytes,
          compressedBytes: originalBytes,
          compressed: false,
        );
      }

      final int compressedBytes =
      await compressedFile.length();

      // Compression occasionally produces a file that is
      // equal to or larger than the original.
      // In that situation keep the original instead.
      if (compressedBytes >= originalBytes) {
        await deleteTemporaryCompressedFile(
          compressedFile,
          originalFile: originalFile,
        );

        return VideoCompressionResult(
          file: originalFile,
          originalBytes: originalBytes,
          compressedBytes: originalBytes,
          compressed: false,
        );
      }

      return VideoCompressionResult(
        file: compressedFile,
        originalBytes: originalBytes,
        compressedBytes: compressedBytes,
        compressed: true,
      );
    } catch (_) {
      // Compression failure should not destroy valid evidence.
      return VideoCompressionResult(
        file: originalFile,
        originalBytes: originalBytes,
        compressedBytes: originalBytes,
        compressed: false,
      );
    }
  }

  Future<void> deleteTemporaryCompressedFile(
      File file, {
        File? originalFile,
      }) async {
    try {
      if (originalFile != null &&
          file.path == originalFile.path) {
        return;
      }

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Temporary cleanup failure is non-critical.
    }
  }

  String formatBytes(
      int bytes,
      ) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final double kb =
        bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final double mb =
        kb / 1024;

    return '${mb.toStringAsFixed(1)} MB';
  }
}