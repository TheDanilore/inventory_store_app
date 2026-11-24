import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_components.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Vista de contenido lazy para una pestaña de documentación del Centro de Ayuda.
///
/// Preserva la posición de scroll mediante [PageStorageKey] sin retener todos los
/// subárboles de pestañas inactivas en RAM, optimizado para equipos de gama baja.
class HelpContentTab extends StatelessWidget {
  final int index;
  final HelpTabModel tab;

  const HelpContentTab({super.key, required this.index, required this.tab});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = c.maxWidth >= 720 ? 24.0 : 16.0;
        final isWide = c.maxWidth >= 720;
        return ListView.separated(
          key: PageStorageKey<String>('help_tab_$index'),
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 48),
          itemCount: tab.groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: 32),
          itemBuilder: (context, groupIndex) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: _HelpGroupSection(
                  group: tab.groups[groupIndex],
                  isWide: isWide,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HelpGroupSection extends StatelessWidget {
  final HelpGroupModel group;
  final bool isWide;

  const _HelpGroupSection({required this.group, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final cols = isWide ? group.columns : 1;
    final items = group.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.title != null) ...[
          HelpSectionHeader(title: group.title!, subtitle: group.subtitle),
          const SizedBox(height: 14),
        ],
        if (items.length == 1 || cols <= 1)
          Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                items[i].child,
              ],
            ],
          )
        else
          Column(
            children: [
              for (var i = 0; i < items.length; i += cols) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) const SizedBox(width: 12),
                      Expanded(
                        child:
                            i + j < items.length
                                ? items[i + j].child
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
      ],
    );
  }
}
