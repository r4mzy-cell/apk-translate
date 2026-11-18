#!/usr/bin/env python3
# Convert Opus-MT models to ONNX format for Android
# Run this on any machine with Python (Windows/Linux/macOS)

import os
import subprocess
import sys

def run(cmd, cwd=None):
    print(f"  $ {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}")
    return result

def convert_model(model_name, output_dir):
    """Convert Opus-MT model to ONNX INT8 using Optimum"""
    print(f"\n=== Converting {model_name} ===")
    
    # Install dependencies
    run("pip install -U optimum[onnxruntime] onnxruntime transformers sentencepiece")
    
    # Export to ONNX with optimization and INT8 quantization
    # This creates encoder_model_quantized.onnx and decoder_model_merged_quantized.onnx
    cmd = (
        f"optimum-cli export onnx "
        f"--model {model_name} "
        f"--task translation "
        f"--output {output_dir} "
        f"--optimize O1 "
        f"--quantize int8 "
        f"--trust-remote-code"
    )
    run(cmd)
    
    print(f"  Done! Output in {output_dir}")

def main():
    # These are the model IDs on HuggingFace
    models = {
        "Helsinki-NLP/opus-mt-en-id": "opus-mt-en-id-onnx",
        "Helsinki-NLP/opus-mt-id-en": "opus-mt-id-en-onnx",
    }
    
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    for model_id, output_name in models.items():
        output_dir = os.path.join(base_dir, output_name)
        os.makedirs(output_dir, exist_ok=True)
        try:
            convert_model(model_id, output_dir)
        except Exception as e:
            print(f"  ERROR: {e}")
            print(f"  You may need to run this manually:")
            print(f"    optimum-cli export onnx --model {model_id} --task translation --output {output_dir} --optimize O1 --quantize int8")
    
    print("\n=== All models converted ===")
    print("Copy the output folders to your device at:")
    print("  /sdcard/Android/data/com.translateid/files/models/opus-mt-en-id-onnx/")
    print("  /sdcard/Android/data/com.translateid/files/models/opus-mt-id-en-onnx/")
    print("\nEach folder should contain:")
    print("  - encoder_model_quantized.onnx")
    print("  - decoder_model_merged_quantized.onnx")
    print("  - tokenizer.json")
    print("  - config.json")

if __name__ == "__main__":
    main()