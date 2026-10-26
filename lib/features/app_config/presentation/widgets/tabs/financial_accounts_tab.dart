import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/financial/domain/utils/financial_brand_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_state.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/account_form_sheet.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_scroll_content.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_section_card.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_tiles.dart';

class FinancialAccountsTab extends StatefulWidget {
  final bool isDark;

  const FinancialAccountsTab({super.key, required this.isDark});

  @override
  State<FinancialAccountsTab> createState() => _FinancialAccountsTabState();
}

class _FinancialAccountsTabState extends State<FinancialAccountsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    return BlocProvider.value(
      value: sl<FinancialAccountsCubit>()..fetchAccounts(),
      child: Builder(
        builder: (fContext) {
          return BlocConsumer<FinancialAccountsCubit, FinancialAccountsState>(
            listener: (context, state) {
              if (state is FinancialAccountSaveError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.danger,
                  ),
                );
              } else if (state is FinancialAccountSaved) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cuenta financiera guardada correctamente.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            builder: (context, state) {
              List<FinancialAccountEntity> accounts = [];
              bool isLoading = state is FinancialAccountsLoading;

              if (state is FinancialAccountsLoaded) {
                accounts = state.accounts;
              } else if (state is FinancialAccountSaving) {
                accounts = state.previousAccounts;
              } else if (state is FinancialAccountSaved) {
                accounts = state.accounts;
              } else if (state is FinancialAccountSaveError) {
                accounts = state.previousAccounts;
              }

              final activeAccounts = accounts.where((a) => a.isActive).toList();
              final totalPenBalance = activeAccounts
                  .where((a) => a.currencyCode.toUpperCase() == 'PEN')
                  .fold<double>(0.0, (sum, a) => sum + a.balance);
              final totalUsdBalance = activeAccounts
                  .where((a) => a.currencyCode.toUpperCase() == 'USD')
                  .fold<double>(0.0, (sum, a) => sum + a.balance);

              return SettingsScrollContent(
                isDark: isDark,
                children: [
                  // ── Sección 1: Cuentas y Cajas Registradas ────────────────
                  SettingsSectionCard(
                    isDark: isDark,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Cuentas Financieras & Cajas Receptoras',
                    subtitle:
                        'Administra las cuentas bancarias, billeteras móviles y cajas de cobro para el POS y compras',
                    action: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.go('/financial-accounts'),
                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                          label: const Text(
                            'Ver Tesorería',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            backgroundColor: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.08),
                            side: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            final saved = await AccountFormSheet.show(context);
                            if (saved == true && context.mounted) {
                              context
                                  .read<FinancialAccountsCubit>()
                                  .fetchAccounts();
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('Nueva Cuenta'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      // Bento KPIs de Tesorería (Responsivo)
                      LayoutBuilder(
                        builder: (context, kpiConstraints) {
                          final isNarrow = kpiConstraints.maxWidth < 460;
                          final kpiCards = [
                            _buildBentoKpiCard(
                              context,
                              isDark: isDark,
                              label: 'Cuentas Activas',
                              value:
                                  '${activeAccounts.length} / ${accounts.length}',
                              icon: Icons.account_balance_rounded,
                              color: const Color(0xFF2563EB),
                            ),
                            _buildBentoKpiCard(
                              context,
                              isDark: isDark,
                              label: 'Saldo Total Soles',
                              value:
                                  'S/ ${NumberFormat('#,##0.00', 'es_PE').format(totalPenBalance)}',
                              icon: Icons.monetization_on_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            if (totalUsdBalance > 0)
                              _buildBentoKpiCard(
                                context,
                                isDark: isDark,
                                label: 'Saldo Total Dólares',
                                value:
                                    '\$ ${NumberFormat('#,##0.00', 'en_US').format(totalUsdBalance)}',
                                icon: Icons.currency_exchange_rounded,
                                color: const Color(0xFF8B5CF6),
                              ),
                          ];

                          if (isNarrow) {
                            return Column(
                              children: [
                                for (int i = 0; i < kpiCards.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  kpiCards[i],
                                ],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              for (int i = 0; i < kpiCards.length; i++) ...[
                                if (i > 0) const SizedBox(width: 10),
                                Expanded(child: kpiCards[i]),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Lista de Cuentas Reales
                      if (isLoading && accounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        )
                      else if (accounts.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 32,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkSurfaceElevated
                                    : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppColors.darkBorderSubtle
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 40,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay cuentas financieras configuradas',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? AppColors.darkTextPrimary
                                            : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Crea tu primera caja física, cuenta bancaria (BCP, BBVA) o billetera móvil (Yape/Plin).',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color:
                                        isDark
                                            ? AppColors.darkTextSecondary
                                            : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () async {
                                    final saved = await AccountFormSheet.show(
                                      context,
                                    );
                                    if (saved == true && context.mounted) {
                                      context
                                          .read<FinancialAccountsCubit>()
                                          .fetchAccounts();
                                    }
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Crear Primera Cuenta'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (int i = 0; i < accounts.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _buildFinancialAccountRowItem(
                                context,
                                account: accounts[i],
                                isDark: isDark,
                                onEdit: () async {
                                  final saved = await AccountFormSheet.show(
                                    context,
                                    account: accounts[i],
                                  );
                                  if (saved == true && context.mounted) {
                                    context
                                        .read<FinancialAccountsCubit>()
                                        .fetchAccounts();
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Sección: Modalidad de Control de Cajas Físicas ──────────
                  BlocBuilder<AppConfigCubit, AppConfigState>(
                    builder: (context, configState) {
                      final currentMode =
                          configState.businessInfo?.cashRegisterMode ??
                          'COUNTER';
                      final isCounter = currentMode != 'INDIVIDUAL';

                      return SettingsSectionCard(
                        isDark: isDark,
                        icon: Icons.tune_rounded,
                        title: 'Modalidad de Caja Física (POS)',
                        subtitle:
                            'Define cómo operan los cajeros las cajas registradoras de cada sucursal',
                        children: [
                          LayoutBuilder(
                            builder: (context, boxConstraints) {
                              final isStacked = boxConstraints.maxWidth < 540;

                              final option1 = InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap:
                                    isCounter
                                        ? null
                                        : () async {
                                          final ok = await context
                                              .read<AppConfigCubit>()
                                              .updateCashRegisterMode(
                                                'COUNTER',
                                              );
                                          if (ok && context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Modalidad cambiada a: Caja por Mostrador / Estación de Cobro.',
                                                ),
                                                backgroundColor: Color(
                                                  0xFF10B981,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        isCounter
                                            ? (isDark
                                                ? AppColors.tealDark.withValues(
                                                  alpha: 0.15,
                                                )
                                                : AppColors.teal.withValues(
                                                  alpha: 0.08,
                                                ))
                                            : (isDark
                                                ? AppColors.darkSurfaceElevated
                                                : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isCounter
                                              ? AppColors.teal
                                              : (isDark
                                                  ? AppColors.darkBorder
                                                  : const Color(0xFFE2E8F0)),
                                      width: isCounter ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.storefront_rounded,
                                            size: 20,
                                            color:
                                                isCounter
                                                    ? AppColors.teal
                                                    : (isDark
                                                        ? AppColors
                                                            .darkTextSecondary
                                                        : const Color(
                                                          0xFF64748B,
                                                        )),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Caja por Mostrador / Estación (Recomendado)',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    isCounter
                                                        ? (isDark
                                                            ? Colors.white
                                                            : const Color(
                                                              0xFF0F172A,
                                                            ))
                                                        : (isDark
                                                            ? AppColors
                                                                .darkTextSecondary
                                                            : const Color(
                                                              0xFF475569,
                                                            )),
                                              ),
                                            ),
                                          ),
                                          if (isCounter)
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 18,
                                              color: AppColors.teal,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Cada estación o punto físico de cobro (ej. Caja 1, Caja 2) tiene su propio cajón y arqueo independiente. Múltiples cajas permitidas por tienda con turnos rotativos.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.35,
                                          color:
                                              isDark
                                                  ? AppColors.darkTextSecondary
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              final option2 = InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap:
                                    !isCounter
                                        ? null
                                        : () async {
                                          final ok = await context
                                              .read<AppConfigCubit>()
                                              .updateCashRegisterMode(
                                                'INDIVIDUAL',
                                              );
                                          if (ok && context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Modalidad cambiada a: Caja por Cajero Individual.',
                                                ),
                                                backgroundColor: Color(
                                                  0xFF10B981,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        !isCounter
                                            ? (isDark
                                                ? AppColors.tealDark.withValues(
                                                  alpha: 0.15,
                                                )
                                                : AppColors.teal.withValues(
                                                  alpha: 0.08,
                                                ))
                                            : (isDark
                                                ? AppColors.darkSurfaceElevated
                                                : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          !isCounter
                                              ? AppColors.teal
                                              : (isDark
                                                  ? AppColors.darkBorder
                                                  : const Color(0xFFE2E8F0)),
                                      width: !isCounter ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_rounded,
                                            size: 20,
                                            color:
                                                !isCounter
                                                    ? AppColors.teal
                                                    : (isDark
                                                        ? AppColors
                                                            .darkTextSecondary
                                                        : const Color(
                                                          0xFF64748B,
                                                        )),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Caja por Cajero Individual',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    !isCounter
                                                        ? (isDark
                                                            ? Colors.white
                                                            : const Color(
                                                              0xFF0F172A,
                                                            ))
                                                        : (isDark
                                                            ? AppColors
                                                                .darkTextSecondary
                                                            : const Color(
                                                              0xFF475569,
                                                            )),
                                              ),
                                            ),
                                          ),
                                          if (!isCounter)
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 18,
                                              color: AppColors.teal,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Cada cajero porta su propio dinero de forma personal (tipo riñonera o canguro). Ideal para mozos de restaurante o repartidores independientes.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.35,
                                          color:
                                              isDark
                                                  ? AppColors.darkTextSecondary
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              if (isStacked) {
                                return Column(
                                  children: [
                                    option1,
                                    const SizedBox(height: 10),
                                    option2,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: option1),
                                  const SizedBox(width: 12),
                                  Expanded(child: option2),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Sección 2: Configuración de Moneda y Parámetros Contables ─
                  SettingsSectionCard(
                    isDark: isDark,
                    icon: Icons.currency_exchange_rounded,
                    title: 'Parámetros Operacionales & Métodos de Pago',
                    subtitle:
                        'Directrices de cobro para el Punto de Venta (POS) y conciliación contable',
                    children: [
                      SettingsInfoTile(
                        isDark: isDark,
                        icon: Icons.payments_rounded,
                        title: 'Métodos de Pago Habilitados en Caja',
                        value:
                            accounts.isEmpty
                                ? 'Pendiente de registrar cuentas'
                                : accounts
                                        .map((a) => a.name)
                                        .take(5)
                                        .join(' · ') +
                                    (accounts.length > 5 ? ' y más...' : ''),
                        badge: '${accounts.length} Cuentas',
                        badgeColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 10),
                      SettingsInfoTile(
                        isDark: isDark,
                        icon: Icons.monetization_on_outlined,
                        title: 'Moneda Base Predeterminada',
                        value:
                            'Soles Peruanos (PEN - S/) con soporte Multimoneda',
                        badge: 'PEN',
                        badgeColor: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 10),
                      SettingsInfoTile(
                        isDark: isDark,
                        icon: Icons.point_of_sale_rounded,
                        title: 'Control de Turnos de Caja (Shifts)',
                        value:
                            'Apertura con saldo inicial, registro de ingresos/egresos y arqueo ciego al cierre.',
                        badge: 'Activo',
                        badgeColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

Widget _buildFinancialAccountRowItem(
  BuildContext context, {
  required FinancialAccountEntity account,
  required bool isDark,
  required VoidCallback onEdit,
}) {
  final currencySymbol = FinancialBrandHelper.formatCurrencySymbol(
    account.currencyCode,
  );
  final isPen = account.currencyCode.toUpperCase() == 'PEN';
  final formattedBalance =
      '$currencySymbol ${NumberFormat('#,##0.00', isPen ? 'es_PE' : 'en_US').format(account.balance)}';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Row(
      children: [
        // Logo / Avatar de la marca financiera
        FinancialBrandHelper.buildBrandBadge(
          name: account.name,
          type: account.type,
          size: 38,
        ),
        const SizedBox(width: 14),

        // Detalles de la cuenta
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      account.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Moneda: ${account.currencyCode}',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '·',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          account.isActive
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : const Color(0xFF64748B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      account.isActive ? 'ACTIVA' : 'INACTIVA',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color:
                            account.isActive
                                ? const Color(0xFF10B981)
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Saldo de la Cuenta
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formattedBalance,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Saldo Contable',
              style: TextStyle(
                fontSize: 10,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),

        // Botón Editar
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Editar cuenta',
          visualDensity: VisualDensity.compact,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
          onPressed: onEdit,
        ),
      ],
    ),
  );
}

Widget _buildBentoKpiCard(
  BuildContext context, {
  required bool isDark,
  required String label,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
