#!/usr/bin/env python3
"""
TFLite to ONNX Model Converter

Converts TensorFlow Lite models to ONNX format for use with ONNX Runtime.
This enables GPU acceleration on Windows (DirectML) and Linux (CUDA).

Usage:
    python convert_tflite_to_onnx.py input.tflite output.onnx

Requirements:
    pip install tf2onnx tensorflow onnx
"""

import sys
import subprocess
import os

def convert_tflite_to_onnx(input_path: str, output_path: str):
    """Convert TFLite model to ONNX format."""
    
    if not os.path.exists(input_path):
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)
    
    # Use tf2onnx command line tool
    cmd = [
        sys.executable, "-m", "tf2onnx.convert",
        "--tflite", input_path,
        "--output", output_path,
        "--opset", "13",  # ONNX opset version
    ]
    
    print(f"Converting {input_path} to {output_path}...")
    print(f"Command: {' '.join(cmd)}")
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"Error during conversion:")
        print(result.stderr)
        sys.exit(1)
    
    print(result.stdout)
    print(f"Successfully converted to: {output_path}")
    
    # Verify output
    if os.path.exists(output_path):
        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"Output size: {size_mb:.2f} MB")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        print("\nExample:")
        print("  python convert_tflite_to_onnx.py mobilenet_v2.tflite mobilenet_v2.onnx")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    
    convert_tflite_to_onnx(input_path, output_path)


if __name__ == "__main__":
    main()
