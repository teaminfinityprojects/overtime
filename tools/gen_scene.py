#!/usr/bin/env python3
"""Genera la ilustración de una escena por estado con Illustrious en estilo cartoon occidental.
Solo biblioteca estándar. Guarda en assets/scenes/<nivel>/<estado>.png (o --out).

    HEARTLINE_POD=<pod> python3 tools/gen_scene.py desk_tuesday work_top_bottom_none
    HEARTLINE_POD=<pod> python3 tools/gen_scene.py desk_tuesday fuck_notop_bottom_mario --seed 7

La identidad de Candela y la descripción de cada compañero salen de data/; la ropa y la
postura, de la clave de estado. Misma semilla en todos los estados de un nivel.
"""
import argparse, json, os, sys, time, urllib.parse, urllib.request, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = {"Content-Type": "application/json", "User-Agent": "overtime-gen/1.0"}

STYLES = {
    # El actual: cómic americano de color plano (guardado como referencia).
    "comic": ("western cartoon style, american comic style, flat colors, thick clean outlines, cel shading, "
              "bold shapes, saturated palette, expressive faces, adult animation style, no lineart sketch"),
    # Dibujo animado de sábado por la mañana: formas simples, ojos grandes, contorno grueso uniforme.
    "toon": ("saturday morning cartoon style, 2d animation, toon shading, very thick uniform black outlines, "
             "simplified rounded shapes, big expressive eyes, exaggerated curvy proportions, bright flat colors, "
             "clean vector look, no gradients"),
    # Animación adulta tipo Adult Swim / Archer: formas angulosas, sombras duras, paleta contenida.
    "adult_swim": ("adult animation style, archer style, angular stylized shapes, sharp hard-edged shadows, "
                   "limited muted palette with strong accent colors, thin precise outlines, glossy highlights, "
                   "retro modern office aesthetic"),
    # Pin-up cartoon retro: curvas exageradas, línea de pincel, colores cálidos.
    "pinup": ("retro pin-up cartoon style, 1950s animation inspired, brush line art with varying line weight, "
              "exaggerated hourglass figure, soft cel shading, warm saturated palette, playful expressions, "
              "clean flat backgrounds"),
    # Estilo de novela gráfica europea: línea clara, colores planos con textura ligera.
    "ligne_claire": ("ligne claire style, european comic style, clear uniform line, flat colors with subtle shading, "
                     "clean detailed backgrounds, elegant proportions, calm palette"),
}
# Estilo del proyecto (data/art_style.json); los flags de línea de comandos lo sobrescriben.
ART = json.loads((ROOT / "data/art_style.json").read_text()) if (ROOT / "data/art_style.json").exists() else {}
STYLE_NAME = ART.get("preset", "comic")
STYLE = STYLES[STYLE_NAME] + ", masterpiece, best quality, absurdres"
NEGATIVE = ("anime, manga, japanese style, pixel art, realistic, photorealistic, 3d render, lowres, blurry, "
            "bad anatomy, bad hands, extra digits, text, watermark, signature, speech bubble, censored, mosaic censoring, "
            "child, loli, young")
CANDELA = ("1girl, mature female, office lady, blonde hair, high ponytail, red-framed glasses, red lipstick, "
           "curvy, large breasts, wide hips, thick thighs")
CLOTHES = {
    ("top", "bottom"): "white dress shirt, brown sweater vest, red pencil skirt, brown pantyhose",
    ("notop", "bottom"): "topless, bare breasts, nipples, red pencil skirt, brown pantyhose, shirt removed",
    ("top", "nobottom"): "white dress shirt, brown sweater vest, bottomless, no skirt, no panties, bare ass, brown thigh highs",
    ("notop", "nobottom"): "completely nude, bare breasts, nipples, bare ass, brown thigh highs, glasses only",
}
LOCATION = {"desk_tuesday": "modern open office interior, desk with laptop, office chair, cubicle walls, potted plant, window light"}


