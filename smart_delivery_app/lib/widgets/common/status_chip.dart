import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final bool compact;

  const StatusChip({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final label = status.replaceAll('_', ' ');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        compact ? label.toUpperCase() : _capitalize(label),
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: compact ? 0.5 : 0,
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.live.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.live.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.live,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.live,
        shape: BoxShape.circle,
      ),
    );
  }
}
