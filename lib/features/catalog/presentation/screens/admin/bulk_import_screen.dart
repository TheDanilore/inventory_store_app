import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/bulk_import/bulk_import_components.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/bulk_import/bulk_import_config_view.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/bulk_import/bulk_import_review_view.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/bulk_import/bulk_import_status_views.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BulkImportCubit>().loadContext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      anyPermissions: const [
        AppPermissions.productsCreate,
        AppPermissions.productsEdit,
      ],
      fallback: AdminLayout(
        title: 'Importación Masiva',
        showBackButton: true,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 38,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Acceso Restringido',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'No cuentas con permisos suficientes para realizar importaciones masivas de productos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: bulkImportMuted(context)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/products'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver al Catálogo'),
                ),
              ],
            ),
          ),
        ),
      ),
      child: BlocListener<BulkImportCubit, BulkImportState>(
        listenWhen:
            (p, c) => p.status != c.status || p.errorMessage != c.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            AppSnackbar.show(
              context,
              message: state.errorMessage!,
              type: SnackbarType.error,
            );
          }
          if (state.status == BulkImportStatus.success) {
            context.read<AdminCatalogCubit>().refreshProducts(
              forceRefresh: true,
            );
          }
        },
        child: BlocBuilder<BulkImportCubit, BulkImportState>(
          builder: (context, state) {
            final importing = state.status == BulkImportStatus.importing;
            void warnBusy() => AppSnackbar.show(
              context,
              message: 'La importación está en curso, por favor espere.',
              type: SnackbarType.warning,
            );

            return PopScope(
              canPop: !importing,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && importing) warnBusy();
              },
              child: AdminLayout(
                title: 'Importación Masiva (Excel / CSV)',
                showBackButton: true,
                onBack: importing ? warnBusy : null,
                body: Container(
                  color: AppColors.bg(context),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final compact = c.maxWidth < bulkImportWideBreakpoint;

                      if (state.status == BulkImportStatus.review) {
                        final pad = compact ? 16.0 : 24.0;
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1200,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: BulkImportStepHeader(
                                      status: state.status,
                                      compact: compact,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 16 : 24),
                            Expanded(child: _content(state, compact)),
                          ],
                        );
                      }

                      return Padding(
                        padding: EdgeInsets.all(compact ? 16 : 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              children: [
                                BulkImportStepHeader(
                                  status: state.status,
                                  compact: compact,
                                ),
                                SizedBox(height: compact ? 16 : 24),
                                Expanded(child: _content(state, compact)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(BulkImportState state, bool compact) {
    switch (state.status) {
      case BulkImportStatus.loadingContext:
      case BulkImportStatus.parsing:
        return BulkImportBusy(
          label:
              state.status == BulkImportStatus.parsing
                  ? 'Leyendo y validando el archivo...'
                  : 'Cargando configuración...',
        );
      case BulkImportStatus.initial:
        return BulkImportConfigView(state: state, compact: compact);
      case BulkImportStatus.review:
        return BulkImportReviewView(state: state, compact: compact);
      case BulkImportStatus.importing:
        return BulkImportingView(state: state);
      case BulkImportStatus.success:
        return BulkImportSuccessView(state: state, compact: compact);
    }
  }
}
