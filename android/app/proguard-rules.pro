# Flutter-specific ProGuard rules
# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep audioplayers plugin
-keep class xyz.luan.audioplayers.** { *; }

# Don't warn about missing annotations
-dontwarn javax.annotation.**
