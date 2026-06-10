import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/enterprise_app_bar.dart';
import '../../widgets/common/gradient_header.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/delivery_card.dart';
import 'create_order_screen.dart';
import 'tracking_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final _trackingIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().loadDeliveries();
    });
  }

  @override
  void dispose() {
    _trackingIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final delivery = context.watch<DeliveryProvider>();

    return Scaffold(
      appBar: EnterpriseAppBar(
        title: 'Track & Trace',
        subtitle: auth.user?.name ?? 'Customer',
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
              child: _buildBody(delivery),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateOrder,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Order',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _openCreateOrder() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
    );
    if (created == true && mounted) {
      context.read<DeliveryProvider>().loadDeliveries();
    }
  }

  Widget _buildBody(DeliveryProvider delivery) {
    return ListView(
      children: [
        GradientHeader(
          greeting: 'Your Deliveries',
          subtitle: 'Real-time tracking powered by AI',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: AppColors.info,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Track by ID',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _trackingIdController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. SDO00001',
                          prefixIcon: Icon(Icons.tag_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _trackById(delivery),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Track'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (delivery.error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      delivery.error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (delivery.deliveries.isNotEmpty)
          SectionHeader(
            title: 'My Orders',
            actionLabel: '${delivery.deliveries.length} total',
          ),
        if (delivery.deliveries.isEmpty && !delivery.isLoading)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No orders yet',
            message:
                'Your linked deliveries will appear here. '
                'You can also track any order using its tracking ID above.',
          ),
        ...delivery.deliveries.map((d) => DeliveryCard(
              delivery: d,
              onTap: () => _openTracking(d.id),
            )),
        const SizedBox(height: 24),
      ],
    );
  }

  void _trackById(DeliveryProvider delivery) {
    final idText = _trackingIdController.text.trim();
    if (idText.isEmpty) return;

    final id = int.tryParse(idText);
    if (id != null) {
      _openTracking(id);
    } else {
      final match = delivery.deliveries
          .where((d) => d.name.toLowerCase() == idText.toLowerCase())
          .toList();
      if (match.isNotEmpty) {
        _openTracking(match.first.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery not found')),
        );
      }
    }
  }

  void _openTracking(int deliveryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingScreen(deliveryId: deliveryId),
      ),
    );
  }
}
