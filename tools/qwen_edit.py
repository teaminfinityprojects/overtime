#!/usr/bin/env python3
"""Edición de imágenes con Qwen-Image-Edit 2509 en el pod: una imagen base bien hecha y a partir de
ella todo lo demás por instrucciones ("quítale la blusa", "añade un hombre de pie detrás…"), sin
máscaras. Solo biblioteca estándar.

    HEARTLINE_POD=<pod> python3 tools/qwen_edit.py base.png "instrucción" salida.png [--ref otra.png] [--seed N] [--steps 20]
    HEARTLINE_POD=<pod> python3 tools/qwen_edit.py --batch edits.json      # lista de {in, prompt, out, ref?}

Con --ref se pasa una segunda imagen (p. ej. el sprite del compañero) para que copie su identidad.
La salida conserva el tamaño de la base. Usa el acelerador Lightning (4 pasos) si está instalado.
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
UNET = "qwenImageEdit2511_fp8.safetensors"
CLIP = "qwen/qwen_2.5_vl_7b_fp8_scaled.safetensors"
VAE = "qwen_image_vae.safetensors"
LIGHTNING = "qwen-image-edit-lightning/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors"
NEGATIVE = "blurry, low quality, deformed, extra fingers, text, watermark, different character, changed face, changed hairstyle"


def api(base, path, data=None, timeout=120):
    req = urllib.request.Request(base + path, data=json.dumps(data).encode() if data is not None else None, headers=UA)
    with _urlopen_retry(req, timeout) as r:
        return json.loads(r.read().decode())


def available(base: str, node: str, field: str, name: str) -> bool:
    info = api(base, f"/object_info/{node}")
    return name in info[node]["input"]["required"][field][0]


NSFW_LORA = "nsfw_flux_wan_2_2_qwen_mystic_xxx.safetensors"


def workflow(image: str, ref: str, prompt: str, seed: int, steps: int, cfg: float, lightning: bool, prefix: str, lora: float = 0.0, lora_name: str = NSFW_LORA, negative: str = NEGATIVE) -> dict:
    wf = {
        "37": {"class_type": "UNETLoader", "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "38": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "qwen_image", "device": "default"}},
        "39": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "78": {"class_type": "LoadImage", "inputs": {"image": image}},
        # Escala la base a ~1 MP manteniendo proporción, como recomienda el flujo oficial.
        "93": {"class_type": "ImageScaleToTotalPixels", "inputs": {"image": ["78", 0], "upscale_method": "lanczos", "megapixels": 1.0, "resolution_steps": 8}},
        "88": {"class_type": "VAEEncode", "inputs": {"pixels": ["93", 0], "vae": ["39", 0]}},
        "66": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["37", 0], "shift": 3.0}},
        "76": {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {"clip": ["38", 0], "prompt": prompt, "vae": ["39", 0], "image1": ["93", 0]}},
        "77": {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {"clip": ["38", 0], "prompt": negative, "vae": ["39", 0], "image1": ["93", 0]}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["66", 0], "seed": seed, "steps": steps, "cfg": cfg, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0, "positive": ["76", 0], "negative": ["77", 0], "latent_image": ["88", 0]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["39", 0]}},
        "60": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": prefix}},
    }
    if ref:
        wf["79"] = {"class_type": "LoadImage", "inputs": {"image": ref}}
        wf["94"] = {"class_type": "ImageScaleToTotalPixels", "inputs": {"image": ["79", 0], "upscale_method": "lanczos", "megapixels": 1.0, "resolution_steps": 8}}
        wf["76"]["inputs"]["image2"] = ["94", 0]
        wf["77"]["inputs"]["image2"] = ["94", 0]
    model_ref = ["37", 0]
    if lora > 0.0:
        # LoRA NSFW: el modelo base esquiva los actos explícitos aunque acepte desnudos.
        wf["90"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": model_ref, "lora_name": lora_name, "strength_model": lora}}
        model_ref = ["90", 0]
    wf["66"]["inputs"]["model"] = model_ref
    if lightning:
        wf["89"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": model_ref, "lora_name": LIGHTNING, "strength_model": 1.0}}
        wf["66"]["inputs"]["model"] = ["89", 0]
        wf["3"]["inputs"]["steps"] = 4
        wf["3"]["inputs"]["cfg"] = 1.0
    return wf


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
        if time.time() - t0 > 900:
            sys.exit("tiempo agotado")
    h = hist[pid]
    if h.get("status", {}).get("status_str") == "error":
        sys.exit("error en el pod: " + json.dumps(h["status"], ensure_ascii=False)[:1500])
    img = [i for n in h["outputs"].values() for i in n.get("images", [])][0]
    q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": "output"})
    with _urlopen_retry(urllib.request.Request(base + "/view?" + q, headers={"User-Agent": UA["User-Agent"]}), 120) as r:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(r.read())
    print(f"  {out} en {time.time() - t0:.0f}s", flush=True)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("image", nargs="?")
    p.add_argument("prompt", nargs="?")
    p.add_argument("out", nargs="?")
    p.add_argument("--ref", default=None)
    p.add_argument("--seed", type=int, default=4243)
    p.add_argument("--steps", type=int, default=20)
    p.add_argument("--cfg", type=float, default=4.0)
    p.add_argument("--no-lightning", action="store_true")
    p.add_argument("--lora", type=float, default=0.0, help="fuerza de la LoRA NSFW (0 = sin LoRA)")
    p.add_argument("--lora-name", default=NSFW_LORA)
    p.add_argument("--batch", default=None)
    a = p.parse_args()
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    lightning = (not a.no_lightning) and available(base, "LoraLoaderModelOnly", "lora_name", LIGHTNING)
    print("Lightning 4 pasos:", "sí" if lightning else "no (20 pasos)")

    jobs = json.loads(Path(a.batch).read_text()) if a.batch else [{"in": a.image, "prompt": a.prompt, "out": a.out, "ref": a.ref}]
    uploaded: dict = {}
    for job in jobs:
        for key in ("in", "ref"):
            path = job.get(key)
            if path and path not in uploaded:
                uploaded[path] = upload(base, Path(path))
        # Si la entrada se generó en un paso anterior del mismo batch, resubirla actualizada.
        if job["in"] in [j["out"] for j in jobs]:
            uploaded[job["in"]] = upload(base, Path(job["in"]))
        print(f"{Path(job['in']).name} → {job['prompt'][:90]}", flush=True)
        wf = workflow(uploaded[job["in"]], uploaded.get(job.get("ref") or "", ""), job["prompt"], int(job.get("seed", a.seed)), a.steps, a.cfg, lightning, "overtime/qwen_edit", float(job.get("lora", a.lora)), job.get("lora_name", a.lora_name), NEGATIVE + ", " + job["negative"] if job.get("negative") else NEGATIVE)
        run(base, wf, Path(job["out"]))


if __name__ == "__main__":
    main()
