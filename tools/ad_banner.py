#!/usr/bin/env python3
"""Banners de publicidad: fondo generado en el pod y composición con el logo y los textos, en los dos idiomas.
Español anuncia amateur.tv y inglés sugarcams (misma red; es a donde enlaza cada idioma, ver data/ads.json).
Salida: <sitio>_<variante>.png en español y <sitio>_<variante>_en.png en inglés.
Necesita Pillow. Los fondos van a assets/ads/bg/, los banners terminados a assets/ads/.
Variantes: a = foto (Krea 2 Turbo), b = cartoon (Krea 2 Turbo), c = cartoon NSFW (Illustrious + LoRA Flash del juego;
también saca la foto del chat patrocinado del móvil, phone_c.png). La activa se elige en data/ads.json.

    HEARTLINE_POD=<pod> python3 tools/ad_banner.py gen            # genera los fondos de todas las variantes
    python3 tools/ad_banner.py compose                            # compone todos los banners (textos abajo)

Menú: 800x168 (se ve a 400x84). Fin de jornada: 1120x168 (se ve a 560x84). Tamaño doble para pantalla completa.
"""
import json, os, sys, time, urllib.parse, urllib.request, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BG_DIR = ROOT / "assets/ads/bg"
OUT_DIR = ROOT / "assets/ads"
FONT = ROOT / "assets/fonts/Nunito-Regular.ttf"
# Logo por idioma. Sin archivo (sugarcams, de momento) se dibuja el nombre en Nunito como wordmark.
LOGOS = {"es": (ROOT / "assets/ads/amateur_logo.png", "amateur.tv"), "en": (ROOT / "assets/ads/sugarcams_logo.png", "sugarcams")}
LIVE = (239, 43, 74)
# Color del botón por marca: rojo amateur.tv; rosa del logo de sugarcams, algo oscurecido para que el texto blanco se lea.
BUTTON = {"es": LIVE, "en": (220, 56, 160)}
UA = {"Content-Type": "application/json", "User-Agent": "overtime-gen/1.0"}

KREA = {
    "a": ("Wide cinematic advertising banner photograph. On the right third of the frame, a beautiful adult woman in her late "
          "twenties with long dark wavy hair, wearing black lace lingerie, sitting on a bed in a cozy bedroom at night, smiling "
          "flirtatiously toward a webcam, lit by a pink and red neon glow and a soft ring light. The left half of the image is dark "
          "empty shadow with deep magenta and red bokeh, clean negative space for text. Moody, sensual, high-end advertising "
          "photography, shallow depth of field."),
    "b": ("Wide banner illustration in 2000s Flash cartoon style, thick clean black outlines, flat cel shading, saturated colors. "
          "On the right third, a curvy adult woman with long red hair in a tight red dress, lying on her stomach on a bed, winking "
          "and blowing a kiss at a laptop webcam, a small glowing red light on the laptop camera. Night bedroom with pink and purple "
          "neon lighting. The left half of the image is a plain dark purple gradient, empty negative space for text."),
}
# Fondo por ubicación: (ancho, alto de generación, semilla), con la proporción del banner (≈4,8:1 y ≈6,7:1).
SHAPES = {"menu": (1760, 368, 11), "end": (2048, 304, 11)}
# Variante NSFW: Illustrious no aguanta proporciones tan apaisadas, así que se genera a 3:1 y se recorta la figura
# (caja x0, y0, x1, y1 sobre la imagen generada), que se pega a la derecha del banner con un fundido.
NSFW = {
    "c": {
        "prompt": ("thickflashstyle, flat color, saturday morning cartoon style, 2d animation, toon shading, very thick uniform "
                   "black outlines, simplified rounded shapes, bright flat colors, clean vector look, masterpiece, best quality, "
                   "absurdres, 1girl, solo, mature female, adult woman, long red hair, curvy, large breasts, wide hips, lying on "
                   "stomach on bed, legs up, topless, nude, bare breasts, nipples, looking at viewer, winking, seductive smile, "
                   "laptop on bed in front of her, webcam red light, bedroom at night, pink and purple neon lighting, wide shot, "
                   "girl on the right side of the image, plain dark purple background on the left side, empty space on the left"),
        "size": (1536, 512), "seed": 404, "crop": (640, 70, 1536, 440),
        # Foto del chat del móvil: más cerrada (cara, pecho y portátil).
        "photo": (760, 80, 1536, 440),
    },
}
IL_NEGATIVE = ("anime, manga, japanese style, pixel art, realistic, photorealistic, 3d render, lowres, blurry, bad anatomy, "
               "bad hands, extra digits, text, watermark, signature, logo, speech bubble, censored, mosaic censoring, "
               "child, loli, young, multiple girls")
