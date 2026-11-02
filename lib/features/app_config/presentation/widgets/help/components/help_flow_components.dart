import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_text.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_ui_primitives.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Tarjeta de nivel jerárquico (Nivel 1 Tienda, Nivel 2 Caja, Nivel 3 Turno).
class HelpHierarchyCard extends StatelessWidget {
  final String badge;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  const HelpHierarchyCard({
    super.key,
    required this.badge,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return HelpCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HelpIconTile(icon: icon, color: color),
              const SizedBox(width: 10),
              HelpBadge(text: badge, color: color),
            ],
          ),
          const SizedBox(height: 14),
          HelpText(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.title,
            ),
          ),
          const SizedBox(height: 6),
          HelpText(
            desc,
            style: TextStyle(fontSize: 13, color: t.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Timeline vertical con conector entre pasos.
class HelpStepFlow extends StatelessWidget {
  final List<(String, String, String)> steps;
  final List<Color>? colors;

  const HelpStepFlow(this.steps, {super.key, this.colors});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return HelpCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              step: steps[i],
              last: i == steps.length - 1,
              color: colors != null ? colors![i] : t.primaryBtn,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final (String, String, String) step;
  final bool last;
  final Color color;

  const _StepRow({required this.step, required this.last, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  step.$1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: t.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HelpText(
                    step.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.title,
                    ),
                  ),
                  const SizedBox(height: 3),
                  HelpText(
                    step.$3,
                    style: TextStyle(fontSize: 13, color: t.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acordeón FAQ para preguntas frecuentes.
class HelpFaqAccordion extends StatelessWidget {
  final String question;
  final String answer;

  const HelpFaqAccordion(this.question, this.answer, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    final scope = HelpHighlightScope.maybeOf(context);
    final searching = (scope?.searchTokens.isNotEmpty) ?? false;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
        boxShadow: t.shadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('$question-$searching'),
          initiallyExpanded: searching,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(44, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: t.muted,
          collapsedIconColor: t.muted,
          title: Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 18, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child: HelpText(
                  question,
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
          children: [
            HelpText(
              answer,
              style: TextStyle(fontSize: 13, color: t.body, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta descriptiva de rol y permisos.
class HelpRoleCard extends StatelessWidget {
  final String role;
  final String code;
  final String desc;
  final Color color;
  final IconData icon;

  const HelpRoleCard({
    super.key,
    required this.role,
    required this.code,
    required this.desc,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return HelpCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelpIconTile(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    HelpText(
                      role,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.tone(color),
                      ),
                    ),
                    HelpMonoPill(text: code),
                  ],
                ),
                const SizedBox(height: 5),
                HelpText(
                  desc,
                  style: TextStyle(fontSize: 13, color: t.muted, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta descriptiva de tipo de comprobante.
class HelpDocTypeCard extends StatelessWidget {
  final String title;
  final String series;
  final String badge;
  final Color color;
  final String desc;
  final List<String> requirements;

  const HelpDocTypeCard({
    super.key,
    required this.title,
    required this.series,
    required this.badge,
    required this.color,
    required this.desc,
    required this.requirements,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return HelpCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HelpText(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.title,
                ),
              ),
              HelpBadge(text: badge, color: color),
              HelpMonoPill(text: series),
            ],
          ),
          const SizedBox(height: 8),
          HelpText(
            desc,
            style: TextStyle(fontSize: 13, color: t.muted, height: 1.55),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final r in requirements)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: t.tone(color),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: HelpText(
                        r,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: t.body,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tabla comparativa responsive.
class HelpComparisonTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const HelpComparisonTable({
    super.key,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 640) {
          return HelpCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: t.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HelpText(
                          rows[i][0],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.title,
                          ),
                        ),
                        for (var k = 1; k < rows[i].length; k++) ...[
                          const SizedBox(height: 10),
                          Text(
                            headers[k].toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: t.accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          HelpText(
                            rows[i][k],
                            style: TextStyle(
                              fontSize: 13,
                              color: t.body,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        Widget cell(String text, {bool header = false, bool first = false}) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: HelpText(
              text,
              style: TextStyle(
                fontSize: header ? 12.5 : 13,
                fontWeight: header || first ? FontWeight.w700 : FontWeight.w400,
                color: header || first ? t.title : t.body,
                height: 1.45,
              ),
            ),
          );
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
            boxShadow: t.shadow,
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(1.8),
              2: FlexColumnWidth(1.8),
            },
            border: TableBorder(horizontalInside: BorderSide(color: t.border)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: t.field),
                children: [for (final h in headers) cell(h, header: true)],
              ),
              for (final row in rows)
                TableRow(
                  children: [
                    for (var k = 0; k < row.length; k++)
                      cell(row[k], first: k == 0),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
