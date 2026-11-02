import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/components/pos_caja_tier1_header.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/components/pos_client_mobile_picker_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/components/pos_client_search_popover.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/components/pos_client_selector_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/quick_create_customer_dialog.dart';

/// Barra de comando unificada superior del panel POS.
///
/// Refactorizada bajo principios de Clean Architecture y rendimiento:
/// - Desacoplamiento modular en componentes atómicos dedicados
/// - Virtualización de resultados en popover sin `shrinkWrap`
/// - Eliminación de duplicación de código entre plataformas
/// - Garantía Zero-Shimmer (Frame 0) en selección y búsquedas
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

  /// Propiedades de la barra de comando unificada
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

  void openSearch() => _onClientPillTapped(context);
  void closeSearch() => _closeDesktopSearch();

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
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      PosClientMobilePickerSheet.show(
        context: context,
        searching: widget.searching,
        matches: widget.matches,
        selectedClientId: widget.selectedClientId,
        isLoyaltyEnabled: widget.isLoyaltyEnabled,
        onSearchChanged: widget.onSearchChanged,
        onClearClient: widget.onClearClient,
        onClientTap: widget.onClientTap,
        onCreateCustomer: _openCreateCustomerDialog,
      );
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

  @override
  Widget build(BuildContext context) {
    final hasClient = widget.selectedClientId != null;
    final clientName = widget.controller.text.trim();
    final displayName =
        hasClient
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
          // ── TIER 1: TÍTULO CAJA + ACCIONES RÁPIDAS ──
          if (widget.showCajaHeader)
            PosCajaTier1Header(
              title: widget.title,
              cartItemCount: widget.cartItemCount,
              onClearCart: widget.onClearCart,
              isCartEmpty: widget.isCartEmpty,
            ),

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
                              child: const ColoredBox(
                                color: Colors.transparent,
                              ),
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
                                child: PosClientSearchPopover(
                                  cardWidth: stripWidth,
                                  hasClient: hasClient,
                                  selectedClientId: widget.selectedClientId,
                                  searchFieldCtrl: _searchFieldCtrl,
                                  searchFocusNode: _searchFocusNode,
                                  searching: widget.searching,
                                  matches: widget.matches,
                                  isLoyaltyEnabled: widget.isLoyaltyEnabled,
                                  onSearchChanged: (val) {
                                    widget.onSearchChanged(val);
                                    setState(() {});
                                  },
                                  onClearSearch: () {
                                    _searchFieldCtrl.clear();
                                    widget.onSearchChanged('');
                                    setState(() {});
                                  },
                                  onClose: _closeDesktopSearch,
                                  onClearClient: widget.onClearClient,
                                  onClientTap: widget.onClientTap,
                                  onCreateCustomer: _openCreateCustomerDialog,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    child: PosClientSelectorCard(
                      hasClient: hasClient,
                      displayName: displayName,
                      creditInfo: widget.creditInfo,
                      isCredito: widget.isCredito,
                      isLoyaltyEnabled: widget.isLoyaltyEnabled,
                      saldoActualCliente: widget.saldoActualCliente,
                      onTap: () => _onClientPillTapped(context),
                      onClearClient: () {
                        widget.onClearClient();
                        _closeDesktopSearch();
                      },
                      onNewClientTap: () => _openCreateCustomerDialog(),
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
}
