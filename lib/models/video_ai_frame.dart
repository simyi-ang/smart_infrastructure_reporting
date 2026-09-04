import 'dart:typed_data';

class VideoAiFrame {
  final int index;

  final int timestampMs;

  final Uint8List bytes;

  const VideoAiFrame({
    required this.index,
    required this.timestampMs,
    required this.bytes,
  });

  double get timestampSeconds =>
      timestampMs / 1000.0;
}