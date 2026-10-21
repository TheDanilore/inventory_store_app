# Reglas críticas para corregir el bug de R8 en shared_preferences_android 2.5.x
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.intrinsics.** { *; }

# Mantener intacta la API de SharedPreferences de Flutter
-keep class io.flutter.plugins.sharedpreferences.** { *; }
