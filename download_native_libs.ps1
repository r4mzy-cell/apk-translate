# ============================================
# Download native libraries for Android (Windows PowerShell)
# Run in PowerShell as Administrator
# ============================================

$projectDir = "D:\opencode project\apk translate"
$jniDir = "$projectDir\android\app\src\main\jniLibs"

Write-Host "Creating jniLibs directories..."
New-Item -ItemType Directory -Force -Path "$jniDir\arm64-v8a" | Out-Null
New-Item -ItemType Directory -Force -Path "$jniDir\armeabi-v7a" | Out-Null

# ============================================
# 1. Sherpa-ONNX (prebuilt from GitHub)
# ============================================
$version = "1.12.1"
$baseUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/v$version"

function Download-Sherpa {
    param($arch, $jniArch, $url)
    
    Write-Host "Downloading Sherpa-ONNX for $arch..."
    $zip = "$env:TEMP\sherpa-$arch.tar.gz"
    Invoke-WebRequest -Uri $url -OutFile $zip
    
    Write-Host "Extracting..."
    $tmp = "$env:TEMP\sherpa-$arch"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    
    # Extract .tar.gz -> .tar -> files (requires 7-Zip)
    & "C:\Program Files\7-Zip\7z.exe" x $zip -o$tmp -y | Out-Null
    $tar = "$tmp\sherpa-onnx-$version-android-$arch.tar"
    if (Test-Path $tar) {
        & "C:\Program Files\7-Zip\7z.exe" x $tar -o$tmp -y | Out-Null
    }
    
    $srcLib = "$tmp\lib\libsherpa-onnx-jni.so"
    $dstLib = "$jniDir\$jniArch\libsherpa-onnx-jni.so"
    if (Test-Path $srcLib) {
        Copy-Item $srcLib $dstLib -Force
        Write-Host "Copied to $jniArch"
    } else {
        Write-Warning "Library not found at $srcLib"
    }
    
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

Download-Sherpa -arch "aarch64" -jniArch "arm64-v8a" -url "$baseUrl/sherpa-onnx-$version-android-aarch64.tar.gz"
Download-Sherpa -arch "arm" -jniArch "armeabi-v7a" -url "$baseUrl/sherpa-onnx-$version-android-arm.tar.gz"

# ============================================
# 2. ONNX Runtime (from GitHub release AAR)
# ============================================
# Optional - Gradle dependency handles this automatically
# But you can extract the .so for verification:
$onnxVersion = "1.18.0"
$onnxUrl = "https://github.com/microsoft/onnxruntime/releases/download/v$onnxVersion/onnxruntime-android-$onnxVersion.aar"
$onnxZip = "$env:TEMP\onnxruntime.aar"

Write-Host "Downloading ONNX Runtime AAR..."
Invoke-WebRequest -Uri $onnxUrl -OutFile $onnxZip

$onnxTmp = "$env:TEMP\onnxruntime"
New-Item -ItemType Directory -Force -Path $onnxTmp | Out-Null
& "C:\Program Files\7-Zip\7z.exe" x $onnxZip -o"$onnxTmp\aar" -y | Out-Null

foreach ($arch in @("arm64-v8a", "armeabi-v7a")) {
    $src = "$onnxTmp\aar\jni\$arch\libonnxruntime.so"
    $dst = "$jniDir\$arch\libonnxruntime.so"
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "Copied libonnxruntime.so to $arch"
    }
}

Remove-Item -Recurse -Force $onnxTmp -ErrorAction SilentlyContinue

# ============================================
# 3. Verify
# ============================================
Write-Host ""
Write-Host "=== Verification ==="
foreach ($arch in @("arm64-v8a", "armeabi-v7a")) {
    Write-Host "--- $arch ---"
    Get-ChildItem "$jniDir\$arch" | Format-Table Name, Length
}

Write-Host ""
Write-Host "Done! Next steps:"
Write-Host "1. Convert Opus-MT models to ONNX INT8 (run in WSL/Linux/macOS or Python):"
Write-Host "   pip install ctranslate2[transformers]"
Write-Host "   python -m ctranslate2.converters --model Helsinki-NLP/opus-mt-en-id --output_dir models/ctranslate-en-id --quantization int8"
Write-Host "   python -m ctranslate2.converters --model Helsinki-NLP/opus-mt-id-en --output_dir models/ctranslate-id-en --quantization int8"
Write-Host ""
Write-Host "2. Each model dir should contain: model.onnx, vocabulary.json, tokenizer.json, config.json"
Write-Host ""
Write-Host "3. Place models on device at: /sdcard/Android/data/com.translateid/files/models/"
Write-Host ""
Write-Host "4. Build: flutter build apk --release"