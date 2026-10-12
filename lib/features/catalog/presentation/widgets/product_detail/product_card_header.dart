import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductCardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;

  const ProductCardHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
