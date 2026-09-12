#!/usr/bin/env python3
"""Deriva todos los estados de una escena a partir de la imagen base por inpainting, para
mantener estilo y continuidad: la ropa se repinta en la zona del cuerpo, el compañero en la
zona de detrás de la silla, y el resto de píxeles se copia exacto de la imagen de origen.

    HEARTLINE_POD=<pod> python3 tools/inpaint_scene.py desk_tuesday work_notop_bottom_none
    HEARTLINE_POD=<pod> python3 tools/inpaint_scene.py desk_tuesday --all

Cadena: work_top_bottom_none (base) → work_<ropa>_none (ropa) → work_<ropa>_<quien> (compañero de pie)
y fuck_<ropa>_<quien> (ella inclinada sobre la mesa con él detrás; se repinta su zona entera).
Las máscaras están en ZONES por nivel, medidas sobre la imagen base (1216x832).
"""
import argparse, json, mimetypes, os, sys, time, urllib.parse, urllib.request, uuid
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
from gen_scene import STYLE, NEGATIVE, CANDELA, CLOTHES, LOCATION, CKPT, LORA, TRIGGER, ART  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
UA = {"User-Agent": "overtime-gen/1.0"}
W, H = 1216, 832
MASK_SIZE = [W, H]  # lo cambian las herramientas que trabajan con otro tamaño (sprites 1024x1024)

# Rectángulos (x, y, w, h) sobre la base de cada nivel.
ZONES = {
    # Base "flash": ella sentada en el centro-izquierda mirando a la derecha; la mesa a la derecha,
    # la silla y espacio libre a su izquierda (ahí se coloca el compañero, detrás de ella).
    "desk_tuesday": {
        "face": (500, 270, 200, 160),       # cara: expresión según lo desvestida que va
        "torso": (470, 360, 280, 200),      # blusa y chaleco, brazos incluidos
        "hips": (410, 470, 320, 190),       # falda y parte alta de las medias
        "behind": (140, 40, 360, 770),      # de pie detrás de la silla
        "figure": (280, 40, 600, 770),      # ella + silla: cambio de postura (hasta el techo: cabezas enteras)
        "behind_bent": (300, 40, 300, 770), # él detrás de ella ya inclinada (sin tocar la mesa izquierda)
        "pair": (140, 40, 740, 770),        # ella + él repintados juntos (oral y tetas: él delante de ella)
    }
}
DENOISE = {"clothes": 0.92, "behind": 1.0, "figure": 1.0, "pair": 1.0}
ACT = {("top", "bottom"): "oral", ("notop", "bottom"): "titjob", ("top", "nobottom"): "sex", ("notop", "nobottom"): "sex"}
# La cara cambia con la ropa: cuanto menos lleva, más se le nota. Evita el efecto "copia y pega".
EXPRESSION = {
    ("top", "bottom"): "focused expression, neutral face, looking at laptop",
    ("notop", "bottom"): "light blush, small smile, glancing sideways, playful",
    ("top", "nobottom"): "blush, biting lip, nervous smile, looking at laptop",
    ("notop", "nobottom"): "heavy blush, half-closed eyes, parted lips, aroused expression, sweat drop",
}
# Cuando se pinta al compañero, el modelo tiende a meter otra chica: se prohíbe explícitamente.
NEGATIVE_PEOPLE = ", empty room, no humans, furniture only, 1girl, 2girls, woman, female, girl, breasts, skirt, dress, long hair, ponytail, feminine"


