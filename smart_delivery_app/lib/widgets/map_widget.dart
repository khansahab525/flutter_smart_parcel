import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/delivery_model.dart';
import '../theme/app_colors.dart';

class DeliveryMapWidget extends StatefulWidget {
  final TrackingData trackingData;

  const DeliveryMapWidget({super.key, required this.trackingData});

  @override
  State<DeliveryMapWidget> createState() => _DeliveryMapWidgetState();
}

class _DeliveryMapWidgetState extends State<DeliveryMapWidget> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  @override
  void didUpdateWidget(DeliveryMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.trackingData;
    final driverLat = data.driverLat ?? data.delivery.currentLat;
    final driverLng = data.driverLng ?? data.delivery.currentLng;

    final center = LatLng(
      driverLat ?? data.destLat,
      driverLng ?? data.destLng,
    );

    final markers = <Marker>[
      Marker(
        point: LatLng(data.destLat, data.destLng),
        width: 90,
        height: 80,
        child: _MapMarker(
          color: AppColors.success,
          icon: Icons.location_on_rounded,
          label: 'Destination',
          isPrimary: false,
        ),
      ),
      Marker(
        point: LatLng(data.pickupLat, data.pickupLng),
        width: 90,
        height: 80,
        child: _MapMarker(
          color: AppColors.info,
          icon: Icons.storefront_rounded,
          label: 'Pickup',
          isPrimary: false,
        ),
      ),
    ];

    if (driverLat != null && driverLng != null) {
      markers.add(Marker(
        point: LatLng(driverLat, driverLng),
        width: 100,
        height: 85,
        child: _MapMarker(
          color: AppColors.accent,
          icon: Icons.local_shipping_rounded,
          label: data.delivery.driver?.name ?? 'Driver',
          isPrimary: true,
        ),
      ));
    }

    final polylines = <Polyline>[];
    if (driverLat != null && driverLng != null) {
      if (data.routeHistory.isNotEmpty) {
        polylines.add(Polyline(
          points: data.routeHistory
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          color: AppColors.accent,
          strokeWidth: 4,
          borderColor: AppColors.accentDark,
          borderStrokeWidth: 1,
        ));
      } else {
        polylines.add(Polyline(
          points: [
            LatLng(driverLat, driverLng),
            LatLng(data.destLat, data.destLng),
          ],
          color: AppColors.accent.withValues(alpha: 0.7),
          strokeWidth: 3,
          borderStrokeWidth: 0,
          pattern: StrokePattern.dashed(segments: [10, 8]),
        ));
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.smartdelivery.smart_delivery_app',
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            children: [
              _MapControlButton(
                icon: Icons.add_rounded,
                onTap: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(
                    _mapController.camera.center,
                    zoom + 1,
                  );
                },
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.remove_rounded,
                onTap: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(
                    _mapController.camera.center,
                    zoom - 1,
                  );
                },
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.my_location_rounded,
                onTap: _fitBounds,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _fitBounds() {
    final data = widget.trackingData;
    final points = <LatLng>[
      LatLng(data.destLat, data.destLng),
      LatLng(data.pickupLat, data.pickupLng),
    ];

    final driverLat = data.driverLat ?? data.delivery.currentLat;
    final driverLng = data.driverLng ?? data.delivery.currentLng;
    if (driverLat != null && driverLng != null) {
      points.add(LatLng(driverLat, driverLng));
    }

    if (points.length < 2) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(56),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const _MapMarker({
    required this.color,
    required this.icon,
    required this.label,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isPrimary ? 40.0 : 34.0;
    final iconSize = isPrimary ? 20.0 : 17.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.85)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: isPrimary ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: isPrimary ? 10 : 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
