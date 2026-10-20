import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'bulk_import_components.dart';

class BulkImportingView extends StatelessWidget {
  final BulkImportState state;
  const BulkImportingView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final primary = bulkImportPrimary(context);
    final pct = (state.progress * 100).round();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: AppColors.cardAdaptive(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: state.progress == 0 ? null : state.progress,
                        strokeWidth: 6,
                        backgroundColor: primary.withValues(alpha: 0.12),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Importando productos y stock',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'No cierres ni salgas de esta pantalla.',
                style: TextStyle(color: bulkImportMuted(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulkImportSuccessView extends StatelessWidget {
  final BulkImportState state;
  final bool compact;
  const BulkImportSuccessView({
    super.key,
    required this.state,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final r = state.result ?? const ImportBatchResult();
    final cubit = context.read<BulkImportCubit>();
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: EdgeInsets.all(compact ? 20 : 32),
            decoration: AppColors.cardAdaptive(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Importación completada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                if (state.selectedWarehouse != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Stock cargado en «${state.selectedWarehouse!.name}»',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: bulkImportMuted(context)),
                  ),
                ],
                const SizedBox(height: 24),
                BulkImportStatsGrid(
                  items: [
                    BulkImportStatItem(
                      Icons.inventory_2_outlined,
                      'Productos creados',
                      r.createdProducts,
                      AppColors.success,
                    ),
                    BulkImportStatItem(
                      Icons.style_outlined,
                      'Variantes creadas',
                      r.createdVariants,
                      AppColors.info,
                    ),
                    BulkImportStatItem(
                      Icons.sync_alt_rounded,
                      'Variantes actualizadas',
                      r.updatedVariants,
                      bulkImportViolet,
                    ),
                    BulkImportStatItem(
                      Icons.swap_vert_rounded,
                      'Movimientos de stock',
                      r.stockMovements,
                      AppColors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: cubit.reset,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Importar otro archivo'),
                    ),
                    ElevatedButton.icon(
                      // Se llega aquí con context.go (sin historial), por eso
                      // pop() no hacía nada: se navega directo al catálogo.
                      onPressed: () => context.go('/products'),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Ver productos'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