def upload(base: str, path: Path) -> str:
    boundary = uuid.uuid4().hex
    body = b""
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{path.name}\"\r\nContent-Type: {mimetypes.guess_type(path.name)[0] or 'image/png'}\r\n\r\n".encode()
    body += path.read_bytes() + b"\r\n"
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n".encode()
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"subfolder\"\r\n\r\novertime\r\n".encode()
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(base + "/upload/image", data=body, headers={**UA, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    with _urlopen_retry(req, 120) as r:
        info = json.loads(r.read().decode())
    return f"{info.get('subfolder', '')}/{info['name']}" if info.get("subfolder") else info["name"]


def api(base, path, data=None):
    req = urllib.request.Request(base + path, data=json.dumps(data).encode() if data is not None else None,
                                 headers={**UA, "Content-Type": "application/json"})
    with _urlopen_retry(req, 120) as r:
        return json.loads(r.read().decode())


def workflow(image_name: str, rects: list, prompt: str, seed: int, denoise: float, prefix: str) -> dict:
    if TRIGGER:
        prompt = TRIGGER + ", " + prompt
    wf = {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "1": {"class_type": "LoadImage", "inputs": {"image": image_name, "upload": "image"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["4", 1]}},
        "8": {"class_type": "CLIPTextEncode", "inputs": {"text": NEGATIVE + (NEGATIVE_PEOPLE if "1boy" in prompt and "1girl" not in prompt else ", 2girls, 3girls, multiple girls, empty room, no humans"), "clip": ["4", 1]}},
        "20": {"class_type": "SolidMask", "inputs": {"value": 0.0, "width": MASK_SIZE[0], "height": MASK_SIZE[1]}},
    }
    last = "20"
    for i, (x, y, w, h) in enumerate(rects):
        wf[f"3{i}"] = {"class_type": "SolidMask", "inputs": {"value": 1.0, "width": w, "height": h}}
        wf[f"4{i}"] = {"class_type": "MaskComposite", "inputs": {"destination": [last, 0], "source": [f"3{i}", 0], "x": x, "y": y, "operation": "add"}}
        last = f"4{i}"
    wf["50"] = {"class_type": "FeatherMask", "inputs": {"mask": [last, 0], "left": 24, "top": 24, "right": 24, "bottom": 24}}
    wf["11"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["1", 0], "vae": ["4", 2]}}
    wf["12"] = {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["11", 0], "mask": ["50", 0]}}
    model_ref = ["4", 0]
    if LORA:
        wf["10"] = {"class_type": "LoraLoader", "inputs": {"model": ["4", 0], "clip": ["4", 1], "lora_name": LORA[0], "strength_model": LORA[1], "strength_clip": LORA[1]}}
        model_ref = ["10", 0]
        wf["6"]["inputs"]["clip"] = ["10", 1]
        wf["8"]["inputs"]["clip"] = ["10", 1]
    wf["3"] = {"class_type": "KSampler", "inputs": {"model": model_ref, "seed": seed, "steps": 30, "cfg": 6.0, "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": denoise, "positive": ["6", 0], "negative": ["8", 0], "latent_image": ["12", 0]}}
    wf["9"] = {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}}
    # Fuera de la máscara, píxeles originales exactos.
    wf["13"] = {"class_type": "ImageCompositeMasked", "inputs": {"destination": ["1", 0], "source": ["9", 0], "x": 0, "y": 0, "resize_source": False, "mask": ["50", 0]}}
    wf["29"] = {"class_type": "SaveImage", "inputs": {"images": ["13", 0], "filename_prefix": prefix}}
    return wf


