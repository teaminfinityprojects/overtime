#!/usr/bin/env python3
"""Props sueltos sobre verde en el estilo del proyecto (ropa colgada, objetos), para superponer
en la escena desde scene_view: HEARTLINE_POD=<pod> python3 tools/gen_props.py
Luego: godot --headless --path . -s res://tools/chroma_key.gd -- res://assets/props
"""
import os, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_scene import STYLE, NEGATIVE, TRIGGER, run  # noqa: E402
from gen_layers import sprite_workflow, GREEN  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PROPS = {
    "blouse_hanging": ("a white long-sleeved dress shirt with a beige knit sweater vest over it, hanging limp from a single wall hook, "
                       "empty clothes with no body inside, seen from the front, slightly wrinkled", 7301),
    "skirt_hanging": ("a dark red pencil skirt with sheer brown pantyhose draped over it, hanging limp over the edge of an invisible surface, "
                      "empty clothes with no body inside, seen from the front, slightly wrinkled", 7302),
}
NEG = NEGATIVE + ", 1girl, 1boy, person, people, human, body, legs, arms, mannequin, hanger, furniture, wall, floor, shadow, gradient background"


def main() -> None:
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base = f"https://{pod}-8188.proxy.runpod.net"
    for name, (desc, seed) in PROPS.items():
        prompt = ", ".join(x for x in [TRIGGER, STYLE, desc, "object, product shot, centered", GREEN] if x)
        print(f"{name}:", end="", flush=True)
        run(base, sprite_workflow(prompt, NEG, seed, f"overtime/prop_{name}", (768, 1024)), ROOT / "assets/props/raw" / f"{name}.png")


if __name__ == "__main__":
    main()
