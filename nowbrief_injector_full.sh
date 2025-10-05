#!/data/data/com.termux/files/usr/bin/bash

set -e

LOGFILE=~/nowbrief/injector_log.txt
APK_OUT=~/nowbrief_injector/SmartSuggestionsInjector.apk
INJECTOR_BASE=~/nowbrief_injector/base

function log {
  echo "[*] $1" | tee -a "$LOGFILE"
}

function progress {
  echo -ne "\r[+] $1..."; sleep 0.5
}

log "Starting full Now Brief injector flow"
progress "Navigating to injector base"
cd "$INJECTOR_BASE" || { log "Injector base not found"; exit 1; }

progress "Running Galaxy AI string repair"
bash ~/nowbrief/repair_galaxy_ai_strings.sh >> "$LOGFILE" 2>&1

progress "Validating XML files"
find res/ -name "*.xml" -exec xmllint --noout {} \; >> "$LOGFILE" 2>&1 || {
  log "XML validation failed"; exit 1;
}

progress "Rebuilding APK"
apktool b . --use-aapt2 -o "$APK_OUT" >> "$LOGFILE" 2>&1 || {
  log "APK build failed"; exit 1;
}

progress "Signing APK"
bash ~/sign_injected_apk.sh "$APK_OUT" >> "$LOGFILE" 2>&1 || {
  log "Signing failed"; exit 1;
}

progress "Pushing APK via ADB"
adb push "$APK_OUT" /data/local/tmp/SmartSuggestionsInjector.apk >> "$LOGFILE" 2>&1

progress "Installing APK"
adb shell pm install -r /data/local/tmp/SmartSuggestionsInjector.apk >> "$LOGFILE" 2>&1

progress "Activating Now Brief"
adb shell am start -n com.samsung.android.smartsuggestions/.ui.NowBriefActivity >> "$LOGFILE" 2>&1

log "✓ Now Brief Injector installed and activated"
echo -e "\n✅ Now Brief is ready. Check your launcher or Smart Hub."
