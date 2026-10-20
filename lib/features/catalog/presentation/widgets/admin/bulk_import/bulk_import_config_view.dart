import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'bulk_import_columns_guide.dart';
import 'bulk_import_components.dart';

class BulkImportConfigView extends StatelessWidget {
  final BulkImportState state;
  final bool compact;
  const BulkImportConfigView({
    super.key,
    required this.state,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BulkImportCubit>();
    final left = Column(
      children: [
        _warehouseCard(context, cubit),
        const SizedBox(height: 16),
        _modeCard(context, cubit),
      ],
    );
    final right = Column(
      children: [
        _dropZone(context, cubit),
        const SizedBox(height: 16),
        BulkImportColumnsGuide(compact: compact),
      ],
    );

    return SingleChildScrollView(
      child:
          compact
              ? Column(children: [left, const SizedBox(height: 16), right])
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: left),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: right),
                ],
              ),
    );
  }

  Widget _warehouseCard(BuildContext context, BulkImportCubit cubit) {
    final ws = state.warehouses;
    Widget body;
    if (ws.isEmpty) {
      body = const BulkImportInfoBox(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        text:
            'No hay almacenes creados. Puedes importar el catálogo, pero las filas con stock serán rechazadas hasta que crees un almacén.',
      );
    } else if (ws.length == 1) {
      body = BulkImportInfoBox(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        text: 'El stock se cargará en el almacén «${ws.first.name}».',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in ws) ...[
            BulkImportSelectTile(
              icon: Icons.warehouse_outlined,
              title: w.name,
              selected: state.selectedWarehouseId == w.id,
              onTap: () => cubit.setWarehouseId(w.id),
            ),
            const SizedBox(height: 10),
          ],
          if (state.needsWarehouseChoice)
            const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.error),
                SizedBox(width: 6),
                Text(
                  'Elige un almacén para continuar.',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ),
        ],
      );
    }
    return BulkImportCard(
      icon: Icons.warehouse_outlined,
      title: 'Almacén destino',
      subtitle: 'Los productos son globales; solo el stock entra al almacén.',
      child: body,
    );
  }

  Widget _modeCard(BuildContext context, BulkImportCubit cubit) {
    final add = state.stockMode == ImportStockMode.add;
    return BulkImportCard(
      icon: Icons.tune_rounded,
      title: 'Si el producto ya existe',
      subtitle: 'Los productos nuevos siempre entran con la cantidad del CSV.',
      child: Column(
        children: [
          BulkImportSelectTile(
            icon: Icons.add_circle_outline_rounded,
            title: 'Sumar al stock',
            subtitle:
                'Registra una entrada. Ej: stock 50 + CSV 30 → queda 80. Ideal para recibir mercadería.',
            selected: add,
            onTap: () => cubit.setStockMode(ImportStockMode.add),
          ),
          const SizedBox(height: 10),
          BulkImportSelectTile(
            icon: Icons.sync_alt_rounded,
            title: 'Reemplazar stock',
            subtitle:
                'Registra un ajuste. Ej: stock 50, CSV 30 → queda 30. Ideal para conteos; es seguro repetir.',
            selected: !add,
            onTap: () => cubit.setStockMode(ImportStockMode.replace),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.brd(context)),
          ),
          BulkImportSwitchRow(
            title: 'Actualizar precios de productos existentes',
            subtitle:
                'Apagado: solo se toca el stock y los precios actuales se conservan.',
            value: state.updatePrices,
            onChanged: cubit.setUpdatePrices,
          ),
        ],
      ),
    );
  }

  Widget _dropZone(BuildContext context, BulkImportCubit cubit) {
    final primary = bulkImportPrimary(context);
    final blocked = state.needsWarehouseChoice;
    return DropTarget(
      onDragDone: (detail) async {
        if (blocked || detail.files.isEmpty) return;
        final xFile = detail.files.first;
        final bytes = await xFile.readAsBytes();
        await cubit.parseBytes(fileName: xFile.name, bytes: bytes);
      },
      child: CustomPaint(
        painter: BulkImportDashedRRectPainter(
          color:
              blocked
                  ? AppColors.brdSubtle(context)
                  : primary.withValues(alpha: 0.45),
          radius: 18,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: compact ? 28 : 40,
          ),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: blocked ? 0.015 : 0.035),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: blocked ? 0.06 : 0.12),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  size: 34,
                  color: blocked ? bulkImportMuted(context) : primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sube tu archivo Excel o CSV',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Arrastra tu archivo o selecciónalo para revisarlo antes de importar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: bulkImportMuted(context)),
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  BulkImportMiniChip(
                    '.xlsx, .xls, .csv',
                    icon: Icons.table_chart_outlined,
                  ),
                  BulkImportMiniChip('Hasta 5 000 filas'),
                  BulkImportMiniChip('Auto-detección de columnas'),
                ],
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: blocked ? null : cubit.pickAndParseFile,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Seleccionar archivo'),
              ),
              if (blocked) ...[
                const SizedBox(height: 10),
                Text(
                  'Elige primero el almacén destino.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        AppColors.isDark(context)
                            ? AppColors.warning
                            : AppColors.warningDark,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => cubit.downloadTemplate(asExcel: true),
                    icon: const Icon(
                      Icons.table_chart_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    label: const Text('Plantilla Excel (.xlsx)'),
                  ),
                  TextButton.icon(
                    onPressed: () => cubit.downloadTemplate(asExcel: false),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Plantilla CSV (.csv)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
