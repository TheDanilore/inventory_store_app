import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio centralizado de configuración y utilidades para Impresoras Térmicas POS.
class PosPrinterSettingsService {
  static const String _keyPaperWidth = 'pos_printer_paper_width';
  static const String _keyAutoPrint = 'pos_printer_auto_print';
  static const String _keyCopies = 'pos_printer_copies';
  static const String _keyShowLogo = 'pos_printer_show_logo';
  static const String _keyFooterMessage = 'pos_printer_footer_message';

  static final ValueNotifier<String> paperWidthNotifier = ValueNotifier<String>(
    '80mm',
  );
  static final ValueNotifier<bool> autoPrintNotifier = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<int> copiesNotifier = ValueNotifier<int>(1);
  static final ValueNotifier<bool> showLogoNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<String>
  footerMessageNotifier = ValueNotifier<String>(
    '¡Gracias por su compra! Conserve este comprobante para cualquier reclamo o garantía.',
  );

  static bool _initialized = false;

  /// Carga la configuración inicial desde SharedPreferences.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      paperWidthNotifier.value = prefs.getString(_keyPaperWidth) ?? '80mm';
      autoPrintNotifier.value = prefs.getBool(_keyAutoPrint) ?? false;
      copiesNotifier.value = prefs.getInt(_keyCopies) ?? 1;
      showLogoNotifier.value = prefs.getBool(_keyShowLogo) ?? true;
      footerMessageNotifier.value =
          prefs.getString(_keyFooterMessage) ??
          '¡Gracias por su compra! Conserve este comprobante para cualquier reclamo o garantía.';
    } catch (_) {}
  }

  static Future<void> setPaperWidth(String width) async {
    paperWidthNotifier.value = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperWidth, width);
  }

  static Future<void> setAutoPrint(bool value) async {
    autoPrintNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPrint, value);
  }

  static Future<void> setCopies(int copies) async {
    copiesNotifier.value = copies;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCopies, copies);
  }

  static Future<void> setShowLogo(bool value) async {
    showLogoNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowLogo, value);
  }

  static Future<void> setFooterMessage(String message) async {
    footerMessageNotifier.value = message;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFooterMessage, message);
  }

  /// Genera e imprime un ticket térmico de prueba para calibrar la impresora
  static Future<bool> printTestTicket({
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    try {
      final is58 = paperWidthNotifier.value == '58mm';
      final pageFormat = is58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
      final pdf = pw.Document();

      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
      final footer = footerMessageNotifier.value;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.symmetric(
            horizontal: is58 ? 6 : 12,
            vertical: 10,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Cabecera
                pw.Center(
                  child: pw.Text(
                    businessName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: is58 ? 12 : 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'RUC: $taxId',
                    style: pw.TextStyle(fontSize: is58 ? 8 : 9),
                  ),
                ),
                if (address.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.Text(
                      address,
                      style: pw.TextStyle(fontSize: is58 ? 7.5 : 8.5),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.Text(
                      'Tel: $phone',
                      style: pw.TextStyle(fontSize: is58 ? 7.5 : 8.5),
                    ),
                  ),
                ],
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8),
                pw.Center(
                  child: pw.Text(
                    '*** TICKET DE PRUEBA POS ***',
                    style: pw.TextStyle(
                      fontSize: is58 ? 9 : 10.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'Formato: ${is58 ? "58 mm (Rollo compacto)" : "80 mm (Estándar POS)"}',
                    style: pw.TextStyle(fontSize: is58 ? 7.5 : 8.5),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    dateStr,
                    style: pw.TextStyle(fontSize: is58 ? 7.5 : 8),
                  ),
                ),
                pw.Divider(thickness: 0.8),
                pw.SizedBox(height: 4),

                // Lista de prueba
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'CANT / DESCRIPCIÓN',
                      style: pw.TextStyle(
                        fontSize: is58 ? 7 : 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: is58 ? 7 : 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                _buildTestItem(
                  qty: '1',
                  desc: 'Artículo de Prueba 01',
                  price: 'S/ 25.00',
                  is58: is58,
                ),
                _buildTestItem(
                  qty: '2',
                  desc: 'Servicio Demo Sistema',
                  price: 'S/ 30.00',
                  is58: is58,
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8),

                // Totales
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'SUBTOTAL:',
                      style: pw.TextStyle(fontSize: is58 ? 7.5 : 8.5),
                    ),
                    pw.Text(
                      'S/ 46.61',
                      style: pw.TextStyle(fontSize: is58 ? 7.5 : 8.5),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'IGV (18%):',
                      style: pw.TextStyle(fontSize: is58 ? 7.5 : 8.5),
                    ),
                    pw.Text(
                      'S/ 8.39',
                      style: pw.TextStyle(fontSize: is58 ? 7.5 : 8.5),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL VENTA:',
                      style: pw.TextStyle(
                        fontSize: is58 ? 9 : 10.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'S/ 55.00',
                      style: pw.TextStyle(
                        fontSize: is58 ? 9 : 10.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.8),
                pw.SizedBox(height: 6),

                // Pie de página
                if (footer.isNotEmpty) ...[
                  pw.Center(
                    child: pw.Text(
                      footer,
                      style: pw.TextStyle(fontSize: is58 ? 7 : 8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                ],
                pw.Center(
                  child: pw.Text(
                    'CALIBRACIÓN EXITOSA · DANILORE ONE ERP',
                    style: pw.TextStyle(
                      fontSize: is58 ? 6.5 : 7.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    '- - - - CORTE AQUÍ - - - -',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Ticket_Prueba_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf',
      );
      return true;
    } catch (e) {
      debugPrint('Error imprimiendo ticket de prueba: $e');
      return false;
    }
  }

  static pw.Widget _buildTestItem({
    required String qty,
    required String desc,
    required String price,
    required bool is58,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: is58 ? 14 : 18,
            child: pw.Text(
              qty,
              style: pw.TextStyle(
                fontSize: is58 ? 7.5 : 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              desc,
              style: pw.TextStyle(fontSize: is58 ? 7.5 : 8.5),
            ),
          ),
          pw.Text(
            price,
            style: pw.TextStyle(
              fontSize: is58 ? 7.5 : 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
