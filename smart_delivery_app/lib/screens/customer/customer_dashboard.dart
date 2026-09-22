import 'dart:async';

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
import '../../widgets/delivery_card.dart';
import '../profile_screen.dart';
import 'create_order_screen.dart';
import 'tracking_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard>
    with WidgetsBindingObserver {
  final _trackingIdController = TextEditingController();
  int _watchGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<DeliveryProvider>().loadDeliveries();
      if (mounted) _startWatchingDeliveries();
    });
  }

  @override
  void dispose() {
    _trackingIdController.dispose();
    _watchGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _resumeDeliveryUpdates();
    } else if (
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _watchGeneration++;
    }
  }

  Future<void> _resumeDeliveryUpdates() async {
    await context
        .read<DeliveryProvider>()
        .loadDeliveries(showLoading: false);
    if (mounted) _startWatchingDeliveries();
  }

  void _startWatchingDeliveries() {
    final generation = ++_watchGeneration;
    unawaited(_watchDeliveries(generation));
  }

  Future<void> _watchDeliveries(int generation) async {
    var retrySeconds = 2;
    while (mounted && generation == _watchGeneration) {
      final success =
          await context.read<DeliveryProvider>().pollDeliveries();
      if (!mounted || generation != _watchGeneration) return;
      if (success) {
        retrySeconds = 2;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      } else {
        await Future<void>.delayed(Duration(seconds: retrySeconds));
        retrySeconds = retrySeconds >= 15 ? 30 : retrySeconds * 2;
      }
    }
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
            icon: Icons.account_circle_outlined,
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
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
    _watchGeneration++;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
    );
    if (!mounted) return;
    await context
        .read<DeliveryProvider>()
        .loadDeliveries(showLoading: false);
    if (mounted) _startWatchingDeliveries();
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
              onCancel: d.canCustomerCancel
                  ? () => _cancelOrder(delivery, d)
                  : null,
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

  Future<void> _openTracking(int deliveryId) async {
    _watchGeneration++;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingScreen(deliveryId: deliveryId),
      ),
    );
    if (!mounted) return;
    await context
        .read<DeliveryProvider>()
        .loadDeliveries(showLoading: false);
    if (mounted) _startWatchingDeliveries();
  }

  Future<void> _cancelOrder(
    DeliveryProvider provider,
    DeliveryModel order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          order.status == 'assigned'
              ? 'A driver has accepted this order but has not started the trip yet.'
              : 'The order will be cancelled and all driver offers will close.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await provider.cancelDelivery(order.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Order cancelled'
              : 'Unable to cancel the order. Please try again.',
        ),
        backgroundColor: success ? AppColors.primary : AppColors.error,
      ),
    );
  }
}