def prompt_for(level: str, state: str) -> str:
    mode, top, bottom, who = state.split("_")
    parts = [STYLE, LOCATION.get(level, "office interior"), CANDELA, CLOTHES[(top, bottom)]]
    if who == "none":
        # Composición base: ella en el centro-izquierda y espacio libre a la derecha para que
        # luego quepa un compañero de pie detrás de la silla (inpainting).
        parts.append("sitting at desk typing on laptop, focused, from side, full body, wide shot, "
                     "desk on the left, chair in the center, empty floor space on the right side of the image, "
                     "copy space on the right")
    else:
        coworkers = json.loads((ROOT / "data/coworkers.json").read_text())
        man = coworkers[who]
        parts.append(f"1boy, adult man, office worker, dress shirt and tie, {man.get('look', 'short brown hair')}")
        if mode == "fuck":
            parts.append("bent over the desk, man standing behind her, sex from behind, hands on her hips, smirk, "
                         "she keeps typing on the laptop, hetero, from side")
        else:
            parts.append("man standing behind her chair holding a coffee mug, looking at her, she is typing, side view")
    return ", ".join(parts)


CKPT = ART.get("ckpt", "waiIllustriousSDXL_v170.safetensors")
LORA = (ART["lora"], float(ART.get("lora_strength", 0.8))) if ART.get("lora") else None
TRIGGER = ART.get("trigger", "")
NEGATIVE_ACTIVE = NEGATIVE


def workflow(prompt: str, seed: int, prefix: str) -> dict:
    wf = {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["4", 1]}},
        "8": {"class_type": "CLIPTextEncode", "inputs": {"text": NEGATIVE_ACTIVE, "clip": ["4", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1216, "height": 832, "batch_size": 1}},
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


def api(base, path, data=None):
    req = urllib.request.Request(base + path, data=json.dumps(data).encode() if data is not None else None, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())


def run(base: str, wf: dict, out: Path) -> None:
    pid = api(base, "/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})["prompt_id"]
    t0 = time.time()
    while True:
        time.sleep(2)
        hist = api(base, f"/history/{pid}")
        if pid in hist:
            break
        if time.time() - t0 > 600:
            sys.exit("tiempo agotado")
    img = [i for n in hist[pid]["outputs"].values() for i in n.get("images", [])][0]
    q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": "output"})
    with urllib.request.urlopen(urllib.request.Request(base + "/view?" + q, headers=UA), timeout=120) as r:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(r.read())
    print(f"  {out} en {time.time() - t0:.0f}s")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("level")
    p.add_argument("states", nargs="+")
    p.add_argument("--seed", type=int, default=int(ART.get("seed", 4242)))
    p.add_argument("--out", default=None, help="carpeta de salida alternativa (pruebas)")
    p.add_argument("--style", default=None, choices=list(STYLES), help="preset de estilo (por defecto el activo)")
    p.add_argument("--ckpt", default=None, help="checkpoint alternativo")
    p.add_argument("--lora", default=None, help="archivo de LoRA de estilo")
    p.add_argument("--lora-strength", type=float, default=0.8)
    p.add_argument("--trigger", default="", help="palabra de activación de la LoRA, se antepone al prompt")
    p.add_argument("--no-anime-negative", action="store_true", help="quita 'anime' del negativo (para checkpoints no anime)")
    a = p.parse_args()
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    global STYLE, CKPT, LORA, NEGATIVE_ACTIVE
    if a.style:
        STYLE = STYLES[a.style] + ", masterpiece, best quality, absurdres"
    if a.ckpt:
        CKPT = a.ckpt
    if a.lora:
        LORA = (a.lora, a.lora_strength)
    if a.no_anime_negative:
        NEGATIVE_ACTIVE = NEGATIVE.replace("anime, manga, japanese style, ", "")
    trigger = a.trigger if a.trigger else TRIGGER
    for state in a.states:
        prompt = prompt_for(a.level, state)
        if trigger:
            prompt = trigger + ", " + prompt
        print(f"{state}: {prompt[:120]}…")
        out_dir = Path(a.out) if a.out else ROOT / "assets/scenes" / a.level
        run(base, workflow(prompt, a.seed, f"overtime/{a.level}_{state}"), out_dir / f"{state}.png")


if __name__ == "__main__":
    main()
