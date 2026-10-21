// ─── SKELETON SHIMMER LOADING PLACEHOLDER ─────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class BusinessInfoSkeleton extends StatelessWidget {
  const BusinessInfoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildBox(isDark, height: 240),
                const SizedBox(height: 16),
                _buildBox(isDark, height: 140),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(flex: 6, child: _buildBox(isDark, height: 480)),
        ],
      ),
    );
  }

  Widget _buildBox(bool isDark, {required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
    );
  }
}
