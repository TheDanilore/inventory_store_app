import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/financial/domain/entities/account_movement_entity.dart';

class MovementsDesktopTable extends StatelessWidget {
  final List<AccountMovementEntity> movements;
  final ScrollController scrollController;

  const MovementsDesktopTable({
    super.key,
    required this.movements,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Cabecera fija de la tabla
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      'FECHA Y HORA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'DESCRIPCIÓN / MOTIVO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: Text(
                      'CUENTA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      'TIPO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      'REGISTRADO POR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      'MONTO (S/)',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filas
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: movements.length,
                separatorBuilder:
                    (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                itemBuilder: (context, index) {
                  return _DesktopMovementRow(movement: movements[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopMovementRow extends StatefulWidget {
  final AccountMovementEntity movement;
  const _DesktopMovementRow({required this.movement});

  @override
  State<_DesktopMovementRow> createState() => _DesktopMovementRowState();
}

class _DesktopMovementRowState extends State<_DesktopMovementRow> {
  bool _isHovered = false;
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');
  static final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');

  @override
  Widget build(BuildContext context) {
    final m = widget.movement;
    final isIncome = m.movementType == 'INCOME';
    final isExpense = m.movementType == 'EXPENSE';

    final Color badgeBg =
        isIncome
            ? AppColors.teal.withValues(alpha: 0.1)
            : (isExpense
                ? AppColors.danger.withValues(alpha: 0.1)
                : AppColors.info.withValues(alpha: 0.1));
    final Color badgeColor =
        isIncome
            ? AppColors.tealDark
            : (isExpense ? AppColors.dangerDark : AppColors.info);
    final String badgeLabel =
        isIncome ? 'Ingreso' : (isExpense ? 'Egreso' : 'Transfer.');

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Fecha y hora
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _dateFormat.format(m.createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Descripción
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    m.description,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Cuenta
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 13,
                      color: AppColors.tealDark,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        m.accountName ?? 'Sin cuenta',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Tipo badge
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ),
              ),
              // Operador
              SizedBox(
                width: 120,
                child: Text(
                  m.createdByName?.split(' ').first ?? 'Sistema',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Monto
              SizedBox(
                width: 130,
                child: Builder(
                  builder: (context) {
                    final isZero = m.amount == 0.0;
                    final formattedAmount = _currencyFormat.format(
                      m.amount.abs(),
                    );
                    final label =
                        isZero
                            ? 'S/ 0.00'
                            : '${isIncome ? '+' : '-'} S/ $formattedAmount';
                    final textColor =
                        isZero
                            ? AppColors.textSecondary
                            : (isIncome
                                ? AppColors.tealDark
                                : AppColors.danger);

                    return Text(
                      label,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
