#!/usr/bin/env python3
"""Variantes de un sprite máster (sobre verde) por inpaint de zonas: ropa y cara. Todo lo que no
está en la zona se copia exacto, así que la pose, el tamaño y la silla no cambian.

    HEARTLINE_POD=<pod> python3 tools/sprite_variants.py sit           # sit_* a partir de sit_top_bottom
Zonas medidas sobre el máster (1024x1024) en ZONES.
"""
import os, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_scene import STYLE, NEGATIVE, CANDELA, CLOTHES, TRIGGER  # noqa: E402
import inpaint_scene  # noqa: E402
from inpaint_scene import upload, workflow, run, EXPRESSION  # noqa: E402
inpaint_scene.MASK_SIZE[:] = [1024, 1024]

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets/layers/girl/raw"
GREEN = "simple background, flat green background, green screen"
ZONES = {
    "sit": {"face": (620, 160, 260, 200), "torso": (590, 340, 240, 220), "hips": (610, 520, 300, 240), "screen": (250, 262, 150, 220), "hands": (400, 430, 220, 110)},
}


def fix_screens(base: str, pose: str) -> None:
    """La pantalla salió verde por el green screen del prompt: se repinta con una hoja de cálculo.
    Misma zona, misma semilla y mismo contenido de entrada en las 4 variantes → resultado idéntico."""
    zone = ZONES[pose]["screen"]
    for path in sorted(RAW.glob(f"{pose}_*.png")):
        image = upload(base, path)
        prompt = ", ".join(x for x in [TRIGGER, STYLE, "black computer monitor displaying a white spreadsheet document with rows of small text and a chart, office software, screen glow"] if x)
        wf = workflow(image, [zone], prompt, 777, 0.9, f"overtime/screenfix_{path.stem}")
        wf["8"]["inputs"]["text"] = NEGATIVE + ", green screen, green, blank screen, person, face"
        print(f"pantalla {path.stem}:", end="", flush=True)
        run(base, wf, path)


def make_desk_layer(base: str, pose: str) -> None:
    """Capa de mesa: el máster con las manos repintadas como mesa vacía; luego chroma_key.gd la
    recorta a la mitad izquierda (solo mesa y monitor). Así la mesa es idéntica en TODAS las poses."""
    zone = ZONES[pose]["hands"]
    master = RAW / f"{pose}_top_bottom.png"
    image = upload(base, master)
    prompt = ", ".join(x for x in [TRIGGER, STYLE, "black office desk surface, computer keyboard on the desk, side view, furniture, nothing else"] if x)
    wf = workflow(image, [zone], prompt, 778, 0.95, "overtime/desk_layer")
    wf["8"]["inputs"]["text"] = NEGATIVE + ", hands, arms, fingers, person, 1girl, 1boy, creature, green"
    out = ROOT / "assets/layers/props/raw/desk.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    print("capa de mesa:", end="", flush=True)
    run(base, wf, out)


def main() -> None:
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    pose = sys.argv[1] if len(sys.argv) > 1 else "sit"
    if len(sys.argv) > 2 and sys.argv[2] == "screens":
        fix_screens(base, pose)
        return
    if len(sys.argv) > 2 and sys.argv[2] == "desk":
        make_desk_layer(base, pose)
        return
    zones = ZONES[pose]
    master = RAW / f"{pose}_top_bottom.png"
    image = upload(base, master)
    for top, bottom in [("notop", "bottom"), ("top", "nobottom"), ("notop", "nobottom")]:
        rects = [zones["face"]]
        if top == "notop":
            rects.append(zones["torso"])
        if bottom == "nobottom":
            rects.append(zones["hips"])
        prompt = ", ".join(x for x in [TRIGGER, STYLE, "1girl, solo", CANDELA, CLOTHES[(top, bottom)], EXPRESSION[(top, bottom)],
                                       "sitting on a black office chair, facing left, typing, same pose", GREEN] if x)
        wf = workflow(image, rects, prompt, 4243, 0.92, f"overtime/sprite_{pose}_{top}_{bottom}")
        wf["8"]["inputs"]["text"] = NEGATIVE + ", 1boy, male, desk, monitor, window, wall, floor"
        print(f"{pose}_{top}_{bottom}:", end="", flush=True)
        run(base, wf, RAW / f"{pose}_{top}_{bottom}.png")


if __name__ == "__main__":
    main()
