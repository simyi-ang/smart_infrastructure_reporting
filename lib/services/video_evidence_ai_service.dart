import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/report_video_ai_analysis.dart';
import '../models/video_ai_frame.dart';

class VideoEvidenceAiService {
  VideoEvidenceAiService._();

  static final VideoEvidenceAiService instance =
  VideoEvidenceAiService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  static const String edgeFunctionName =
      'analyze-report-video';

  static const int maximumVideoBytes =
      100 * 1024 * 1024;

  static const int maximumVideoSeconds =
  30;

  static const int frameCount =
  5;

  static const List<double>
  _samplePositions = [
    0.10,
    0.30,
    0.50,
    0.70,
    0.90,
  ];

  Future<ReportVideoAiAnalysis>
  analyzeLocalVideo({
    required File videoFile,

    required String userCategory,
    required String userPriority,
    required String userTitle,
    required String userDescription,

    String? address,

    double? latitude,
    double? longitude,
  }) async {
    final Session? session =
        _supabase.auth.currentSession;

    if (session == null) {
      throw Exception(
        'Please sign in before using Video Smart Assist.',
      );
    }

    // ==========================================================
    // FILE VALIDATION
    // ==========================================================

    if (!await videoFile.exists()) {
      throw Exception(
        'The selected video could not be found.',
      );
    }

    final int bytes =
    await videoFile.length();

    if (bytes <= 0) {
      throw Exception(
        'The selected video is empty.',
      );
    }

    if (bytes >
        maximumVideoBytes) {
      throw Exception(
        'The selected video is too large for AI analysis.',
      );
    }

    // ==========================================================
    // DURATION
    // ==========================================================

    final Duration duration =
    await _readDuration(
      videoFile,
    );

    if (duration.inMilliseconds <=
        0) {
      throw Exception(
        'Unable to determine the video duration.',
      );
    }

    if (duration.inSeconds >
        maximumVideoSeconds) {
      throw Exception(
        'Video Smart Assist currently supports clips up to '
            '$maximumVideoSeconds seconds.',
      );
    }

    // ==========================================================
    // REPRESENTATIVE FRAME EXTRACTION
    // ==========================================================

    final List<VideoAiFrame> frames =
    await _extractFrames(
      videoFile:
      videoFile,

      duration:
      duration,
    );

    if (frames.length < 3) {
      throw Exception(
        'Not enough usable frames could be extracted from '
            'this video. Please try another recording.',
      );
    }

    // ==========================================================
    // BUILD REQUEST
    // ==========================================================

    final List<Map<String, dynamic>>
    encodedFrames =
    frames.map(
          (
          VideoAiFrame frame,
          ) {
        return {
          'index':
          frame.index,

          'timestamp_ms':
          frame.timestampMs,

          'timestamp_seconds':
          frame.timestampSeconds,

          'mime_type':
          'image/jpeg',

          'image_base64':
          base64Encode(
            frame.bytes,
          ),
        };
      },
    ).toList(
      growable: false,
    );

    // ==========================================================
    // EDGE FUNCTION
    // ==========================================================

    final FunctionResponse response =
    await _supabase.functions.invoke(
      edgeFunctionName,

      body: {
        'analysis_mode':
        'pre_submission',

        'video_duration_ms':
        duration.inMilliseconds,

        'frames':
        encodedFrames,

        'report_context': {
          'category':
          userCategory,

          'priority':
          userPriority,

          'title':
          userTitle.trim(),

          'description':
          userDescription.trim(),

          'address':
          address?.trim(),

          // These are context only.
          // AI must NEVER claim coordinates were visually verified.
          'latitude':
          latitude,

          'longitude':
          longitude,
        },
      },
    );

    final dynamic raw =
        response.data;

    if (raw is! Map) {
      throw Exception(
        'Video AI returned an invalid response.',
      );
    }

    final Map<String, dynamic> data =
    Map<String, dynamic>.from(
      raw,
    );

    final String error =
        data['error']
            ?.toString()
            .trim() ??
            '';

    if (error.isNotEmpty) {
      throw Exception(
        error,
      );
    }

    return ReportVideoAiAnalysis
        .fromJson(
      data,
    );
  }

  // ============================================================
  // DURATION
  // ============================================================

  Future<Duration> _readDuration(
      File videoFile,
      ) async {
    final VideoPlayerController
    controller =
    VideoPlayerController.file(
      videoFile,
    );

    try {
      await controller.initialize();

      return controller
          .value.duration;
    } finally {
      await controller.dispose();
    }
  }

  // ============================================================
  // EXTRACT REPRESENTATIVE FRAMES
  // ============================================================

  Future<List<VideoAiFrame>>
  _extractFrames({
    required File videoFile,
    required Duration duration,
  }) async {
    final List<VideoAiFrame> result =
    [];

    final int durationMs =
        duration.inMilliseconds;

    for (
    int index = 0;
    index < _samplePositions.length;
    index++
    ) {
      final double fraction =
      _samplePositions[index];

      final int timeMs =
      (durationMs * fraction)
          .round()
          .clamp(
        0,
        durationMs - 1,
      );

      try {
        final Uint8List? data =
        await VideoThumbnail
            .thumbnailData(
          video:
          videoFile.path,

          imageFormat:
          ImageFormat.JPEG,

          // Keep aspect ratio by setting width only.
          maxWidth:
          1280,

          quality:
          82,

          timeMs:
          timeMs,
        );

        if (data == null ||
            data.isEmpty) {
          continue;
        }

        result.add(
          VideoAiFrame(
            index:
            index,

            timestampMs:
            timeMs,

            bytes:
            data,
          ),
        );
      } catch (_) {
        // One damaged/unavailable frame should not
        // invalidate the whole clip.
      }
    }

    return result;
  }
}