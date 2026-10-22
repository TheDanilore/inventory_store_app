import 'dart:convert';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';

/// Servicio de exportación ejecutiva del Dashboard a formato CSV/Excel compatible.
///
/// Implementa codificación UTF-8 BOM (\uFEFF) para visualización sin caracteres extraños
/// en Microsoft Excel, Google Sheets y LibreOffice Calc.
class DashboardExportService {
  static Future<FileExportResult> exportConsolidatedReport(
    DashboardLoaded state,
  ) async {
    try {
      final csvString = await compute(_generateCsvContent, state);
      final bytes = Uint8List.fromList(utf8.encode(csvString));

      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(now);
      final fileName = 'reporte_ejecutivo_dashboard_$dateStr';

      final result = await FileExportService.save(
        fileName: fileName,
        bytes: bytes,
        extension: 'csv',
        mimeType: MimeType.csv,
      );

      if (result.isFailed) {
        throw Exception(
          result.error ?? 'Error desconocido al guardar el archivo.',
        );
      }

      return result;
    } catch (e, stack) {
      LoggerService.e(
        'Error al exportar reporte consolidado del dashboard',
        error: e,
        stackTrace: stack,
        tag: 'DASHBOARD_EXPORT',
      );
      rethrow;
    }
  }

  static String _filterDisplayName(SalesTimeFilter filter) {
    switch (filter) {
      case SalesTimeFilter.today:
        return 'Hoy';
      case SalesTimeFilter.thisWeek:
        return 'Esta semana';
      case SalesTimeFilter.thisMonth:
        return 'Este mes';
      case SalesTimeFilter.allTime:
        return 'Todo el histórico';
      case SalesTimeFilter.custom:
        return 'Personalizado';
    }
  }

