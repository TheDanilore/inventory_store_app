import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/quick_create_customer_dialog.dart';

/// Barra de comando unificada superior del panel POS.
///
/// Fusiona en un solo strip compacto de 52px de altura:
/// 1. Título e indicador de Caja con contador dinámico de ítems en carrito.
/// 2. Selector/Pill interactivo de Cliente (con badges de puntos de lealtad).
/// 3. Botón de creación exprés de cliente (+ Nuevo / Alt+A).
/// 4. Botón de vaciado de caja (con confirmación modal).
///
/// La búsqueda de cliente se despliega como un Popover Flotante anclado (Zero Layout Shift)
/// en Desktop/Tablet y como un Modal BottomSheet nativo Apple HIG en Mobile.
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

  /// Nuevas propiedades de la barra de comando unificada
  final int cartItemCount;
  final VoidCallback? onClearCart;
  final bool isCartEmpty;
  final String title;
  final bool showCajaHeader;

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
    this.cartItemCount = 0,
    this.onClearCart,
    this.isCartEmpty = true,
    this.title = 'CAJA',
    this.showCajaHeader = true,
  });

  @override
  State<PosClientHeaderBar> createState() => PosClientHeaderBarState();
}

class PosClientHeaderBarState extends State<PosClientHeaderBar> {
  final _layerLink = LayerLink();
  final _overlayPortalCtrl = OverlayPortalController();
  final _searchFocusNode = FocusNode();
  final _searchFieldCtrl = TextEditingController();

  void openSearch() {
    _onClientPillTapped(context);
  }

  void closeSearch() {
    _closeDesktopSearch();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchFieldCtrl.dispose();
    super.dispose();
  }

  void _openDesktopSearch() {
    _searchFieldCtrl.clear();
    widget.onSearchChanged('');
    _overlayPortalCtrl.show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeDesktopSearch() {
    if (_overlayPortalCtrl.isShowing) {
      _searchFocusNode.unfocus();
      _overlayPortalCtrl.hide();
      _searchFieldCtrl.clear();
    }
  }

  void _onClientPillTapped(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      _openMobileClientPickerSheet(context);
    } else {
      if (_overlayPortalCtrl.isShowing) {
        _closeDesktopSearch();
      } else {
        _openDesktopSearch();
      }
    }
  }

