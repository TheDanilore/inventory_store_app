import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/loyalty/domain/constants/loyalty_settings_keys.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_responsive_grid.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/settings/points_section_card.dart';

class PointsPrizesTab extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final bool disabled;

  const PointsPrizesTab({
    super.key,
    required this.controllers,
    this.disabled = false,
  });

  @override
  State<PointsPrizesTab> createState() => _PointsPrizesTabState();
}

class _PointsPrizesTabState extends State<PointsPrizesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PointsSectionCard(
          title: 'Cajitas Misteriosas',
          subtitle: 'Premios aleatorios de las cajas.',
          icon: Icons.inventory_2_rounded,
          color: Colors.purple,
          children: [
            PointsResponsiveGrid(
              keys: const [
                LoyaltySettingsKeys.boxesPrize1,
                LoyaltySettingsKeys.boxesPrize2,
                LoyaltySettingsKeys.boxesPrize3,
              ],
              controllers: widget.controllers,
              disabled: widget.disabled,
            ),
          ],
        ),
        const SizedBox(height: 20),
        PointsSectionCard(
          title: 'Piñata y Memorama',
          subtitle: 'Premios mayores, consolación y por pares.',
          icon: Icons.celebration_rounded,
          color: Colors.pink,
          children: [
            PointsResponsiveGrid(
              keys: const [
                LoyaltySettingsKeys.pinataGrandPrize,
                LoyaltySettingsKeys.pinataConsolationPrize,
                LoyaltySettingsKeys.memoramaMatchReward,
              ],
              controllers: widget.controllers,
              disabled: widget.disabled,
            ),
          ],
        ),
        const SizedBox(height: 20),
        PointsSectionCard(
          title: 'Lluvia de Monedas',
          subtitle: 'Valor por atrapar elementos.',
          icon: Icons.cloud_download_rounded,
          color: Colors.lightBlue,
          children: [
            PointsResponsiveGrid(
              keys: const [
                LoyaltySettingsKeys.catcherCoinReward,
                LoyaltySettingsKeys.catcherGiftReward,
                LoyaltySettingsKeys.catcherBombPenalty,
              ],
              controllers: widget.controllers,
              disabled: widget.disabled,
              allowNegativeKeys: const {LoyaltySettingsKeys.catcherBombPenalty},
            ),
          ],
        ),
        const SizedBox(height: 20),
        PointsSectionCard(
          title: 'Máquina de Garra',
          subtitle: 'Premios según la ranura donde cae el gancho (1 al 5).',
          icon: Icons.precision_manufacturing_rounded,
          color: Colors.amber,
          children: [
            PointsResponsiveGrid(
              keys: const [
                LoyaltySettingsKeys.clawPrize1,
                LoyaltySettingsKeys.clawPrize2,
                LoyaltySettingsKeys.clawPrize3,
                LoyaltySettingsKeys.clawPrize4,
                LoyaltySettingsKeys.clawPrize5,
              ],
              controllers: widget.controllers,
              disabled: widget.disabled,
            ),
          ],
        ),
      ],
    );
  }
}
