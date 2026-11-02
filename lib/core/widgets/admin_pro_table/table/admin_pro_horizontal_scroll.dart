import 'package:flutter/material.dart';

/// Contenedor de tabla con scroll horizontal, scrollbar visible e indicador sutil de desbordamiento lateral.
class HorizontalScrollableTable extends StatefulWidget {
  final double minTableWidth;
  final Widget header;
  final Widget rows;

  const HorizontalScrollableTable({
    super.key,
    required this.minTableWidth,
    required this.header,
    required this.rows,
  });

  @override
  State<HorizontalScrollableTable> createState() =>
      _HorizontalScrollableTableState();
}

class _HorizontalScrollableTableState extends State<HorizontalScrollableTable> {
  final _scrollController = ScrollController();
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicator);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateScrollIndicator(),
    );
  }

  void _updateScrollIndicator() {
    if (!_scrollController.hasClients) return;
    final canScroll =
        _scrollController.position.maxScrollExtent > 0 &&
        _scrollController.offset <
            _scrollController.position.maxScrollExtent - 2;
    if (canScroll != _canScrollRight) {
      setState(() => _canScrollRight = canScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicator);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth.isFinite &&
                    constraints.maxWidth > widget.minTableWidth
                ? constraints.maxWidth
                : widget.minTableWidth;

        return Stack(
          children: [
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 5,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [widget.header, widget.rows],
                  ),
                ),
              ),
            ),
            // Sombra sutil de degradado en el borde derecho cuando hay columnas ocultas
            if (_canScrollRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 36,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
