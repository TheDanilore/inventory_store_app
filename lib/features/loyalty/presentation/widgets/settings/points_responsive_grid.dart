import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/loyalty/domain/constants/loyalty_settings_keys.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_setting_field.dart';

class PointsResponsiveGrid extends StatelessWidget {
  final List<String> keys;
  final Map<String, TextEditingController> controllers;
  final bool disabled;
  final Set<String> allowNegativeKeys;

  const PointsResponsiveGrid({
    super.key,
    required this.keys,
    required this.controllers,
    this.disabled = false,
    this.allowNegativeKeys = const {},
  });

  @override
  Widget build(BuildContext context) {
    final configs = {
      for (var c in LoyaltySettingsKeys.allDefinitions) c.key: c,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;

        if (!isWide) {
          return Column(
            children: [
              for (int i = 0; i < keys.length; i++) ...[
                PointsSettingField(
                  config: configs[keys[i]]!,
                  controller: controllers[keys[i]]!,
                  disabled: disabled,
                  allowNegative: allowNegativeKeys.contains(keys[i]),
                ),
                if (i < keys.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (int i = 0; i < keys.length; i += 2) {
          final left = PointsSettingField(
            config: configs[keys[i]]!,
            controller: controllers[keys[i]]!,
            disabled: disabled,
            allowNegative: allowNegativeKeys.contains(keys[i]),
          );
          Widget right;
          if (i + 1 < keys.length) {
            right = PointsSettingField(
              config: configs[keys[i + 1]]!,
              controller: controllers[keys[i + 1]]!,
              disabled: disabled,
              allowNegative: allowNegativeKeys.contains(keys[i + 1]),
            );
          } else {
            right = const SizedBox.shrink();
          }

          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                Expanded(child: right),
              ],
            ),
          );
          if (i + 2 < keys.length) rows.add(const SizedBox(height: 12));
        }

        return Column(children: rows);
      },
    );
  }
}
