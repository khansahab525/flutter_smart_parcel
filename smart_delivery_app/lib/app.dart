import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/customer/customer_dashboard.dart';
import 'screens/driver/driver_dashboard.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

class SmartDeliveryApp extends StatelessWidget {
  const SmartDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartDelivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.isDriver) {
      return const DriverDashboard();
    }

    return const CustomerDashboard();
  }
}
