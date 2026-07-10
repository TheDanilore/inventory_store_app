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
import '../../features/app_config/domain/usecases/change_connection_uc.dart'
    as _i286;
import '../../features/app_config/domain/usecases/get_app_settings_uc.dart'
    as _i506;
import '../../features/app_config/domain/usecases/get_business_info_uc.dart'
    as _i868;
import '../../features/app_config/domain/usecases/restore_default_connection_uc.dart'
    as _i36;
import '../../features/app_config/domain/usecases/save_business_info_uc.dart'
    as _i702;
import '../../features/app_config/domain/usecases/upload_logo_uc.dart' as _i217;
import '../../features/app_config/presentation/bloc/app_config_cubit.dart'
    as _i556;
import '../../features/auth/data/repositories_impl/auth_repository_impl.dart'
    as _i710;
import '../../features/auth/domain/repositories/auth_repository.dart' as _i787;
import '../../features/auth/domain/usecases/change_password_uc.dart' as _i832;
import '../../features/auth/domain/usecases/delete_account_uc.dart' as _i853;
import '../../features/auth/domain/usecases/get_current_user_uc.dart' as _i813;
import '../../features/auth/domain/usecases/login_with_email_uc.dart' as _i175;
import '../../features/auth/domain/usecases/logout_uc.dart' as _i72;
import '../../features/auth/domain/usecases/register_uc.dart' as _i182;
import '../../features/auth/domain/usecases/reset_password_uc.dart' as _i878;
import '../../features/auth/domain/usecases/update_profile_uc.dart' as _i282;
import '../../features/auth/presentation/bloc/auth_cubit.dart' as _i52;
import '../../features/catalog/data/repositories_impl/catalog_repository_impl.dart'
    as _i524;
import '../../features/catalog/domain/repositories/catalog_repository.dart'
    as _i1018;
import '../../features/catalog/domain/usecases/catalog_attribute_mutations_uc.dart'
    as _i382;
import '../../features/catalog/domain/usecases/catalog_category_mutations_uc.dart'
    as _i110;
import '../../features/catalog/domain/usecases/catalog_form_mutations_uc.dart'
    as _i1067;
import '../../features/catalog/domain/usecases/catalog_image_ucs.dart'
    as _i1014;
import '../../features/catalog/domain/usecases/catalog_ingredient_mutations_uc.dart'
    as _i538;
import '../../features/catalog/domain/usecases/catalog_ingredient_ucs.dart'
    as _i597;
import '../../features/catalog/domain/usecases/catalog_variant_ucs.dart'
    as _i929;
import '../../features/catalog/domain/usecases/check_wishlist_state_usecase.dart'
    as _i44;
import '../../features/catalog/domain/usecases/create_ingredient_uc.dart'
    as _i498;
import '../../features/catalog/domain/usecases/get_admin_financial_data_usecase.dart'
    as _i712;
import '../../features/catalog/domain/usecases/get_attributes_uc.dart' as _i487;
import '../../features/catalog/domain/usecases/get_categories_uc.dart' as _i700;
import '../../features/catalog/domain/usecases/get_current_profile_id_usecase.dart'
    as _i927;
import '../../features/catalog/domain/usecases/get_product_by_id_uc.dart'
    as _i567;
import '../../features/catalog/domain/usecases/get_product_extra_data_usecase.dart'
    as _i338;
import '../../features/catalog/domain/usecases/get_product_stock_uc.dart'
    as _i958;
import '../../features/catalog/domain/usecases/get_products_uc.dart' as _i222;
import '../../features/catalog/domain/usecases/save_product_usecase.dart'
    as _i1064;
import '../../features/catalog/domain/usecases/toggle_wishlist_usecase.dart'
    as _i839;
import '../../features/catalog/presentation/bloc/admin_catalog_cubit.dart'
    as _i332;
import '../../features/catalog/presentation/bloc/attributes_cubit.dart'
    as _i919;
import '../../features/catalog/presentation/bloc/categories_cubit.dart'
    as _i777;
import '../../features/catalog/presentation/bloc/customer_catalog_cubit.dart'
    as _i160;
import '../../features/catalog/presentation/bloc/ingredients_cubit.dart'
    as _i841;
import '../../features/catalog/presentation/bloc/product_detail_cubit.dart'
    as _i711;
