import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_model.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/geo_utils.dart';
import '../../widgets/common/enterprise_app_bar.dart';
import '../../widgets/common/info_card.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/map_widget.dart';
import 'chat_screen.dart';

class TrackingScreen extends StatefulWidget {
  final int deliveryId;

  const TrackingScreen({super.key, required this.deliveryId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackingProvider>().startTracking(widget.deliveryId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<TrackingProvider>().stopTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tracking = context.read<TrackingProvider>();
    if (state == AppLifecycleState.resumed) {
      tracking.startTracking(widget.deliveryId);
    } else if (
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      tracking.pauseTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();

    return Scaffold(
      backgroundColor: AppColors.surfaceCard,
      appBar: EnterpriseAppBar(
        title: tracking.delivery?.name ?? 'Live Tracking',
        subtitle: tracking.delivery?.statusLabel ?? 'Loading...',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (tracking.isLiveConnected) const LiveBadge(),
          if (tracking.delivery?.canCustomerCancel == true)
            AppBarIconButton(
              icon: Icons.cancel_outlined,
              tooltip: 'Cancel order',
              onPressed: () => _cancelOrder(tracking.delivery!),
            ),
          AppBarIconButton(
            icon: Icons.smart_toy_outlined,
            tooltip: 'AI Assistant',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(deliveryId: widget.deliveryId),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: tracking.isLoading && tracking.trackingData == null
          ? const Center(child: CircularProgressIndicator())
          : tracking.trackingData == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Tracking is temporarily unavailable.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : _buildTrackingView(tracking),
    );
  }

  Future<void> _cancelOrder(DeliveryModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'Cancellation is available only before the driver starts the trip.',
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

    final delivery = context.read<DeliveryProvider>();
    final success = await delivery.cancelDelivery(order.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to cancel the order. Please try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildTrackingView(TrackingProvider tracking) {
    final data = tracking.trackingData!;
    final delivery = data.delivery;

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: DeliveryMapWidget(trackingData: data),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapLegendDot(color: AppColors.accent, label: 'Driver'),
                      const SizedBox(width: 12),
                      _MapLegendDot(color: AppColors.success, label: 'Destination'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: AppColors.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StatusChip(status: delivery.status),
                      if (_distanceRemaining(data) != null)
                        _DistanceBadge(label: _distanceRemaining(data)!),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (delivery.driver?.name != null)
                    InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Driver',
                      value: delivery.driver!.name!,
                    ),
                  if (delivery.deliveryAddress != null)
                    InfoRow(
                      icon: Icons.home_outlined,
                      label: 'Deliver To',
                      value: delivery.deliveryAddress!,
                    ),
                  if (delivery.isActive &&
                      delivery.confirmationPin != null) ...[
                    const SizedBox(height: 16),
                    _PinCard(pin: delivery.confirmationPin!),
                  ],
                  if (delivery.status == 'delivered') ...[
                    const SizedBox(height: 16),
                    _RatingCard(
                      rating: delivery.rating,
                      feedback: delivery.feedback,
                    ),
                  ],
                  if (data.notifications.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Updates',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ...data.notifications.map((n) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.notifications_none_rounded,
                                size: 18,
                                color: AppColors.info,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(n, style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(deliveryId: widget.deliveryId),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Ask AI Assistant'),
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(
                        Size(double.infinity, 52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _distanceRemaining(TrackingData data) {
    final delivery = data.delivery;
    if (!delivery.isActive) return null;
    if (data.driverLat == null || data.driverLng == null) return null;

    final km = haversineKm(
      data.driverLat!,
      data.driverLng!,
      data.destLat,
      data.destLng,
    );
    return '${formatDistance(km)} away';
  }
}

class _DistanceBadge extends StatelessWidget {
  final String label;

  const _DistanceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_rounded, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  final String pin;

  const _PinCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery PIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Share this code with your driver at handover',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            pin,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatefulWidget {
  final int? rating;
  final String? feedback;

  const _RatingCard({required this.rating, required this.feedback});

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  final _feedbackController = TextEditingController();
  int _selectedStars = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await context.read<TrackingProvider>().submitRating(
          _selectedStars,
          _feedbackController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Thank you for your feedback!'
            : 'Failed to submit rating. Please try again.'),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alreadyRated = widget.rating != null && widget.rating! > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alreadyRated ? 'Your Rating' : 'Rate Your Delivery',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final filled = alreadyRated
                  ? starIndex <= widget.rating!
                  : starIndex <= _selectedStars;
              return GestureDetector(
                onTap: alreadyRated
                    ? null
                    : () => setState(() => _selectedStars = starIndex),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: filled ? AppColors.warning : AppColors.textMuted,
                  ),
                ),
              );
            }),
          ),
          if (alreadyRated &&
              widget.feedback != null &&
              widget.feedback!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '"${widget.feedback!}"',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (!alreadyRated) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Leave feedback (optional)',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(_isSubmitting ? 'Submitting...' : 'Submit Rating'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _MapLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
