// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

import '../../features/app_config/data/repositories_impl/app_config_repository_impl.dart'
    as _i785;
import '../../features/app_config/domain/repositories/app_config_repository.dart'
    as _i257;
import '../../features/app_config/domain/usecases/get_app_settings_uc.dart'
    as _i506;
import '../../features/app_config/domain/usecases/get_business_info_uc.dart'
    as _i868;
import '../../features/app_config/domain/usecases/save_business_info_uc.dart'
    as _i702;
import '../../features/app_config/domain/usecases/upload_logo_uc.dart' as _i217;
import '../../features/app_config/presentation/bloc/app_config_cubit.dart'
    as _i556;
import '../network/network_cubit.dart' as _i11;
import 'register_module.dart' as _i291;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i454.SupabaseClient>(() => registerModule.supabase);
    gh.lazySingleton<_i11.NetworkCubit>(() => _i11.NetworkCubit());
    gh.lazySingleton<_i257.AppConfigRepository>(
      () => _i785.AppConfigRepositoryImpl(client: gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i506.GetAppSettingsUseCase>(
      () => _i506.GetAppSettingsUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.lazySingleton<_i868.GetBusinessInfoUseCase>(
      () => _i868.GetBusinessInfoUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.lazySingleton<_i702.SaveBusinessInfoUseCase>(
      () => _i702.SaveBusinessInfoUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.lazySingleton<_i217.UploadLogoUseCase>(
      () => _i217.UploadLogoUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.factory<_i556.AppConfigCubit>(
      () => _i556.AppConfigCubit(
        getAppSettingsUseCase: gh<_i506.GetAppSettingsUseCase>(),
        getBusinessInfoUseCase: gh<_i868.GetBusinessInfoUseCase>(),
        saveBusinessInfoUseCase: gh<_i702.SaveBusinessInfoUseCase>(),
        uploadLogoUseCase: gh<_i217.UploadLogoUseCase>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}
