# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Dio
-keep class com.squareup.okhttp3.** { *; }
-dontwarn com.squareup.okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# Video Player
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Cached Network Image
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# Keep app models
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Dart/Flutter
-keep class **.joyscroll.** { *; }
-dontwarn java.lang.invoke.**