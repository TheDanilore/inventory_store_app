import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Banner superior del Centro de Ayuda con buscador interactivo y chips rápidos.
class HelpHeroHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onChipSelected;
  final VoidCallback onCopyDiagnostics;

  const HelpHeroHeader({
    super.key,
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onChipSelected,
    required this.onCopyDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 760;
        final pad = narrow ? 16.0 : 24.0;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Centro de Ayuda, Documentación y Operaciones',
              style: TextStyle(
                fontSize: narrow ? 18 : 21,
                fontWeight: FontWeight.w700,
                color: t.title,
                letterSpacing: -0.4,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Guías completas del sistema: arquitectura de cajas y mostradores, roles, comprobantes y atajos.',
              style: TextStyle(fontSize: 13.5, color: t.muted, height: 1.4),
            ),
          ],
        );

        return Container(
          color: t.surface,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 22, pad, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroIcon(44),
                    const SizedBox(width: 12),
                    Expanded(child: titleBlock),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildPosButton(context, t)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDiagButton(t, short: true)),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildHeroIcon(52),
                    const SizedBox(width: 16),
                    Expanded(child: titleBlock),
                    const SizedBox(width: 16),
                    _buildPosButton(context, t),
                    const SizedBox(width: 8),
                    _buildDiagButton(t),
                  ],
                ),
              const SizedBox(height: 16),
              _buildSearchField(t),
              if (searchQuery.isEmpty) ...[
                const SizedBox(height: 12),
                _buildQuickChips(t),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }

  Widget _buildPosButton(BuildContext context, HelpThemeTokens t) {
    final color = t.tone(AppColors.teal);
    return OutlinedButton.icon(
      onPressed: () => context.go('/pos'),
      icon: const Icon(Icons.point_of_sale_rounded, size: 17),
      label: const Text('Ir al POS', maxLines: 1),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDiagButton(HelpThemeTokens t, {bool short = false}) {
    return FilledButton.icon(
      onPressed: onCopyDiagnostics,
      icon: const Icon(Icons.copy_rounded, size: 16),
      label: Text(short ? 'Diagnóstico' : 'Copiar Diagnóstico', maxLines: 1),
      style: FilledButton.styleFrom(
        backgroundColor: t.primaryBtn,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSearchField(HelpThemeTokens t) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextField(
      controller: searchCtrl,
      onChanged: onSearchChanged,
      style: TextStyle(fontSize: 14, color: t.title),
      decoration: InputDecoration(
        hintText: 'Buscar en las guías: turnos, Yape, IGV, permisos…',
        hintStyle: TextStyle(fontSize: 13.5, color: t.muted),
        filled: true,
        fillColor: t.field,
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.muted),
        suffixIcon:
            searchQuery.isNotEmpty
                ? IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: Icon(Icons.close_rounded, size: 18, color: t.muted),
                  onPressed: onClearSearch,
                )
                : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: border(t.border),
        enabledBorder: border(t.border),
        focusedBorder: border(t.accent, 1.5),
      ),
    );
  }

  Widget _buildQuickChips(HelpThemeTokens t) {
    const topics = [
      ('Turnos', 'turno'),
      ('Yape y Plin', 'yape'),
      ('IGV', 'igv'),
      ('Permisos', 'permisos'),
      ('Factura', 'factura'),
      ('Lotes', 'lotes'),
      ('Atajos', 'atajos'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Frecuentes',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.muted,
          ),
        ),
        for (final topic in topics)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onChipSelected(topic.$2),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                ),
                child: Text(
                  topic.$1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: t.body,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
