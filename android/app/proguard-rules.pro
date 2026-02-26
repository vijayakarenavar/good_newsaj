# ================= FLUTTER =================
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ================= CONNECTIVITY PLUS (IMPORTANT) =================
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ================= DIO / HTTP =================
-keep class com.squareup.okhttp3.** { *; }
-dontwarn com.squareup.okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# ================= VIDEO PLAYER =================
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ================= GLIDE =================
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# ================= KEEP APP MODELS =================
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# ================= YOUR APP PACKAGE =================
-keep class **.joyscroll.** { *; }
-dontwarn java.lang.invoke.**