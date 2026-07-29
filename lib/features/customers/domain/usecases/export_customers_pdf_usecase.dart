import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/data/utils/customer_pdf_generator.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

/// Caso de uso que delega la generación y compartición del PDF a la utilidad
/// de infraestructura. El Cubit solo llama a este UseCase — no importa nada de data/.
@lazySingleton
class ExportCustomersPdfUseCase {
  Future<void> call(List<CustomerEntity> customers) {
    return CustomerPdfGenerator.shareOrPrintPdf(customers);
  }
}
