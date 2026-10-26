import 'package:flutter/material.dart';

/// Mantiene vivo el árbol de renderizado de cada pestaña de un [TabBarView] o [PageView]
/// para evitar rebuilds destructivos, preservar scroll y anular shimmers al alternar pestañas.
class AppKeepAliveTab extends StatefulWidget {
  final Widget child;
  const AppKeepAliveTab({super.key, required this.child});

  @override
  State<AppKeepAliveTab> createState() => _AppKeepAliveTabState();
}

class _AppKeepAliveTabState extends State<AppKeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
