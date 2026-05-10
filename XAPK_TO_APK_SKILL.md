---
description: Convert Android XAPK split-APK bundles to single installable APK files using xapktool, with dependency verification and output validation. Use when you need to merge and sign XAPK files for direct installation on Android devices.
trigger: convert XAPK|xapk to apk|merge XAPK|xapktool|single APK|installable APK
---

# XAPK to APK Converter Skill

Automate the conversion of Android XAPK (split APK bundle) files into single, installable APK files using xapktool. This workflow handles dependency checks, validates package integrity, merges all splits, and produces a signed APK ready for direct installation.

## Use Cases

- **Convert app bundles**: Download `.xapk` files from APK mirror sites and convert to single `.apk` for installation
- **Test on older devices**: Merge all splits into one APK for Android devices that don't support split installs
- **Reference app analysis**: Extract and analyze the merged package structure before decompilation
- **Distribution**: Create portable APK copies for offline deployment or testing

## Prerequisites

This skill requires:

1. **Java Runtime**: JDK/JRE 8+ (tested with OpenJDK 21)
2. **Android Build-Tools**: `zipalign` and `apksigner` commands
3. **xapktool repository**: Clone from `https://github.com/koai-dev/xapktool.git`
4. **APKEditor.jar**: Included with xapktool; placed at `xapktool/bin/APKEditor.jar`

## Workflow

### Phase 1: Verify and Prepare Environment

**Goal**: Ensure all tools are available and xapktool is properly set up.

**Actions**:

1. **Check Java runtime**:
   ```bash
   command -v java
   java -version
   # If missing, install via Homebrew: brew install openjdk@21
   # Or use system Java at /opt/homebrew/opt/openjdk@21/bin/java
   ```

2. **Clone xapktool** (if not already present):
   ```bash
   cd <workspace>
   git clone https://github.com/koai-dev/xapktool.git
   cd xapktool && chmod +x convert.sh
   ```

3. **Create bin directory and link APKEditor.jar**:
   ```bash
   cd xapktool
   mkdir -p bin
   ln -sf ../APKEditor.jar bin/APKEditor.jar
   ```

4. **Verify xapktool structure**:
   ```bash
   ls -la APKEditor.jar
   ls -la bin/APKEditor.jar
   ls -la convert.sh
   ```

### Phase 2: Install Android Build-Tools

**Goal**: Provide `zipalign` and `apksigner` commands required by convert.sh.

**Actions**:

1. **Check if build-tools already installed**:
   ```bash
   command -v zipalign
   command -v apksigner
   ```

2. **Install via Homebrew (macOS)**:
   ```bash
   brew install --cask android-commandlinetools
   # Installs to: /opt/homebrew/share/android-commandlinetools
   ```

3. **Install build-tools and platform-tools via sdkmanager**:
   ```bash
   export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
   export JAVA_HOME="/opt/homebrew/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home"
   
   # Accept licenses
   yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses
   
   # Install build-tools and platform-tools
   sdkmanager --sdk_root="$ANDROID_SDK_ROOT" "build-tools;36.0.0" "platform-tools"
   ```

4. **Verify installation**:
   ```bash
   export PATH="/opt/homebrew/share/android-commandlinetools/build-tools/36.0.0:$PATH"
   command -v zipalign && zipalign -h | head -2
   command -v apksigner && apksigner --version
   ```

### Phase 3: Validate XAPK Input

**Goal**: Confirm the XAPK file is structurally valid and extractable.

**Actions**:

1. **Check XAPK file**:
   ```bash
   file <input.xapk>
   # Should report: "Zip archive data, at least v1.0 to extract"
   ```

2. **Verify XAPK contents**:
   ```bash
   unzip -l <input.xapk> | head -40
   # Should show: 1 base APK (com.*.apk) + config APKs (config.*.apk)
   ```

3. **Inspect manifest**:
   ```bash
   unzip -p <input.xapk> manifest.json | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))" | head -50
   # Should show: xapk_version, package_name, version_code, min_sdk_version, split_apks array
   ```

### Phase 4: Execute Conversion

**Goal**: Merge all split APKs, zipalign, and sign the output APK.

**Actions**:

1. **Set up environment variables** (adjust paths as needed for your system):
   ```bash
   export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
   export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
   export PATH="$ANDROID_SDK_ROOT/build-tools/36.0.0:$PATH"
   ```

2. **Verify all tools are on PATH**:
   ```bash
   command -v java && command -v zipalign && command -v apksigner
   ```

3. **Run conversion**:
   ```bash
   cd xapktool
   ./convert.sh "<absolute/path/to/input.xapk>" "output-name.apk"
   ```

   The script will:
   - Extract the XAPK
   - Merge all split APKs using APKEditor.jar
   - Zipalign the merged APK (4-byte alignment)
   - Create a debug keystore (if not present)
   - Sign the APK with the debug key
   - Clean up temporary files

