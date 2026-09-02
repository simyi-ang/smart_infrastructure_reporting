import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/location_service.dart';
import '../../theme/app_colors.dart';

class MapPickerResult {
  final double latitude;

  final double longitude;

  final String address;

  const MapPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class MapPickerScreen
    extends StatefulWidget {
  final double initialLatitude;

  final double initialLongitude;

  const MapPickerScreen({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
  });

  @override
  State<MapPickerScreen> createState() =>
      _MapPickerScreenState();
}

class _MapPickerScreenState
    extends State<MapPickerScreen> {
  final LocationService locationService =
  LocationService();

  GoogleMapController? mapController;

  late LatLng selectedPosition;

  String selectedAddress =
      'Move the pin to select a location';

  bool loadingAddress = true;

  @override
  void initState() {
    super.initState();

    selectedPosition =
        LatLng(
          widget.initialLatitude,
          widget.initialLongitude,
        );

    loadAddress();
  }

  // ============================================================
  // LOAD ADDRESS
  // ============================================================

  Future<void> loadAddress() async {
    setState(() {
      loadingAddress = true;
    });

    try {
      final String address =
      await locationService
          .getAddressFromCoordinates(
        latitude:
        selectedPosition.latitude,

        longitude:
        selectedPosition.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        selectedAddress =
            address;

        loadingAddress =
        false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        selectedAddress =
        '${selectedPosition.latitude.toStringAsFixed(6)}, '
            '${selectedPosition.longitude.toStringAsFixed(6)}';

        loadingAddress =
        false;
      });
    }
  }

  // ============================================================
  // MAP TAP
  // ============================================================

  Future<void> selectLocation(
      LatLng position,
      ) async {
    setState(() {
      selectedPosition =
          position;
    });

    await loadAddress();
  }

  // ============================================================
  // CURRENT GPS
  // ============================================================

  Future<void> useCurrentLocation() async {
    try {
      final result =
      await locationService
          .getCurrentLocationWithAddress();

      final LatLng position =
      LatLng(
        result.latitude,
        result.longitude,
      );

      setState(() {
        selectedPosition =
            position;

        selectedAddress =
            result.address;
      });

      await mapController
          ?.animateCamera(
        CameraUpdate.newLatLngZoom(
          position,
          17,
        ),
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
    }
  }

  // ============================================================
  // CONFIRM
  // ============================================================

  void confirmLocation() {
    Navigator.pop(
      context,

      MapPickerResult(
        latitude:
        selectedPosition.latitude,

        longitude:
        selectedPosition.longitude,

        address:
        selectedAddress,
      ),
    );
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
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                12,
                10,
                12,
                10,
              ),

              child: Row(
                children: [
                  Container(
                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.surface,

                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),

                      border:
                      Border.all(
                        color:
                        AppColors.border,
                      ),
                    ),

                    child:
                    IconButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },

                      icon:
                      const Icon(
                        Icons.arrow_back,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Choose Location',

                          style:
                          TextStyle(
                            fontSize: 20,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        Text(
                          'Tap anywhere on the map',

                          style:
                          TextStyle(
                            color:
                            AppColors
                                .textSecondary,

                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // MAP
            // ==================================================

            Expanded(
              child:
              Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition:
                    CameraPosition(
                      target:
                      selectedPosition,

                      zoom:
                      16,
                    ),

                    myLocationEnabled:
                    true,

                    myLocationButtonEnabled:
                    false,

                    zoomControlsEnabled:
                    false,

                    compassEnabled:
                    true,

                    markers: {
                      Marker(
                        markerId:
                        const MarkerId(
                          'selected_location',
                        ),

                        position:
                        selectedPosition,

                        draggable:
                        true,

                        onDragEnd:
                            (
                            LatLng value,
                            ) {
                          selectLocation(
                            value,
                          );
                        },
                      ),
                    },

                    onTap:
                    selectLocation,

                    onMapCreated:
                        (
                        controller,
                        ) {
                      mapController =
                          controller;
                    },
                  ),

                  Positioned(
                    right: 16,
                    bottom: 18,

                    child:
                    FloatingActionButton(
                      heroTag:
                      'current_location',

                      mini:
                      true,

                      backgroundColor:
                      AppColors
                          .primaryDark,

                      onPressed:
                      useCurrentLocation,

                      child:
                      const Icon(
                        Icons
                            .my_location,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // SELECTED ADDRESS
            // ==================================================

            Container(
              width:
              double.infinity,

              padding:
              const EdgeInsets.all(
                16,
              ),

              decoration:
              const BoxDecoration(
                color:
                AppColors.surface,

                border:
                Border(
                  top:
                  BorderSide(
                    color:
                    AppColors.border,
                  ),
                ),
              ),

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Text(
                    'SELECTED LOCATION',

                    style:
                    TextStyle(
                      color:
                      AppColors
                          .textSecondary,

                      fontSize:
                      9,

                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      const Icon(
                        Icons
                            .location_on_outlined,

                        color:
                        AppColors.primary,

                        size:
                        20,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                        loadingAddress
                            ? const Text(
                          'Finding address...',
                        )
                            : Text(
                          selectedAddress,

                          style:
                          const TextStyle(
                            fontSize: 11,

                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    '${selectedPosition.latitude.toStringAsFixed(6)}, '
                        '${selectedPosition.longitude.toStringAsFixed(6)}',

                    style:
                    const TextStyle(
                      color:
                      AppColors
                          .textSecondary,

                      fontSize:
                      9,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  SizedBox(
                    width:
                    double.infinity,

                    height:
                    52,

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
                      loadingAddress
                          ? null
                          : confirmLocation,

                      icon:
                      const Icon(
                        Icons
                            .check_circle_outline,
                      ),

                      label:
                      const Text(
                        'Use This Location',
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