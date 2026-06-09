import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/enterprise_app_bar.dart';
import '../../widgets/common/gradient_header.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/delivery_card.dart';
import 'delivery_detail_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().loadDeliveries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final delivery = context.watch<DeliveryProvider>();

    return Scaffold(
      appBar: EnterpriseAppBar(
        title: 'Driver Portal',
        subtitle: auth.user?.name ?? 'Driver',
        actions: [
          AppBarIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () => delivery.loadDeliveries(),
          ),
          const SizedBox(width: 4),
          AppBarIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Logout',
            color: AppColors.error,
            onPressed: () => auth.logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: delivery.isLoading && delivery.deliveries.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => delivery.loadDeliveries(),
              child: _buildBody(auth, delivery),
            ),
    );
  }

  Widget _buildBody(AuthProvider auth, DeliveryProvider delivery) {
    if (delivery.error != null && delivery.deliveries.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load deliveries',
            message: delivery.error!,
            actionLabel: 'Retry',
            onAction: () => delivery.loadDeliveries(),
          ),
        ],
      );
    }

    final all = delivery.deliveries;
    final active = delivery.activeDeliveries;
    final completed = all.where((d) => !d.isActive).toList();

    return ListView(
      children: [
        GradientHeader(
          greeting: 'Good day, ${(auth.user?.name ?? 'Driver').split(' ').first}',
          subtitle: 'Manage your assigned deliveries',
          child: Row(
            children: [
              StatCard(
                icon: Icons.local_shipping_outlined,
                label: 'Active',
                value: '${active.length}',
                iconColor: AppColors.accentLight,
              ),
              const SizedBox(width: 12),
              StatCard(
                icon: Icons.check_circle_outline,
                label: 'Total',
                value: '${all.length}',
                iconColor: AppColors.info,
              ),
              const SizedBox(width: 12),
              StatCard(
                icon: delivery.isTrackingLocation
                    ? Icons.gps_fixed
                    : Icons.gps_off_outlined,
                label: 'GPS',
                value: delivery.isTrackingLocation ? 'On' : 'Off',
                iconColor: delivery.isTrackingLocation
                    ? AppColors.live
                    : AppColors.textMuted,
              ),
            ],
          ),
        ),
        if (all.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No deliveries assigned',
            message:
                'Deliveries assigned to your driver profile will appear here. '
                'Ensure your Odoo user is linked to a driver record.',
          ),
        if (active.isNotEmpty) ...[
          const SectionHeader(title: 'Active Deliveries'),
          ...active.map((d) => DeliveryCard(
                delivery: d,
                onTap: () => _openDetail(d),
              )),
        ],
        if (completed.isNotEmpty) ...[
          SectionHeader(
            title: 'Completed',
            actionLabel: '${completed.length} items',
          ),
          ...completed.map((d) => _CompletedTile(delivery: d)),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  void _openDetail(DeliveryModel d) {
    context.read<DeliveryProvider>().setActiveDelivery(d);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryDetailScreen()),
    );
  }
}

class _CompletedTile extends StatelessWidget {
  final DeliveryModel delivery;

  const _CompletedTile({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(delivery.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    delivery.customerName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusChip(status: delivery.status, compact: true),
          ],
        ),
      ),
    );
  }
}