# Banner terminado: (fondo, ancho, alto, titular, botón), textos por idioma. Sin titular: logo y botón apilados
# (el menú es estrecho); con titular: logo y titular apilados y el botón a su derecha.
BANNERS = {
    "menu": ("menu", 800, 168, {"es": "", "en": ""}, {"es": "Ver chicas en directo", "en": "Watch live cams"}),
    "end_win": ("end", 1120, 168, {"es": "Informe entregado. ¿Y ahora qué?", "en": "Report delivered. Now what?"},
                {"es": "Entrar en amateur.tv", "en": "Go to sugarcams"}),
    "end_lose": ("end", 1120, 168, {"es": "Mal día en la oficina. Desconecta.", "en": "Rough day at the office. Unwind."},
                 {"es": "Entrar en amateur.tv", "en": "Go to sugarcams"}),
}
SUFFIX = {"es": "", "en": "_en"}


# --- Generación ------------------------------------------------------------------------------

def api(base, path, data=None, timeout=120):
    req = urllib.request.Request(base + path, data=json.dumps(data).encode() if data is not None else None, headers=UA)
    return json.load(urllib.request.urlopen(req, timeout=timeout))


def workflow(prompt, w, h, seed):
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_fp8_scaled.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "5": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["4", 0]}},
        "6": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "7": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "seed": seed, "steps": 8, "cfg": 1.0,
              "sampler_name": "euler", "scheduler": "simple", "positive": ["4", 0], "negative": ["5", 0],
              "latent_image": ["6", 0], "denoise": 1.0}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "overtime_ad"}},
    }


def workflow_illustrious(prompt, w, h, seed):
    """Mismo pipeline que el arte del juego (tools/gen_scene.py con data/art_style.json)."""
    return {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "waiIllustriousSDXL_v170.safetensors"}},
        "10": {"class_type": "LoraLoader", "inputs": {"model": ["4", 0], "clip": ["4", 1], "lora_name": "flash_cartoon_il.safetensors",
               "strength_model": 0.9, "strength_clip": 0.9}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["10", 1]}},
        "8": {"class_type": "CLIPTextEncode", "inputs": {"text": IL_NEGATIVE, "clip": ["10", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "seed": seed, "steps": 30, "cfg": 6.0,
              "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": 1, "positive": ["6", 0],
              "negative": ["8", 0], "latent_image": ["5", 0]}},
        "7": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["7", 0], "filename_prefix": "overtime_ad"}},
    }


