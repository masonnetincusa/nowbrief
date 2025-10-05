#!/data/data/com.termux/files/usr/bin/bash

echo -e "\e[1;36m🔧 Injecting SmartBrief payload into base APK...\e[0m"
sleep 1

WORKDIR="$HOME/nowbrief_injector"
BASE="$WORKDIR/base"

progress() {
  echo "$1"
  sleep 0.5
}

progress "📁 Creating target folders..."
mkdir -p "$BASE/res/layout" "$BASE/res/xml" "$BASE/smali/com/mason/injector/smartbrief"

progress "📥 Copying Fold 6 layouts..."
cp "$WORKDIR/fold6_payload/res/layout/suggestion_ui_app_widget_brief.xml" "$BASE/res/layout/"
cp "$WORKDIR/fold6_payload/res/layout/now_brief_widget_setting_layout.xml" "$BASE/res/layout/"

progress "🧠 Injecting dummy BriefService..."
cat > "$BASE/smali/com/mason/injector/smartbrief/BriefService.smali" << 'EOF'
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

progress "🧩 Creating accessibility config..."
cat > "$BASE/res/xml/accessibility_config.xml" << 'EOF'
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canRetrieveWindowContent="true"
    android:settingsActivity="com.mason.injector.smartbrief.SettingsActivity" />
EOF

progress "🧼 Validating and repairing XML..."
find "$BASE/res" -type f -name "*.xml" -exec grep -l 'android:[a-zA-Z]*="[^"]*$' {} \; | while read -r file; do
  echo "🔧 Fixing malformed XML: $file"
  sed -i 's/\(android:[a-zA-Z]*="\([^"]*\)\)$/\1"/g' "$file"
done

progress "✅ Payload injection complete. Ready to build."
