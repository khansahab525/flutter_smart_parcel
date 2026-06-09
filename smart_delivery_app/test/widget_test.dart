import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_delivery_app/app.dart';
import 'package:smart_delivery_app/providers/auth_provider.dart';
import 'package:smart_delivery_app/providers/delivery_provider.dart';
import 'package:smart_delivery_app/providers/tracking_provider.dart';
import 'package:smart_delivery_app/services/api_service.dart';
import 'package:smart_delivery_app/services/delivery_service.dart';
import 'package:smart_delivery_app/services/location_service.dart';
import 'package:smart_delivery_app/services/tracking_stream_service.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    final apiService = ApiService();
    final deliveryService = DeliveryService(apiService);
    final streamService = TrackingStreamService(apiService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService),
          ),
          ChangeNotifierProvider(
            create: (_) => DeliveryProvider(
              DeliveryService(apiService),
              LocationService(),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => TrackingProvider(deliveryService, streamService),
          ),
        ],
        child: const SmartDeliveryApp(),
      ),
    );

    expect(find.text('SmartDelivery'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
