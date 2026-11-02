import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';

/// Servicio especializado en parseo de archivos Excel y CSV (RFC 4180) para importación masiva.
/// Optimizado para ejecutarse en un Isolate secundario para no bloquear el hilo de UI.
class BulkImportFileParserService {
  /// Determina si el archivo es un binario de Excel (.xlsx o .xls)
  static bool isExcelFile(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return true;
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) return true;
    if (bytes.length >= 8 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0) {
      return true;
    }
    return false;
  }

  /// Función pura compatible con compute() para parsear hojas de cálculo en segundo plano
  static List<List<String>> parseSpreadsheetInIsolate(
    Map<String, dynamic> args,
  ) {
    final fileName = args['fileName'] as String;
    final bytes = args['bytes'] as Uint8List;

    if (isExcelFile(fileName, bytes)) {
      return parseExcel(bytes);
    } else {
      var text = decode(bytes);
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      return parseCsv(text, detectDelimiter(text));
    }
  }

  /// Parsea un archivo Excel binario y retorna matriz de strings
  static List<List<String>> parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];
    Sheet? sheet;
    for (final name in excel.tables.keys) {
      final s = excel.tables[name];
      if (s != null && s.maxRows > 0) {
        sheet = s;
        break;
      }
    }
    if (sheet == null) return const [];

    final result = <List<String>>[];
    for (final row in sheet.rows) {
      final rowStrings = <String>[];
      for (final cell in row) {
        rowStrings.add(cellToString(cell?.value));
      }
      result.add(rowStrings);
    }
    return result;
  }

  /// Convierte cualquier tipo de celda Excel a su representación en String
  static String cellToString(CellValue? val) {
    if (val == null) return '';
    if (val is TextCellValue) return val.value.text ?? '';
    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) {
      if (val.value % 1 == 0) return val.value.toInt().toString();
      return val.value.toString();
    }
    if (val is BoolCellValue) return val.value ? 'si' : 'no';
    if (val is DateCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    }
    if (val is DateTimeCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    }
    if (val is TimeCellValue) return val.toString();
    if (val is FormulaCellValue) return val.formula;
    return val.toString();
  }

  /// Decodifica bytes a texto probando UTF-8 y recayendo en Latin-1
  static String decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes); // CSV guardado desde Excel "ANSI"
    }
  }

  /// Detecta automáticamente el delimitador del CSV (, ; o tabulación)
  static String detectDelimiter(String text) {
    final firstLine = text.split(RegExp(r'\r?\n')).first;
    final counts = {
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
    };
    var best = ',';
    counts.forEach((k, v) {
      if (v > counts[best]!) best = k;
    });
    return best;
  }

  /// Parser CSV conforme a RFC 4180 con delimitador dinámico
  static List<List<String>> parseCsv(String text, String d) {
    final rows = <List<String>>[];
    var row = <String>[];
    final f = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            f.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          f.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == d) {
        row.add(f.toString());
        f.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(f.toString());
        f.clear();
        rows.add(row);
        row = <String>[];
      } else {
        f.write(c);
      }
    }
    if (f.isNotEmpty || row.isNotEmpty) {
      row.add(f.toString());
      rows.add(row);
    }
    return rows;
  }
}
