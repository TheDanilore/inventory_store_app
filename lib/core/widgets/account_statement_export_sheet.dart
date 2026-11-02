import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/account_statement/services/account_statement_pdf_service.dart';
import 'package:inventory_store_app/core/widgets/account_statement/services/account_statement_share_service.dart';
import 'package:inventory_store_app/core/widgets/account_statement/statement_item_model.dart';
import 'package:inventory_store_app/core/widgets/account_statement/widgets/account_statement_action_buttons.dart';
import 'package:inventory_store_app/core/widgets/account_statement/widgets/account_statement_document_preview.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';

export 'package:inventory_store_app/core/widgets/account_statement/statement_item_model.dart'
    show StatementItem;

/// Panel adaptativo de comprobación y exportación de Estado de Cuenta (Cliente / Proveedor).
/// Arquitectura modular de alto rendimiento con generación de PDF en segundo plano y caché L1.
class AccountStatementExportSheet extends StatefulWidget {
  final String titularName;
  final bool isSupplier;
  final double currentBalance;
  final double totalCharged;
  final double totalPaid;
  final List<StatementItem> items;
  final String? phone;
  final String? currencySymbol;

  const AccountStatementExportSheet({
    super.key,
    required this.titularName,
    required this.isSupplier,
    required this.currentBalance,
    required this.totalCharged,
    required this.totalPaid,
    required this.items,
    this.phone,
    this.currencySymbol,
  });

  static Future<void> show(
    BuildContext context, {
    required String titularName,
    required bool isSupplier,
    required double currentBalance,
    required double totalCharged,
    required double totalPaid,
    required List<StatementItem> items,
    String? phone,
    String? currencySymbol,
  }) {
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 520,
      breakpoint: 900,
      barrierLabel: 'Cerrar estado de cuenta',
      builder:
          (_) => AccountStatementExportSheet(
            titularName: titularName,
            isSupplier: isSupplier,
            currentBalance: currentBalance,
            totalCharged: totalCharged,
            totalPaid: totalPaid,
            items: items,
            phone: phone,
            currencySymbol: currencySymbol,
          ),
    );
  }

  @override
  State<AccountStatementExportSheet> createState() =>
      _AccountStatementExportSheetState();
}

class _AccountStatementExportSheetState
    extends State<AccountStatementExportSheet> {
  final AccountStatementPdfService _pdfService = AccountStatementPdfService();
  bool _isProcessing = false;
  String? _processingLabel;

  String get _currencySymbol {
    if (widget.currencySymbol != null &&
        widget.currencySymbol!.trim().isNotEmpty) {
      return widget.currencySymbol!.trim();
    }
    try {
      return context.read<AppConfigCubit>().state.baseCurrency.symbol;
    } catch (_) {
      return 'S/';
    }
  }

  String get _shareText => AccountStatementShareService.buildStatementShareText(
    titularName: widget.titularName,
    isSupplier: widget.isSupplier,
    currencySymbol: _currencySymbol,
    currentBalance: widget.currentBalance,
    totalCharged: widget.totalCharged,
    totalPaid: widget.totalPaid,
    items: widget.items,
  );

  Future<void> _handlePrint() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Preparando impresión...';
    });

    try {
      final config = context.read<AppConfigCubit>();
      final bytes = await _pdfService.generatePdfBytes(
        businessName: config.businessName,
        businessTaxId: config.businessTaxId,
        businessAddress: config.businessAddress,
        titularName: widget.titularName,
        isSupplier: widget.isSupplier,
        currencySymbol: _currencySymbol,
        currentBalance: widget.currentBalance,
        totalCharged: widget.totalCharged,
        totalPaid: widget.totalPaid,
        items: widget.items,
      );

      await _pdfService.printStatement(
        bytes: bytes,
        titularName: widget.titularName,
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al enviar a imprimir: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleWhatsApp() async {
    final res = await AccountStatementShareService.shareViaWhatsApp(
      text: _shareText,
      phone: widget.phone,
    );
    if (!mounted) return;
    if (res == StatementShareResult.copiedToClipboard) {
      AppSnackbar.show(
        context,
        message: 'Resumen copiado para WhatsApp.',
        type: SnackbarType.info,
      );
    }
  }

  Future<void> _handleEmail() async {
    final config = context.read<AppConfigCubit>();
    final res = await AccountStatementShareService.shareViaEmail(
      text: _shareText,
      titularName: widget.titularName,
      businessName: config.businessName,
    );
    if (!mounted) return;
    if (res == StatementShareResult.copiedToClipboard) {
      AppSnackbar.show(
        context,
        message: 'Resumen copiado al portapapeles.',
        type: SnackbarType.info,
      );
    }
  }

  Future<void> _handleSavePdf() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Descargando PDF...';
    });

    try {
      final config = context.read<AppConfigCubit>();
      final bytes = await _pdfService.generatePdfBytes(
        businessName: config.businessName,
        businessTaxId: config.businessTaxId,
        businessAddress: config.businessAddress,
        titularName: widget.titularName,
        isSupplier: widget.isSupplier,
        currencySymbol: _currencySymbol,
        currentBalance: widget.currentBalance,
        totalCharged: widget.totalCharged,
        totalPaid: widget.totalPaid,
        items: widget.items,
      );

      await _pdfService.savePdfFile(
        bytes: bytes,
        titularName: widget.titularName,
      );

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Estado de Cuenta PDF descargado con éxito.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al guardar PDF: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleCopy() async {
    await AccountStatementShareService.copyToClipboard(_shareText);
    if (mounted) {
      AppSnackbar.show(
        context,
        message: 'Resumen copiado al portapapeles.',
        type: SnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailSheetFrame(
      title: 'Estado de Cuenta',
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              widget.isSupplier ? 'PROVEEDOR' : 'CLIENTE',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.titularName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: Color(0xFF2563EB),
          size: 20,
        ),
      ),
      bodyPadding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ACCIONES RÁPIDAS ──
          AccountStatementActionButtons(
            isProcessing: _isProcessing,
            processingLabel: _processingLabel,
            onPrint: _handlePrint,
            onWhatsApp: _handleWhatsApp,
            onEmail: _handleEmail,
            onSavePdf: _handleSavePdf,
            onCopy: _handleCopy,
          ),

          const SizedBox(height: 16),

          // ── VISTA PREVIA DEL DOCUMENTO ──
          AccountStatementDocumentPreview(
            titularName: widget.titularName,
            currencySymbol: _currencySymbol,
            currentBalance: widget.currentBalance,
            totalCharged: widget.totalCharged,
            totalPaid: widget.totalPaid,
            items: widget.items,
          ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