import '../../features/catalog/presentation/bloc/product_form_cubit.dart'
    as _i150;
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
    gh.lazySingleton<_i787.AuthRepository>(
      () => _i710.AuthRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i1018.CatalogRepository>(
      () => _i524.CatalogRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i257.AppConfigRepository>(
      () => _i785.AppConfigRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i382.CreateAttributeUC>(
      () => _i382.CreateAttributeUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i382.UpdateAttributeUC>(
      () => _i382.UpdateAttributeUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i382.DeleteAttributeUC>(
      () => _i382.DeleteAttributeUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i382.CreateAttributeValueUC>(
      () => _i382.CreateAttributeValueUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i382.UpdateAttributeValueUC>(
      () => _i382.UpdateAttributeValueUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i382.DeleteAttributeValueUC>(
      () => _i382.DeleteAttributeValueUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i110.CreateCategoryUC>(
      () => _i110.CreateCategoryUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i110.UpdateCategoryUC>(
      () => _i110.UpdateCategoryUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i110.DeleteCategoryUC>(
      () => _i110.DeleteCategoryUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1067.SaveProductMasterUC>(
      () => _i1067.SaveProductMasterUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1067.SaveVariantUC>(
      () => _i1067.SaveVariantUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1067.SaveVariantAttributesUC>(
      () => _i1067.SaveVariantAttributesUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1067.GetFirstVariantIdUC>(
      () => _i1067.GetFirstVariantIdUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1067.SetProductActiveUC>(
      () => _i1067.SetProductActiveUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1067.ClearCatalogCacheUC>(
      () => _i1067.ClearCatalogCacheUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1014.GetProductImagesUC>(
      () => _i1014.GetProductImagesUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1014.UploadImageToStorageUC>(
      () => _i1014.UploadImageToStorageUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1014.DeleteProductImageUC>(
      () => _i1014.DeleteProductImageUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1014.SyncProductImagesUC>(
      () => _i1014.SyncProductImagesUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1014.ClearVariantImagesUC>(
      () => _i1014.ClearVariantImagesUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i538.UpdateIngredientUC>(
      () => _i538.UpdateIngredientUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i538.DeleteIngredientUC>(
      () => _i538.DeleteIngredientUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i538.GetIngredientsUC>(
      () => _i538.GetIngredientsUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i597.GetAttributesUC>(
      () => _i597.GetAttributesUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i597.GetProductIngredientsUC>(
      () => _i597.GetProductIngredientsUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i597.SearchIngredientsUC>(
      () => _i597.SearchIngredientsUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i597.CreateIngredientUC>(
      () => _i597.CreateIngredientUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i597.ClearProductIngredientsUC>(
      () => _i597.ClearProductIngredientsUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i597.InsertProductIngredientUC>(
      () => _i597.InsertProductIngredientUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i929.GetVariantByIdUC>(
      () => _i929.GetVariantByIdUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i929.GetStockByVariantUC>(
      () => _i929.GetStockByVariantUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i929.GetVariantsDraftsUC>(
      () => _i929.GetVariantsDraftsUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i929.DeleteVariantUC>(
      () => _i929.DeleteVariantUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i929.DeactivateVariantUC>(
      () => _i929.DeactivateVariantUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i929.HasVariantSalesUC>(
      () => _i929.HasVariantSalesUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i44.CheckWishlistStateUseCase>(
      () => _i44.CheckWishlistStateUseCase(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i498.CreateIngredientUC>(
      () => _i498.CreateIngredientUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i712.GetAdminFinancialDataUseCase>(
      () => _i712.GetAdminFinancialDataUseCase(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i487.GetAttributesUC>(
      () => _i487.GetAttributesUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i700.GetCategoriesUC>(
      () => _i700.GetCategoriesUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i927.GetCurrentProfileIdUseCase>(
      () => _i927.GetCurrentProfileIdUseCase(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i567.GetProductByIdUC>(
      () => _i567.GetProductByIdUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i338.GetProductExtraDataUseCase>(
      () => _i338.GetProductExtraDataUseCase(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i958.GetProductStockUC>(
      () => _i958.GetProductStockUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i222.GetProductsUC>(
      () => _i222.GetProductsUC(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i1064.SaveProductUseCase>(
      () => _i1064.SaveProductUseCase(gh<_i1018.CatalogRepository>()),
    );
    gh.lazySingleton<_i839.ToggleWishlistUseCase>(
      () => _i839.ToggleWishlistUseCase(gh<_i1018.CatalogRepository>()),
    );
    gh.factory<_i160.CustomerCatalogCubit>(
      () => _i160.CustomerCatalogCubit(
        getCategoriesUC: gh<_i700.GetCategoriesUC>(),
        getProductsUC: gh<_i222.GetProductsUC>(),
        getProductStockUC: gh<_i958.GetProductStockUC>(),
      ),
    );
    gh.factory<_i841.IngredientsCubit>(
      () => _i841.IngredientsCubit(
        getIngredientsUC: gh<_i538.GetIngredientsUC>(),
        createIngredientUC: gh<_i498.CreateIngredientUC>(),
        updateIngredientUC: gh<_i538.UpdateIngredientUC>(),
        deleteIngredientUC: gh<_i538.DeleteIngredientUC>(),
      ),
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
    gh.factory<_i286.ChangeConnectionUseCase>(
      () => _i286.ChangeConnectionUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.factory<_i36.RestoreDefaultConnectionUseCase>(
      () =>
          _i36.RestoreDefaultConnectionUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.factory<_i711.ProductDetailCubit>(
      () => _i711.ProductDetailCubit(
        getExtraData: gh<_i338.GetProductExtraDataUseCase>(),
        getAdminData: gh<_i712.GetAdminFinancialDataUseCase>(),
        checkWishlist: gh<_i44.CheckWishlistStateUseCase>(),
        toggleWishlist: gh<_i839.ToggleWishlistUseCase>(),
        getProfileId: gh<_i927.GetCurrentProfileIdUseCase>(),
      ),
    );
    gh.factory<_i832.ChangePasswordUseCase>(
      () => _i832.ChangePasswordUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i853.DeleteAccountUseCase>(
      () => _i853.DeleteAccountUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i813.GetCurrentUserUseCase>(
      () => _i813.GetCurrentUserUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i175.LoginWithEmailUseCase>(
      () => _i175.LoginWithEmailUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i72.LogoutUseCase>(
      () => _i72.LogoutUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i182.RegisterUseCase>(
      () => _i182.RegisterUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i878.ResetPasswordUseCase>(
      () => _i878.ResetPasswordUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i282.UpdateProfileUseCase>(
      () => _i282.UpdateProfileUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i332.AdminCatalogCubit>(
      () => _i332.AdminCatalogCubit(
        getCategoriesUC: gh<_i700.GetCategoriesUC>(),
        getProductsUC: gh<_i222.GetProductsUC>(),
        setProductActiveUC: gh<_i1067.SetProductActiveUC>(),
        clearCatalogCacheUC: gh<_i1067.ClearCatalogCacheUC>(),
      ),
    );
    gh.factory<_i919.AttributesCubit>(
      () => _i919.AttributesCubit(
        getAttributesUC: gh<_i487.GetAttributesUC>(),
        createAttributeUC: gh<_i382.CreateAttributeUC>(),
        updateAttributeUC: gh<_i382.UpdateAttributeUC>(),
        deleteAttributeUC: gh<_i382.DeleteAttributeUC>(),
        createAttributeValueUC: gh<_i382.CreateAttributeValueUC>(),
        updateAttributeValueUC: gh<_i382.UpdateAttributeValueUC>(),
        deleteAttributeValueUC: gh<_i382.DeleteAttributeValueUC>(),
      ),
    );
    gh.factory<_i777.CategoriesCubit>(
      () => _i777.CategoriesCubit(
        getCategoriesUC: gh<_i700.GetCategoriesUC>(),
        createCategoryUC: gh<_i110.CreateCategoryUC>(),
        updateCategoryUC: gh<_i110.UpdateCategoryUC>(),
        deleteCategoryUC: gh<_i110.DeleteCategoryUC>(),
      ),
    );
    gh.factory<_i150.ProductFormCubit>(
      () => _i150.ProductFormCubit(
        gh<_i700.GetCategoriesUC>(),
        gh<_i1014.GetProductImagesUC>(),
        gh<_i597.GetProductIngredientsUC>(),
        gh<_i929.GetVariantsDraftsUC>(),
        gh<_i1014.DeleteProductImageUC>(),
        gh<_i929.DeleteVariantUC>(),
        gh<_i929.HasVariantSalesUC>(),
        gh<_i927.GetCurrentProfileIdUseCase>(),
        gh<_i1064.SaveProductUseCase>(),
      ),
    );
    gh.factory<_i52.AuthCubit>(
      () => _i52.AuthCubit(
        getCurrentUserUseCase: gh<_i813.GetCurrentUserUseCase>(),
        loginUseCase: gh<_i175.LoginWithEmailUseCase>(),
        registerUseCase: gh<_i182.RegisterUseCase>(),
        logoutUseCase: gh<_i72.LogoutUseCase>(),
        resetPasswordUseCase: gh<_i878.ResetPasswordUseCase>(),
        changePasswordUseCase: gh<_i832.ChangePasswordUseCase>(),
        deleteAccountUseCase: gh<_i853.DeleteAccountUseCase>(),
        updateProfileUseCase: gh<_i282.UpdateProfileUseCase>(),
      ),
    );
    gh.factory<_i556.AppConfigCubit>(
      () => _i556.AppConfigCubit(
        getAppSettingsUseCase: gh<_i506.GetAppSettingsUseCase>(),
        getBusinessInfoUseCase: gh<_i868.GetBusinessInfoUseCase>(),
        saveBusinessInfoUseCase: gh<_i702.SaveBusinessInfoUseCase>(),
        uploadLogoUseCase: gh<_i217.UploadLogoUseCase>(),
        changeConnectionUseCase: gh<_i286.ChangeConnectionUseCase>(),
        restoreDefaultConnectionUseCase:
            gh<_i36.RestoreDefaultConnectionUseCase>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}
