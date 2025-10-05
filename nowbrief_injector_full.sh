#!/data/data/com.termux/files/usr/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# Configuration
INJECTOR_BASE="${INJECTOR_BASE:-$HOME/nowbrief_injector/base}"
REPAIR_SCRIPT="${REPAIR_SCRIPT:-$HOME/nowbrief/repair_galaxy_ai_strings.sh}"
SIGN_SCRIPT="${SIGN_SCRIPT:-$HOME/sign_injected_apk.sh}"
APK_OUT="${APK_OUT:-$HOME/nowbrief_injector/SmartSuggestionsInjector.apk}"
TMP_REMOTE="/data/local/tmp/SmartSuggestionsInjector.apk"
DOWNLOADS_PATH="${DOWNLOADS_PATH:-$HOME/storage/downloads}"
LOGFILE="${LOGFILE:-$DOWNLOADS_PATH/injector_log.txt}"
ADB_BIN="${ADB_BIN:-adb}"
APKTOOL_BIN="${APKTOOL_BIN:-apktool}"
XMLLINT_BIN="${XMLLINT_BIN:-xmllint}"

# Helpers
_now() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf "%s %s\n" "$(_now)" "$1" | tee -a "$LOGFILE"; }
err() { printf "%s ERROR: %s\n" "$(_now)" "$1" | tee -a "$LOGFILE" >&2; }
progress_bar() {
  local msg="$1"; local i
  printf "%s " "$msg"
  for i in {1..20}; do printf "█"; sleep 0.02; done
  printf " \n"
}

safe_cd() {
  if ! cd "$1" 2>/dev/null; then
    err "Directory not found: $1"
    exit 1
  fi
}

ensure_downloads() {
  # Termux-specific storage may require termux-setup-storage; try both common writable places
  if [ -d "$HOME/storage/downloads" ]; then
    mkdir -p "$HOME/storage/downloads"
    DOWNLOADS_PATH="$HOME/storage/downloads"
  else
    mkdir -p "$HOME/downloads"
    DOWNLOADS_PATH="$HOME/downloads"
  fi
  LOGFILE="$DOWNLOADS_PATH/injector_log.txt"
  touch "$LOGFILE" || { echo "Cannot write to $LOGFILE"; exit 1; }
}

check_bin() {
  local b="$1"
  command -v "$b" >/dev/null 2>&1 || { err "Required binary not found in PATH: $b"; exit 1; }
}

# Start
ensure_downloads
log "Starting Now Brief injector flow"
log "Injector base: $INJECTOR_BASE"
log "Logfile: $LOGFILE"

# Basic prerequisites
check_bin "$APKTOOL_BIN"
check_bin "$XMLLINT_BIN"
check_bin "$ADB_BIN"

# 1) Go to injector base
progress_bar "Step 1/8: Navigating to injector base"
safe_cd "$INJECTOR_BASE"

# 2) Repair strings if present
if [ -x "$REPAIR_SCRIPT" ] || [ -f "$REPAIR_SCRIPT" ]; then
  progress_bar "Step 2/8: Running repair script"
  log "Running repair script: $REPAIR_SCRIPT"
  if bash "$REPAIR_SCRIPT" >> "$LOGFILE" 2>&1; then
    log "Repair script finished without fatal error"
  else
    err "Repair script returned non-zero; continuing but check log"
  fi
else
  log "Repair script not found or not executable: $REPAIR_SCRIPT — skipping"
fi

# 3) Validate all XML files and auto-fix simple common issues
progress_bar "Step 3/8: Validating XML files"
log "Validating XML files under $INJECTOR_BASE/res"
find res/ -name "*.xml" -print0 | while IFS= read -r -d '' file; do
  if ! "$XMLLINT_BIN" --noout "$file" 2>>"$LOGFILE"; then
    log "xmllint failed on $file — attempting safe fixes"
    # safe fixes: close unterminated attribute quotes, escape stray ampersands
    sed -i.bak -E 's/="\s*([^"]*)$/="\1"/' "$file" || true
    sed -i.bak -E 's/&([^a-zA-Z0-9#;])/\&amp;\1/g' "$file" || true
    if "$XMLLINT_BIN" --noout "$file" 2>>"$LOGFILE"; then
      log "Fixed and validated $file"
    else
      err "Persistent XML error in $file — see log"
    fi
  fi
