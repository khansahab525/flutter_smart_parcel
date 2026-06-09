import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 64, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.local_shipping_rounded,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 16),
          Text(
            'SmartDelivery',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Enterprise Last Mile Platform',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
