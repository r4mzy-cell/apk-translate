# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ML Kit Text Recognition
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ONNX Runtime
-keep class com.microsoft.onnxruntime.** { *; }
-dontwarn com.microsoft.onnxruntime.**

# Kotlin Coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Google Play Services (for ML Kit)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Prevent R8 from stripping serializer fields
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep generated protobuf classes if any
-keep class * extends com.google.protobuf.GeneratedMessage
-keep class * extends com.google.protobuf.GeneratedMessageLite

# Flutter method channels
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler
-keep class * implements io.flutter.plugin.common.EventChannel$StreamHandler