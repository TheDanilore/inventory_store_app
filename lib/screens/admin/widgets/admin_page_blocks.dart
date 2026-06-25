import 'package:flutter/material.dart';

class AdminPageBlocks extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const AdminPageBlocks({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  List<int?> _buildPages() {
    if (totalPages <= 1) return [0];

    final pages = <int?>[0];
    final start = (currentPage - 1) < 1 ? 1 : currentPage - 1;
    final end =
        (currentPage + 1) > (totalPages - 2)
            ? (totalPages - 2)
            : currentPage + 1;

    if (start > 1) {
      pages.add(null);
    }

    for (var i = start; i <= end; i++) {
      pages.add(i);
    }

    if (end < totalPages - 2) {
      pages.add(null);
    }

    pages.add(totalPages - 1);
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    // Obtenemos el color primario de tu tema
    final primaryColor = Theme.of(context).primaryColor;

    return Row(
      children: [
        IconButton(
          onPressed:
              currentPage <= 0 ? null : () => onPageChanged(currentPage - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  pages.map((page) {
                    if (page == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('...'),
                      );
                    }

                    final isSelected = page == currentPage;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed:
                            isSelected ? null : () => onPageChanged(page),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero, // Quitamos padding interno
                          minimumSize: const Size(48, 48), // Fix: 48dp mínimo para accesibilidad
                          // Si está seleccionado: fondo primario, si no: transparente
                          backgroundColor:
                              isSelected ? primaryColor : Colors.grey.shade100,
                          // Borde gris claro si no está seleccionado
                          side: BorderSide(
                            color:
                                isSelected
                                    ? primaryColor
                                    : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${page + 1}',
                          style: TextStyle(
                            // Texto blanco si está seleccionado, gris oscuro si no
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.grey.shade800,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
        IconButton(
          onPressed:
              currentPage >= totalPages - 1
                  ? null
                  : () => onPageChanged(currentPage + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
