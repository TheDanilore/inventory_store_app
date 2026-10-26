import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Scope reactivo para inyectar tokens de búsqueda y tokens de tema a todos los hijos.
class HelpHighlightScope extends InheritedWidget {
  final List<String> searchTokens;
  final HelpThemeTokens tokens;

  const HelpHighlightScope({
    super.key,
    required this.searchTokens,
    required this.tokens,
    required super.child,
  });

  static HelpHighlightScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HelpHighlightScope>();

  static HelpHighlightScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No HelpHighlightScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(HelpHighlightScope oldWidget) =>
      searchTokens != oldWidget.searchTokens ||
      tokens.isDark != oldWidget.tokens.isDark;
}

/// Widget de texto inteligente que resalta automáticamente las palabras que coinciden
/// con los tokens de búsqueda activos en [HelpHighlightScope].
class HelpText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const HelpText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  static String normalize(String s) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    var out = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scope = HelpHighlightScope.maybeOf(context);
    final tokens = scope?.searchTokens ?? const [];
    if (tokens.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final t = scope!.tokens;
    final baseStyle = style ?? TextStyle(fontSize: 13, color: t.body);
    final normalizedText = normalize(text);
    final spans = <TextSpan>[];
    var index = 0;

    while (index < text.length) {
      int? nextMatchIndex;
      String? matchedToken;
      for (final token in tokens) {
        final matchIndex = normalizedText.indexOf(token, index);
        if (matchIndex == -1) continue;
        if (nextMatchIndex == null || matchIndex < nextMatchIndex) {
          nextMatchIndex = matchIndex;
          matchedToken = token;
        } else if (matchIndex == nextMatchIndex && matchedToken != null) {
          if (token.length > matchedToken.length) {
            matchedToken = token;
          }
        }
      }
      if (nextMatchIndex == null || matchedToken == null) {
        spans.add(TextSpan(text: text.substring(index), style: baseStyle));
        break;
      }
      if (nextMatchIndex > index) {
        spans.add(
          TextSpan(
            text: text.substring(index, nextMatchIndex),
            style: baseStyle,
          ),
        );
        index = nextMatchIndex;
        continue;
      }
      final matchLength = matchedToken.length;
      if (index + matchLength <= text.length) {
        final matchText = text.substring(index, index + matchLength);
        spans.add(
          TextSpan(
            text: matchText,
            style: baseStyle.copyWith(
              backgroundColor: t.accent.withValues(
                alpha: t.isDark ? 0.22 : 0.16,
              ),
              color: t.title,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        index += matchLength;
      } else {
        spans.add(TextSpan(text: text.substring(index), style: baseStyle));
        break;
      }
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(children: spans),
    );
  }
}

/// Contenedor de tarjeta estándar para el Centro de Ayuda.
class HelpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const HelpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
        boxShadow: t.shadow,
      ),
      child: child,
    );
  }
}

/// Título y subtítulo de sección de ayuda.
class HelpSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const HelpSectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HelpText(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t.title,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          HelpText(
            subtitle!,
            style: TextStyle(fontSize: 13, color: t.muted, height: 1.4),
          ),
        ],
      ],
    );
  }
}

/// Icono en caja redondeada con fondo suave para categorización.
class HelpIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const HelpIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size * 0.5, color: t.tone(color)),
    );
  }
}

/// Insignia (badge) distintiva.
class HelpBadge extends StatelessWidget {
  final String text;
  final Color color;

  const HelpBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: t.tone(color),
        ),
      ),
    );
  }
}

/// Píldora de código monospace.
class HelpMonoPill extends StatelessWidget {
  final String text;

  const HelpMonoPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: t.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: t.muted,
        ),
      ),
    );
  }
}

/// Callout destacado con barra vertical de color.
class HelpCallout extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;
  final String? lead;

  const HelpCallout({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
    this.lead,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HelpIconTile(icon: icon, color: color, size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HelpText(
                              title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: t.tone(color),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            HelpText(
                              lead == null ? content : '$lead $content',
                              style: TextStyle(
                                fontSize: 13,
                                color: t.body,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Tile informativo con icono lateral.
class HelpInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const HelpInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    return HelpCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelpIconTile(icon: icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HelpText(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.title,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
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
