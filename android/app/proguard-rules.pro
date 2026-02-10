# Flutter-specific ProGuard rules
# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep audioplayers plugin
-keep class xyz.luan.audioplayers.** { *; }

# Don't warn about missing annotations
-dontwarn javax.annotation.**

# Play Core (deferred components) — not used but referenced by Flutter engine
-dontwarn com.google.android.play.core.**
