import 'dart:typed_data';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/utils/result.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

class UploadLogoUseCase extends UseCase<String, Uint8List> {
  final AppConfigRepository repository;

  UploadLogoUseCase(this.repository);

  @override
  Future<Result<String>> execute(Uint8List params) async {
    try {
      final logoUrl = await repository.uploadBusinessLogo(params);
      return Success(logoUrl);
    } catch (e) {
      return Error(Failure.from(e));
    }
  }
}
