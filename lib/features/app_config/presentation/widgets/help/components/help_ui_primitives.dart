import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_text.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

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
