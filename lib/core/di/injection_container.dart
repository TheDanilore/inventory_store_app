import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/di/injection_container.config.dart';

final sl = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
// Main DI Container Initializer
void initDI() => sl.init();
