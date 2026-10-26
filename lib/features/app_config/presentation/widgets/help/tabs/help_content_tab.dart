import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_keep_alive_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_components.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Vista de contenido para una pestaña de documentación del Centro de Ayuda.
/// Mantiene vivo su estado y posición de scroll mediante [AppKeepAliveTab].
class HelpContentTab extends StatelessWidget {
  final int index;
  final HelpTabModel tab;

  const HelpContentTab({super.key, required this.index, required this.tab});

  @override
  Widget build(BuildContext context) {
    return AppKeepAliveTab(
      child: LayoutBuilder(
        builder: (context, c) {
          final pad = c.maxWidth >= 720 ? 24.0 : 16.0;
          return ListView(
            key: PageStorageKey<String>('help_tab_$index'),
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 48),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildGroupsWithGaps(tab.groups),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupsWithGaps(List<HelpGroupModel> groups) {
    final widgets = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 32));
      widgets.add(_buildGroup(groups[i]));
    }
    return widgets;
  }

  Widget _buildGroup(HelpGroupModel g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (g.title != null) ...[
          HelpSectionHeader(title: g.title!, subtitle: g.subtitle),
          const SizedBox(height: 14),
        ],
        _buildGrid(g.items.map((e) => e.child).toList(), g.columns),
      ],
    );
  }

  Widget _buildGrid(List<Widget> items, int columns) {
    if (items.length == 1 || columns == 1) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            items[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720 ? columns : 1;
        if (cols == 1) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                items[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < items.length; i += cols) {
          if (i > 0) rows.add(const SizedBox(height: 12));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(
                      child:
                          i + j < items.length
                              ? items[i + j]
                              : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}