4. **Monitor progress** (script outputs multiple phases):
   - `>> Merging XAPK...` — merges splits into single APK
   - `>> Zipaligning...` — optimizes APK for installation
   - `>> Signing...` — signs with debug key
   - `>> Success! Output: <path>`

### Phase 5: Validate Output

**Goal**: Confirm the signed APK is valid and installable.

**Actions**:

1. **Check output file size and format**:
   ```bash
   ls -lh <output.apk>
   file <output.apk>
   # Should report: "Zip archive data" and size close to sum of input splits
   ```

2. **Compute integrity checksum**:
   ```bash
   shasum -a 256 <output.apk>
   # Store for verification records
   ```

3. **Inspect APK structure** (if available, optional):
   ```bash
   unzip -l <output.apk> | head -50
   # Should show: AndroidManifest.xml, classes.dex(es), resources.arsc, etc.
   ```

4. **Test installation** (requires connected Android device/emulator, SDK 29+):
   ```bash
   adb devices -l  # Verify device connected
   adb install -r <output.apk>
   # Monitor output for "Success" or error
   ```

5. **Verify app is installed**:
   ```bash
   adb shell pm list packages | grep <package_name>
   # Should list the installed package
   ```

## Output Artifacts

- **signed APK**: `<output>.apk` — ready for direct installation on Android devices
- **integrity checksum**: SHA-256 hash for verification
- **size ratio**: Typically 60–80% of input XAPK size (removes redundant splits, adds signature)

## Decision Points

| Question | Action |
|---|---|
| **Java not found?** | Install via Homebrew: `brew install openjdk@21` or use existing JDK |
| **zipalign/apksigner missing?** | Install Android SDK via Homebrew: `brew install --cask android-commandlinetools`, then use sdkmanager to fetch build-tools |
| **APKEditor.jar not found?** | Ensure xapktool is properly cloned and `bin/APKEditor.jar` symlink exists |
| **Conversion fails with merge error?** | Re-validate input XAPK with unzip; ensure all 30+ config APKs are present |
| **No connected device for install test?** | Proceed with output artifact; store APK for later testing or distribution |

## Common Issues & Fixes

| Error | Root Cause | Solution |
|---|---|---|
| `Error: Java is not installed` | `java` not in PATH or JRE missing | Set `export JAVA_HOME=...` and prepend to PATH |
| `Error: zipalign is not installed` | Build-tools not installed or not in PATH | Run sdkmanager to fetch build-tools/36.0.0; prepend to PATH |
| `Error: APKEditor.jar not found at ./bin/APKEditor.jar` | Symlink not created or xapktool not cloned | Run `mkdir -p bin && ln -sf ../APKEditor.jar bin/APKEditor.jar` |
| `Error: Merge failed` | XAPK file corrupted or missing splits | Re-validate input with `unzip -l` and `file` commands |
| `adb install: device not found` | No Android device connected or adb not in PATH | Connect device via USB with debugging enabled, or start Android emulator |

## Example Prompts to Trigger Skill

- "Convert this XAPK to an installable APK"
- "Merge the Claude XAPK into a single APK"
- "I have a .xapk file and need a .apk for my Android device"
- "Use xapktool to convert [file]"
- "Create a single APK from the split bundle"

## Integration with Phase 0 Validation

This skill complements **Phase 0: Reference APK Validation**:
- **Phase 0**: Validates the XAPK structure, extracts splits, and documents metadata
- **This skill**: Produces a direct-install APK for compatibility testing
- **Together**: Enable both reverse-engineering analysis and runnable validation

## Related Skills & Customizations

- **Android Reverse-Engineering Skill**: Decompile the merged APK to understand architecture and API patterns
- **APK Signing & Distribution**: Extend for release signing, app bundle analysis, or automated testing
- **Device Management**: Automate multi-device install, uninstall, and feature testing pipelines

## Environment Tested

- **macOS**: Monterey, Ventura, Sonoma (Homebrew-based setup)
- **Java**: OpenJDK 21.0.10
- **Android Build-Tools**: 36.0.0
- **xapktool**: Latest from `koai-dev/xapktool` (as of 2026-05-10)
- **Input**: Claude by Anthropic v1.260430.10 (XAPK v2, 40 MB, 36 splits)
- **Output**: 26 MB single signed APK

## Exit Criteria (Skill Complete)

✅ XAPK converted to single APK  
✅ Output APK is properly signed  
✅ Output APK passes basic validation (structure, size, checksum)  
✅ Output APK installs on Android device (if device available)  
✅ Output artifact stored and documented

