import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class EnterpriseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showDivider;

  const EnterpriseAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showDivider = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 72 : 64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (leading != null) leading!,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

class AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  const AppBarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? AppColors.textSecondary),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.borderLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
