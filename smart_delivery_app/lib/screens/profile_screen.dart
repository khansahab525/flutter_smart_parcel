import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/delivery_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common/enterprise_app_bar.dart';
import '../widgets/driver_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: EnterpriseAppBar(
        title: 'Profile',
        subtitle: 'Account information',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      DriverAvatar(
                        name: user.name,
                        imageBase64: user.driverProfileImageBase64,
                        radius: 38,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roleLabel(user.role),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _ProfileRow(
                        icon: Icons.alternate_email_rounded,
                        label: 'Username',
                        value: user.login,
                      ),
                      if (user.email != null && user.email!.isNotEmpty)
                        _ProfileRow(
                          icon: Icons.email_outlined,
                          label: 'Recovery email',
                          value: user.email!,
                        ),
                      _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone number',
                        value: user.phone?.isNotEmpty == true
                            ? user.phone!
                            : 'Not provided',
                      ),
                      _ProfileRow(
                        icon: Icons.badge_outlined,
                        label: 'Account type',
                        value: _roleLabel(user.role),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (user.isDriver) {
                      await context
                          .read<DeliveryProvider>()
                          .disconnectDriver();
                    }
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],
            ),
    );
  }

  static String _roleLabel(String role) {
    if (role.isEmpty) return 'Customer';
    return '${role.substring(0, 1).toUpperCase()}${role.substring(1)}';
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 62, color: AppColors.border),
      ],
    );
  }
}
