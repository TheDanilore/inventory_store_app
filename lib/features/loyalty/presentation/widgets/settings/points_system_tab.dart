import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/loyalty/domain/constants/loyalty_settings_keys.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_section_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_setting_field.dart';

class PointsSystemTab extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final bool disabled;

  const PointsSystemTab({
    super.key,
    required this.controllers,
    this.disabled = false,
  });

  @override
  State<PointsSystemTab> createState() => _PointsSystemTabState();
}

class _PointsSystemTabState extends State<PointsSystemTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final configs = {
      for (var c in LoyaltySettingsKeys.allDefinitions) c.key: c,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PointsSectionCard(
              title: 'Sistema de Puntos y Canjes',
              subtitle: 'Define el valor monetario y la acumulación.',
              icon: Icons.currency_exchange_rounded,
              color: Colors.blue,
              children: [
                isWide
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PointsSettingField(
                            config: configs[LoyaltySettingsKeys.earningRate]!,
                            controller:
                                widget.controllers[LoyaltySettingsKeys
                                    .earningRate]!,
                            disabled: widget.disabled,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PointsSettingField(
                            config: configs[LoyaltySettingsKeys.pointsRatio]!,
                            controller:
                                widget.controllers[LoyaltySettingsKeys
                                    .pointsRatio]!,
                            disabled: widget.disabled,
                          ),
                        ),
                      ],
                    )
                    : Column(
                      children: [
                        PointsSettingField(
                          config: configs[LoyaltySettingsKeys.earningRate]!,
                          controller:
                              widget.controllers[LoyaltySettingsKeys
                                  .earningRate]!,
                          disabled: widget.disabled,
                        ),
                        const SizedBox(height: 12),
                        PointsSettingField(
                          config: configs[LoyaltySettingsKeys.pointsRatio]!,
                          controller:
                              widget.controllers[LoyaltySettingsKeys
                                  .pointsRatio]!,
                          disabled: widget.disabled,
                        ),
                      ],
                    ),
              ],
            ),
            const SizedBox(height: 20),
            PointsSectionCard(
              title: 'Check-in Diario',
              subtitle: 'Recompensas por rachas consecutivas.',
              icon: Icons.fact_check_rounded,
              color: Colors.green,
              children: [
                isWide
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PointsSettingField(
                            config: configs[LoyaltySettingsKeys.checkinReward]!,
                            controller:
                                widget.controllers[LoyaltySettingsKeys
                                    .checkinReward]!,
                            disabled: widget.disabled,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PointsSettingField(
                            config:
                                configs[LoyaltySettingsKeys.checkinStreakStep]!,
                            controller:
                                widget.controllers[LoyaltySettingsKeys
                                    .checkinStreakStep]!,
                            disabled: widget.disabled,
                          ),
                        ),
                      ],
                    )
                    : Column(
                      children: [
                        PointsSettingField(
                          config: configs[LoyaltySettingsKeys.checkinReward]!,
                          controller:
                              widget.controllers[LoyaltySettingsKeys
                                  .checkinReward]!,
                          disabled: widget.disabled,
                        ),
                        const SizedBox(height: 12),
                        PointsSettingField(
                          config:
                              configs[LoyaltySettingsKeys.checkinStreakStep]!,
                          controller:
                              widget.controllers[LoyaltySettingsKeys
                                  .checkinStreakStep]!,
                          disabled: widget.disabled,
                        ),
                      ],
                    ),
              ],
            ),
          ],
        );
      },
    );
  }
}
