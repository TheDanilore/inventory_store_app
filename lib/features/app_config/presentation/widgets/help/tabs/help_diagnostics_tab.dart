import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/core/network/network_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/system_diagnostics_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_components.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

class HelpDiagnosticsTab extends StatefulWidget {
  const HelpDiagnosticsTab({super.key});

  @override
  State<HelpDiagnosticsTab> createState() => _HelpDiagnosticsTabState();
}

class _HelpDiagnosticsTabState extends State<HelpDiagnosticsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Zero-Shimmer SWR: Solo carga si la memoria está vacía
    context.read<SystemDiagnosticsCubit>().loadDiagnostics();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = HelpThemeTokens.of(context);
    final isOnline = context.watch<NetworkCubit>().state is NetworkConnected;

    return BlocBuilder<SystemDiagnosticsCubit, SystemDiagnosticsState>(
      builder: (context, state) {
        final d = state.diagnostics;
        final isMeasuring = state.isMeasuring;
        final appVersion = d?.appVersion ?? 'Cargando...';
        final buildNumber = d?.buildNumber ?? '';
        final latencyMs = d?.latencyMs;
        final isReachable = d?.isBackendReachable ?? true;

        final latencyText =
            isMeasuring
                ? 'Midiendo...'
                : latencyMs == null
                ? (isReachable ? 'N/D' : 'Error de conexión')
                : d?.latencyText ?? 'N/D';

        final latencyColor =
            latencyMs == null
                ? (isReachable ? AppColors.warning : AppColors.error)
                : latencyMs < 100
                ? AppColors.success
                : latencyMs < 300
                ? AppColors.info
                : latencyMs < 600
                ? AppColors.warning
                : AppColors.error;

        final versionDisplay =
            d?.versionDisplay ?? 'DANILORE ONE ERP v$appVersion';

        final rows = [
          ('Versión de Software', versionDisplay, null),
          ('Motor de Base de Datos', 'PostgreSQL vía Supabase Cloud', null),
          (
            'Arquitectura POS',
            'Multi-Store, Multi-Register y caché offline resiliente',
            null,
          ),
          (
            'Plataforma Activa',
            'Flutter Multiplatform Desktop/Web/Android',
            null,
          ),
          ('Latencia a Supabase', latencyText, latencyColor),
          (
            'Conectividad de Red',
            isOnline ? 'Conectado a Internet' : 'Sin conexión a Internet',
            isOnline ? AppColors.success : AppColors.error,
          ),
          ('Seguridad', 'Row Level Security (RLS) + JWT Auth', null),
        ];

        final buildSuffix =
            buildNumber.isNotEmpty ? ' (Build $buildNumber)' : '';
        final reportText =
            'DANILORE ONE ERP v$appVersion$buildSuffix | Latency: ${latencyMs?.toString() ?? 'N/D'}ms | DB: PostgreSQL Supabase | Network: ${isOnline ? 'Online' : 'Offline'} | Supabase: ${isReachable ? 'Reachable' : 'Unreachable'}';

        return ListView(
          key: const PageStorageKey<String>('help_tab_diagnostics'),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner de Conexión Activa
                    HelpStatusBanner(reachable: isReachable && isOnline),
                    const SizedBox(height: 24),

                    // Encabezado de Sección
                    const HelpSectionHeader(
                      title: 'Telemetría de la Aplicación',
                      subtitle: 'Información del entorno y conectividad',
                    ),
                    const SizedBox(height: 14),

                    // Grid de Telemetría
                    LayoutBuilder(
                      builder: (context, c) {
                        final isWide = c.maxWidth >= 720;
                        if (!isWide) {
                          return Column(
                            children: [
                              for (var i = 0; i < rows.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                HelpDiagTile(
                                  label: rows[i].$1,
                                  value: rows[i].$2,
                                  dot: rows[i].$3,
                                ),
                              ],
                            ],
                          );
                        }

                        final widgets = <Widget>[];
                        for (var i = 0; i < rows.length; i += 2) {
                          widgets.add(
                            Row(
                              children: [
                                Expanded(
                                  child: HelpDiagTile(
                                    label: rows[i].$1,
                                    value: rows[i].$2,
                                    dot: rows[i].$3,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child:
                                      i + 1 < rows.length
                                          ? HelpDiagTile(
                                            label: rows[i + 1].$1,
                                            value: rows[i + 1].$2,
                                            dot: rows[i + 1].$3,
                                          )
                                          : const SizedBox(),
                                ),
                              ],
                            ),
                          );
                          if (i + 2 < rows.length) {
                            widgets.add(const SizedBox(height: 12));
                          }
                        }
                        return Column(children: widgets);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Botones de Acción
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              () => _copyToClipboard(
                                reportText,
                                'Reporte de Diagnóstico',
                              ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text(
                            'Copiar reporte para soporte técnico',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: t.primaryBtn,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              isMeasuring
                                  ? null
                                  : () =>
                                      context
                                          .read<SystemDiagnosticsCubit>()
                                          .measureLatency(),
                          icon:
                              isMeasuring
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Re-medir latencia'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
