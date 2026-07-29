import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/utils/kardex_pdf_generator.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/kardex_repository.dart';

@injectable
class ExportKardexPdfUseCase {
  final KardexRepository repository;

  ExportKardexPdfUseCase(this.repository);

  Future<void> call({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
  }) async {
    final movements = await repository.getAllKardexMovements(
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
    );

    await KardexPdfGenerator.exportKardexToPdf(
      movements,
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
    );
  }
}
