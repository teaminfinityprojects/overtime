#!/usr/bin/env python3
"""Sprite de cada compañero de pie (con su taza) sobre fondo verde, en el estilo del proyecto,
para superponerlo detrás de la silla de Candela mientras espera. Después: chroma_key.gd.

    HEARTLINE_POD=<pod> python3 tools/gen_coworker_sprites.py            # todos
    HEARTLINE_POD=<pod> python3 tools/gen_coworker_sprites.py mario
"""
import json, os, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_scene import STYLE, NEGATIVE, CKPT, LORA, TRIGGER, run  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SEED = 6060


def workflow(prompt: str, negative: str, seed: int, prefix: str) -> dict:
    wf = {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["4", 1]}},
        "8": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["4", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 832, "height": 1216, "batch_size": 1}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["4", 0], "seed": seed, "steps": 30, "cfg": 6.0, "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": 1, "positive": ["6", 0], "negative": ["8", 0], "latent_image": ["5", 0]}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": prefix}},
    }
    if LORA:
        wf["10"] = {"class_type": "LoraLoader", "inputs": {"model": ["4", 0], "clip": ["4", 1], "lora_name": LORA[0], "strength_model": LORA[1], "strength_clip": LORA[1]}}
        wf["3"]["inputs"]["model"] = ["10", 0]
        wf["6"]["inputs"]["clip"] = ["10", 1]
        wf["8"]["inputs"]["clip"] = ["10", 1]
    return wf


def main() -> None:
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    coworkers = json.loads((ROOT / "data/coworkers.json").read_text())
    wanted = sys.argv[1:] or [k for k, v in coworkers.items() if v.get("kind") == "coworker"]
    for i, key in enumerate(wanted):
        man = coworkers[key]
        seed = int(man.get("sprite_seed", SEED + i))
        prompt = ", ".join(x for x in [TRIGGER, STYLE, "1boy, solo, adult male, masculine, office worker", man.get("look", ""),
                                       "standing, full body, from side, facing left, holding a coffee mug, smirk, relaxed posture",
                                       "simple background, flat green background, green screen, no shadow"] if x)
        negative = NEGATIVE + ", 1girl, woman, female, girl, multiple people, 2boys, 2people, duo, couple, silhouette, furniture, desk, chair, floor, shadow, gradient background"
        print(f"{key}:", end="", flush=True)
        run(base, workflow(prompt, negative, seed, f"overtime/coworker_{key}"), ROOT / "assets/coworkers/raw" / f"{key}.png")


if __name__ == "__main__":
    main()
