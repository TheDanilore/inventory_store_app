import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/currency_entity.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

class CurrenciesSettingsTab extends StatefulWidget {
  final bool isDark;

  const CurrenciesSettingsTab({super.key, required this.isDark});

  @override
  State<CurrenciesSettingsTab> createState() => _CurrenciesSettingsTabState();
}

class _CurrenciesSettingsTabState extends State<CurrenciesSettingsTab> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<AppConfigCubit>();
    if (cubit.state.currencies.isEmpty) {
      cubit.loadCurrencies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.currentUser;
    final canEdit = user?.hasPermission('settings.edit') ?? false;

    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, state) {
        final currencies = state.currencies;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Banner de Garantía de Inmutabilidad Histórica y Kárdex
            _buildInfoBanner(widget.isDark),
            const SizedBox(height: 16),

            // Encabezado con acción de refrescar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monedas del Sistema ERP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color:
                            widget.isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Configura tipos de cambio sugeridos y estado de divisas',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            widget.isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed:
                      () => context.read<AppConfigCubit>().loadCurrencies(
                        force: true,
                      ),
                  tooltip: 'Refrescar monedas',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (currencies.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        widget.isDark
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF2563EB),
                  ),
                ),
              )
            else
              ...currencies.map((currency) {
                return _buildCurrencyCard(
                  context,
                  currency: currency,
                  isDark: widget.isDark,
                  canEdit: canEdit,
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildInfoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF16A34A),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inmutabilidad Histórica Garantizada',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'La moneda base del ERP es el Sol (PEN). Toda compra, venta y movimiento registra y congela el tipo de cambio del momento. Si actualizas el tipo de cambio hoy, las operaciones pasadas NO se alteran y el Kárdex valorizado permanece 100% íntegro.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyCard(
    BuildContext context, {
    required CurrencyEntity currency,
    required bool isDark,
    required bool canEdit,
  }) {
    final isBase = currency.isBase;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isBase
                  ? const Color(0xFF10B981)
                  : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          width: isBase ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícono de divisa
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isBase
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : (currency.code == 'USD'
                            ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                            : [
                              const Color(0xFF8B5CF6),
                              const Color(0xFF6D28D9),
                            ]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                currency.symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Datos de la moneda
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      currency.code,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color:
                            isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isBase)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MONEDA BASE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  currency.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBase
                      ? 'T.C. Referencial: 1.0000 (Patrón)'
                      : '1 ${currency.code} = S/ ${currency.exchangeRate.toStringAsFixed(4)} (Sugerido)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isBase
                            ? const Color(0xFF10B981)
                            : (isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),

          // Toggle Activo
          if (!isBase)
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: currency.isActive,
                activeThumbColor: const Color(0xFF10B981),
                onChanged:
                    canEdit
                        ? (val) {
                          context.read<AppConfigCubit>().toggleCurrencyActive(
                            currency.id,
                            val,
                          );
                        }
                        : null,
              ),
            ),

          // Botón Editar Tipo de Cambio
          if (!isBase && canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 19),
              tooltip: 'Editar tipo de cambio',
              onPressed: () => _showEditDialog(context, currency, isDark),
            ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    CurrencyEntity currency,
    bool isDark,
  ) {
    final rateCtrl = TextEditingController(
      text: currency.exchangeRate.toStringAsFixed(4),
    );
    final nameCtrl = TextEditingController(text: currency.name);
    final symbolCtrl = TextEditingController(text: currency.symbol);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.currency_exchange_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Editar ${currency.code}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nombre descriptivo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Símbolo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: symbolCtrl,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'T.C. Sugerido (S/)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              prefixText: 'S/ ',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💡 Nota: Al crear una compra o venta podrás editar el tipo de cambio pactado en ese instante específico.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final newRate =
                    double.tryParse(rateCtrl.text.replaceAll(',', '.')) ??
                    currency.exchangeRate;
                final newName = nameCtrl.text.trim();
                final newSymbol = symbolCtrl.text.trim();

                if (newRate <= 0) {
                  AppSnackbar.show(
                    context,
                    message: 'El tipo de cambio debe ser mayor a 0',
                    type: SnackbarType.warning,
                  );
                  return;
                }

                final updated = currency.copyWith(
                  name: newName.isNotEmpty ? newName : currency.name,
                  symbol: newSymbol.isNotEmpty ? newSymbol : currency.symbol,
                  exchangeRate: newRate,
                );

                Navigator.pop(dialogCtx);
                final ok = await context.read<AppConfigCubit>().updateCurrency(
                  updated,
                );
                if (ok && context.mounted) {
                  AppSnackbar.show(
                    context,
                    message: 'Tipo de cambio de ${currency.code} actualizado.',
                    type: SnackbarType.success,
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
