# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# Added from Flutter ML Kit documentation recommendations
-keep public class com.google.mlkit.** { public *; }
-keep public class com.google.android.gms.vision.** { public *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google.mlkit.common.sdkinternal.** { *; }
-keep class com.google.mlkit.vision.common.internal.** { *; }
-keep class com.google.mlkit.vision.text.internal.** { *; }
-keep class com.google.mlkit.vision.label.internal.** { *; }
-keep class com.google.mlkit.vision.objects.internal.** { *; }
-keep class com.google.mlkit.vision.face.internal.** { *; }
-keep class com.google.mlkit.vision.barcode.internal.** { *; }
-keep class com.google.mlkit.vision.digitalink.internal.** { *; }
-keep class com.google.mlkit.vision.automl.internal.** { *; }
-keep class com.google.mlkit.nl.entityextraction.internal.** { *; }

# For google_mlkit_text_recognition specific languages, if you use them:
-keep class com.google.mlkit.vision.text.chinese.internal.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.internal.** { *; }
-keep class com.google.mlkit.vision.text.japanese.internal.** { *; }
-keep class com.google.mlkit.vision.text.korean.internal.** { *; }
-keep class com.google.mlkit.vision.text.latin.internal.** { *; }


# General rules for Flutter plugins that might use reflection or have native code
-keep class io.flutter.plugins.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * extends java.lang.Enum { *; }
-keepclassmembers class * implements android.os.Parcelable { 
  public static final android.os.Parcelable$Creator *;
}
-keepclassmembers class * implements java.io.Serializable { *; } 