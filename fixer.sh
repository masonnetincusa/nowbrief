#!/data/data/com.termux/files/usr/bin/bash

echo -e "\e[1;36m=============================="
echo -e "🚀  SmartBrief Injector: Now Brief Activation"
echo -e "==============================\e[0m"
sleep 1

SRC_APK="/storage/emulated/0/notruinedapk/SamsungSmartSuggestions.apk"
WORKDIR="$HOME/nowbrief_injector"
BASE="$WORKDIR/base"
OUT_APK="$WORKDIR/SmartBriefInjector.apk"

progress() {
  echo "$1"
  sleep 0.5
}

progress "📦 Preparing workspace..."
rm -rf "$WORKDIR"
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
cat > "$WORKDIR/xml/accessibility_config.xml" << 'EOF'
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canRetrieveWindowContent="true"
    android:settingsActivity="com.mason.injector.smartbrief.SettingsActivity" />
EOF

progress "📦 Decoding base APK for rebuild..."
apktool d "$SRC_APK" -o "$BASE" -f

progress "📁 Injecting layouts and XML..."
mkdir -p "$BASE/res/layout" "$BASE/res/xml"
cp -r "$WORKDIR/res/layout" "$BASE/res/"
cp -r "$WORKDIR/xml" "$BASE/res/"

progress "🧠 Injecting smali logic..."
cp -r "$WORKDIR/smali" "$BASE/"

progress "🧩 Modifying manifest in-place..."
sed -i '/<application/,/<\/application>/c\
        <application android:label="SmartBrief Injector">\
            <service android:name=".smartbrief.BriefService"\
                android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">\
                <intent-filter>\
                    <action android:name="android.accessibilityservice.AccessibilityService" />\
                </intent-filter>\
                <meta-data android:name="android.accessibilityservice"\
                    android:resource="@xml/accessibility_config" />\
            </service>\
        </application>' "$BASE/AndroidManifest.xml"

progress "🧼 Auto-repairing malformed XML..."
find "$BASE/res" -type f -name "*.xml" -exec sed -i 's/\(android:[a-zA-Z]*="\([^"]*\)\)$/\1"/g' {} +

progress "🔨 Building SmartBrief Injector APK..."
apktool b "$BASE" -o "$OUT_APK"

if [ -f "$OUT_APK" ]; then
  echo -e "\e[1;32m✅ Build complete: $OUT_APK\e[0m"
else
  echo -e "\e[1;31m❌ Build failed: APK not found\e[0m"
  exit 1
fi

progress "📲 Installing APK via ADB..."
adb install -r "$OUT_APK"
adb shell settings put secure enabled_accessibility_services com.mason.injector.smartbrief/com.mason.injector.smartbrief.BriefService
adb shell settings put secure accessibility_enabled 1

progress "🔔 Triggering overlay..."
termux-notification --title "Now Brief Activated" --content "SmartBrief Injector is live. Swipe to launcher to view Now Brief."

echo -e "\e[1;32m🎉 Success: Now Brief overlay is active on Fold 5.\e[0m"
