#!/usr/bin/env python3
"""Bucle animado de una escena con MiniMax H3 (modelo FL2VA): la misma imagen como primer y
último fotograma, así el clip vuelve exacto al punto de partida y encadena sin salto.

    HEARTLINE_POD=<pod> python3 tools/gen_video.py escena.png "movimiento" salida.mp4 [--seconds 3.75] [--seed N]
    HEARTLINE_POD=<pod> python3 tools/gen_video.py --batch loops.json      # lista de {in, prompt, out, seed?}

Salida 832x480 a 24 fps. Luego tools/video_to_sheet.py la convierte en spritesheet para Godot.
"""
import argparse, json, os, sys, time, urllib.parse, urllib.request, uuid
from pathlib import Path

def _urlopen_retry(req, timeout, attempts=8):
    """urlopen con reintentos exponenciales: el DNS del Mac se cae de vez en cuando."""
    import time as _t
    import urllib.error as _e
    for i in range(attempts):
        try:
            return urllib.request.urlopen(req, timeout=timeout)
        except (_e.URLError, ConnectionError, TimeoutError, OSError) as err:
            if isinstance(err, _e.HTTPError) and err.code < 500:
                raise
            if i == attempts - 1:
                raise
            wait = min(60, 5 * 2 ** i)
            print(f"  (red: {err}; reintento en {wait}s)", flush=True)
            _t.sleep(wait)


sys.path.insert(0, str(Path(__file__).resolve().parent))
from inpaint_scene import upload  # noqa: E402

UA = {"User-Agent": "overtime-gen/1.0", "Content-Type": "application/json"}
# Misma proporción que las escenas (1240x848 ≈ 1.46) para que el primer frame no se estire.
W, H = 704, 480
FFMPEG = str(Path.home() / ".local/bin/ffmpeg")


def frames_for(seconds: float) -> int:
    """H3 exige longitudes ≡ 5 (mod 17): 5, 22, 39, 56, 73, 90, 107…"""
    n = max(5, round(seconds * 24))
    return n + (5 - (n % 17)) % 17


TURBO = "minimax_h3_turbo_v4_step600_ema_pruned_comfyui.safetensors"


def workflow(image: str, prompt: str, seed: int, length: int, prefix: str, turbo_steps: int = 0) -> dict:
    wf = {
        "127": {"class_type": "UNETLoader", "inputs": {"unet_name": "minimax_h3_fl2va_pruned_int8_convrot.safetensors", "weight_dtype": "default"}},
        "128": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_32b_minimax_h3_int8_convrot.safetensors", "type": "minimax", "device": "default"}},
        "119": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_video_vae_fp16.safetensors"}},
        "120": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_audio_vae_fp32.safetensors"}},
        "137": {"class_type": "LoadImage", "inputs": {"image": image}},
        "136": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {"clip": ["128", 0], "vae": ["119", 0], "prompt": prompt, "width": W, "height": H, "length": length,
                                                                  "first_frame": ["137", 0], "last_frame": ["137", 0]}},
        "129": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "126": {"class_type": "BasicGuider", "inputs": {"model": ["127", 0], "conditioning": ["136", 0]}},
        "123": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
        "124": {"class_type": "BasicScheduler", "inputs": {"model": ["127", 0], "scheduler": "simple", "steps": 20, "denoise": 1.0}},
        "125": {"class_type": "SamplerCustomAdvanced", "inputs": {"noise": ["129", 0], "guider": ["126", 0], "sampler": ["123", 0], "sigmas": ["124", 0], "latent_image": ["136", 1]}},
        "122": {"class_type": "VAEDecode", "inputs": {"samples": ["125", 0], "vae": ["119", 0]}},
        "121": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["125", 0], "vae": ["120", 0]}},
        "130": {"class_type": "CreateVideo", "inputs": {"images": ["122", 0], "fps": 24, "audio": ["121", 0]}},
        "92": {"class_type": "SaveVideo", "inputs": {"video": ["130", 0], "filename_prefix": prefix, "format": "mp4", "codec": "h264"}},
    }
    if turbo_steps > 0:
        # LoRA turbo: mismo resultado aproximado en 6-8 pasos en vez de 20.
        wf["140"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["127", 0], "lora_name": TURBO, "strength_model": 1.0}}
        wf["126"]["inputs"]["model"] = ["140", 0]
        wf["124"]["inputs"]["model"] = ["140", 0]
        wf["124"]["inputs"]["steps"] = turbo_steps
    return wf


def api(base, path, data=None, timeout=120):
    req = urllib.request.Request(base + path, data=json.dumps(data).encode() if data is not None else None, headers=UA)
    with _urlopen_retry(req, timeout) as r:
        return json.loads(r.read().decode())


def run(base: str, wf: dict, out: Path) -> None:
    res = api(base, "/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})
    if "error" in res:
        sys.exit("ComfyUI rechazó el workflow: " + json.dumps(res, ensure_ascii=False)[:1500])
    pid = res["prompt_id"]
    t0 = time.time()
    while True:
        time.sleep(5)
        hist = api(base, f"/history/{pid}")
        if pid in hist:
            break
        if time.time() - t0 > 1800:
            sys.exit("tiempo agotado")
    h = hist[pid]
    if h.get("status", {}).get("status_str") == "error":
        sys.exit("error en el pod: " + json.dumps(h["status"], ensure_ascii=False)[:1500])
    vids = [v for n in h["outputs"].values() for k in ("videos", "gifs", "images") for v in n.get(k, [])]
    v = vids[0]
    q = urllib.parse.urlencode({"filename": v["filename"], "subfolder": v.get("subfolder", ""), "type": v.get("type", "output")})
    with _urlopen_retry(urllib.request.Request(base + "/view?" + q, headers={"User-Agent": UA["User-Agent"]}), 300) as r:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(r.read())
    print(f"  {out} en {time.time() - t0:.0f}s", flush=True)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("image", nargs="?")
    p.add_argument("prompt", nargs="?")
    p.add_argument("out", nargs="?")
    p.add_argument("--seconds", type=float, default=3.75)
    p.add_argument("--seed", type=int, default=4243)
    p.add_argument("--batch", default=None)
    p.add_argument("--turbo", type=int, default=6, help="pasos con la LoRA turbo (0 = sin turbo, 20 pasos)")
    a = p.parse_args()
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    jobs = json.loads(Path(a.batch).read_text()) if a.batch else [{"in": a.image, "prompt": a.prompt, "out": a.out}]
    length = frames_for(a.seconds)
    for job in jobs:
        out = Path(job["out"])
        if out.exists() and not job.get("force"):
            print(f"  {out.name}: ya existe", flush=True)
            continue
        # Pre-escalado exacto al tamaño del vídeo: el primer y el último frame son la escena tal cual.
        scaled = Path(".godot/video/_in") / Path(job["in"]).name
        scaled.parent.mkdir(parents=True, exist_ok=True)
        import subprocess
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", job["in"], "-vf", f"scale={W}:{H}", str(scaled)], check=True)
        image = upload(base, scaled)
        print(f"{Path(job['in']).name} → {job['prompt'][:80]}", flush=True)
        run(base, workflow(image, job["prompt"], int(job.get("seed", a.seed)), length, "overtime/loop", a.turbo), out)


if __name__ == "__main__":
    main()
