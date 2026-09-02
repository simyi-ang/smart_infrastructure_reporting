import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;

  // NEW: accuracy reported by the device GPS in metres.
  final double accuracy;

  final String address;
  final String? country;
  final String? locality;
  final String? postalCode;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.address,
    this.country,
    this.locality,
    this.postalCode,
  });

  // ============================================================
  // GPS ACCURACY DISPLAY
  // ============================================================

  String get accuracyLabel {
    if (accuracy <= 10) {
      return 'Excellent';
    }

    if (accuracy <= 25) {
      return 'Good';
    }

    if (accuracy <= 50) {
      return 'Moderate';
    }

    return 'Low';
  }

  String get accuracyText {
    return '$accuracyLabel • ±${accuracy.toStringAsFixed(0)} m';
  }

  bool get hasGoodAccuracy {
    return accuracy <= 50;
  }
}

class LocationService {
  final Geocoding _geocoding =
  Geocoding();

  // ============================================================
  // CHECK GPS + PERMISSION
  // ============================================================

  Future<void> ensureLocationPermission() async {
    final bool serviceEnabled =
    await Geolocator
        .isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please turn on GPS.',
      );
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
      await Geolocator
          .requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw Exception(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
            'Please enable location permission in app settings.',
      );
    }
  }

  // ============================================================
  // GET CURRENT GPS POSITION
  // ============================================================

  Future<Position> getCurrentPosition() async {
    await ensureLocationPermission();

    try {
      return await Geolocator
          .getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.high,

          // Avoid the screen hanging forever while waiting
          // for a new GPS fix.
          timeLimit:
          Duration(
            seconds: 15,
          ),
        ),
      );
    } catch (e) {
      // If a fresh high-accuracy reading times out,
      // try the last known position as a fallback.
      try {
        final Position? lastKnown =
        await Geolocator
            .getLastKnownPosition();

        if (lastKnown != null) {
          return lastKnown;
        }
      } catch (_) {}

      throw Exception(
        'Unable to get current GPS location: $e',
      );
    }
  }

  // ============================================================
  // REVERSE GEOCODING
  // ============================================================

  Future<Placemark?> getPlacemark({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final List<Placemark> placemarks =
      await _geocoding
          .placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return null;
      }

      return placemarks.first;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // GPS -> ADDRESS
  // ============================================================

  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final Placemark? place =
    await getPlacemark(
      latitude:
      latitude,
      longitude:
      longitude,
    );

    if (place == null) {
      return _coordinateFallback(
        latitude,
        longitude,
      );
    }

    final List<String> addressParts = [];

    void addPart(
        String? value,
        ) {
      if (value == null) {
        return;
      }

      final String cleaned =
      value.trim();

      if (cleaned.isEmpty) {
        return;
      }

      if (!addressParts
          .contains(cleaned)) {
        addressParts.add(
          cleaned,
        );
      }
    }

    // Good order for Malaysian addresses.
    addPart(
      place.street,
    );

    addPart(
      place.subLocality,
    );

    addPart(
      place.locality,
    );

    addPart(
      place.postalCode,
    );

    addPart(
      place.administrativeArea,
    );

    addPart(
      place.country,
    );

    if (addressParts.isEmpty) {
      return _coordinateFallback(
        latitude,
        longitude,
      );
    }

    return addressParts.join(
      ', ',
    );
  }

  // ============================================================
  // GET CURRENT GPS + ADDRESS + ACCURACY
  // ============================================================

  Future<LocationResult>
  getCurrentLocationWithAddress() async {
    final Position position =
    await getCurrentPosition();

    final Placemark? place =
    await getPlacemark(
      latitude:
      position.latitude,
      longitude:
      position.longitude,
    );

    String address;

    if (place == null) {
      address =
          _coordinateFallback(
            position.latitude,
            position.longitude,
          );
    } else {
      final List<String> parts = [];

      void addPart(
          String? value,
          ) {
        if (value == null) {
          return;
        }

        final String cleaned =
        value.trim();

        if (cleaned.isEmpty) {
          return;
        }

        if (!parts.contains(cleaned)) {
          parts.add(cleaned);
        }
      }

      addPart(
        place.street,
      );

      addPart(
        place.subLocality,
      );

      addPart(
        place.locality,
      );

      addPart(
        place.postalCode,
      );

      addPart(
        place.administrativeArea,
      );

      addPart(
        place.country,
      );

      address =
      parts.isEmpty
          ? _coordinateFallback(
        position.latitude,
        position.longitude,
      )
          : parts.join(
        ', ',
      );
    }

    return LocationResult(
      latitude:
      position.latitude,
      longitude:
      position.longitude,

      // NEW: Position.accuracy is in metres.
      accuracy:
      position.accuracy,

      address:
      address,
      country:
      place?.country,
      locality:
      place?.locality,
      postalCode:
      place?.postalCode,
    );
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Future<bool>
  openLocationSettings() async {
    return await Geolocator
        .openLocationSettings();
  }

  Future<bool>
  openAppSettings() async {
    return await Geolocator
        .openAppSettings();
  }

  // ============================================================
  // FALLBACK
  // ============================================================

  String _coordinateFallback(
      double latitude,
      double longitude,
      ) {
    return '${latitude.toStringAsFixed(6)}, '
        '${longitude.toStringAsFixed(6)}';
  }
}