  static String _generateCsvContent(DashboardLoaded state) {
    final buffer = StringBuffer();
    // Inyectar BOM UTF-8 para compatibilidad nativa con Microsoft Excel en Windows y Mac
    buffer.write('\uFEFF');

    final currencyFmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final now = DateTime.now();

    void writeRow(List<dynamic> cells) {
      final line = cells
          .map((cell) {
            final str = cell?.toString() ?? '';
            if (str.contains(',') || str.contains('"') || str.contains('\n')) {
              return '"${str.replaceAll('"', '""')}"';
            }
            return str;
          })
          .join(',');
      buffer.writeln(line);
    }

    // ── 1. CABECERA EJECUTIVA ────────────────────────────────────────────────
    writeRow(['DANILORE ONE ERP - REPORTE CONSOLIDADO EJECUTIVO DE DASHBOARD']);
    writeRow([
      'Fecha de Generación',
      DateFormat('dd/MM/yyyy HH:mm:ss').format(now),
    ]);
    writeRow(['Período Analizado', _filterDisplayName(state.salesFilter)]);
    if (state.salesFilter == SalesTimeFilter.custom &&
        state.customStartDate != null &&
        state.customEndDate != null) {
      final rangeStr =
          '${DateFormat('dd/MM/yyyy').format(state.customStartDate!)} - ${DateFormat('dd/MM/yyyy').format(state.customEndDate!)}';
      writeRow(['Rango Personalizado', rangeStr]);
    }
    writeRow([]);

    // ── 2. RESUMEN COMERCIAL Y VENTAS ────────────────────────────────────────
    writeRow(['MÉTRICAS CLAVE DE VENTAS Y RENTABILIDAD']);
    writeRow(['Indicador', 'Valor']);
    writeRow(['Ventas Totales (N° Órdenes)', state.sales.totalSales]);
    writeRow([
      'Ingresos Totales Brutos',
      currencyFmt.format(state.sales.totalRevenue),
    ]);
    writeRow([
      'Ganancia Neta Real',
      currencyFmt.format(state.sales.totalProfit),
    ]);
    writeRow([
      'Margen de Utilidad sobre Ventas',
      '${state.sales.salesMargin.toStringAsFixed(1)}%',
    ]);
    writeRow([
      'Ticket Promedio por Orden',
      currencyFmt.format(state.sales.averageTicket),
    ]);
    writeRow([
      'Fondo de Reposición de Mercadería',
      currencyFmt.format(state.sales.replacementFund),
    ]);
    writeRow(['Día de Mayor Facturación', state.sales.peakDayLabel]);
    writeRow([]);

    // ── 3. SALUD Y RESUMEN DEL INVENTARIO ────────────────────────────────────
    writeRow(['SALUD Y MONITOREO DE INVENTARIO']);
    writeRow(['Indicador', 'Valor']);
    writeRow([
      'Stock Físico Total en Almacén',
      '${state.inventory.totalStock} unidades',
    ]);
    writeRow(['Variantes y Productos Activos', state.inventory.totalProducts]);
    writeRow([
      'Inversión Inmovilizada al Costo',
      currencyFmt.format(state.inventory.totalInvestment),
    ]);
    writeRow([
      'Valorización Comercial Retail Estimada',
      currencyFmt.format(state.inventory.retailValue),
    ]);
    writeRow([
      'Margen Comercial Potencial de Inventario',
      '${state.inventory.grossMargin.toStringAsFixed(1)}%',
    ]);
    writeRow([
      'Productos en Alerta de Bajo Stock',
      state.inventory.lowStockProducts,
    ]);
    writeRow([]);

    // ── 4. PRODUCTOS DE MAYOR ROTACIÓN ───────────────────────────────────────
    writeRow(['TOP PRODUCTOS CON MAYOR ROTACIÓN']);
    writeRow([
      'N°',
      'Producto',
      'Categoría',
      'Despachados',
      'Facturación Total',
      'Estado',
    ]);
    final bestSellers = state.sales.bestSellers;
    if (bestSellers.isEmpty) {
      writeRow([
        '-',
        'No se registraron ventas en el período',
        '-',
        '0 unid.',
        'S/ 0.00',
        'Sin datos',
      ]);
    } else {
      for (int i = 0; i < bestSellers.length; i++) {
        final item = bestSellers[i];
        writeRow([
          i + 1,
          item['name'] ?? 'Producto',
          item['category'] ?? 'General',
          item['sold'] ?? '0 unid.',
          item['revenue'] ?? 'S/ 0.00',
          item['status'] ?? 'Estable',
        ]);
      }
    }
    writeRow([]);

    // ── 5. CLIENTES TOP ──────────────────────────────────────────────────────
    writeRow(['CLIENTES CON MAYOR VOLUMEN DE FACTURACIÓN']);
    writeRow([
      'Ranking',
      'Cliente',
      'N° Pedidos',
      'Ticket Medio',
      'Total Facturado',
    ]);
    final topCust = state.topCustomers;
    if (topCust.isEmpty) {
      writeRow([
        '-',
        'Sin historial de compras de clientes en el período',
        0,
        'S/ 0.00',
        'S/ 0.00',
      ]);
    } else {
      for (int i = 0; i < topCust.length; i++) {
        final c = topCust[i];
        final avgTicket =
            c.orderCount > 0 ? c.totalRevenue / c.orderCount : 0.0;
        writeRow([
          i + 1,
          c.fullName,
          '${c.orderCount} ord.',
          currencyFmt.format(avgTicket),
          currencyFmt.format(c.totalRevenue),
        ]);
      }
    }
    writeRow([]);

    // ── 6. LOTES CRÍTICOS Y POR VENCER (FEFO) ────────────────────────────────
    writeRow(['CONTROL FITOSANITARIO Y LOTES CRÍTICOS POR VENCER (FEFO)']);
    writeRow([
      'N° Lote',
      'Producto',
      'Almacén',
      'Cantidad Disponible',
      'Vencimiento',
      'Diagnóstico',
    ]);
    final batches = state.criticalBatches;
    if (batches.isEmpty) {
      writeRow([
        '-',
        'No existen lotes vencidos o próximos a expirar en los próximos 30 días',
        '-',
        '0',
        '-',
        'Óptimo',
      ]);
    } else {
      for (final b in batches) {
        final batchNum = b['batch_number'] ?? 'DEFAULT';
        final prod = b['products'] as Map<String, dynamic>?;
        final prodName = prod?['name'] ?? 'Producto';
        final wh = b['warehouses'] as Map<String, dynamic>?;
        final whName = wh?['name'] ?? 'Almacén General';
        final qty = (b['available_quantity'] as num?)?.toInt() ?? 0;
        final expiryStr = b['expiry_date'] as String? ?? 'Sin fecha';

        String statusDiag = 'En Seguimiento';
        if (expiryStr != 'Sin fecha') {
          final expDate = DateTime.tryParse(expiryStr);
          if (expDate != null) {
            final diff = expDate.difference(now).inDays;
            if (diff < 0) {
              statusDiag = 'VENCIDO hace ${diff.abs()} días';
            } else if (diff == 0) {
              statusDiag = 'VENCE HOY';
            } else {
              statusDiag = 'Por vencer en $diff días';
            }
          }
        }

        writeRow([
          batchNum,
          prodName,
          whName,
          '$qty unid.',
          expiryStr,
          statusDiag,
        ]);
      }
    }

    return buffer.toString();
  }
}
