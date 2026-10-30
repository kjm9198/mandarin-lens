"""Offline transcription of one bounded PCM clip. Never receives the expected word."""
import os, sys, json, wave, contextlib
os.environ.update(HF_HUB_OFFLINE="1", TRANSFORMERS_OFFLINE="1", HF_HUB_DISABLE_TELEMETRY="1")
try:
    import numpy as np
    with wave.open(sys.argv[2], "rb") as audio:
        if audio.getnchannels() != 1 or audio.getsampwidth() != 2 or audio.getframerate() != 16000 or audio.getnframes() > 16 * 16000:
            raise ValueError("Expected a short mono 16 kHz PCM clip")
        samples = np.frombuffer(audio.readframes(audio.getnframes()), dtype="<i2").astype(np.float32) / 32768
    if len(samples) == 0 or float(np.sqrt(np.mean(samples * samples))) < 0.008:
        print(json.dumps({"text": ""})); sys.exit(0)
    with contextlib.redirect_stdout(sys.stderr):
        from mlx_audio.stt.utils import load
        model = load(sys.argv[1])
        result = model.generate(samples, language=sys.argv[3], verbose=None, temperature=0.0, condition_on_previous_text=False, return_timestamps=False)
    print(json.dumps({"text": result.text[:2000]}, ensure_ascii=False), flush=True)
except Exception as error:
    print(json.dumps({"error": str(error)[:1000]}), flush=True)
    sys.exit(1)
