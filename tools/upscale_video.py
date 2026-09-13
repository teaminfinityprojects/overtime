#!/usr/bin/env python3
"""Reescala los bucles H3 (704x480) al doble con un modelo ESRGAN para dibujos (4x-AnimeSharp → 1408x960)
en el pod y los deja como vídeo Theora para Godot, con el audio original del clip al lado.

    HEARTLINE_POD=<pod> python3 tools/upscale_video.py [.godot/video/*.mp4]     # por defecto los 31 bucles

Salida: .godot/video/up/<nombre>.mp4 (h264 1408x960 24 fps, con audio) →
        assets/video/<nivel>/<nombre>.ogv (Theora, sin audio) + <nombre>.ogg (audio del clip, estéreo).
"""
import json, os, shutil, subprocess, sys, time, urllib.parse, urllib.request, uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_video import _urlopen_retry, api  # noqa: E402
from inpaint_scene import upload  # noqa: E402

MODEL = "realesrgan_x4plus_anime_6b.pt"
W, H = 1408, 960
LEVEL = "desk_tuesday"
FFMPEG = "/opt/homebrew/bin/ffmpeg"


def workflow(video: str, prefix: str) -> dict:
    return {
        "1": {"class_type": "LoadVideo", "inputs": {"file": video}},
        "2": {"class_type": "GetVideoComponents", "inputs": {"video": ["1", 0]}},
        "3": {"class_type": "UpscaleModelLoader", "inputs": {"model_name": MODEL}},
        "4": {"class_type": "ImageUpscaleWithModel", "inputs": {"upscale_model": ["3", 0], "image": ["2", 0]}},
        "5": {"class_type": "ImageScale", "inputs": {"image": ["4", 0], "upscale_method": "lanczos", "width": W, "height": H, "crop": "disabled"}},
        "6": {"class_type": "CreateVideo", "inputs": {"images": ["5", 0], "fps": ["2", 2], "audio": ["2", 1]}},
        "7": {"class_type": "SaveVideo", "inputs": {"video": ["6", 0], "filename_prefix": prefix, "format": "mp4", "codec": "h264"}},
    }


def run(base: str, wf: dict, out: Path) -> None:
    res = api(base, "/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})
    if "error" in res:
        sys.exit("ComfyUI rechazó el workflow: " + json.dumps(res, ensure_ascii=False)[:1500])
    pid = res["prompt_id"]
    t0 = time.time()
    while True:
        time.sleep(4)
        hist = api(base, f"/history/{pid}")
        if pid in hist:
            break
        if time.time() - t0 > 1800:
            sys.exit("tiempo agotado")
    h = hist[pid]
    if h.get("status", {}).get("status_str") == "error":
        sys.exit("error en el pod: " + json.dumps(h["status"], ensure_ascii=False)[:1500])
    v = [x for n in h["outputs"].values() for k in ("videos", "gifs", "images") for x in n.get(k, [])][0]
    q = urllib.parse.urlencode({"filename": v["filename"], "subfolder": v.get("subfolder", ""), "type": v.get("type", "output")})
    with _urlopen_retry(urllib.request.Request(base + "/view?" + q, headers={"User-Agent": "overtime-gen/1.0"}), 600) as r:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(r.read())
    print(f"  {out} en {time.time() - t0:.0f}s", flush=True)


def to_godot(mp4: Path, name: str) -> None:
    dst = Path("assets/video") / LEVEL
    dst.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg2theora", "-v", "9", "--noaudio", "-o", str(dst / f"{name}.ogv"), str(mp4)], check=True, capture_output=True)
    ogg = Path("assets/anim") / LEVEL / f"{name}.ogg"
    if ogg.exists():
        shutil.copy(ogg, dst / f"{name}.ogg")
    else:
        # Clip sin pista de audio (p. ej. pruebas de Wan): se deja sin .ogg y la escena cae al efecto por acto.
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", str(mp4), "-vn", "-ac", "2", "-ar", "44100", "-c:a", "vorbis", "-strict", "-2", "-q:a", "4", str(dst / f"{name}.ogg")], check=False)


def main() -> None:
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    files = [Path(a) for a in sys.argv[1:]] or sorted(p for p in Path(".godot/video").glob("*.mp4") if not p.name.startswith(("_", "wan_")) and not p.stem.endswith(("_v2", "_turbo")))
    for src in files:
        out = Path(".godot/video/up") / src.name
        if not out.exists():
            print(f"{src.name} → x2 {MODEL}", flush=True)
            run(base, workflow(upload(base, src), "overtime/up"), out)
        to_godot(out, src.stem)
        print(f"  ogv+ogg {src.stem}", flush=True)
    print("LOTE UPSCALE TERMINADO", flush=True)


if __name__ == "__main__":
    main()
