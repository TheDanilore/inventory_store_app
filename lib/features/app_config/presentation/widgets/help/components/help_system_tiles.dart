import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_text.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_ui_primitives.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Fila para atajos de teclado con keycaps estilizados.
class HelpShortcutRow extends StatelessWidget {
  final String keys;
  final String desc;

  const HelpShortcutRow(this.keys, this.desc, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    final alternatives = keys.split(' / ');
    return HelpCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: HelpText(
              desc,
              style: TextStyle(
                fontSize: 13,
                color: t.body,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          for (var a = 0; a < alternatives.length; a++) ...[
            if (a > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'o',
                  style: TextStyle(fontSize: 11, color: t.muted),
                ),
              ),
            ..._buildKeycaps(t, alternatives[a].split(' + ')),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildKeycaps(HelpThemeTokens t, List<String> parts) {
    return [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text('+', style: TextStyle(fontSize: 11, color: t.muted)),
          ),
        Container(
          constraints: const BoxConstraints(minWidth: 28),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: t.field,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.strongBorder),
            boxShadow: [
              BoxShadow(color: t.strongBorder, offset: const Offset(0, 1.5)),
            ],
          ),
          child: Text(
            parts[i],
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: t.title,
            ),
          ),
        ),
      ],
    ];
  }
}

/// Banner de estado del backend Supabase.
class HelpStatusBanner extends StatelessWidget {
  final bool reachable;

  const HelpStatusBanner({super.key, this.reachable = true});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    final color = reachable ? AppColors.success : AppColors.error;
    final title =
        reachable
            ? 'Servidor Supabase Cloud activo y sincronizado'
            : 'Sin conexión a Supabase o red inaccesible';
    final body =
        reachable
            ? 'Conexión segura con la nube PostgreSQL. Todos los datos, turnos y ventas están respaldados.'
            : 'No se pudo verificar la conexión. Revisa tu red o credenciales de Supabase.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow:
                  reachable
                      ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 0,
                          spreadRadius: 4,
                        ),
                      ]
                      : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HelpText(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.tone(color),
                  ),
                ),
                const SizedBox(height: 3),
                HelpText(
                  body,
                  style: TextStyle(fontSize: 13, color: t.body, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila para elementos de telemetría y diagnóstico.
class HelpDiagTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? dot;

  const HelpDiagTile({
    super.key,
    required this.label,
    required this.value,
    this.dot,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return HelpCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelpText(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: t.muted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: HelpText(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.title,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
