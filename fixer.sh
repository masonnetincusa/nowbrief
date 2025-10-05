#!/data/data/com.termux/files/usr/bin/bash

echo -e "\e[1;36m🔧 Running SmartBrief Injector Fixer...\e[0m"
sleep 1

SRC_APK="/storage/emulated/0/notruinedapk/SamsungSmartSuggestions.apk"
WORKDIR="$HOME/nowbrief_injector"
BASE="$WORKDIR/base"
OUT_APK="$WORKDIR/SmartBriefInjector.apk"

progress() {
  echo "$1"
  sleep 0.5
}

progress "📦 Decoding base APK for rebuild..."
apktool d "$SRC_APK" -o "$BASE" -f

progress "📁 Injecting layouts and XML..."
cp -r "$WORKDIR/res/layout" "$BASE/res/"
cp -r "$WORKDIR/xml" "$BASE/res/"

progress "🧠 Injecting smali logic..."
cp -r "$WORKDIR/smali" "$BASE/"

progress "🧩 Replacing manifest..."
cp "$WORKDIR/AndroidManifest.xml" "$BASE/"

progress "🔨 Building SmartBriefInjector.apk..."
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
