import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class EtaBadge extends StatelessWidget {
  final int? etaMinutes;
  final String delayStatus;

  const EtaBadge({
    super.key,
    required this.etaMinutes,
    required this.delayStatus,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.delayColor(delayStatus);
    final label = etaMinutes != null ? '$etaMinutes min' : 'Calculating';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForStatus(delayStatus), size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForStatus(String status) {
    switch (status) {
      case 'delayed':
        return Icons.schedule_rounded;
      case 'high_risk':
        return Icons.warning_amber_rounded;
      default:
        return Icons.timer_outlined;
    }
  }
}
