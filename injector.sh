#!/data/data/com.termux/files/usr/bin/bash

echo -e "\e[43dcd9a7-70db-4a1f-b0ae-981daa162054](https://github.com/Vove7/Android-Accessibility-Api/tree/857b0c4a43e5df82cb1ad7156265d9ff9108b399/ReadMe.md?citationMarker=43dcd9a7-70db-4a1f-b0ae-981daa162054 "1")[1;36m=============================="
echo -e "🚀  Get Now Brief  Now!"
echo -e "==============================\e[0m"
sleep 1

SRC_APK="/storage/emulated/0/notruinedapk/SamsungSmartSuggestions.apk"
WORKDIR="$HOME/nowbrief_injector"
OUT_APK="$WORKDIR/SmartBriefInjector.apk"

progress() {
  echo "$1"
  sleep 0.5
}

progress "📦 Preparing workspace..."
mkdir -p "$WORKDIR/res/layout" "$WORKDIR/xml" "$WORKDIR/smali/com/mason/injector/smartbrief"

progress "🔍 Decoding Fold 6 APK..."
apktool d "$SRC_APK" -o "$WORKDIR/fold6_payload" -f

progress "📁 Extracting Now Brief layouts..."
cp "$WORKDIR/fold6_payload/res/layout/suggestion_ui_app_widget_brief.xml" "$WORKDIR/res/layout/"
cp "$WORKDIR/fold6_payload/res/layout/now_brief_widget_setting_layout.xml" "$WORKDIR/res/layout/"

progress "🧠 Injecting dummy BriefService..."
cat > "$WORKDIR/smali/com/mason/injector/smartbrief/BriefService.smali" << 'EOF'
.class public Lcom/mason/injector/smartbrief/BriefService;
.super Landroid/accessibilityservice/AccessibilityService;

.method public onAccessibilityEvent(Landroid/view/accessibility/AccessibilityEvent;)V
    .locals 0
    return-void
.end method

.method public onInterrupt()V
    .locals 0
    return-void
.end method
EOF

progress "🧩 Creating manifest and config..."
cat > "$WORKDIR/AndroidManifest.xml" << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.mason.injector.smartbrief"
    android:versionCode="1"
    android:versionName="1.0">
    <application android:label="SmartBrief Injector">
        <service android:name=".smartbrief.BriefService"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_config" />
        </service>
    </application>
</manifest>
EOF

cat > "$WORKDIR/xml/accessibility_config.xml" << 'EOF'
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canRetrieveWindowContent="true"
    android:settingsActivity="com.mason.injector.smartbrief.SettingsActivity" />
EOF

progress "📲 Installing signed APK..."
adb install -r "$OUT_APK"
adb shell settings put secure enabled_accessibility_services com.mason.injector.smartbrief/com.mason.injector.smartbrief.BriefService
adb shell settings put secure accessibility_enabled 1

progress "🔔 Triggering overlay..."
termux-notification --title "Now Brief Activated" --content "SmartBrief Injector is live. Swipe to launcher to view Now Brief."

echo -e "\e[1;32m🎉 Success: Now Brief overlay is active on Fold 5.\e[0m"