def run(base: str, wf: dict, out: Path) -> None:
    pid = api(base, "/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})
    if "error" in pid:
        sys.exit("ComfyUI rechazó el workflow: " + json.dumps(pid)[:600])
    pid = pid["prompt_id"]
    t0 = time.time()
    while True:
        time.sleep(2)
        hist = api(base, f"/history/{pid}")
        if pid in hist:
            break
        if time.time() - t0 > 600:
            sys.exit("tiempo agotado")
    status = hist[pid].get("status", {})
    if status.get("status_str") == "error":
        sys.exit("error en el pod: " + json.dumps(status)[:800])
    img = [i for n in hist[pid]["outputs"].values() for i in n.get("images", [])][0]
    q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": "output"})
    with _urlopen_retry(urllib.request.Request(base + "/view?" + q, headers=UA), 120) as r:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(r.read())
    print(f"  {out.name} en {time.time() - t0:.0f}s")


def plan(level: str, state: str, coworkers: dict) -> tuple:
    """Devuelve (estado_origen, zonas, prompt, tipo) para derivar `state`."""
    mode, top, bottom, who = state.split("_")
    zones = ZONES[level]
    clothes = CLOTHES[(top, bottom)]
    act = ACT[(top, bottom)]
    if mode == "pose":
        pose = {
            "oral": "sitting on the office chair turned to the left, kneeling on the chair, facing left, looking up, mouth open, tongue out, one hand still on the laptop, from side, full body, solo",
            "titjob": "sitting on the office chair turned to the left, facing left, holding her bare breasts together, squeezing breasts, looking up, from side, full body, solo",
            "sex": "standing, bent over the desk, hands on the desk, leaning forward, ass pushed back, looking at the laptop, from side, full body, solo",
        }[act]
        prompt = ", ".join([STYLE, LOCATION[level], CANDELA, clothes, pose])
        return f"work_{top}_{bottom}_none", [zones["figure"]], prompt, "figure"
    if mode == "hot":
        # Sola y desvestida se toca: sin blusa las tetas, sin falda suave, desnuda a fondo.
        solo = {
            ("notop", "bottom"): "sitting on office chair, groping own breasts, squeezing own breasts, one hand on the laptop, light blush, biting lip, eyes closed, from side, full body, solo",
            ("top", "nobottom"): "sitting on office chair, one hand under the desk between her legs, gently touching herself, other hand typing, blush, half-closed eyes, small smile, from side, full body, solo",
            ("notop", "nobottom"): "sitting on office chair, legs spread wide, one foot on the desk, fingering herself, masturbating hard, other hand squeezing breast, head tilted back, heavy blush, open mouth, sweat, aroused, from side, full body, solo",
        }[(top, bottom)]
        prompt = ", ".join([STYLE, LOCATION[level], CANDELA, clothes, solo])
        return f"work_{top}_{bottom}_none", [zones["figure"]], prompt, "figure"
    if who == "none":
        rects = [zones["face"]]
        if top == "notop":
            rects.append(zones["torso"])
        if bottom == "nobottom":
            rects.append(zones["hips"])
        prompt = ", ".join([STYLE, LOCATION[level], CANDELA, clothes, EXPRESSION[(top, bottom)], "sitting at desk, from side, typing, same pose"])
        return "work_top_bottom_none", rects, prompt, "clothes"
    man = coworkers[who]
    man_desc = f"(1boy:1.4), (adult male:1.3), masculine, broad shoulders, flat chest, {man.get('look', 'short brown hair, dress shirt and tie')}, office worker, full body, from side"
    if mode == "work":
        prompt = ", ".join([STYLE, LOCATION[level], "1girl and 1boy, hetero, couple", CANDELA, clothes,
                            "sitting on office chair, typing on laptop, from side, focused",
                            man_desc, "standing right behind her chair, leaning over the chair back, looking down at her, holding a coffee mug, smirk"])
        return f"work_{top}_{bottom}_none", [zones["pair"]], prompt, "pair"
    if mode == "pose":
        # Paso intermedio: ella sola, inclinada sobre la mesa, sin nadie detrás.
        prompt = ", ".join([STYLE, LOCATION[level], CANDELA, clothes, "standing, bent over the desk, hands on the desk, leaning forward, ass pushed back, looking at the laptop, from side, full body, solo"])
        return f"work_{top}_{bottom}_none", [zones["figure"]], prompt, "figure"
    if act == "sex":
        prompt = ", ".join([STYLE, man_desc, "standing right behind her, hips pressed against her ass, hands on her hips, thrusting, sex from behind, " + ("clothed sex, skirt lifted" if bottom == "bottom" else "vaginal, bare ass"), "hetero, office interior"])
        return f"pose_{top}_{bottom}_none", [zones["behind_bent"]], prompt, "behind"
    her = {
        "oral": "sitting on office chair turned to the left, facing left, leaning forward, fellatio, penis in mouth, sucking, looking up at him, one hand reaching back to the laptop on the desk",
        "titjob": "(sitting on office chair:1.3), chair turned to the left, facing left, (paizuri:1.4), (penis between breasts:1.3), pressing her breasts together with both hands around his penis, looking up at him, mouth slightly open",
    }[act]
    prompt = ", ".join([STYLE, LOCATION[level], "(1girl:1.2) and (1boy:1.3), hetero, couple, sex", CANDELA, clothes, her,
                        man_desc, "standing on the left in front of her, pants down, hand on her head, looking down at her, smirk"])
    return f"work_{top}_{bottom}_none", [zones["pair"]], prompt, "pair"


def all_states(coworkers: dict) -> list:
    states = []
    for top in ("top", "notop"):
        for bottom in ("bottom", "nobottom"):
            if not (top == "top" and bottom == "bottom"):
                states.append(f"work_{top}_{bottom}_none")
    for top in ("top", "notop"):
        for bottom in ("bottom", "nobottom"):
            if not (top == "top" and bottom == "bottom"):
                states.append(f"hot_{top}_{bottom}_none")
    for who in coworkers:
        if coworkers[who].get("kind") != "coworker":
            continue
        for top in ("top", "notop"):
            for bottom in ("bottom", "nobottom"):
                states.append(f"work_{top}_{bottom}_{who}")
                states.append(f"fuck_{top}_{bottom}_{who}")
    return states


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("level")
    p.add_argument("states", nargs="*")
    p.add_argument("--all", action="store_true")
    p.add_argument("--seed", type=int, default=int(ART.get("seed", 4243)))
    p.add_argument("--force", action="store_true", help="regenera aunque exista")
    p.add_argument("--denoise", type=float, default=None, help="fuerza del repintado (por defecto según tipo de zona)")
    a = p.parse_args()
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    coworkers = json.loads((ROOT / "data/coworkers.json").read_text())
    folder = ROOT / "assets/scenes" / a.level
    states = all_states(coworkers) if a.all else a.states
    uploaded: dict = {}
    for state in states:
        out = folder / f"{state}.png"
        if out.exists() and not a.force:
            print(f"  {state}: ya existe")
            continue
        source, rects, prompt, kind = plan(a.level, state, coworkers)
        src_path = folder / f"{source}.png"
        if not src_path.exists() and source.startswith("pose_"):
            p_source, p_rects, p_prompt, p_kind = plan(a.level, source, coworkers)
            print(f"{source} ← {p_source} [{p_kind}]")
            if p_source not in uploaded:
                uploaded[p_source] = upload(base, folder / f"{p_source}.png")
            run(base, workflow(uploaded[p_source], p_rects, p_prompt, a.seed, DENOISE[p_kind], f"overtime/{a.level}_{source}"), src_path)
        if not src_path.exists():
            sys.exit(f"Falta el origen {source} para {state}")
        if source not in uploaded:
            uploaded[source] = upload(base, src_path)
        print(f"{state} ← {source} [{kind}]")
        run(base, workflow(uploaded[source], rects, prompt, a.seed, a.denoise if a.denoise is not None else DENOISE[kind], f"overtime/{a.level}_{state}"), out)


if __name__ == "__main__":
    main()
