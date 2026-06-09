import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/tracking_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/enterprise_app_bar.dart';
import '../../widgets/common/info_card.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/eta_badge.dart';
import '../../widgets/map_widget.dart';
import 'chat_screen.dart';

class TrackingScreen extends StatefulWidget {
  final int deliveryId;

  const TrackingScreen({super.key, required this.deliveryId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackingProvider>().startTracking(widget.deliveryId);
    });
  }

  @override
  void dispose() {
    context.read<TrackingProvider>().stopTracking();
    super.dispose();
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
                      tracking.error ?? 'Unable to load tracking',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : _buildTrackingView(tracking),
    );
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
                      EtaBadge(
                        etaMinutes: delivery.etaMinutes,
                        delayStatus: delivery.delayStatus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (delivery.driver?.name != null)
                    InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Driver',
                      value: delivery.driver!.name!,
                    ),
                  if (delivery.etaDatetime != null)
                    InfoRow(
                      icon: Icons.schedule_rounded,
                      label: 'Estimated Arrival',
                      value: delivery.etaDatetime!,
                    ),
                  if (delivery.delayReason != null &&
                      delivery.delayReason!.isNotEmpty)
                    InfoRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Delay Notice',
                      value: delivery.delayReason!,
                      valueColor: AppColors.warning,
                    ),
                  InfoRow(
                    icon: Icons.shield_outlined,
                    label: 'Risk Level',
                    value: '${delivery.riskLevel.toUpperCase()} (${delivery.riskScore}/100)',
                    valueColor: delivery.riskScore >= 60
                        ? AppColors.error
                        : delivery.riskScore >= 30
                            ? AppColors.warning
                            : AppColors.success,
                  ),
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
