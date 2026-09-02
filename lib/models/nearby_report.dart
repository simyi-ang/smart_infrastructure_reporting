class NearbyReport {
  final String id;

  final String referenceNumber;

  final String title;

  final String category;

  final String priority;

  final String status;

  final String address;

  final double latitude;

  final double longitude;

  final double distanceMeters;

  const NearbyReport({
    required this.id,
    required this.referenceNumber,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  bool get isVeryClose =>
      distanceMeters <= 100;

  bool get isNearby =>
      distanceMeters <= 500;

  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m away';
    }

    return '${(distanceMeters / 1000).toStringAsFixed(1)} km away';
  }
}