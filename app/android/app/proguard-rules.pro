# Readendar-specific R8 rules only.
#
# Flutter's Android embedding and every current reflection/JNI-based plugin
# (notifications/Gson, Google Play services, ML Kit, WebView and Sentry) ship
# consumer rules in their own AARs. Broad application-level `-keep` rules would
# override those carefully scoped rules and prevent R8 from shrinking,
# optimizing, obfuscating and repackaging much of the Android bytecode.
#
# Add a rule here only when a release-only failure proves that application code
# is reached exclusively through reflection or JNI. Resource-only entry points
# belong in res/raw/keep.xml instead.

# google_mlkit_text_recognition exposes optional CJK/Devanagari recognizers from
# one shared plugin class. Readendar installs only the Latin recognizer, so R8
# correctly cannot resolve these deliberately absent language modules.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
