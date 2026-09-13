#!/usr/bin/env python3
"""Efectos de sonido en bucle con Stable Audio 3 medium (pesos abiertos, Stability Community License,
entrenado con audio licenciado) en el pod: un bucle por acto (teclado/oficina, tocarse, oral, tetas,
sexo). Sustituye al audio nativo de H3, cuya licencia no permite mostrar las salidas en EE. UU./UE/UK/Corea.

    HEARTLINE_POD=<pod> python3 tools/gen_sfx.py --batch sfx.json      # lista de {prompt, out, seed?, seconds?}
    HEARTLINE_POD=<pod> python3 tools/gen_sfx.py "prompt" salida.ogg [--seconds 12] [--seed N]

Cada clip se convierte en bucle sin corte (los últimos `--xfade` s se funden con el principio) y se
normaliza a -16 LUFS. La salida es OGG Vorbis estéreo (Godot lo reproduce con loop).
"""
import argparse, json, os, subprocess, sys, tempfile, time, urllib.parse, urllib.request, uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_video import _urlopen_retry, api  # noqa: E402

FFMPEG = str(Path.home() / ".local/bin/ffmpeg")
CKPT = "stable_audio_3_medium_base.safetensors"
CLIP = "t5gemma_b_b_ul2.safetensors"
NEGATIVE = "music, melody, instruments, singing, speech"


def workflow(prompt: str, seconds: float, seed: int, steps: int, cfg: float, prefix: str, negative: str = NEGATIVE) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "9": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "stable_audio", "device": "default"}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["9", 0], "text": prompt}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["9", 0], "text": negative}},
        "4": {"class_type": "EmptyLatentAudio", "inputs": {"seconds": seconds, "batch_size": 1}},
        # Receta de la plantilla oficial de ComfyUI (audio_stable_audio_3_medium_base): lcm/simple, 50 pasos, cfg 7,
        # sin ConditioningStableAudio (eso era de Stable Audio Open 1.0 y aquí sale ruido blanco).
        "6": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "seed": seed, "steps": steps, "cfg": cfg, "sampler_name": "lcm", "scheduler": "simple", "denoise": 1.0,
                                                   "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}},
        "7": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveAudio", "inputs": {"audio": ["7", 0], "filename_prefix": prefix}},
    }


def run(base: str, wf: dict, out: Path) -> None:
    res = api(base, "/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})
    if "error" in res:
        sys.exit("ComfyUI rechazó el workflow: " + json.dumps(res, ensure_ascii=False)[:1500])
    pid = res["prompt_id"]
    t0 = time.time()
    while True:
        time.sleep(3)
        hist = api(base, f"/history/{pid}")
        if pid in hist:
            break
        if time.time() - t0 > 3600:
            sys.exit("tiempo agotado")
    h = hist[pid]
    if h.get("status", {}).get("status_str") == "error":
        sys.exit("error en el pod: " + json.dumps(h["status"], ensure_ascii=False)[:1500])
    a = [x for n in h["outputs"].values() for x in n.get("audio", [])][0]
    q = urllib.parse.urlencode({"filename": a["filename"], "subfolder": a.get("subfolder", ""), "type": "output"})
    with _urlopen_retry(urllib.request.Request(base + "/view?" + q, headers={"User-Agent": "overtime-gen/1.0"}), 120) as r:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(r.read())
    print(f"  {out} en {time.time() - t0:.0f}s", flush=True)


def make_loop(src: Path, out: Path, xfade: float) -> None:
    """Bucle sin corte: el clip empieza en `xfade` s y su cola se funde con el principio original,
    así el último instante coincide con el primero. Luego normaliza y codifica OGG estéreo."""
    total = float(subprocess.run([FFMPEG.replace("ffmpeg", "ffprobe"), "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(src)], capture_output=True, text=True, check=True).stdout.strip())
    body = total - xfade
    fc = (f"[0:a]atrim=start={xfade},asetpts=PTS-STARTPTS[a];[0:a]atrim=end={xfade},asetpts=PTS-STARTPTS[b];"
          f"[a][b]acrossfade=d={xfade}:c1=tri:c2=tri[x];[x]loudnorm=I=-16:TP=-1.5:LRA=11,aformat=channel_layouts=stereo,aresample=44100[o]")
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", str(src), "-filter_complex", fc, "-map", "[o]", "-c:a", "vorbis", "-strict", "-2", "-q:a", "5", str(out)], check=True)
    print(f"  bucle {out.name}: {body:.1f}s", flush=True)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("prompt", nargs="?")
    p.add_argument("out", nargs="?")
    p.add_argument("--seconds", type=float, default=12.0)
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--steps", type=int, default=50)
    p.add_argument("--cfg", type=float, default=7.0)
    p.add_argument("--xfade", type=float, default=1.5)
    p.add_argument("--batch", default=None)
    a = p.parse_args()
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    jobs = json.loads(Path(a.batch).read_text()) if a.batch else [{"prompt": a.prompt, "out": a.out}]
    for job in jobs:
        out = Path(job["out"])
        if out.exists() and not job.get("force"):
            print(f"  {out.name}: ya existe", flush=True)
            continue
        raw = out.with_suffix(".raw.flac")
        print(f"{out.name} ← {job['prompt'][:90]}", flush=True)
        run(base, workflow(job["prompt"], float(job.get("seconds", a.seconds)), int(job.get("seed", a.seed)), a.steps, a.cfg, "overtime/sfx", job.get("negative", NEGATIVE)), raw)
        make_loop(raw, out, float(job.get("xfade", a.xfade)))


if __name__ == "__main__":
    main()
