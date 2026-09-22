import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_model.dart';
import '../../models/driver_assignment.dart';
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
import '../profile_screen.dart';
import 'delivery_detail_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  Timer? _offerRefreshTimer;
  Timer? _availabilityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final delivery = context.read<DeliveryProvider>();
      delivery.loadDeliveries();
      delivery.updateDriverAvailabilityLocation();
      delivery.loadDriverOffers();
    });
    _offerRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      context.read<DeliveryProvider>().loadDriverOffers();
    });
    _availabilityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      context.read<DeliveryProvider>().updateDriverAvailabilityLocation();
    });
  }

  @override
  void dispose() {
    _offerRefreshTimer?.cancel();
    _availabilityTimer?.cancel();
    super.dispose();
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
            onPressed: _refresh,
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
              onRefresh: _refresh,
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
        if (delivery.driverOffers.isNotEmpty) ...[
          SectionHeader(
            title: 'New Delivery Offers',
            actionLabel: '${delivery.driverOffers.length} waiting',
          ),
          ...delivery.driverOffers.map(
            (offer) => _DriverOfferCard(
              offer: offer,
              onAccept: () => _respondToOffer(
                delivery,
                offer,
                accept: true,
              ),
              onReject: () => _respondToOffer(
                delivery,
                offer,
                accept: false,
              ),
            ),
          ),
        ],
        if (all.isEmpty && delivery.driverOffers.isEmpty)
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

  Future<void> _refresh() async {
    final delivery = context.read<DeliveryProvider>();
    await delivery.updateDriverAvailabilityLocation();
    await Future.wait([
      delivery.loadDeliveries(),
      delivery.loadDriverOffers(),
    ]);
  }

  void _openDetail(DeliveryModel d) {
    context.read<DeliveryProvider>().setActiveDelivery(d);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryDetailScreen()),
    );
  }

  Future<void> _respondToOffer(
    DeliveryProvider delivery,
    DeliveryOffer offer, {
    required bool accept,
  }) async {
    final success = accept
        ? await delivery.acceptDriverOffer(offer.id)
        : await delivery.rejectDriverOffer(offer.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? accept
                    ? 'Delivery accepted'
                    : 'Delivery offer declined'
              : delivery.error ?? 'Unable to update this offer',
        ),
        backgroundColor: success
            ? accept
                  ? AppColors.success
                  : AppColors.primary
            : AppColors.error,
      ),
    );
    if (success && accept) {
      await delivery.loadDeliveries();
    }
  }
}

class _DriverOfferCard extends StatefulWidget {
  final DeliveryOffer offer;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  const _DriverOfferCard({
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_DriverOfferCard> createState() => _DriverOfferCardState();
}

class _DriverOfferCardState extends State<_DriverOfferCard> {
  Timer? _timer;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _secondsRemaining {
    final seconds = widget.offer.expiresAt.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  Future<void> _respond(Future<void> Function() action) async {
    setState(() => _isResponding = true);
    await action();
    if (mounted) setState(() => _isResponding = false);
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final order = offer.delivery;
    final expired = _secondsRemaining == 0;
    final distance = offer.distanceKm == null
        ? null
        : '${offer.distanceKm!.toStringAsFixed(1)} km from you';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        offer.source == 'preferred'
                            ? 'Customer requested you'
                            : offer.source == 'admin'
                            ? 'Offer from dispatcher'
                            : 'Nearby pickup offer',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: expired
                        ? AppColors.errorBg
                        : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    expired ? 'Expired' : '${_secondsRemaining}s',
                    style: TextStyle(
                      color: expired ? AppColors.error : AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (distance != null)
              _OfferDetail(
                icon: Icons.near_me_outlined,
                text: distance,
              ),
            _OfferDetail(
              icon: Icons.inventory_2_outlined,
              text: [
                order.parcelSize?.label ?? 'Parcel',
                if (order.parcelWeightKg != null)
                  '${order.parcelWeightKg!.toStringAsFixed(1)} kg',
                if (order.isFragile) 'Fragile',
              ].join(' • '),
            ),
            _OfferDetail(
              icon: Icons.location_on_outlined,
              text: order.pickupAddress ?? 'Pickup location provided',
            ),
            if (order.estimatedPrice != null)
              _OfferDetail(
                icon: Icons.payments_outlined,
                text:
                    '${order.currencyCode ?? 'USD'} ${order.estimatedPrice!.toStringAsFixed(2)}',
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: expired || _isResponding
                        ? null
                        : () => _respond(widget.onReject),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: expired || _isResponding
                        ? null
                        : () => _respond(widget.onAccept),
                    child: Text(_isResponding ? 'Please wait...' : 'Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferDetail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OfferDetail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
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
