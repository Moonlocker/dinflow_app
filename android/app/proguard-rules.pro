# Regras R8/ProGuard do DinFlow (Android release).

# Mantém as classes do Flutter requeridas em runtime.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mantém os plugins registrados pelo Flutter acessíveis via canal de platform.
-keep class com.example.dinflow_app.* { *; }
-dontwarn com.example.dinflow_app.**

# Módulos opcionais do Play Core (split install) ausentes em builds sem Play:
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# flutter_local_notifications + Gson (reflexão usada ao ler/gravar payloads).
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keepattributes Signature
-keepattributes *Annotation*