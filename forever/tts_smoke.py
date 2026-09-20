"""Smoke test: does Chatterbox run on the GPU in this environment?

Run with forever/run.sh:  ./forever/run.sh python forever/tts_smoke.py
"""
import sys
import time

import torch

print("torch", torch.__version__, "cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))

import torchaudio as ta
from chatterbox.tts import ChatterboxTTS

t0 = time.time()
model = ChatterboxTTS.from_pretrained(device="cuda" if torch.cuda.is_available() else "cpu")
print(f"model loaded in {time.time() - t0:.1f}s, sample rate {model.sr}")

text = "Greetings, traveler. The winds of Zephras Isle have carried your name to us. Rest here a while before the storm returns."
t0 = time.time()
wav = model.generate(text)
dur = wav.shape[-1] / model.sr
print(f"generated {dur:.1f}s of audio in {time.time() - t0:.1f}s")
out = sys.argv[1] if len(sys.argv) > 1 else "forever/smoke.wav"
ta.save(out, wav, model.sr)
print("wrote", out)
