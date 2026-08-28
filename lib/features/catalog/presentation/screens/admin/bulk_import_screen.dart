import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';

class BulkImportScreen extends StatelessWidget {
  const BulkImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<BulkImportCubit, BulkImportState>(
      listenWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.status == BulkImportStatus.error &&
            state.errorMessage != null) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        } else if (state.status == BulkImportStatus.success) {
          AppSnackbar.show(
            context,
            message: '¡Importación completada con éxito!',
            type: SnackbarType.success,
          );
          context.read<AdminCatalogCubit>().refreshProducts();
          context.pop();
        }
      },
      child: BlocBuilder<BulkImportCubit, BulkImportState>(
        builder: (context, state) {
          final isUploading = state.status == BulkImportStatus.uploading;

          return PopScope(
            canPop: !isUploading,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && isUploading) {
                AppSnackbar.show(
                  context,
                  message: 'La importación está en curso, por favor espere.',
                  type: SnackbarType.warning,
                );
              }
            },
            child: AdminLayout(
              title: 'Importación Masiva (CSV)',
              showBackButton: true,
              onBack:
                  isUploading
                      ? () {
                        AppSnackbar.show(
                          context,
                          message:
                              'La importación está en curso, por favor espere.',
                          type: SnackbarType.warning,
                        );
                      }
                      : null,
              body: Container(
                color: AppColors.background,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInstructions(context),
                    const SizedBox(height: 24),
                    Expanded(
                      child: BlocBuilder<BulkImportCubit, BulkImportState>(
                        builder: (context, state) {
                          if (state.status == BulkImportStatus.parsing ||
                              state.status == BulkImportStatus.uploading) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (state.status == BulkImportStatus.validationDone ||
                              state.errors.isNotEmpty) {
                            return _buildValidationResults(context, state);
                          }

                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_file_rounded,
                                  size: 64,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Selecciona un archivo CSV para importar productos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed:
                                          () =>
                                              context
                                                  .read<BulkImportCubit>()
                                                  .downloadTemplate(),
                                      icon: const Icon(Icons.download_rounded),
                                      label: const Text('Descargar Plantilla'),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton.icon(
                                      onPressed:
                                          () =>
                                              context
                                                  .read<BulkImportCubit>()
                                                  .pickAndParseFile(),
                                      icon: const Icon(Icons.file_upload),
                                      label: const Text(
                                        'Seleccionar Archivo CSV',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Instrucciones de Importación',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '1. El archivo DEBE ser en formato .CSV (Valores separados por comas).',
          ),
          Text(
            '2. La primera fila DEBE contener los siguientes encabezados exactos (en minúsculas):',
          ),
          Text('   - Requeridos: "nombre", "sku", "costo"'),
          Text(
            '   - Opcionales: "descripcion", "categoria", "precio_venta", "stock_inicial", "imagen_url"',
          ),
          Text(
            '3. Cada fila creará automáticamente un Producto y una Variante base.',
          ),
          Text(
            '4. No usar separadores de miles en precios o stock. Usar punto (.) para decimales.',
          ),
        ],
      ),
    );
  }

  Widget _buildValidationResults(BuildContext context, BulkImportState state) {
    final hasErrors = state.errors.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasErrors
                  ? 'Se encontraron errores de validación'
                  : 'Validación exitosa (${state.parsedRows.length} productos listos)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: hasErrors ? AppColors.error : AppColors.success,
              ),
            ),
            if (!hasErrors)
              ElevatedButton.icon(
                onPressed: () => context.read<BulkImportCubit>().uploadData(),
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Confirmar Subida a Base de Datos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            if (hasErrors)
              OutlinedButton.icon(
                onPressed: () => context.read<BulkImportCubit>().reset(),
                icon: const Icon(Icons.refresh),
                label: const Text('Intentar Nuevo Archivo'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (hasErrors)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.errors.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errors[index],
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          )
        else
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: BlocSelector<
                BulkImportCubit,
                BulkImportState,
                List<Map<String, dynamic>>
              >(
                selector: (state) => state.parsedRows,
                builder: (context, parsedRows) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.background,
                        ),
                        columns: const [
                          DataColumn(label: Text('Nombre')),
                          DataColumn(label: Text('SKU')),
                          DataColumn(label: Text('Categoría')),
                          DataColumn(label: Text('Costo')),
                          DataColumn(label: Text('Precio Venta')),
                          DataColumn(label: Text('Stock Inicial')),
                        ],
                        rows:
                            parsedRows.take(100).map((row) {
                              // Take 100 max for preview
                              return DataRow(
                                cells: [
                                  DataCell(Text(row['nombre'].toString())),
                                  DataCell(Text(row['sku'].toString())),
                                  DataCell(
                                    Text(row['categoria']?.toString() ?? '-'),
                                  ),
                                  DataCell(
                                    Text(row['costo_parsed'].toString()),
                                  ),
                                  DataCell(
                                    Text(
                                      row['precio_venta_parsed']?.toString() ??
                                          '-',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row['stock_inicial_parsed']?.toString() ??
                                          '0',
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
