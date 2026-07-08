import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/core/config/data/repositories/app_config_repository_impl.dart';
import 'package:inventory_store_app/core/config/domain/repositories/app_config_repository.dart';
import 'package:inventory_store_app/core/config/domain/usecases/get_app_settings_uc.dart';
import 'package:inventory_store_app/core/config/domain/usecases/get_business_info_uc.dart';
import 'package:inventory_store_app/core/config/domain/usecases/save_business_info_uc.dart';
import 'package:inventory_store_app/core/config/domain/usecases/upload_logo_uc.dart';
import 'package:inventory_store_app/core/config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/core/network/presentation/bloc/network_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance; // sl = Service Locator

Future<void> initDI() async {
  // --- Core ---
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // --- Network ---
  sl.registerFactory(() => NetworkCubit());

  // --- App Config ---
  // Repositories
  sl.registerLazySingleton<AppConfigRepository>(
    () => AppConfigRepositoryImpl(client: sl()),
  );

  // UseCases
  sl.registerLazySingleton(() => GetAppSettingsUseCase(sl()));
  sl.registerLazySingleton(() => GetBusinessInfoUseCase(sl()));
  sl.registerLazySingleton(() => SaveBusinessInfoUseCase(sl()));
  sl.registerLazySingleton(() => UploadLogoUseCase(sl()));

  // Bloc / Cubit
  sl.registerFactory(
    () => AppConfigCubit(
      getAppSettingsUseCase: sl(),
      getBusinessInfoUseCase: sl(),
      saveBusinessInfoUseCase: sl(),
      uploadLogoUseCase: sl(),
    ),
  );

  // NOTA: Conforme vayamos migrando los otros features (pos, catalog, etc.),
  // iremos agregando sus inyecciones de dependencias aquí.
}
