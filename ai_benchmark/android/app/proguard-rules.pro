# TensorFlow Lite - Keep all classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep interface org.tensorflow.lite.** { *; }

# Keep all inner classes
-keep class org.tensorflow.lite.gpu.**$* { *; }
-keep class org.tensorflow.lite.GpuDelegate { *; }
-keep class org.tensorflow.lite.GpuDelegate$* { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate$* { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$* { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Don't warn about missing TensorFlow Lite classes
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**
