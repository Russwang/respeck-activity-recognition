# Keep TensorFlow Lite classes
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Keep TFLite GPU delegate
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# Keep FlatBuffer classes
-keep class com.google.flatbuffers.** { *; }
-dontwarn com.google.flatbuffers.**
