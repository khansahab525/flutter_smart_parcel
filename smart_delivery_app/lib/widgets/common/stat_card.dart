import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? backgroundColor;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.borderLight;
    final ic = iconColor ?? AppColors.accent;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ic.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: ic),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
