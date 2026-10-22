import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_saver/file_saver.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';

class StatementItem {
  final DateTime? date;
  final bool isCharge;
  final double amount;
  final String? method;
  final String? notes;
  final String? user;

  const StatementItem({
    required this.date,
    required this.isCharge,
    required this.amount,
    this.method,
    this.notes,
    this.user,
  });

  factory StatementItem.fromCustomer(CreditMovementEntity m) {
    return StatementItem(
      date: m.createdAt,
      isCharge: m.movementType == 'CHARGE',
      amount: m.amount,
      method: m.paymentMethod,
      notes: m.notes,
      user: m.createdByName,
    );
  }

  factory StatementItem.fromSupplier(SupplierCreditMovementEntity m) {
    return StatementItem(
      date: m.createdAt,
      isCharge: m.isCharge,
      amount: m.amount,
      method: m.paymentMethod,
      notes: m.notes,
      user: m.createdByName,
    );
  }
}

/// Panel adaptativo de comprobación y exportación de Estado de Cuenta (Cliente / Proveedor).
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

  String get _statementShareText {
    final buffer = StringBuffer();
    final role = widget.isSupplier ? 'PROVEEDOR' : 'CLIENTE';
    buffer.writeln('📋 *ESTADO DE CUENTA ($role)*');
    buffer.writeln('👤 *Titular:* ${widget.titularName}');
    buffer.writeln(
      '📅 *Fecha:* ${DateFormat('dd/MM/yyyy HH:mm', 'es').format(DateTime.now())}',
    );
    buffer.writeln('--------------------------------');
    buffer.writeln(
      '💰 *Saldo Actual:* $_currencySymbol ${widget.currentBalance.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '📈 Total Cargos: $_currencySymbol ${widget.totalCharged.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '📉 Total Abonos: $_currencySymbol ${widget.totalPaid.toStringAsFixed(2)}',
    );
    buffer.writeln('--------------------------------');
    buffer.writeln('📝 *ÚLTIMOS MOVIMIENTOS:*');

    final displayItems = widget.items.take(15);
    for (final it in displayItems) {
      final date =
          it.date != null ? DateFormat('dd/MM/yy', 'es').format(it.date!) : '-';
      final type = it.isCharge ? 'CARGO' : 'ABONO';
      buffer.writeln(
        '• $date [$type]: $_currencySymbol ${it.amount.toStringAsFixed(2)} (${it.method ?? "N/A"})',
      );
    }
    if (widget.items.length > 15) {
      buffer.writeln('... y ${widget.items.length - 15} movimientos más.');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Comprobante emitido para control de créditos.');
    return buffer.toString();
  }

  Future<Uint8List> _generatePdfBytes() async {
    final config = context.read<AppConfigCubit>();
    final pdf = pw.Document();
    final nowStr = DateFormat('dd/MM/yyyy HH:mm', 'es').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return [
            // Cabecera institucional
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      config.businessName.isNotEmpty
                          ? config.businessName
                          : 'MI NEGOCIO',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (config.businessTaxId.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'RUC: ${config.businessTaxId}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    if (config.businessAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        config.businessAddress,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.blueGrey800,
                      width: 1.2,
                    ),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'ESTADO DE CUENTA',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        widget.isSupplier
                            ? 'CRÉDITO PROVEEDOR'
                            : 'CRÉDITO CLIENTE',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        nowStr,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Tarjeta de Beneficiario y Resumen de Saldos
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Titular: ${widget.titularName}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tipo: ${widget.isSupplier ? "Proveedor" : "Cliente"}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      _buildPdfKpi(
                        'Total Cargos',
                        '$_currencySymbol ${widget.totalCharged.toStringAsFixed(2)}',
                      ),
                      pw.SizedBox(width: 12),
                      _buildPdfKpi(
                        'Total Pagado',
                        '$_currencySymbol ${widget.totalPaid.toStringAsFixed(2)}',
                      ),
                      pw.SizedBox(width: 12),
                      _buildPdfKpi(
                        'Saldo Actual',
                        '$_currencySymbol ${widget.currentBalance.toStringAsFixed(2)}',
                        isHighlight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Tabla de Movimientos
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(2.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  children: [
                    _buildPdfCell('FECHA', isHeader: true),
                    _buildPdfCell(
                      'TIPO',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildPdfCell(
                      'MONTO',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                    _buildPdfCell('MÉTODO', isHeader: true),
                    _buildPdfCell('NOTAS', isHeader: true),
                  ],
                ),
                ...widget.items.map((m) {
                  final dateStr =
                      m.date != null
                          ? DateFormat('dd/MM/yyyy HH:mm', 'es').format(m.date!)
                          : '-';
                  return pw.TableRow(
                    children: [
                      _buildPdfCell(dateStr),
                      _buildPdfCell(
                        m.isCharge ? 'CARGO' : 'ABONO',
                        align: pw.TextAlign.center,
                      ),
                      _buildPdfCell(
                        '$_currencySymbol ${m.amount.toStringAsFixed(2)}',
                        align: pw.TextAlign.right,
                      ),
                      _buildPdfCell(m.method ?? '-'),
                      _buildPdfCell(m.notes ?? '-'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.Center(
              child: pw.Text(
                'Reporte de movimientos para uso administrativo y conciliación de créditos.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfKpi(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: isHighlight ? PdfColors.red800 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  Future<void> _handlePrint() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Preparando impresión...';
    });

    try {
      final bytes = await _generatePdfBytes();
      final cleanName = widget.titularName.replaceAll(' ', '_');
      await Printing.layoutPdf(
        name: 'Estado_Cuenta_$cleanName',
        onLayout: (_) async => bytes,
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
    final text = Uri.encodeComponent(_statementShareText);
    String cleanPhone = widget.phone ?? '';
    cleanPhone = cleanPhone.replaceAll(RegExp(r'\D'), '');

    final urlStr =
        cleanPhone.isNotEmpty
            ? 'https://wa.me/$cleanPhone?text=$text'
            : 'https://wa.me/?text=$text';

    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: _statementShareText));
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Resumen copiado para WhatsApp.',
            type: SnackbarType.info,
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _statementShareText));
    }
  }

  Future<void> _handleEmail() async {
    final config = context.read<AppConfigCubit>();
    final subject = Uri.encodeComponent(
      'Estado de Cuenta: ${widget.titularName} - ${config.businessName}',
    );
    final body = Uri.encodeComponent(_statementShareText);
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: _statementShareText));
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _statementShareText));
    }
  }

  Future<void> _handleSavePdf() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Descargando PDF...';
    });

    try {
      final bytes = await _generatePdfBytes();
      final cleanName = widget.titularName.replaceAll(' ', '_');
      await FileExportService.save(
        fileName: 'Estado_Cuenta_$cleanName',
        bytes: bytes,
        extension: 'pdf',
        mimeType: MimeType.pdf,
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
    await Clipboard.setData(ClipboardData(text: _statementShareText));
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
          _buildActionButtons(),

          const SizedBox(height: 16),

          // ── VISTA PREVIA DEL DOCUMENTO ──
          _buildDocumentPreview(),
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

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Botón Principal: IMPRIMIR
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _handlePrint,
              icon:
                  _isProcessing &&
                          _processingLabel?.contains('impresión') == true
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.print_rounded, size: 18),
              label: const Text(
                'IMPRIMIR ESTADO DE CUENTA',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Fila 1: WHATSAPP + CORREO
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _handleWhatsApp,
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: const Text(
                      'WHATSAPP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _handleEmail,
                    icon: const Icon(Icons.mail_rounded, size: 16),
                    label: const Text(
                      'CORREO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Fila 2: GUARDAR PDF + COPIAR TEXTO
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : _handleSavePdf,
                    icon:
                        _isProcessing &&
                                _processingLabel?.contains('PDF') == true
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                            ),
                    label: const Text(
                      'GUARDAR PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _handleCopy,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'COPIAR TEXTO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF475569),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview() {
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
                      widget.titularName,
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
                  '$_currencySymbol ${widget.currentBalance.toStringAsFixed(2)}',
                  isDebt: widget.currentBalance > 0,
                ),
                Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                _kpiCol(
                  'Cargos',
                  '$_currencySymbol ${widget.totalCharged.toStringAsFixed(2)}',
                ),
                Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                _kpiCol(
                  'Abonos',
                  '$_currencySymbol ${widget.totalPaid.toStringAsFixed(2)}',
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
                '${widget.items.length} total',
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
                if (widget.items.isEmpty)
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
                  ...widget.items.take(15).map((it) {
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
                            '$_currencySymbol ${it.amount.toStringAsFixed(2)}',
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
