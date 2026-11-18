#!/bin/bash
# ============================================
# Download native libraries for Android
# Run this in WSL2 (Ubuntu) or Linux/macOS
# ============================================

set -e

PROJECT_DIR="$(pwd)"
JNI_DIR="$PROJECT_DIR/android/app/src/main/jniLibs"

echo "Creating jniLibs directories..."
mkdir -p "$JNI_DIR/arm64-v8a"
mkdir -p "$JNI_DIR/armeabi-v7a"

# ============================================
# 1. Sherpa-ONNX (prebuilt from GitHub)
# ============================================
SHERPA_VERSION="1.12.1"
SHERPA_BASE="https://github.com/k2-fsa/sherpa-onnx/releases/download/v$SHERPA_VERSION"

download_sherpa() {
    local arch=$1
    local jni_arch=$2
    local url="$SHERPA_BASE/sherpa-onnx-$SHERPA_VERSION-android-$arch.tar.gz"
    local tmpdir=$(mktemp -d)
    
    echo "Downloading Sherpa-ONNX for $arch..."
    wget -q "$url" -O "$tmpdir/sherpa.tar.gz"
    
    echo "Extracting..."
    tar -xzf "$tmpdir/sherpa.tar.gz" -C "$tmpdir"
    tar -xf "$tmpdir/sherpa-onnx-$SHERPA_VERSION-android-$arch.tar" -C "$tmpdir"
    
    echo "Copying to $JNI_DIR/$jni_arch/..."
    cp "$tmpdir/lib/libsherpa-onnx-jni.so" "$JNI_DIR/$jni_arch/"
    
    rm -rf "$tmpdir"
    echo "Done: $jni_arch"
}

download_sherpa "aarch64" "arm64-v8a"
download_sherpa "arm" "armeabi-v7a"

# ============================================
# 2. ONNX Runtime (from Microsoft's Maven)
# ============================================
# We don't need to download .so separately - it's in the AAR
# The Gradle dependency `com.microsoft.onnxruntime:onnxruntime:1.18.0` handles it
# But if you want the raw .so for inspection:
download_onnxruntime() {
    local version="1.18.0"
    local tmpdir=$(mktemp -d)
    
    echo "Downloading ONNX Runtime AAR..."
    wget -q "https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-android-$version.aar" -O "$tmpdir/onnxruntime.aar"
    
    echo "Extracting native libs..."
    unzip -q "$tmpdir/onnxruntime.aar" -d "$tmpdir/aar"
    
    for arch in arm64-v8a armeabi-v7a; do
        if [ -f "$tmpdir/aar/jni/$arch/libonnxruntime.so" ]; then
            cp "$tmpdir/aar/jni/$arch/libonnxruntime.so" "$JNI_DIR/$arch/"
            echo "Copied libonnxruntime.so to $arch"
        fi
    done
    
    rm -rf "$tmpdir"
}

# download_onnxruntime  # Uncomment if you want local .so files (not needed with Gradle dep)

# ============================================
# 3. Verify
# ============================================
echo ""
echo "=== Verification ==="
for arch in arm64-v8a armeabi-v7a; do
    echo "--- $arch ---"
    ls -la "$JNI_DIR/$arch/"
done

echo ""
echo "Done! Next steps:"
echo "1. Convert Opus-MT models to ONNX INT8:"
echo "   pip install ctranslate2[transformers]"
echo "   python -m ctranslate2.converters --model Helsinki-NLP/opus-mt-en-id --output_dir models/ctranslate-en-id --quantization int8"
echo "   python -m ctranslate2.converters --model Helsinki-NLP/opus-mt-id-en --output_dir models/ctranslate-id-en --quantization int8"
echo ""
echo "2. Copy converted models to device /sdcard/Android/data/com.translateid/files/models/"
echo "   Each model dir should contain: model.onnx, vocabulary.json, tokenizer.json, config.json"
echo ""
echo "3. Build and run: flutter build apk --release"