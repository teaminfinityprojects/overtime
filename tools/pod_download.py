#!/usr/bin/env python3
"""Descarga modelos de Civitai directamente en el pod de ComfyUI usando el nodo Civicomfy
que ya está instalado. Solo biblioteca estándar.

    python3 tools/pod_download.py 1132089 --type lora --name flat_color_style_illustrious
    python3 tools/pod_download.py https://civitai.com/models/827184 --type checkpoints --version 2883731
    python3 tools/pod_download.py --status

La API key de Civitai (necesaria para muchas LoRAs) se lee de la variable CIVITAI_API_KEY o
del archivo .env del proyecto (línea CIVITAI_API_KEY=...). Nunca se pasa por argumento ni se
imprime. El pod se lee de HEARTLINE_POD o --pod.
"""
import argparse, json, os, sys, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = {"Content-Type": "application/json", "User-Agent": "heartline-gen/1.0"}


def load_env() -> None:
    env = ROOT / ".env"
    if not env.exists():
        return
    for line in env.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def call(base: str, path: str, body=None):
    req = urllib.request.Request(base + path, data=json.dumps(body).encode() if body is not None else None,
                                 headers=UA, method="POST" if body is not None else "GET")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def main() -> None:
    load_env()
    p = argparse.ArgumentParser()
    p.add_argument("model", nargs="?", help="id o URL de civitai.com/models/…")
    p.add_argument("--type", default="lora", help="lora | checkpoints | vae | controlnet …")
    p.add_argument("--version", type=int, default=None, help="model_version_id concreto; por defecto la última")
    p.add_argument("--name", default=None, help="nombre de archivo sin extensión")
    p.add_argument("--pod", default=os.environ.get("HEARTLINE_POD"))
    p.add_argument("--status", action="store_true")
    a = p.parse_args()

    if not a.pod:
        sys.exit("Falta --pod o HEARTLINE_POD")
    base = a.pod if a.pod.startswith("http") else f"https://{a.pod}-8188.proxy.runpod.net"

    if a.status or not a.model:
        s = call(base, "/civitai/status")
        for item in s.get("active", []):
            print(f"  ⏳ {item.get('filename')}  {item.get('progress', 0):.0f}%")
        for item in s.get("queue", []):
            print(f"  ·  {item.get('filename')} (en cola)")
        for item in s.get("history", [])[:8]:
            print(f"  {'✓' if item.get('status') == 'completed' else '✗'} {item.get('filename')}  {item.get('error') or ''}")
        return

    api_key = os.environ.get("CIVITAI_API_KEY", "")
    if not api_key:
        print("aviso: sin CIVITAI_API_KEY; muchas LoRAs devolverán 401", file=sys.stderr)
    url = a.model if a.model.startswith("http") else f"https://civitai.com/models/{a.model}"
    body = {"model_url_or_id": url, "model_type": a.type, "model_version_id": a.version,
            "custom_filename": a.name or "", "num_connections": 8, "force_redownload": False, "api_key": api_key}
    r = call(base, "/civitai/download", body)
    print(r.get("status"), "·", r.get("message", ""))
    if r.get("status") != "queued":
        sys.exit(1)

    t0 = time.time()
    while time.time() - t0 < 900:
        time.sleep(10)
        s = call(base, "/civitai/status")
        active = s.get("active", []) + s.get("queue", [])
        if not active:
            break
        print("  " + " | ".join(f"{x.get('filename', '?')[:30]} {x.get('progress', 0):.0f}%" for x in active), flush=True)
    for item in s.get("history", [])[:3]:
        print(f"  {'✓' if item.get('status') == 'completed' else '✗'} {item.get('filename')}  {item.get('error') or ''}")


if __name__ == "__main__":
    main()
