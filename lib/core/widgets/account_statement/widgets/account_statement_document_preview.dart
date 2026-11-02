import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/account_statement/statement_item_model.dart';

/// Previsualización gráfica en pantalla del comprobante de Estado de Cuenta
class AccountStatementDocumentPreview extends StatelessWidget {
  final String titularName;
  final String currencySymbol;
  final double currentBalance;
  final double totalCharged;
  final double totalPaid;
  final List<StatementItem> items;

  const AccountStatementDocumentPreview({
    super.key,
    required this.titularName,
    required this.currencySymbol,
    required this.currentBalance,
    required this.totalCharged,
    required this.totalPaid,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera Documento
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTADO DE CUENTA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      titularName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('dd/MM/yyyy', 'es').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Resumen de Saldos
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _kpiCol(
                  'Saldo Actual',
                  '$currencySymbol ${currentBalance.toStringAsFixed(2)}',
                  isDebt: currentBalance > 0,
                ),
                Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                _kpiCol(
                  'Cargos',
                  '$currencySymbol ${totalCharged.toStringAsFixed(2)}',
                ),
                Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                _kpiCol(
                  'Abonos',
                  '$currencySymbol ${totalPaid.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Movimientos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MOVIMIENTOS REGISTRADOS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${items.length} total',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'FECHA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 55,
                        child: Text(
                          'TIPO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'MÉTODO / NOTA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'MONTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No hay movimientos para mostrar.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...items.take(15).map((it) {
                    final dateStr =
                        it.date != null
                            ? DateFormat('dd/MM/yy', 'es').format(it.date!)
                            : '-';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 55,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    it.isCharge
                                        ? const Color(0xFFFEF2F2)
                                        : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                it.isCharge ? 'CARGO' : 'ABONO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      it.isCharge
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                it.notes?.isNotEmpty == true
                                    ? it.notes!
                                    : (it.method ?? '-'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '$currencySymbol ${it.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  it.isCharge
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCol(String label, String value, {bool isDebt = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: isDebt ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
