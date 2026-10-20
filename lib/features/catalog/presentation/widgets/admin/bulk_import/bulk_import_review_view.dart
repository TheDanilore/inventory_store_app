import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'bulk_import_components.dart';

enum BulkImportFilter { all, created, existing, warnings, errors }

/// Barra que queda fija arriba al hacer scroll (filtros de la revisión).
class BulkImportPinnedBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color background;
  final double height;
  const BulkImportPinnedBarDelegate({
    required this.child,
    required this.background,
    required this.height,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        border:
            overlapsContent
                ? Border(
                  bottom: BorderSide(color: AppColors.brdSubtle(context)),
                )
                : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant BulkImportPinnedBarDelegate old) => true;
}

class BulkImportReviewView extends StatefulWidget {
  final BulkImportState state;
  final bool compact;
  const BulkImportReviewView({
    super.key,
    required this.state,
    required this.compact,
  });

  @override
  State<BulkImportReviewView> createState() => _BulkImportReviewViewState();
}

class _BulkImportReviewViewState extends State<BulkImportReviewView> {
  BulkImportFilter _filter = BulkImportFilter.all;
  static const int _maxShown = 300;

  final ScrollController _scroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  bool _isCreated(ImportRow r) =>
      !r.hasError && r.action != ImportRowAction.updateVariant;
  bool _isExisting(ImportRow r) =>
      !r.hasError && r.action == ImportRowAction.updateVariant;

