import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/enterprise_app_bar.dart';
import '../../widgets/common/info_card.dart';
import '../../widgets/common/status_chip.dart' show StatusChip, LiveBadge;
import '../../widgets/eta_badge.dart';

class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  static const _statusFlow = [
    'assigned',
    'picked_up',
    'in_transit',
    'out_for_delivery',
    'delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final delivery = context.watch<DeliveryProvider>();
    final auth = context.read<AuthProvider>();
    final order = delivery.activeDelivery;

    if (order == null) {
      return const Scaffold(
        body: Center(child: Text('No delivery selected')),
      );
    }

    final currentIndex = _statusFlow.indexOf(order.status);
    final nextStatus = currentIndex >= 0 && currentIndex < _statusFlow.length - 1
        ? _statusFlow[currentIndex + 1]
        : null;

    return Scaffold(
      appBar: EnterpriseAppBar(
        title: order.name,
        subtitle: order.customerName,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (delivery.isTrackingLocation) const LiveBadge(),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusTimeline(currentStatus: order.status),
            const SizedBox(height: 20),
            InfoCard(
              title: 'Customer',
              icon: Icons.person_outline_rounded,
              children: [
                InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Name',
                  value: order.customerName,
                ),
                if (order.customerPhone != null)
                  InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: order.customerPhone!,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InfoCard(
              title: 'Delivery Status',
              icon: Icons.local_shipping_outlined,
              trailing: StatusChip(status: order.status),
              children: [
                Row(
                  children: [
                    EtaBadge(
                      etaMinutes: order.etaMinutes,
                      delayStatus: order.delayStatus,
                    ),
                  ],
                ),
                if (order.delayReason != null &&
                    order.delayReason!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            order.delayReason!,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            InfoCard(
              title: 'Route',
              icon: Icons.map_outlined,
              children: [
                InfoRow(
                  icon: Icons.store_outlined,
                  label: 'Pickup',
                  value:
                      '${order.pickupLat.toStringAsFixed(4)}, ${order.pickupLng.toStringAsFixed(4)}',
                ),
                InfoRow(
                  icon: Icons.home_outlined,
                  label: 'Drop-off',
                  value:
                      '${order.deliveryLat.toStringAsFixed(4)}, ${order.deliveryLng.toStringAsFixed(4)}',
                ),
                if (order.currentLat != null)
                  InfoRow(
                    icon: Icons.my_location,
                    label: 'Current Position',
                    value:
                        '${order.currentLat!.toStringAsFixed(4)}, ${order.currentLng!.toStringAsFixed(4)}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InfoCard(
              title: 'Risk Assessment',
              icon: Icons.shield_outlined,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: order.riskScore / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.borderLight,
                    color: order.riskScore >= 60
                        ? AppColors.error
                        : order.riskScore >= 30
                            ? AppColors.warning
                            : AppColors.success,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Score: ${order.riskScore}/100 · ${order.riskLevel.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (!delivery.isTrackingLocation && order.isActive)
              ElevatedButton.icon(
                onPressed: () => _startDelivery(auth, delivery, order),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Delivery & GPS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            if (delivery.isTrackingLocation && nextStatus != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _updateStatus(delivery, order.id, nextStatus),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text('Mark as ${_formatStatus(nextStatus)}'),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(double.infinity, 52)),
                ),
              ),
            ],
            if (delivery.isTrackingLocation) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  delivery.stopLocationTracking();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('GPS tracking stopped')),
                  );
                },
                icon: const Icon(Icons.gps_off_outlined),
                label: const Text('Stop GPS Tracking'),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(double.infinity, 52)),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String s) =>
      s.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  Future<void> _startDelivery(
    AuthProvider auth,
    DeliveryProvider delivery,
    DeliveryModel order,
  ) async {
    final driverId = auth.user?.driverId;
    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No driver profile linked to this account')),
      );
      return;
    }

    if (order.status == 'assigned') {
      await delivery.updateStatus(order.id, 'picked_up');
    }

    await delivery.startLocationTracking(
      driverId: driverId,
      deliveryId: order.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS tracking active — updates every 5 minutes'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _updateStatus(DeliveryProvider delivery, int id, String status) async {
    final success = await delivery.updateStatus(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Status updated successfully' : 'Failed to update'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
    if (success && status == 'delivered') {
      delivery.stopLocationTracking();
    }
  }
}

class _StatusTimeline extends StatelessWidget {
  final String currentStatus;

  const _StatusTimeline({required this.currentStatus});

  static const _steps = [
    ('assigned', 'Assigned'),
    ('picked_up', 'Picked Up'),
    ('in_transit', 'In Transit'),
    ('out_for_delivery', 'Nearby'),
    ('delivered', 'Delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _steps.indexWhere((s) => s.$1 == currentStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final done = currentIdx > stepIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? AppColors.accent : AppColors.border,
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final (key, label) = _steps[stepIdx];
          final isActive = key == currentStatus;
          final isDone = currentIdx > stepIdx;

          return Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isActive || isDone
                      ? AppColors.accent
                      : AppColors.borderLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? AppColors.accent : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  size: isDone ? 14 : 8,
                  color: isActive || isDone ? Colors.white : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AppColors.accent : AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }),
      ),
    );
  }
}
