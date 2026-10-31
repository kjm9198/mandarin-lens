"""Explicit user-triggered setup. Downloads packages, never learning data."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import venv

if sys.version_info < (3, 10):
    raise SystemExit("Python 3.10 or later is required")
root = Path(sys.argv[1]).expanduser().resolve()
root.mkdir(parents=True, exist_ok=True, mode=0o700)
marker = root / "runtime-installing"
marker.write_text("Runtime setup is incomplete; retry setup to finish.\n")
child = None

def stop(signum, frame):
    if child and child.poll() is None:
        os.killpg(child.pid, signal.SIGTERM)
    raise SystemExit(1)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
runtime = root / "mlx-runtime"
venv.EnvBuilder(with_pip=True, clear=False).create(runtime)
child = subprocess.Popen([str(runtime / "bin/python"), "-m", "pip", "install", "--disable-pip-version-check", "mlx-vlm==0.7.11", "mlx-audio==0.6.3", "huggingface_hub"], start_new_session=True)
if child.wait() != 0:
    raise SystemExit("Package installation failed; retry to finish setup")
subprocess.run([str(runtime / "bin/python"), "-c", "import mlx_vlm, mlx_audio, huggingface_hub"], check=True)
marker.unlink()
print("Local runtime ready", flush=True)
