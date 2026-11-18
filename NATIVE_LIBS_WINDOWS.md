# Native Library Download for Windows

## Option 1: Download Prebuilt Sherpa-ONNX (Recommended)

### Via Browser (Manual)
1. Open: https://github.com/k2-fsa/sherpa-onnx/releases
2. Download latest `sherpa-onnx-<version>-android-aarch64.tar.gz` and `sherpa-onnx-<version>-android-arm.tar.gz`
3. Extract using 7-Zip or WinRAR
4. Copy `lib/libsherpa-onnx-jni.so` from each to:
   - `android/app/src/main/jniLibs/arm64-v8a/libsherpa-onnx-jni.so`
   - `android/app/src/main/jniLibs/armeabi-v7a/libsherpa-onnx-jni.so`

### Via PowerShell (Automated)
```powershell
# Run in PowerShell as Administrator
$version = "1.12.1"
$baseUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/v$version"

# Create directories
New-Item -ItemType Directory -Force -Path "D:\opencode project\apk translate\android\app\src\main\jniLibs\arm64-v8a"
New-Item -ItemType Directory -Force -Path "D:\opencode project\apk translate\android\app\src\main\jniLibs\armeabi-v7a"

# Download arm64
$arm64Url = "$baseUrl/sherpa-onnx-$version-android-aarch64.tar.gz"
$arm64Zip = "$env:TEMP\sherpa-arm64.tar.gz"
Invoke-WebRequest -Uri $arm64Url -OutFile $arm64Zip

# Download arm32
$arm32Url = "$baseUrl/sherpa-onnx-$version-android-arm.tar.gz"
$arm32Zip = "$env:TEMP\sherpa-arm32.tar.gz"
Invoke-WebRequest -Uri $arm32Url -OutFile $arm32Zip

# Extract using 7-Zip (install if needed: choco install 7zip)
& "C:\Program Files\7-Zip\7z.exe" x $arm64Zip -o"$env:TEMP\sherpa-arm64" -y
& "C:\Program Files\7-Zip\7z.exe" x "$env:TEMP\sherpa-arm64\sherpa-onnx-$version-android-aarch64.tar" -o"$env:TEMP\sherpa-arm64" -y
Copy-Item "$env:TEMP\sherpa-arm64\lib\libsherpa-onnx-jni.so" "D:\opencode project\apk translate\android\app\src\main\jniLibs\arm64-v8a\"

& "C:\Program Files\7-Zip\7z.exe" x $arm32Zip -o"$env:TEMP\sherpa-arm32" -y
& "C:\Program Files\7-Zip\7z.exe" x "$env:TEMP\sherpa-arm32\sherpa-onnx-$version-android-arm.tar" -o"$env:TEMP\sherpa-arm32" -y
Copy-Item "$env:TEMP\sherpa-arm32\lib\libsherpa-onnx-jni.so" "D:\opencode project\apk translate\android\app\src\main\jniLibs\armeabi-v7a\"
```

---

## Option 2: CTranslate2 - Use Hugging Face Prebuilt (Easier)

CTranslate2 doesn't officially provide Android .so. **Simpler approach:** Use the Python/ONNX runtime via a different strategy, OR build via Docker/WSL.

### Quick Alternative: Use Python CTranslate2 via FFI (Not JNI)
Instead of JNI, you can call CTranslate2 Python API from Dart using `flutter_ffi` + Python embedding, but that's complex.

### Recommended: Build via WSL2 (Windows Subsystem for Linux)
```bash
# In WSL2 (Ubuntu)
sudo apt update && sudo apt install -y cmake ninja-build git python3-pip
git clone --depth 1 https://github.com/OpenNMT/CTranslate2.git
cd CTranslate2

# Android NDK path (install via Android Studio)
export ANDROID_NDK=/home/$USER/Android/Sdk/ndk/27.0.12077973

# Build for arm64
mkdir build_arm64 && cd build_arm64
cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-29 \
      -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --config Release -j$(nproc)

# Build for arm32
cd .. && mkdir build_arm && cd build_arm
cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-29 \
      -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --config Release -j$(nproc)

# Copy libctranslate2.so from both build dirs to your jniLibs
```

---

## Option 3: Skip CTranslate2 JNI — Use ONNX Runtime Directly (Simpler on Windows)

Since you're on Windows, consider **ONNX Runtime** instead of CTranslate2:

1. **Download ONNX Runtime Android**: https://github.com/microsoft/onnxruntime/releases
   - `onnxruntime-android-<version>.aar` → extract `.so` files
2. **Convert Opus-MT to ONNX** (one-time, can do on any machine):
   ```bash
   pip install ctranslate2[transformers] onnx
   python -c "
   from ctranslate2.converters import TransformersConverter
   converter = TransformersConverter('Helsinki-NLP/opus-mt-en-id')
   converter.convert('opus-mt-en-id-onnx', quantization='int8')
   "
   ```
3. Use ONNX Runtime from Kotlin/Java (much easier JNI, well documented)

---

## Option 4: Use GitHub Actions to Build (No Local Build Needed)

Add a workflow that builds the .so files and uploads as artifacts:

```yaml
# .github/workflows/build-native.yml
name: Build Native Libraries
on: [workflow_dispatch]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Sherpa-ONNX
        run: |
          # ... build commands
      - name: Build CTranslate2
        run: |
          # ... build commands
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: native-libs
          path: |
            jniLibs/arm64-v8a/*.so
            jniLibs/armeabi-v7a/*.so
```

Then download from Actions artifacts.

---

## My Recommendation for You (Windows)

**Fastest path:**
1. **Sherpa-ONNX**: Use Option 1 PowerShell script above (prebuilt exists)
2. **CTranslate2**: Switch to **ONNX Runtime** (Microsoft provides official Android AAR)
   - Download: https://github.com/microsoft/onnxruntime/releases/tag/v1.18.0
   - File: `onnxruntime-android-1.18.0.aar` → rename to `.zip` → extract `jni/arm64-v8a/libonnxruntime.so` etc.
   - Convert your Opus-MT models to ONNX INT8 (run once on any machine with Python)
   - Update `CTranslateWrapper.kt` to use ONNX Runtime API instead

This avoids building C++ from source entirely.

---

## Verify Placement

After download, confirm:
```powershell
ls "D:\opencode project\apk translate\android\app\src\main\jniLibs\arm64-v8a"
ls "D:\opencode project\apk translate\android\app\src\main\jniLibs\armeabi-v7a"
```
Should show:
- `libsherpa-onnx-jni.so` (both folders)
- `libonnxruntime.so` (both folders) — if using ONNX Runtime