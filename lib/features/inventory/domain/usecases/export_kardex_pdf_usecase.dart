import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/utils/kardex_pdf_service.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/kardex_repository.dart';

@injectable
class ExportKardexPdfUseCase {
  final KardexRepository repository;

  ExportKardexPdfUseCase(this.repository);

  Future<void> call({
    DateTimeRange? dateRange,
    String typeFilter = 'ALL',
    String searchText = '',
  }) async {
    final movements = await repository.getAllKardexMovements(
      dateRange: dateRange,
      typeFilter: typeFilter,
      searchText: searchText,
    );

    await KardexPdfService.exportKardexToPdf(
      movements,
      dateRange: dateRange,
      typeFilter: typeFilter,
    );
  }
}