def generate(base, wf, out: Path):
    pid = api(base, "/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})["prompt_id"]
    while True:
        hist = api(base, f"/history/{pid}")
        if pid in hist:
            if hist[pid].get("status", {}).get("status_str") == "error":
                sys.exit(json.dumps(hist[pid]["status"])[:800])
            img = hist[pid]["outputs"]["9"]["images"][0]
            q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
            out.write_bytes(urllib.request.urlopen(urllib.request.Request(f"{base}/view?{q}", headers=UA), timeout=120).read())
            print(out.relative_to(ROOT))
            return
        time.sleep(2)


# --- Composición ---------------------------------------------------------------------------

def font(size, weight):
    from PIL import ImageFont
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([weight])  # Nunito es variable: 800 = ExtraBold, como nunito_bold.tres
    return f


def logo_image(lang, width):
    from PIL import Image, ImageDraw
    path, name = LOGOS[lang]
    if path.exists():
        logo = Image.open(path).convert("RGBA")
        return logo.resize((width, round(logo.height * width / logo.width)), Image.LANCZOS)
    f = font(round(width * 0.2), 900)
    box = f.getbbox(name)
    img = Image.new("RGBA", (box[2] - box[0] + 4, box[3] - box[1] + 4), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((2 - box[0], 2 - box[1]), name, font=f, fill="white")
    return img


def compose(bg_path: Path, out: Path, w, h, title, cta, crop=None, lang="es"):
    from PIL import Image, ImageDraw
    s = h / 168  # la maqueta está pensada a 168 px de alto (84 en pantalla)
    src = Image.open(bg_path).convert("RGB")
    if crop:
        # Recorte de la figura a la altura del banner, pegado a la derecha; el borde izquierdo se funde con el fondo.
        fig = src.crop(crop)
        fig = fig.resize((round(fig.width * h / fig.height), h), Image.LANCZOS).convert("RGBA")
        fade = Image.new("L", (fig.width, 1))
        for x in range(fig.width):
            fade.putpixel((x, 0), int(255 * min(1.0, x / (fig.width * 0.3))))
        fig.putalpha(fade.resize(fig.size))
        bg = Image.new("RGBA", (w, h), src.getpixel((crop[0] + 4, crop[1] + 4)) + (255,))
        bg.alpha_composite(fig, (w - fig.width, 0))
    else:
        ratio = max(w / src.width, h / src.height)
        src = src.resize((round(src.width * ratio), round(src.height * ratio)), Image.LANCZOS)
        left, top = (src.width - w) // 2, (src.height - h) // 2
        bg = src.crop((left, top, left + w, top + h)).convert("RGBA")
    # Degradado oscuro a la izquierda para que el texto se lea sobre cualquier fondo.
    shade = Image.new("L", (w, 1))
    for x in range(w):
        shade.putpixel((x, 0), int(225 * max(0.0, 1 - x / (w * 0.62)) ** 1.3))
    veil = Image.new("RGBA", (w, h), (12, 8, 18, 255))
    veil.putalpha(shade.resize((w, h)))
    bg = Image.alpha_composite(bg, veil)
    d = ImageDraw.Draw(bg)
    x = round(26 * s)
    lw = round(230 * s)
    logo = logo_image(lang, lw)
    lw = logo.width
    bf = font(round(22 * s), 800)
    bh, arrow = round(50 * s), round(11 * s)
    button_w = d.textlength(cta, font=bf) + arrow + round(54 * s)

    def button(bx, by):
        d.rounded_rectangle((bx, by, bx + button_w, by + bh), radius=round(12 * s), fill=BUTTON[lang])
        tx = bx + round(20 * s)
        d.text((tx, by + bh // 2), cta, font=bf, fill="white", anchor="lm")
        # Chevron dibujado (Nunito no trae flechas).
        ax, ay = tx + d.textlength(cta, font=bf) + round(13 * s), by + bh // 2
        d.line((ax, ay - arrow // 2 - 1, ax + arrow // 2 + 1, ay, ax, ay + arrow // 2 + 1), fill="white", width=max(2, round(3 * s)), joint="curve")

    gap = round(14 * s)
    if title:
        tf = font(round(26 * s), 800)
        th = tf.getbbox(title)[3]
        y = (h - (logo.height + gap + th)) // 2
        bg.alpha_composite(logo, (x, y))
        d.text((x, y + logo.height + gap), title, font=tf, fill=(243, 241, 234))
        bx = x + max(lw, round(d.textlength(title, font=tf))) + round(30 * s)
        button(bx, (h - bh) // 2)
    else:
        y = (h - (logo.height + gap + bh)) // 2
        bg.alpha_composite(logo, (x, y))
        button(x, y + logo.height + gap)
    # Esquinas redondeadas como las tarjetas de la UI (radio 12 px a tamaño de pantalla).
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=round(24 * s), fill=255)
    bg.putalpha(mask)
    bg.save(out)
    print(out.relative_to(ROOT))


def photo(bg_path: Path, out: Path, crop, width=640):
    """Foto suelta para la burbuja del chat del móvil (sin textos)."""
    from PIL import Image
    img = Image.open(bg_path).convert("RGB").crop(crop)
    img.resize((width, round(img.height * width / img.width)), Image.LANCZOS).save(out)
    print(out.relative_to(ROOT))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "gen":
        pod = os.environ.get("HEARTLINE_POD") or sys.exit("Falta HEARTLINE_POD")
        base = f"https://{pod}-8188.proxy.runpod.net"
        BG_DIR.mkdir(parents=True, exist_ok=True)
        for variant, prompt in KREA.items():
            for shape, (w, h, seed) in SHAPES.items():
                generate(base, workflow(prompt, w, h, seed), BG_DIR / f"{shape}_{variant}.png")
        for variant, conf in NSFW.items():
            generate(base, workflow_illustrious(conf["prompt"], *conf["size"], conf["seed"]), BG_DIR / f"end_{variant}.png")
    elif cmd == "compose":
        for lang, suffix in SUFFIX.items():
            for variant in KREA:
                for name, (shape, w, h, title, cta) in BANNERS.items():
                    compose(BG_DIR / f"{shape}_{variant}.png", OUT_DIR / f"{name}_{variant}{suffix}.png", w, h,
                            title[lang], cta[lang], lang=lang)
            for variant, conf in NSFW.items():
                for name, (_, w, h, title, cta) in BANNERS.items():
                    compose(BG_DIR / f"end_{variant}.png", OUT_DIR / f"{name}_{variant}{suffix}.png", w, h,
                            title[lang], cta[lang], conf["crop"], lang)
        for variant, conf in NSFW.items():
            photo(BG_DIR / f"end_{variant}.png", OUT_DIR / f"phone_{variant}.png", conf["photo"])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
