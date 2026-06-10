import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/tracking_provider.dart';
import 'services/api_service.dart';
import 'services/delivery_service.dart';
import 'services/location_service.dart';
import 'services/tracking_stream_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = ApiService();
  final deliveryService = DeliveryService(apiService);
  final locationService = LocationService();
  final streamService = TrackingStreamService(apiService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => DeliveryProvider(deliveryService, locationService),
        ),
        ChangeNotifierProvider(
          create: (_) => TrackingProvider(deliveryService, streamService),
        ),
      ],
      child: const SmartDeliveryApp(),
    ),
  );
}
