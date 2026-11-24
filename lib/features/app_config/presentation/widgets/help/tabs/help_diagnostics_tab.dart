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

/// Pestaña de telemetría y conectividad con rebuilds granulares vía [BlocSelector].
///
/// No retiene árboles ocultos en RAM; el estado vive en el singleton [SystemDiagnosticsCubit]
/// con caché L1/L2 Zero-Shimmer y `PageStorageKey` para preservar scroll.
class HelpDiagnosticsTab extends StatelessWidget {
  const HelpDiagnosticsTab({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);

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
                const _DiagnosticsStatusSection(),
                const SizedBox(height: 24),
                const HelpSectionHeader(
                  title: 'Telemetría de la Aplicación',
                  subtitle: 'Información del entorno y conectividad',
                ),
                const SizedBox(height: 14),
                const _DiagnosticsTelemetryGrid(),
                const SizedBox(height: 24),
                _DiagnosticsActionBar(
                  primaryBtnColor: t.primaryBtn,
                  onCopyReport: (report) {
                    _copyToClipboard(context, report, 'Reporte de Diagnóstico');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsStatusSection extends StatelessWidget {
  const _DiagnosticsStatusSection();

  @override
  Widget build(BuildContext context) {
    final isOnline = context.select<NetworkCubit, bool>(
      (cubit) => cubit.state is NetworkConnected,
    );

    return BlocSelector<
      SystemDiagnosticsCubit,
      SystemDiagnosticsState,
      ({bool? reachable, bool isChecking, String? errorMessage})
    >(
      selector:
          (state) => (
            reachable: state.diagnostics?.isBackendReachable,
            isChecking: state.isMeasuring,
            errorMessage:
                state is SystemDiagnosticsError ? state.message : null,
          ),
      builder: (context, info) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HelpStatusBanner(
              reachable: info.reachable,
              isOnline: isOnline,
              isChecking: info.isChecking,
            ),
            if (info.errorMessage != null) ...[
              const SizedBox(height: 12),
              _DiagnosticsErrorNotice(message: info.errorMessage!),
            ],
          ],
        );
      },
    );
  }
}

class _DiagnosticsErrorNotice extends StatelessWidget {
  final String message;

  const _DiagnosticsErrorNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: t.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: t.tone(AppColors.warning),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: t.body, height: 1.35),
            ),
          ),
          TextButton(
            onPressed:
                () => context.read<SystemDiagnosticsCubit>().loadDiagnostics(
                  forceRefresh: true,
                ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsTelemetryGrid extends StatelessWidget {
  const _DiagnosticsTelemetryGrid();

  static const _staticDbTile = HelpDiagTile(
    label: 'Motor de Base de Datos',
    value: 'PostgreSQL vía Supabase Cloud',
  );
  static const _staticPosTile = HelpDiagTile(
    label: 'Arquitectura POS',
    value: 'Multi-Store, Multi-Register y caché offline resiliente',
  );
  static const _staticPlatformTile = HelpDiagTile(
    label: 'Plataforma Activa',
    value: 'Flutter Multiplatform Desktop/Web/Android',
  );
  static const _staticSecurityTile = HelpDiagTile(
    label: 'Seguridad',
    value: 'Row Level Security (RLS) + JWT Auth',
  );

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      const _VersionDiagTile(),
      _staticDbTile,
      _staticPosTile,
      _staticPlatformTile,
      const _LatencyDiagTile(),
      const _NetworkDiagTile(),
      _staticSecurityTile,
    ];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 720) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                tiles[i],
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < tiles.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tiles[i]),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        i + 1 < tiles.length
                            ? tiles[i + 1]
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _VersionDiagTile extends StatelessWidget {
  const _VersionDiagTile();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SystemDiagnosticsCubit, SystemDiagnosticsState, String>(
      selector:
          (state) =>
              state.diagnostics?.versionDisplay ?? 'Verificando versión…',
      builder:
          (_, versionDisplay) =>
              HelpDiagTile(label: 'Versión de Software', value: versionDisplay),
    );
  }
}

class _LatencyDiagTile extends StatelessWidget {
  const _LatencyDiagTile();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SystemDiagnosticsCubit,
      SystemDiagnosticsState,
      ({String text, Color color})
    >(
      selector: (state) {
        final d = state.diagnostics;
        if (d == null && state.isMeasuring) {
          return (text: 'Midiendo…', color: AppColors.info);
        }
        if (state.isMeasuring) {
          return (text: 'Midiendo…', color: AppColors.info);
        }
        final ms = d?.latencyMs;
        final reachable = d?.isBackendReachable ?? false;
        if (ms == null) {
          return (
            text: reachable ? 'N/D' : 'Error de conexión',
            color: reachable ? AppColors.warning : AppColors.error,
          );
        }
        final color =
            ms < 100
                ? AppColors.success
                : ms < 300
                ? AppColors.info
                : ms < 600
                ? AppColors.warning
                : AppColors.error;
        return (text: d!.latencyText, color: color);
      },
      builder:
          (_, data) => HelpDiagTile(
            label: 'Latencia a Supabase',
            value: data.text,
            dot: data.color,
          ),
    );
  }
}

class _NetworkDiagTile extends StatelessWidget {
  const _NetworkDiagTile();

  @override
  Widget build(BuildContext context) {
    final isOnline = context.select<NetworkCubit, bool>(
      (cubit) => cubit.state is NetworkConnected,
    );

    return HelpDiagTile(
      label: 'Conectividad de Red',
      value: isOnline ? 'Conectado a Internet' : 'Sin conexión a Internet',
      dot: isOnline ? AppColors.success : AppColors.error,
    );
  }
}

class _DiagnosticsActionBar extends StatelessWidget {
  final Color primaryBtnColor;
  final ValueChanged<String> onCopyReport;

  const _DiagnosticsActionBar({
    required this.primaryBtnColor,
    required this.onCopyReport,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: () {
            final d = context.read<SystemDiagnosticsCubit>().state.diagnostics;
            final isOnline =
                context.read<NetworkCubit>().state is NetworkConnected;
            final report =
                d?.buildDiagnosticReport(isOnline: isOnline) ??
                'DANILORE ONE ERP | DB: PostgreSQL Supabase | Network: ${isOnline ? 'Online' : 'Offline'} | Estado: Verificando';
            onCopyReport(report);
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copiar reporte para soporte técnico'),
          style: FilledButton.styleFrom(
            backgroundColor: primaryBtnColor,
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
        BlocSelector<SystemDiagnosticsCubit, SystemDiagnosticsState, bool>(
          selector: (state) => state.isMeasuring,
          builder: (context, isMeasuring) {
            return OutlinedButton.icon(
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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
            );
          },
        ),
      ],
    );
  }
}
