# Flutter Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.core.**

# TensorFlow Lite, LiteRT & ML Kit Keep Rules
-keep class com.google.ai.edge.litert.** { *; }
-dontwarn com.google.ai.edge.litert.**
-keep class org.tensorflow.tflite_flutter.** { *; }
-dontwarn org.tensorflow.tflite_flutter.**
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# OkHttp & Dio Network Keep Rules
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
