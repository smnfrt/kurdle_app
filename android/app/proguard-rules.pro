# Peyvok — release build için ProGuard / R8 kuralları.
#
# AGP 8.x release build'de R8 minification default davranışla çalışıyor.
# Aşağıdaki kurallar bir sürüm bug'unu önler:

# ── gson + TypeToken (flutter_local_notifications için gerekli) ────
# R8 generic type signature'larını agresif siler. Gson'ın TypeToken
# alt sınıfları runtime'da bu signature'ları okur, silinince
# "TypeToken must be created with a type argument" hatası atıyor.
# Sonuç: scheduleDailyReminder / scheduleStreakEveningReminder
# release'de PlatformException ile bozuluyor.
#
# Resmi gson tavsiyesi: signature attribute'larını koru, TypeToken
# alt sınıflarının ismini ve generic type info'sunu koru.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson alanları (SerializedName ile işaretliyse) korunmalı
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# TypeToken ve alt sınıflarını koru (R8 3.0+ için)
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