  Future<void> _openCreateCustomerDialog([String? query]) async {
    _closeDesktopSearch();
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
    }
  }

  void _openMobileClientPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // iOS Drag Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Título y botón cerrar
                      Row(
                        children: [
                          const Icon(Icons.person_search_rounded, color: AppColors.teal, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Seleccionar Cliente',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(bottomSheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Input buscador
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          autofocus: true,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: const InputDecoration(
                            hintText: 'Buscar por nombre, DNI o teléfono…',
                            prefixIcon: Icon(Icons.search_rounded, size: 18),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) {
                            widget.onSearchChanged(val);
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Opción Cliente Varios
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(Icons.person_outline_rounded, size: 18, color: Colors.grey),
                        ),
                        title: const Text('Cliente Varios (Venta rápida)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('Venta genérica sin registrar datos', style: TextStyle(fontSize: 11.5)),
                        onTap: () {
                          widget.onClearClient();
                          Navigator.pop(bottomSheetCtx);
                        },
                      ),
                      const Divider(height: 1),
                      // Lista de resultados
                      Expanded(
                        child: widget.searching
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal))
                            : widget.matches.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.person_off_outlined, size: 36, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          const Text('No se encontraron clientes', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: widget.matches.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final c = widget.matches[idx];
                                      final name = c['full_name'] as String? ?? 'Cliente';
                                      final doc = c['document_number'] as String?;
                                      final wallet = (c['wallet_balance'] as num?)?.toInt() ?? 0;
                                      return ListTile(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                                          child: const Icon(Icons.person_rounded, size: 18, color: AppColors.teal),
                                        ),
                                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                        subtitle: Text(
                                          [
                                            if (doc != null && doc.isNotEmpty) 'Doc: $doc',
                                            if (widget.isLoyaltyEnabled && wallet > 0) '$wallet pts',
                                          ].join(' • '),
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                        ),
                                        onTap: () {
                                          widget.onClientTap(c);
                                          Navigator.pop(bottomSheetCtx);
                                        },
                                      );
                                    },
                                  ),
                      ),
                      // Botón Nuevo Cliente
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text('Crear Nuevo Cliente Express', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(bottomSheetCtx);
                              _openCreateCustomerDialog();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasClient = widget.selectedClientId != null;
    final clientName = widget.controller.text.trim();
    final displayName = hasClient
        ? (clientName.isNotEmpty ? clientName : 'Cliente Registrado')
        : (clientName.isNotEmpty ? clientName : 'Cliente Varios');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── TIER 1: TÍTULO CAJA + ACCIONES RÁPIDAS (Solo si showCajaHeader es true) ──
          if (widget.showCajaHeader) _buildTier1Header(),

          // ── TIER 2: SELECTOR DE CLIENTE (ANCHO COMPLETO) + NUEVO EXPRESS ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              widget.showCajaHeader ? 0 : 8,
              12,
              8,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stripWidth = constraints.maxWidth;
                return CompositedTransformTarget(
                  link: _layerLink,
                  child: OverlayPortal(
                    controller: _overlayPortalCtrl,
                    overlayChildBuilder: (overlayCtx) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _closeDesktopSearch,
                              child: const ColoredBox(color: Colors.transparent),
                            ),
                          ),
                          Positioned(
                            child: CompositedTransformFollower(
                              link: _layerLink,
                              showWhenUnlinked: false,
                              targetAnchor: Alignment.bottomLeft,
                              followerAnchor: Alignment.topLeft,
                              offset: const Offset(0, 6),
                              child: TapRegion(
                                onTapOutside: (_) => _closeDesktopSearch(),
                                child: _buildFloatingSearchCard(
                                  context,
                                  hasClient,
                                  stripWidth,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildClientSelectorCard(
                            context,
                            hasClient,
                            displayName,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickNewClientButton(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Tier 1: Fila compacta con título de Caja, contador de items y botón de vaciado rápido
  Widget _buildTier1Header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4.5),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              size: 15,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textPrimary,
            ),
          ),
          if (widget.cartItemCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.cartItemCount} ${widget.cartItemCount == 1 ? 'ítem' : 'ítems'}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tealDark,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (widget.onClearCart != null)
            Tooltip(
              message: 'Vaciar caja',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: widget.isCartEmpty ? null : widget.onClearCart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                          color: widget.isCartEmpty
                              ? Colors.grey.shade300
                              : AppColors.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Vaciar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.isCartEmpty
                                ? Colors.grey.shade300
                                : AppColors.error,
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
    );
  }

  /// Tier 2: Card de Cliente a Ancho Completo
  Widget _buildClientSelectorCard(
    BuildContext context,
    bool hasClient,
    String displayName,
  ) {
    return Material(
      color: hasClient
          ? AppColors.teal.withValues(alpha: 0.07)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _onClientPillTapped(context),
        hoverColor: AppColors.teal.withValues(alpha: 0.05),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasClient
                  ? AppColors.teal.withValues(alpha: 0.35)
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: hasClient
                      ? AppColors.teal.withValues(alpha: 0.15)
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasClient ? Icons.person_rounded : Icons.person_outline_rounded,
                  size: 14,
                  color: hasClient ? AppColors.tealDark : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasClient ? FontWeight.w700 : FontWeight.w600,
                        color: hasClient ? AppColors.tealDark : AppColors.textPrimary,
                      ),
                    ),
                    if (hasClient && widget.creditInfo != null && widget.isCredito)
                      Text(
                        'Crédito: S/ ${(widget.creditInfo!['credit_limit'] ?? 0)}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                          height: 1.1,
                        ),
                      )
                    else if (!hasClient)
                      const Text(
                        'Venta rápida • Clic o Alt+C',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),
              ),
              // Badge de puntos SOLO si el sistema está activo y cliente tiene saldo
              if (hasClient && widget.isLoyaltyEnabled && widget.saldoActualCliente > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade300, width: 0.8),
                  ),
                  child: Text(
                    '${widget.saldoActualCliente} pts',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              // Botón limpiar cliente si está asignado
              if (hasClient) ...[
                Tooltip(
                  message: 'Quitar cliente',
                  child: InkWell(
                    onTap: () {
                      widget.onClearClient();
                      _closeDesktopSearch();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.unfold_more_rounded,
                  size: 15,
                  color: Colors.grey.shade500,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Botón + Nuevo Cliente Express (Alt+A)
  Widget _buildQuickNewClientButton() {
    return Tooltip(
      message: 'Nuevo Cliente Express (Alt+A)',
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openCreateCustomerDialog(),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Nuevo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye el Popover Flotante que flota sobre la caja sin desbordar la pantalla.
  Widget _buildFloatingSearchCard(
    BuildContext context,
    bool hasClient,
    double cardWidth,
  ) {

    return SizedBox(
      width: cardWidth,
      child: Material(
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de búsqueda con auto-focus y tecla Esc
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        _closeDesktopSearch();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _searchFieldCtrl,
                      focusNode: _searchFocusNode,
                      onChanged: (val) {
                        widget.onSearchChanged(val);
                        setState(() {});
                      },
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, DNI o teléfono…',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 16,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchFieldCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 15),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () {
                                  _searchFieldCtrl.clear();
                                  widget.onSearchChanged('');
                                  setState(() {});
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 15),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              tooltip: 'Cerrar (Esc)',
                              onPressed: _closeDesktopSearch,
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Contenido scrolleable
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Opción: Cliente Varios (Venta rápida sin datos)
                      InkWell(
                        onTap: () {
                          widget.onClearClient();
                          _closeDesktopSearch();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  Icons.people_outline_rounded,
                                  size: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Cliente Varios',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Venta rápida sin comprobante con datos',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!hasClient)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: AppColors.teal,
                                ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(height: 1, color: AppColors.divider),

                      // Resultados o estado de búsqueda
                      if (widget.searching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.teal,
                              ),
                            ),
                          ),
                        )
                      else if (widget.matches.isNotEmpty)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.matches.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (context, index) {
                            final c = widget.matches[index];
                            final name = c['full_name'] as String? ?? 'Cliente';
                            final doc = c['document_number'] as String?;
                            final phone = c['phone'] as String?;
                            final wallet = (c['wallet_balance'] as num?)?.toInt() ?? 0;
                            final isSelected = c['id'] == widget.selectedClientId;

                            return InkWell(
                              onTap: () {
                                widget.onClientTap(c);
                                _closeDesktopSearch();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.teal
                                            : AppColors.teal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 16,
                                        color: isSelected ? Colors.white : AppColors.teal,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            [
                                              if (doc != null && doc.isNotEmpty) 'Doc: $doc',
                                              if (phone != null && phone.isNotEmpty) 'Tel: $phone',
                                              if (widget.isLoyaltyEnabled && wallet > 0) '$wallet pts',
                                            ].join(' • '),
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: AppColors.teal,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      else if (_searchFieldCtrl.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
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
                                  'No se encontró "${_searchFieldCtrl.text.trim()}".',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  final q = _searchFieldCtrl.text.trim();
                                  _openCreateCustomerDialog(q);
                                },
                                child: const Text('Crear', style: TextStyle(fontSize: 11.5)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Pie del popover con atajo y botón nuevo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Atajo: Alt+A para nuevo',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                    TextButton.icon(
                      onPressed: () => _openCreateCustomerDialog(),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text(
                        'Nuevo cliente',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
