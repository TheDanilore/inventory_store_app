import 'package:flutter/material.dart';

/// Botón secundario de la cabecera: acceso permanente al ranking de clientes y sorteo.
class TopClientsHeaderButton extends StatelessWidget {
  final VoidCallback onPressed;

  const TopClientsHeaderButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Ranking de mejores clientes y sorteo',
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(
          Icons.emoji_events_rounded,
          size: 18,
          color: Color(0xFFF59E0B),
        ),
        label: const Text('Top clientes'),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Franja que aparece bajo la barra de filtros cuando la pestaña "Top VIP" está activa.
class TopVipBanner extends StatelessWidget {
  final VoidCallback onOpen;

  const TopVipBanner({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const amber = Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: isDark ? 0.12 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: amber.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tus clientes VIP por facturación',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Mira el podio completo y sortea un premio entre ellos.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.casino_rounded, size: 18),
              label: const Text('Ranking y sorteo'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
