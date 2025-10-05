apktool b ~/nowbrief_injector/base -o ~/nowbrief_injector/SmartBriefInjector.apk && \
adb install -r ~/nowbrief_injector/SmartBriefInjector.apk && \
adb shell settings put secure enabled_accessibility_services com.mason.injector.smartbrief/com.mason.injector.smartbrief.BriefService && \
adb shell settings put secure accessibility_enabled 1 && \
termux-notification --title "Now Brief Activated" --content "SmartBrief Injector is live. Swipe to launcher to view Now Brief."
