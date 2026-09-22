import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DriverAvatar extends StatelessWidget {
  final String name;
  final String? imageBase64;
  final double radius;

  const DriverAvatar({
    super.key,
    required this.name,
    this.imageBase64,
    this.radius = 22,
  });

  Uint8List? get _imageBytes {
    final value = imageBase64;
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _imageBytes;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent.withValues(alpha: 0.12),
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes == null
          ? Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.accentDark,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