  List<ImportRow> _filtered(List<ImportRow> all) {
    switch (_filter) {
      case BulkImportFilter.all:
        return all;
      case BulkImportFilter.created:
        return all.where(_isCreated).toList();
      case BulkImportFilter.existing:
        return all.where(_isExisting).toList();
      case BulkImportFilter.warnings:
        return all.where((r) => r.hasWarning).toList();
      case BulkImportFilter.errors:
        return all.where((r) => r.hasError).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final compact = widget.compact;
    final cubit = context.read<BulkImportCubit>();
    final pad = compact ? 16.0 : 24.0;

    return LayoutBuilder(
      builder: (context, c) {
        final contentW = (c.maxWidth - 2 * pad).clamp(0.0, 1200.0).toDouble();
        final side = (c.maxWidth - contentW) / 2;
        final hPad = EdgeInsets.symmetric(horizontal: side);

        if (state.fileErrors.isNotEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(side, 0, side, pad),
            child: _fileErrors(context, state, cubit),
          );
        }

        final rows = _filtered(state.rows);
        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fileHeader(context, state, cubit),
            if (state.importError != null) ...[
              const SizedBox(height: 12),
              BulkImportBanner(
                icon: Icons.error_outline,
                color: AppColors.error,
                text: state.importError!,
              ),
            ],
            const SizedBox(height: 14),
            BulkImportStatsGrid(items: _stats(state.summary)),
            const SizedBox(height: 14),
            _statusBanner(state.summary),
            const SizedBox(height: 6),
          ],
        );

        final Widget rowsSliver =
            rows.isEmpty
                ? SliverToBoxAdapter(child: _empty(context))
                : compact
                ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i >= _maxShown) {
                        return _moreNote(context, rows.length);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BulkImportRowCard(
                          row: rows[i],
                          mode: state.stockMode,
                        ),
                      );
                    },
                    childCount:
                        rows.length > _maxShown ? _maxShown + 1 : rows.length,
                  ),
                )
                : SliverToBoxAdapter(
                  child: _table(context, rows, state.stockMode),
                );

        final Widget body = Scrollbar(
          controller: _scroll,
          thumbVisibility: !compact,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: hPad,
                sliver: SliverToBoxAdapter(child: intro),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: BulkImportPinnedBarDelegate(
                  height: 56,
                  background: AppColors.bg(context),
                  child: Padding(padding: hPad, child: _filters(state)),
                ),
              ),
              SliverPadding(padding: hPad, sliver: rowsSliver),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        );

        return Column(
          children: [
            Expanded(child: body),
            Padding(
              padding: EdgeInsets.fromLTRB(side, 12, side, pad),
              child: _actionBar(context, state, cubit),
            ),
          ],
        );
      },
    );
  }

  List<BulkImportStatItem> _stats(ImportSummary s) => [
    BulkImportStatItem(
      Icons.inventory_2_outlined,
      'Productos nuevos',
      s.newProducts,
      AppColors.success,
    ),
    BulkImportStatItem(
      Icons.style_outlined,
      'Variantes nuevas',
      s.newVariants,
      AppColors.info,
    ),
    BulkImportStatItem(
      Icons.sync_alt_rounded,
      'Variantes existentes',
      s.updatedVariants,
      bulkImportViolet,
    ),
    BulkImportStatItem(
      Icons.layers_outlined,
      'Unidades de stock',
      s.units,
      AppColors.amber,
    ),
    if (s.lots > 0)
      BulkImportStatItem(
        Icons.inventory_outlined,
        'Lotes de stock',
        s.lots,
        bulkImportViolet,
      ),
    if (s.newBrands > 0)
      BulkImportStatItem(
        Icons.local_offer_outlined,
        'Marcas a crear',
        s.newBrands,
        AppColors.teal,
      ),
    if (s.newCategories > 0)
      BulkImportStatItem(
        Icons.category_outlined,
        'Categorías a crear',
        s.newCategories,
        AppColors.teal,
      ),
  ];

  Widget _fileErrors(
    BuildContext context,
    BulkImportState state,
    BulkImportCubit cubit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BulkImportBanner(
          icon: Icons.error_outline,
          color: AppColors.error,
          text: 'No se puede procesar "${state.fileName ?? 'el archivo'}".',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: AppColors.cardAdaptive(context, elevated: false),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: state.fileErrors.length,
              separatorBuilder:
                  (_, _) => Divider(height: 1, color: AppColors.brd(context)),
              itemBuilder:
                  (_, i) => ListTile(
                    leading: const Icon(
                      Icons.close_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(state.fileErrors[i]),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: cubit.reset,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Elegir otro archivo'),
          ),
        ),
      ],
    );
  }

  Widget _fileHeader(
    BuildContext context,
    BulkImportState state,
    BulkImportCubit cubit,
  ) {
    final primary = bulkImportPrimary(context);
    final wh = state.selectedWarehouse?.name ?? 'Sin almacén';
    final mode =
        state.stockMode == ImportStockMode.add
            ? 'Sumar al stock'
            : 'Reemplazar stock';
    final hasIssues = state.rows.any((r) => r.issues.isNotEmpty);

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasIssues)
          PopupMenuButton<bool>(
            tooltip: 'Descargar reporte de incidencias',
            onSelected:
                (asExcel) => cubit.downloadIssuesReport(asExcel: asExcel),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.table_chart_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 8),
                        Text('Reporte Excel (.xlsx)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: false,
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Reporte CSV (.csv)'),
                      ],
                    ),
                  ),
                ],
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Reporte'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: cubit.reset,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Cambiar archivo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    );

    final info = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.description_outlined, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.fileName ?? 'archivo.csv',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${state.summary.totalRows} filas leídas',
                style: TextStyle(
                  fontSize: 12.5,
                  color: bulkImportMuted(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardAdaptive(context, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.compact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [info, const SizedBox(height: 12), actions],
              )
              : Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  actions,
                ],
              ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BulkImportMiniChip(wh, icon: Icons.warehouse_outlined),
              BulkImportMiniChip(mode, icon: Icons.sync_alt_rounded),
              BulkImportMiniChip(
                state.updatePrices ? 'Actualiza precios' : 'Conserva precios',
                icon: Icons.sell_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(ImportSummary s) {
    if (s.errorRows > 0) {
      return BulkImportBanner(
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
        text:
            '${s.errorRows} ${s.errorRows == 1 ? 'fila tiene' : 'filas tienen'} errores y no se importarán. Corrige el CSV y vuelve a subirlo si quieres incluirlas.',
        actionLabel: 'Ver errores',
        onAction: () => setState(() => _filter = BulkImportFilter.errors),
      );
    }
    if (s.warningRows > 0) {
      return BulkImportBanner(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        text:
            '${s.warningRows} ${s.warningRows == 1 ? 'fila tiene' : 'filas tienen'} advertencias; se importarán igualmente.',
        actionLabel: 'Revisar',
        onAction: () => setState(() => _filter = BulkImportFilter.warnings),
      );
    }
    return BulkImportBanner(
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
      text: 'Todo en orden: ${s.validRows} filas listas para importar.',
    );
  }

  Widget _filters(BulkImportState state) {
    final s = state.summary;
    final items = <(BulkImportFilter, String, int)>[
      (BulkImportFilter.all, 'Todas', s.totalRows),
      (
        BulkImportFilter.created,
        'Se crean',
        state.rows.where(_isCreated).length,
      ),
      (
        BulkImportFilter.existing,
        'Ya existen',
        state.rows.where(_isExisting).length,
      ),
      (BulkImportFilter.warnings, 'Advertencias', s.warningRows),
      (BulkImportFilter.errors, 'Errores', s.errorRows),
    ];
    final primary = bulkImportPrimary(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() => _filter = it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _filter == it.$1 ? primary : AppColors.surf(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color:
                          _filter == it.$1
                              ? primary
                              : AppColors.brdSubtle(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        it.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              _filter == it.$1
                                  ? Colors.white
                                  : AppColors.txtPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _filter == it.$1
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : bulkImportSoft(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${it.$3}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color:
                                _filter == it.$1
                                    ? Colors.white
                                    : bulkImportMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Text(
        'No hay filas en este filtro.',
        style: TextStyle(color: bulkImportMuted(context)),
      ),
    ),
  );

  Widget _moreNote(BuildContext context, int total) => Padding(
    padding: const EdgeInsets.all(14),
    child: Text(
      'Mostrando $_maxShown de $total filas. Todas se procesan; usa los filtros o el reporte para revisar el resto.',
      style: TextStyle(color: bulkImportMuted(context), fontSize: 12.5),
    ),
  );

  static const cols = <(String, double)>[
    ('Fila', 52),
    ('Estado', 140),
    ('Producto', 210),
    ('Marca', 120),
    ('Variante', 100),
    ('SKU', 100),
    ('Compra', 72),
    ('Venta', 72),
    ('Mayor', 72),
    ('Stock', 64),
    ('Lote', 96),
    ('Vence', 92),
    ('Detalle', 340),
  ];
  static final double _totalWidth = cols.fold(0.0, (a, c) => a + c.$2);

  Widget _table(
    BuildContext context,
    List<ImportRow> rows,
    ImportStockMode mode,
  ) {
    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: AppColors.cardAdaptive(context, elevated: false),
        child: _empty(context),
      );
    }
    final shown = rows.take(_maxShown).toList();
    return Container(
      decoration: AppColors.cardAdaptive(context, elevated: false),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth > _totalWidth ? c.maxWidth : _totalWidth;
          return Scrollbar(
            controller: _hScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: bulkImportSoft(context),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          for (final col in cols)
                            SizedBox(
                              width:
                                  col.$1 == 'Detalle'
                                      ? col.$2 + (width - _totalWidth)
                                      : col.$2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  col.$1.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                    color: bulkImportMuted(context),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: AppColors.brd(context)),
                      BulkImportTableRow(
                        row: shown[i],
                        mode: mode,
                        extraDetailWidth: width - _totalWidth,
                      ),
                    ],
                    if (rows.length > _maxShown)
                      _moreNote(context, rows.length),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _actionBar(
    BuildContext context,
    BulkImportState state,
    BulkImportCubit cubit,
  ) {
    final s = state.summary;
    final canImport = s.validRows > 0;
    final label =
        state.canResume
            ? 'Reanudar importación'
            : 'Importar ${s.validRows} ${s.validRows == 1 ? 'fila' : 'filas'}';

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${s.validRows} de ${s.totalRows} filas listas',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (s.errorRows > 0)
          Text(
            '${s.errorRows} con error se omitirán',
            style: const TextStyle(fontSize: 12.5, color: AppColors.error),
          ),
      ],
    );

    final button = ElevatedButton.icon(
      onPressed:
          canImport
              ? () async {
                if (state.canResume) {
                  cubit.resumeImport();
                  return;
                }
                final ok = await _confirm(context, state);
                if (ok == true) cubit.startImport();
              }
              : null,
      icon: Icon(
        state.canResume ? Icons.play_arrow_rounded : Icons.cloud_upload_rounded,
      ),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        disabledBackgroundColor: bulkImportSoft(context),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppColors.cardAdaptive(context),
      child:
          widget.compact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [text, const SizedBox(height: 10), button],
              )
              : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 12),
                  button,
                ],
              ),
    );
  }

  Future<bool?> _confirm(BuildContext context, BulkImportState state) {
    final s = state.summary;
    final replace = state.stockMode == ImportStockMode.replace;
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: bulkImportMuted(context))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar importación'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  line('Almacén', state.selectedWarehouse?.name ?? '—'),
                  line('Stock existente', replace ? 'Se reemplaza' : 'Se suma'),
                  line(
                    'Precios existentes',
                    state.updatePrices ? 'Se actualizan' : 'Se conservan',
                  ),
                  Divider(color: AppColors.brd(ctx)),
                  line('Productos nuevos', '${s.newProducts}'),
                  line('Variantes nuevas', '${s.newVariants}'),
                  line('Variantes existentes', '${s.updatedVariants}'),
                  line('Unidades de stock', '${s.units}'),
                  if (s.lots > 0) line('Lotes de stock', '${s.lots}'),
                  if (s.newBrands > 0) line('Marcas nuevas', '${s.newBrands}'),
                  if (s.newCategories > 0)
                    line('Categorías nuevas', '${s.newCategories}'),
                  if (s.errorRows > 0) ...[
                    Divider(color: AppColors.brd(ctx)),
                    line('Filas omitidas por error', '${s.errorRows}'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar e importar'),
              ),
            ],
          ),
    );
  }
}

