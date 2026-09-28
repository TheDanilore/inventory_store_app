import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/quick_create_customer_dialog.dart';

class PosClientHeaderBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final bool searching;
  final List<Map<String, dynamic>> matches;
  final String? selectedClientId;
  final ValueChanged<Map<String, dynamic>> onClientTap;
  final VoidCallback onClearClient;
  final int saldoActualCliente;
  final Map<String, dynamic>? creditInfo;
  final bool isCredito;
  final bool isLoyaltyEnabled;
  final VoidCallback? onNewClientCreated;

  const PosClientHeaderBar({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.searching,
    required this.matches,
    required this.selectedClientId,
    required this.onClientTap,
    required this.onClearClient,
    required this.saldoActualCliente,
    required this.creditInfo,
    required this.isCredito,
    required this.isLoyaltyEnabled,
    this.onNewClientCreated,
  });

  @override
  State<PosClientHeaderBar> createState() => _PosClientHeaderBarState();
}

class _PosClientHeaderBarState extends State<PosClientHeaderBar> {
  bool _isSearchExpanded = false;
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    setState(() => _isSearchExpanded = false);
  }

  Future<void> _openCreateCustomerDialog([String? query]) async {
    final customer = await QuickCreateCustomerDialog.show(
      context,
      initialQuery: query,
    );

    if (customer != null && mounted) {
      final posCubit = context.read<PosCubit>();
      posCubit.setClient(
        customer.id,
        customer.fullName,
        customer.walletBalance.toInt(),
      );
      posCubit.fetchClientCredit(customer.id);
      widget.controller.text = customer.fullName;
      widget.onNewClientCreated?.call();
      _closeSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasClient = widget.selectedClientId != null;
    final clientName = widget.controller.text.trim();
    final displayName = hasClient
        ? (clientName.isNotEmpty ? clientName : 'Cliente Registrado')
        : (clientName.isNotEmpty ? clientName : 'Cliente Varios');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: hasClient ? AppColors.teal.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: hasClient
              ? AppColors.teal.withValues(alpha: 0.35)
              : AppColors.border,
          width: hasClient ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── BARRA SUPERIOR PRINCIPAL ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Selector Principal o Toggle de Búsqueda
                Expanded(
                  child: InkWell(
                    onTap: _isSearchExpanded ? null : _openSearch,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: hasClient
                                  ? AppColors.teal
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              hasClient
                                  ? Icons.person_rounded
                                  : Icons.person_outline_rounded,
                              size: 19,
                              color: hasClient
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: hasClient
                                              ? AppColors.tealDark
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (hasClient &&
                                        widget.isLoyaltyEnabled &&
                                        widget.saldoActualCliente > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.amber.shade400,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          '${widget.saldoActualCliente} pts',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  hasClient
                                      ? 'Cliente registrado para venta'
                                      : 'Venta rápida (Toca para buscar)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasClient
                                        ? AppColors.teal.withValues(alpha: 0.8)
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!hasClient)
                            Icon(
                              _isSearchExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Colors.grey.shade500,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Botón Limpiar Selección (si hay cliente seleccionado)
                if (hasClient) ...[
                  Tooltip(
                    message: 'Quitar cliente (Venta Varios)',
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textMuted,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        widget.onClearClient();
                        _closeSearch();
                      },
                    ),
                  ),
                ],

                // Botón + Nuevo Cliente
                Tooltip(
                  message: 'Nuevo Cliente (Alt+A)',
                  child: Material(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _openCreateCustomerDialog(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Nuevo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── ZONA DE BÚSQUEDA DESPLEGABLE ──────────────────────────────────
          if (_isSearchExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _searchFocusNode,
                      onChanged: widget.onSearchChanged,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, DNI o teléfono…',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 17,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.controller.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  widget.controller.clear();
                                  widget.onSearchChanged('');
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                              tooltip: 'Cerrar buscador',
                              onPressed: _closeSearch,
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  if (widget.searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    )
                  else if (widget.matches.isNotEmpty) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: widget.matches.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (context, index) {
                          final c = widget.matches[index];
                          final name = c['full_name'] as String? ?? 'Cliente';
                          final doc = c['document_number'] as String?;
                          final phone = c['phone'] as String?;
                          final wallet =
                              (c['wallet_balance'] as num?)?.toInt() ?? 0;

                          return InkWell(
                            onTap: () {
                              widget.onClientTap(c);
                              _closeSearch();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          [
                                            if (doc != null && doc.isNotEmpty)
                                              'Doc: $doc',
                                            if (phone != null &&
                                                phone.isNotEmpty)
                                              'Tel: $phone',
                                            if (wallet > 0)
                                              '$wallet pts',
                                          ].join(' • '),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: AppColors.teal,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (widget.controller.text.trim().isNotEmpty) ...[
                    // No encontrado: Sugerencia de alta exprés
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 16,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No se encontró "${widget.controller.text.trim()}". ¿Registrarlo ahora?',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _openCreateCustomerDialog(
                              widget.controller.text.trim(),
                            ),
                            child: const Text(
                              'Crear',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
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
}
