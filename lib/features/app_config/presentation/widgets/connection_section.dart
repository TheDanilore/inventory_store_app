// ─── SECCIÓN DE INFRAESTRUCTURA (SUPABASE MULTI-TENANT) ───────────────────────
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ConnectionSection extends StatelessWidget {
  final String supabaseUrl;
  final VoidCallback onResetPressed;

  const ConnectionSection({
    super.key,
    required this.supabaseUrl,
    required this.onResetPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = supabaseUrl.isNotEmpty && supabaseUrl != 'Desconocida';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  color:
                      isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Infraestructura',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color:
                      isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      isConnected
                          ? (isDark
                              ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                              : const Color(0xFFECFDF5))
                          : (isDark
                              ? const Color(0xFF1E293B)
                              : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            isConnected
                                ? const Color(0xFF10B981)
                                : (isDark
                                    ? const Color(0xFF64748B)
                                    : Colors.grey.shade500),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'Conectado' : 'Por defecto',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isConnected
                                ? (isDark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF065F46))
                                : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Servidor de Base de Datos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            supabaseUrl,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onResetPressed,
              icon: const Icon(Icons.sync_alt_rounded, size: 16),
              label: const Text('Cambiar Servidor (Multi-Tenant)'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
