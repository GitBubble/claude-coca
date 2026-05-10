# Phase 0: Reference APK Validation Report

**Date**: 2026-05-10  
**Status**: Extraction validated, install readiness confirmed, device/emulator required for runtime validation

## Summary

Phase 0 has successfully verified the structural integrity of the Claude XAPK package and confirmed all tooling required for installation. The XAPK has been extracted into its split APK set. Runnable validation is blocked only by the absence of a connected Android device or emulator.

## Reference Package Metadata

- **App**: Claude
- **Package name**: `com.anthropic.claude`
- **Version**: `1.260430.10` (code: `26043010`)
- **Min SDK**: 29
- **Target SDK**: 36
- **Total size**: 42.3 MB
- **Split APK set**: 36 files (1 base + 35 configuration splits)

### Configuration Splits Available

| Category | Variants |
|---|---|
| **CPU Architectures** | arm64-v8a, armeabi-v7a, x86, x86_64 |
| **Screen Densities** | ldpi, mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi, tvdpi |
| **Languages** | ar, de, en, es, fi, fr, hi, in, it, ja, ko, ms, my, nl, pl, pt, ru, th, tr, vi, zh |

### Permissions Summary

The app requests 70+ permissions across categories:
- **Network**: INTERNET, ACCESS_NETWORK_STATE, FOREGROUND_SERVICE_MEDIA_PLAYBACK
- **Audio/Sensor**: RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, VIBRATE
- **Location**: ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION
- **Biometric**: USE_BIOMETRIC, USE_FINGERPRINT
- **Health**: 30+ READ_* permissions (steps, heart rate, blood pressure, sleep, nutrition, etc.)
- **File access**: READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE
- **Calendar**: READ_CALENDAR, WRITE_CALENDAR
- **Billing**: BILLING (in-app purchases)
- **System**: SET_ALARM, RECEIVE_BOOT_COMPLETED, WAKE_LOCK

## Extraction & Tooling Status

### ✅ Completed

1. **XAPK Structural Validation**
   - Format: XAPK v2 (ZIP-compatible)
   - Integrity: All 36 APK files present and readable
   - Metadata: manifest.json validates correctly
   - Extracted to: `/Users/arthurbetter/project/claude coca/phase0/xapk-extracted/`

2. **Tooling Installed**
   - Java 21 (via Homebrew OpenJDK @21)
   - jadx 1.5.5 (Android decompiler)
   - Android Platform Tools 37.0.0 (adb, fastboot)
   - xapktool (cloned locally)
   - APKEditor.jar (included with xapktool)

3. **Decompilation Ready**
   - Jadx can analyze the extracted base APK
   - Reverse-engineering skill documentation available at ~/.openclaw/workspace/skills/

### ⏸ Blocked (Device/Emulator Required)

1. **Installation Validation**
   - No Android devices detected via `adb devices`
   - No Android emulators running

2. **Single APK Conversion via xapktool**
   - Requires Android build-tools (`zipalign`, `apksigner`)
   - Homebrew android-sdk formula currently broken
   - Workaround: Install Android SDK command-line tools manually, or skip and use split install

## Installation Instructions (When Device Available)

### Split APK Install (Recommended)

```bash
# Ensure device is connected and has USB debugging enabled
adb devices  # Verify connection

# Navigate to extracted directory
cd /Users/arthurbetter/project/claude\ coca/phase0/xapk-extracted

# Install base + architecture + density + language splits for device
# Example: arm64-v8a, hdpi, English
adb install-multiple \
  com.anthropic.claude.apk \
  config.arm64_v8a.apk \
  config.hdpi.apk \
  config.en.apk

# Verify installation
adb shell pm list packages | grep com.anthropic.claude

# Launch the app
adb shell am start -n com.anthropic.claude/com.anthropic.claude.MainActivity
```

### Single APK Install (Requires Build-Tools)

To create a single merged APK for older devices that don't support split installs:

```bash
cd /Users/arthurbetter/project/claude\ coca/xapktool

# Set Java home
export JAVA_HOME="/opt/homebrew/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home"

# Install missing build-tools (if Homebrew formula works):
# brew install android-sdk

# Then run:
# ./convert.sh ../Claude\ by\ Anthropic_1.260430.10_apkcombo.com.xapk claude-merged.apk

# And install:
# adb install claude-merged.apk
```

## Decompilation Readiness (For Reverse-Engineering Reference)

The reverse-engineering skill is available for lawful analysis. To decompile the base APK for architecture/API documentation:

```bash
# Phase 1: Check dependencies
bash ~/.openclaw/workspace/skills/android-reverse-engineering-skill/plugins/android-reverse-engineering/skills/android-reverse-engineering/scripts/check-deps.sh

# Phase 2: Decompile
export JAVA_HOME="/opt/homebrew/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home"
bash ~/.openclaw/workspace/skills/android-reverse-engineering-skill/plugins/android-reverse-engineering/skills/android-reverse-engineering/scripts/decompile.sh \
  /Users/arthurbetter/project/claude\ coca/phase0/xapk-extracted/com.anthropic.claude.apk \
  -o /Users/arthurbetter/project/claude\ coca/phase0/decompiled \
  --engine jadx

# Phase 3-5: Analyze output in phase0/decompiled/sources/
```

## Next Steps

### For Immediate Progress (No Device Required)

1. **Phase 1**: Create HarmonyOS NEXT project skeleton
   - DevEco Studio setup
   - Project structure
   - Navigation scaffold

2. **Reference Analysis** (Optional)
   - Decompile base APK to understand Claude Android architecture
   - Map key features: chat UI, repository connectors, model API integration
   - Extract API patterns (network layers, authentication, streaming responses)

### For Full Phase 0 Validation (Requires Android Device/Emulator)

1. Connect physical Android device (SDK 29+) with USB debugging enabled, or start Android emulator
2. Run split APK install commands above
3. Verify app launches and basic functionality
4. Capture device model, SDK version, installed architecture
5. Test core features: chat, file access, repository login

## Environment Details

**Local Machine Setup**:
- OS: macOS
- Java: OpenJDK 21.0.10 (Homebrew)
- jadx: 1.5.5 (Homebrew)
- adb: 37.0.0 (Homebrew)
- Git: xapktool cloned to `./xapktool`

**Storage**:
- Original XAPK: 40 MB
- Extracted splits: 41 MB (in `phase0/xapk-extracted/`)
- Decompiled source (if done): ~100–200 MB (not yet generated)

## Constraints & Limitations

1. **Android SDK Build-Tools**: Homebrew formula broken; manual installation required for single APK conversion
2. **Device/Emulator**: None currently available; Phase 0 runnable check pending hardware setup
3. **Proprietary Code**: Reverse-engineering is for reference/compatibility analysis only; implementation must be native HarmonyOS code

## Conclusion

Phase 0 has successfully confirmed:
- ✅ XAPK package is structurally valid and extractable
- ✅ All 36 split APKs are present and intact
- ✅ Package metadata is well-formed
- ✅ Installation tooling (adb, Java, APKEditor) is ready
- ⏸ Runtime validation awaits connected device/emulator

**Recommendation**: Proceed to **Phase 1 (HarmonyOS NEXT Skeleton)** in parallel. The native app development does not depend on completing Phase 0 runnable validation. When a device/emulator becomes available, Phase 0 can be completed without blocking Phase 1 progress.
