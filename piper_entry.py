"""
Piper TTS entry point for PyInstaller bundling.
Wraps `python3 -m piper` as a standalone binary.
"""
import runpy
import sys

if __name__ == "__main__":
    sys.argv[0] = "piper"
    runpy.run_module("piper", run_name="__main__", alter_sys=True)
