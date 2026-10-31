"""Explicit download only. No inference prompt is sent over the network."""
import sys, os, json, threading, time
parent = os.getppid()
def watch_parent():
    while True:
        time.sleep(2)
        if os.getppid() != parent:
            os._exit(1)
threading.Thread(target=watch_parent, daemon=True).start()
os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
os.environ["DO_NOT_TRACK"] = "1"
os.environ["HF_HUB_DISABLE_XET"] = "1"
from huggingface_hub import snapshot_download
allowed = {"mlx-community/Qwen3.5-2B-4bit", "mlx-community/Qwen3.5-4B-4bit", "mlx-community/whisper-small-asr-fp16"}
repo, destination = sys.argv[1:3]
if repo not in allowed:
    raise ValueError("Unknown model")
os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
snapshot_download(repo, local_dir=destination, allow_patterns=["*.json", "*.safetensors", "*.jinja", "*.txt", "*.model"])
print("Download complete", flush=True)
