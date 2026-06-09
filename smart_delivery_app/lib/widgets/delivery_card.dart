import 'package:flutter/material.dart';

import '../models/delivery_model.dart';
import '../theme/app_colors.dart';
import 'common/status_chip.dart';
import 'eta_badge.dart';

class DeliveryCard extends StatelessWidget {
  final DeliveryModel delivery;
  final VoidCallback? onTap;
  final VoidCallback? onStart;

  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onTap,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
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
                if (delivery.driver?.name != null) ...[
                  const SizedBox(height: 14),
                  _MetaRow(
                    icon: Icons.local_shipping_outlined,
                    text: delivery.driver!.name!,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    EtaBadge(
                      etaMinutes: delivery.etaMinutes,
                      delayStatus: delivery.delayStatus,
                    ),
                    const Spacer(),
                    if (delivery.riskScore > 30)
                      _RiskBadge(score: delivery.riskScore),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                if (onStart != null && delivery.isActive) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Start Delivery'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final int score;

  const _RiskBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 60 ? AppColors.error : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