done

# 4) Rebuild APK
progress_bar "Step 4/8: Rebuilding APK"
log "Rebuilding with $APKTOOL_BIN"
if "$APKTOOL_BIN" b . --use-aapt2 -o "$APK_OUT" >>"$LOGFILE" 2>&1; then
  log "APK rebuild created: $APK_OUT"
else
  err "apktool build failed; aborting"
  exit 1
fi

# 5) Sign APK (if sign script exists)
progress_bar "Step 5/8: Signing APK"
if [ -x "$SIGN_SCRIPT" ] || [ -f "$SIGN_SCRIPT" ]; then
  log "Signing APK with $SIGN_SCRIPT"
  if bash "$SIGN_SCRIPT" "$APK_OUT" >>"$LOGFILE" 2>&1; then
    log "APK signed successfully"
  else
    err "Signing script failed; APK may be unsigned"
  fi
else
  log "No signing script found at $SIGN_SCRIPT — APK will be unsigned"
fi

# 6) Push APK via ADB (with retries)
progress_bar "Step 6/8: Pushing APK to device via ADB"
log "Pushing $APK_OUT to $TMP_REMOTE"
push_attempts=0
while [ "$push_attempts" -lt 3 ]; do
  push_attempts=$((push_attempts+1))
  if "$ADB_BIN" push "$APK_OUT" "$TMP_REMOTE" >>"$LOGFILE" 2>&1; then
    log "Push succeeded (attempt $push_attempts)"
    break
  else
    log "Push attempt $push_attempts failed; retrying in 2s"
    sleep 2
  fi
done
if [ "$push_attempts" -ge 3 ]; then err "ADB push failed after retries"; exit 1; fi

# 7) Install APK (with retry and install-mode detection)
progress_bar "Step 7/8: Installing APK on device"
install_attempts=0
while [ "$install_attempts" -lt 4 ]; do
  install_attempts=$((install_attempts+1))
  if "$ADB_BIN" shell pm install -r "$TMP_REMOTE" >>"$LOGFILE" 2>&1; then
    log "Install succeeded (attempt $install_attempts)"
    break
  else
    log "Install attempt $install_attempts failed; trying legacy path"
    # try install via pm install -r -d (allow version downgrade) then fallback to pm install-temp
    if "$ADB_BIN" shell pm install -r -d "$TMP_REMOTE" >>"$LOGFILE" 2>&1; then
      log "Install (with downgrade) succeeded"
      break
    fi
  fi
  sleep 2
done
if [ "$install_attempts" -ge 4 ]; then err "Install failed after retries"; exit 1; fi

# 8) Activate Now Brief and confirm
progress_bar "Step 8/8: Activating Now Brief and confirming readiness"
PACKAGE="com.samsung.android.smartsuggestions"
ACTIVITY="com.samsung.android.smartsuggestions/.ui.NowBriefActivity"
log "Attempting to start activity $ACTIVITY"
if "$ADB_BIN" shell am start -n "$ACTIVITY" >>"$LOGFILE" 2>&1; then
  log "Start intent sent"
else
  log "Start intent may have failed; trying package broadcast and launch by package"
  "$ADB_BIN" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >>"$LOGFILE" 2>&1 || true
fi

# Wait and check for process presence
sleep 2
if "$ADB_BIN" shell pidof com.samsung.android.smartsuggestions >>"$LOGFILE" 2>&1; then
  log "Now Brief process detected — Now Brief should be ready"
  echo "✅ Now Brief appears active on device"
else
  err "Now Brief process not detected. Check device UI and logs"
fi

log "Full injector flow complete"
log "Detailed logfile: $LOGFILE"
echo "Logs: $LOGFILE"
