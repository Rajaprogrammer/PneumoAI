# Keep PyTorch classes
-keep class org.pytorch.** { *; }
-keep class com.facebook.jni.** { *; }
-keep class com.facebook.soloader.** { *; }

# Keep TensorFlow Lite classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.** { *; }

# Keep model file extensions
-keepclassmembers class * {
    *** *.ptl;
    *** *.tflite;
    *** *.pt;
}

# Don't warn about missing classes
-dontwarn org.pytorch.**
-dontwarn org.tensorflow.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Chaquopy
-keep class com.chaquo.python.** { *; }
-dontwarn com.chaquo.python.**