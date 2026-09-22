import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';
import '../theme/app_colors.dart';

class AddressMapPickerPage extends StatefulWidget {
  final String title;
  final GeocodingResult? initialLocation;

  const AddressMapPickerPage({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<AddressMapPickerPage> createState() => _AddressMapPickerPageState();
}

class _AddressMapPickerPageState extends State<AddressMapPickerPage> {
  static const _defaultCenter = LatLng(30.3753, 69.3451);

  final _mapController = MapController();
  final _geocoding = GeocodingService();
  final _searchController = TextEditingController();
  Timer? _reverseDebounce;
  Timer? _searchDebounce;
  List<GeocodingResult> _searchResults = [];
  GeocodingResult? _selected;
  bool _isResolving = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
    if (_selected == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _moveToCurrentLocation(),
      );
    }
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _initialCenter {
    final selected = _selected;
    return selected == null
        ? _defaultCenter
        : LatLng(selected.latitude, selected.longitude);
  }

  Future<void> _moveToCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    _mapController.move(point, 16);
    _selectPoint(point);
  }

  void _selectPoint(LatLng point) {
    FocusScope.of(context).unfocus();
    _reverseDebounce?.cancel();
    setState(() {
      _selected = GeocodingResult(
        displayName:
            '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
        latitude: point.latitude,
        longitude: point.longitude,
      );
      _isResolving = true;
    });

    _reverseDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _resolveAddress(point),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _searchAddress(value),
    );
  }

  Future<void> _searchAddress(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await _geocoding.search(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(GeocodingResult result) {
    _reverseDebounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = result;
      _searchController.text = result.displayName;
      _searchResults = [];
      _isResolving = false;
    });
    _mapController.move(
      LatLng(result.latitude, result.longitude),
      16,
    );
  }

  Future<void> _resolveAddress(LatLng point) async {
    try {
      final result = await _geocoding.reverse(
        point.latitude,
        point.longitude,
      );
      if (!mounted) return;
      if (_selected?.latitude == point.latitude &&
          _selected?.longitude == point.longitude) {
        setState(() => _selected = result);
      }
    } catch (_) {
      // Keep the coordinates as a usable address when lookup is unavailable.
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: selected == null ? 6 : 16,
              onTap: (_, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.smartdelivery.smart_delivery_app',
              ),
              if (selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        selected.latitude,
                        selected.longitude,
                      ),
                      width: 54,
                      height: 54,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        size: 48,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search an address or tap the map',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.accent,
                      ),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: AppColors.borderLight,
                      ),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.accent,
                          ),
                          title: Text(
                            result.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 174,
            child: FloatingActionButton.small(
              heroTag: null,
              onPressed: _moveToCurrentLocation,
              backgroundColor: AppColors.surfaceCard,
              foregroundColor: AppColors.accent,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selected?.displayName ??
                                'No location selected',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isResolving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(context, selected),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Use this location'),
                      style: const ButtonStyle(
                        minimumSize: WidgetStatePropertyAll(
                          Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
