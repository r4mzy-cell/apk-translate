@echo off
REM Convert Opus-MT models to ONNX format for Android
REM Run this in PowerShell or Command Prompt (requires Python)

echo === Converting Opus-MT models to ONNX INT8 ===
echo.

REM Install dependencies
echo Installing Python dependencies...
pip install -U optimum[onnxruntime] onnxruntime transformers sentencepiece
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    exit /b 1
)

echo.
echo === Converting English -> Indonesian ===
optimum-cli export onnx --model Helsinki-NLP/opus-mt-en-id --task translation --output opus-mt-en-id-onnx --optimize O1 --quantize int8 --trust-remote-code
if errorlevel 1 (
    echo ERROR: Failed to convert en-id model
    exit /b 1
)

echo.
echo === Converting Indonesian -> English ===
optimum-cli export onnx --model Helsinki-NLP/opus-mt-id-en --task translation --output opus-mt-id-en-onnx --optimize O1 --quantize int8 --trust-remote-code
if errorlevel 1 (
    echo ERROR: Failed to convert id-en model
    exit /b 1
)

echo.
echo === Conversion complete ===
echo.
echo Copy these folders to your device:
echo   /sdcard/Android/data/com.translateid/files/models/opus-mt-en-id-onnx/
echo   /sdcard/Android/data/com.translateid/files/models/opus-mt-id-en-onnx/
echo.
echo Each folder should contain:
echo   - encoder_model_quantized.onnx
echo   - decoder_model_merged_quantized.onnx
echo   - tokenizer.json
echo   - config.json

pause