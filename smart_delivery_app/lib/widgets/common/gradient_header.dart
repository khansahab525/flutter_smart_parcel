import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class GradientHeader extends StatelessWidget {
  final String greeting;
  final String? subtitle;
  final Widget? child;

  const GradientHeader({
    super.key,
    required this.greeting,
    this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 20),
            child!,
          ],
        ],
      ),
    );
  }
}