// ───────────────────────────── Filas (tabla y tarjeta) ─────────────────────────────

Widget bulkImportStatusBadge(ImportRow row) {
  late final String text;
  late final Color color;
  if (row.hasError) {
    text = 'Error';
    color = AppColors.error;
  } else if (row.isExtraLot) {
    text = 'Lote adicional';
    color = AppColors.teal;
  } else {
    switch (row.action) {
      case ImportRowAction.createProduct:
        text = 'Producto nuevo';
        color = AppColors.success;
      case ImportRowAction.addVariant:
        text = 'Variante nueva';
        color = AppColors.info;
      case ImportRowAction.updateVariant:
        text = 'Ya existe';
        color = bulkImportViolet;
    }
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: BulkImportBadge(text, color)),
      if (row.hasWarning)
        const Padding(
          padding: EdgeInsets.only(left: 5),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.warning,
          ),
        ),
    ],
  );
}

class BulkImportDetailBlock extends StatelessWidget {
  final ImportRow row;
  final ImportStockMode mode;
  const BulkImportDetailBlock({
    super.key,
    required this.row,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    if (row.issues.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in row.issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i.severity == IssueSeverity.error
                        ? Icons.cancel_outlined
                        : Icons.warning_amber_rounded,
                    size: 14,
                    color:
                        i.severity == IssueSeverity.error
                            ? AppColors.error
                            : AppColors.warning,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${i.column}: ${i.message}',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color:
                            i.severity == IssueSeverity.error
                                ? AppColors.error
                                : (AppColors.isDark(context)
                                    ? AppColors.warning
                                    : AppColors.warningDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    final ex = row.existing;
    if (ex != null && row.stock != null) {
      final cur = ex.currentStock;
      final next = mode == ImportStockMode.add ? cur + row.stock! : row.stock!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 14,
            color: bulkImportMuted(context),
          ),
          const SizedBox(width: 5),
          Text(
            'Stock: $cur → $next',
            style: TextStyle(fontSize: 12.5, color: bulkImportMuted(context)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class BulkImportTableRow extends StatelessWidget {
  final ImportRow row;
  final ImportStockMode mode;
  final double extraDetailWidth;
  const BulkImportTableRow({
    super.key,
    required this.row,
    required this.mode,
    required this.extraDetailWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cols = _BulkImportReviewViewState.cols;
    Text t(String s, {Color? color, FontWeight? w}) => Text(
      s,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: color, fontWeight: w),
    );

    final cells = <Widget>[
      t('${row.line}', color: bulkImportMuted(context)),
      bulkImportStatusBadge(row),
      t(row.productName.isEmpty ? '—' : row.productName, w: FontWeight.w600),
      t(row.brand.isEmpty ? '-' : row.brand),
      t(row.variantName.isEmpty ? 'Único' : row.variantName),
      t(row.sku.isEmpty ? '-' : row.sku),
      t(bulkImportMoney(row.cost)),
      t(bulkImportMoney(row.salePrice)),
      t(bulkImportMoney(row.wholesalePrice)),
      t(row.stock?.toString() ?? '-'),
      t(row.effectiveUsesLots && row.lotCode.isNotEmpty ? row.lotCode : '-'),
      t(
        row.effectiveUsesLots && row.expiry != null
            ? bulkImportDate(row.expiry!)
            : '-',
      ),
      BulkImportDetailBlock(row: row, mode: mode),
    ];

    return Container(
      color: row.hasError ? AppColors.error.withValues(alpha: 0.05) : null,
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width:
                  i == cells.length - 1
                      ? cols[i].$2 + extraDetailWidth
                      : cols[i].$2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cells[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de fila para pantallas angostas.
class BulkImportRowCard extends StatelessWidget {
  final ImportRow row;
  final ImportStockMode mode;
  const BulkImportRowCard({super.key, required this.row, required this.mode});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (row.brand.isNotEmpty) row.brand,
      row.variantName.isEmpty ? 'Único' : row.variantName,
      if (row.sku.isNotEmpty) row.sku,
    ].join(' · ');

    Widget kv(String k, String v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          k,
          style: TextStyle(fontSize: 11, color: bulkImportMuted(context)),
        ),
        const SizedBox(height: 1),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ],
    );

    final hasDetail =
        row.issues.isNotEmpty || (row.existing != null && row.stock != null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            row.hasError
                ? AppColors.error.withValues(alpha: 0.05)
                : AppColors.surf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              row.hasError
                  ? AppColors.error.withValues(alpha: 0.4)
                  : AppColors.brd(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: bulkImportStatusBadge(row),
                ),
              ),
              Text(
                'Fila ${row.line}',
                style: TextStyle(fontSize: 12, color: bulkImportMuted(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.productName.isEmpty ? '—' : row.productName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12.5, color: bulkImportMuted(context)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              kv('Compra', bulkImportMoney(row.cost)),
              kv('Venta', bulkImportMoney(row.salePrice)),
              if (row.wholesalePrice != null)
                kv('Mayor', bulkImportMoney(row.wholesalePrice)),
              kv('Stock', row.stock?.toString() ?? '-'),
              if (row.effectiveUsesLots && row.lotCode.isNotEmpty)
                kv('Lote', row.lotCode),
              if (row.effectiveUsesLots && row.expiry != null)
                kv('Vence', bulkImportDate(row.expiry!)),
            ],
          ),
          if (hasDetail) ...[
            const SizedBox(height: 10),
            BulkImportDetailBlock(row: row, mode: mode),
          ],
        ],
      ),
    );
  }
}
