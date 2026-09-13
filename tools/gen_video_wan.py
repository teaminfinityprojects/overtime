#!/usr/bin/env python3
"""Bucle animado de una escena con Wan 2.2 I2V A14B (licencia Apache 2.0, sin restricciones de
territorio ni de contenido, a diferencia de MiniMax H3): la misma imagen como primer y último
fotograma (WanFirstLastFrameToVideo), así el clip vuelve exacto al punto de partida.

    HEARTLINE_POD=<pod> python3 tools/gen_video_wan.py escena.png "movimiento" salida.mp4 [--seconds 5] [--seed N]
    HEARTLINE_POD=<pod> python3 tools/gen_video_wan.py --batch loops.json      # lista de {in, prompt, out, seed?, force?}

Modelo: distilado MoE Lightx2v en NVFP4 (Blackwell), 4 pasos sin CFG (2 alto ruido + 2 bajo ruido).
Salida 1056x720 a 16 fps, sin audio: el sonido va aparte (Stable Audio 3 / librería SFX).
"""
import argparse, json, os, subprocess, sys, time, urllib.parse, urllib.request, uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_video import _urlopen_retry, api, run  # noqa: E402  (mismo cliente, mismos reintentos)
from inpaint_scene import upload  # noqa: E402

# Misma proporción que las escenas (1240x848 ≈ 1.46), 720 de alto: 1056x720 = 704x480 × 1.5.
W, H = 1056, 720
FPS = 16
FFMPEG = str(Path.home() / ".local/bin/ffmpeg")

HIGH = "wan22_i2v_high_nvfp4_lightx2v.safetensors"
LOW = "wan22_i2v_low_nvfp4_lightx2v.safetensors"
CLIP = "umt5_xxl_bf16.safetensors"
VAE = "wan_2.1_vae.safetensors"
NEGATIVE = ("色调艳丽，过曝，静态，细节模糊不清，字幕，风格，作品，画作，画面，静止，整体发灰，最差质量，低质量，JPEG压缩残留，丑陋的，残缺的，"
            "多余的手指，画得不好的手部，画得不好的面部，畸形的，毁容的，形态畸形的肢体，手指融合，静止不动的画面，杂乱的背景，三条腿，背景人很多，倒着走, "
            "camera movement, zoom, cut, text, watermark, extra person, different face, different clothes")


def frames_for(seconds: float) -> int:
    """Wan exige longitudes 4k+1: 17, 33, 49, 65, 81, 97…"""
    n = max(5, round(seconds * FPS))
    return n - ((n - 1) % 4)


def workflow(image: str, prompt: str, seed: int, length: int, prefix: str, shift: float = 5.0, steps: int = 4) -> dict:
    mid = steps // 2
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": HIGH, "weight_dtype": "default"}},
        "2": {"class_type": "UNETLoader", "inputs": {"unet_name": LOW, "weight_dtype": "default"}},
        "3": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "wan", "device": "default"}},
        "4": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "5": {"class_type": "LoadImage", "inputs": {"image": image}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["3", 0], "text": prompt}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["3", 0], "text": NEGATIVE}},
        "8": {"class_type": "WanFirstLastFrameToVideo", "inputs": {"positive": ["6", 0], "negative": ["7", 0], "vae": ["4", 0], "width": W, "height": H, "length": length, "batch_size": 1,
                                                                    "start_image": ["5", 0], "end_image": ["5", 0]}},
        "9": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["1", 0], "shift": shift}},
        "10": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["2", 0], "shift": shift}},
        "11": {"class_type": "KSamplerAdvanced", "inputs": {"model": ["9", 0], "add_noise": "enable", "noise_seed": seed, "steps": steps, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple",
                                                            "positive": ["8", 0], "negative": ["8", 1], "latent_image": ["8", 2], "start_at_step": 0, "end_at_step": mid, "return_with_leftover_noise": "enable"}},
        "12": {"class_type": "KSamplerAdvanced", "inputs": {"model": ["10", 0], "add_noise": "disable", "noise_seed": seed, "steps": steps, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple",
                                                            "positive": ["8", 0], "negative": ["8", 1], "latent_image": ["11", 0], "start_at_step": mid, "end_at_step": 10000, "return_with_leftover_noise": "disable"}},
        "13": {"class_type": "VAEDecode", "inputs": {"samples": ["12", 0], "vae": ["4", 0]}},
        "14": {"class_type": "CreateVideo", "inputs": {"images": ["13", 0], "fps": FPS}},
        "15": {"class_type": "SaveVideo", "inputs": {"video": ["14", 0], "filename_prefix": prefix, "format": "mp4", "codec": "h264"}},
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("image", nargs="?")
    p.add_argument("prompt", nargs="?")
    p.add_argument("out", nargs="?")
    p.add_argument("--seconds", type=float, default=5.0)
    p.add_argument("--seed", type=int, default=4243)
    p.add_argument("--shift", type=float, default=5.0)
    p.add_argument("--steps", type=int, default=4)
    p.add_argument("--batch", default=None)
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
        scaled = Path(".godot/video/_in_wan") / Path(job["in"]).name
        scaled.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", job["in"], "-vf", f"scale={W}:{H}:flags=lanczos", str(scaled)], check=True)
        image = upload(base, scaled)
        print(f"{Path(job['in']).name} → {job['prompt'][:80]}", flush=True)
        run(base, workflow(image, job["prompt"], int(job.get("seed", a.seed)), length, "overtime/wan_loop", a.shift, a.steps), out)


if __name__ == "__main__":
    main()
