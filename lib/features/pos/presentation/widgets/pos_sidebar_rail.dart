import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';

/// Sidebar vertical exclusivo para el módulo POS inspirado en terminales
/// de punto de venta modernas (estilo Clover, Shopify POS y sistemas agronómicos).
class PosSidebarRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onExitPos;
  final int? cartItemCount;

  const PosSidebarRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onExitPos,
    this.cartItemCount,
  });

  // Tono verde bosque oscuro de alta gama agronómica
  static const Color sidebarBg = Color(0xFF142B1A);
  static const Color sidebarActiveBg = Color(0xFF224A2E);
  static const Color limeAccent = Color(0xFF84CC16);
  static const Color limeAccentLight = Color(0xFFA3E635);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      decoration: BoxDecoration(
        color: sidebarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),

            // ── Logo / Isotipo de Tienda Agronómica ───────────────────────────
            Tooltip(
              message: 'Agro-Venta POS',
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [limeAccent, Color(0xFF65A30D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: limeAccent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Items de Navegación Exclusivos del POS ────────────────────────
            _buildNavItem(
              index: 0,
              icon: Icons.grid_view_rounded,
              label: 'VENTA',
              shortcut: AppShortcutLabels.tab(1),
            ),
            const SizedBox(height: 12),

            _buildNavItem(
              index: 1,
              icon: Icons.assignment_outlined,
              label: 'LOTES',
              shortcut: AppShortcutLabels.tab(2),
            ),
            const SizedBox(height: 12),

            _buildNavItem(
              index: 2,
              icon: Icons.history_rounded,
              label: 'VENTAS',
              shortcut: AppShortcutLabels.tab(3),
            ),
            const SizedBox(height: 12),

            _buildNavItem(
              index: 3,
              icon: Icons.point_of_sale_rounded,
              label: 'TURNOS',
              shortcut: AppShortcutLabels.tab(4),
            ),

            const Spacer(),

            // ── Botón de Salir / Volver al ERP ────────────────────────────────
            Tooltip(
              message: 'Volver al ERP',
              preferBelow: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onExitPos,
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required String shortcut,
  }) {
    final isSelected = selectedIndex == index;

    return Tooltip(
      message: '$label ($shortcut)',
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 66,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? sidebarActiveBg : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(
                      color: limeAccent.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : Border.all(color: Colors.transparent, width: 1),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? limeAccentLight : const Color(0xFF94A3B8),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.8,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
