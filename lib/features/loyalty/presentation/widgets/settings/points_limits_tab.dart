import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/loyalty/domain/constants/loyalty_settings_keys.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_responsive_grid.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_section_card.dart';

class PointsLimitsTab extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final bool disabled;

  const PointsLimitsTab({
    super.key,
    required this.controllers,
    this.disabled = false,
  });

  @override
  State<PointsLimitsTab> createState() => _PointsLimitsTabState();
}

class _PointsLimitsTabState extends State<PointsLimitsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PointsSectionCard(
      title: 'Límites de Juegos Diarios',
      subtitle:
          'Controla el máximo de veces que los usuarios pueden jugar cada día.',
      icon: Icons.sports_esports_rounded,
      color: Colors.orange,
      children: [
        PointsResponsiveGrid(
          keys: LoyaltySettingsKeys.limitsKeys,
          controllers: widget.controllers,
          disabled: widget.disabled,
        ),
      ],
    );
  }
}
