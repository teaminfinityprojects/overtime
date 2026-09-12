#!/usr/bin/env python3
"""Arte por CAPAS, como una novela visual: un fondo fijo (oficina vacía), la chica como sprite
por pose y ropa, y el compañero como sprite por acto. El juego los compone en anclas fijas, así
que el fondo nunca cambia y ella siempre mide lo mismo.

    HEARTLINE_POD=<pod> python3 tools/gen_layers.py background            # oficina vacía desde la base
    HEARTLINE_POD=<pod> python3 tools/gen_layers.py girl [pose_ropa ...]  # sprites de Candela (verde)
    HEARTLINE_POD=<pod> python3 tools/gen_layers.py men [quien_acto ...]  # sprites de compañeros (verde)
Luego: godot --headless --path . -s res://tools/chroma_key.gd -- res://assets/layers/girl res://assets/layers/men
"""
import json, os, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_scene import STYLE, NEGATIVE, CANDELA, CLOTHES, CKPT, LORA, TRIGGER, run  # noqa: E402
from inpaint_scene import upload, workflow as inpaint_workflow  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GREEN = "simple background, flat green background, green screen, no shadow, no floor"
NEG_SPRITE = NEGATIVE + ", desk, table, monitor, computer, laptop, keyboard, window, wall, floor, ceiling, plant, shadow, gradient background, multiple people, 2girls, 2boys"

# Poses de la chica. El sprite incluye la silla cuando está sentada (el fondo no tiene silla).
NO_DESK = "(no desk:1.4), (no table:1.3), (no monitor:1.3), no computer, nothing in front of her, empty space in front of her"
GIRL_POSES = {
    "sit":    f"sitting on a black office chair, facing left, both arms stretched forward, hands raised at waist height as if typing in the air, looking forward to the left, {NO_DESK}, full body, from side",
    "hot":    f"sitting on a black office chair, facing left, one arm stretched forward as if typing in the air, {{solo}}, {NO_DESK}, full body, from side",
    "bent":   f"standing, bent over forward at the waist, arms stretched forward and down, facing left, ass pushed back to the right, looking forward, {NO_DESK}, full body, from side",
    "kneel":  f"sitting on a black office chair, facing right, leaning forward, mouth wide open, tongue out, looking up to the right, one arm reaching back behind her, {NO_DESK}, full body, from side",
    "titjob": f"sitting on a black office chair, facing right, leaning forward, pressing her bare breasts together with both hands, looking up to the right, {NO_DESK}, full body, from side",
}
DESK_PROMPT = ("black office desk with a computer monitor showing a spreadsheet, keyboard and mouse on the desk, side view, "
               "the desk seen from the side, no people, nobody, furniture only, object, product shot")
SOLO = {
    ("notop", "bottom"): "groping own breasts with one hand, eyes closed, biting lip, light blush",
    ("top", "nobottom"): "one hand between her legs under the skirt line, gently touching herself, blush, half-closed eyes",
    ("notop", "nobottom"): "legs spread, fingering herself, other hand squeezing breast, head tilted back, heavy blush, open mouth, sweat",
}
# Actos del compañero (sprites sueltos, sin ella): se colocan pegados a su ancla en el juego.
MAN_ACTS = {
    "wait":   "standing, facing right, holding a coffee mug, smirk, relaxed posture, full body, from side",
    "behind": "standing, facing right, pants pulled down to the knees, hips thrust forward, hands reaching forward gripping invisible hips, leaning slightly forward, erect penis, full body, from side",
    "front":  "standing, facing right, pants pulled down to the knees, erect penis, one hand reaching forward down to head height, other hand on own hip, looking down to the right, smirk, full body, from side",
}
SEED = 5150


def sprite_workflow(prompt: str, negative: str, seed: int, prefix: str, size=(1024, 1024), use_lora: bool = True) -> dict:
    wf = {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["4", 1]}},
        "8": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["4", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": size[0], "height": size[1], "batch_size": 1}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["4", 0], "seed": seed, "steps": 30, "cfg": 6.0, "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": 1, "positive": ["6", 0], "negative": ["8", 0], "latent_image": ["5", 0]}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": prefix}},
    }
    if LORA and use_lora:
        wf["10"] = {"class_type": "LoraLoader", "inputs": {"model": ["4", 0], "clip": ["4", 1], "lora_name": LORA[0], "strength_model": LORA[1], "strength_clip": LORA[1]}}
        wf["3"]["inputs"]["model"] = ["10", 0]
        wf["6"]["inputs"]["clip"] = ["10", 1]
        wf["8"]["inputs"]["clip"] = ["10", 1]
    return wf


def gen_background(base_url: str, level: str, seed: int = SEED) -> None:
    """Oficina vacía, mesa con portátil a la IZQUIERDA (los sprites de Candela miran a la izquierda),
    suelo libre en el centro y la derecha para ella, su silla y el compañero. Sin personas."""
    prompt = ", ".join([STYLE, "modern office interior, wide shot, eye level, scenery, background art, visual novel background, architecture",
                        "cubicle partition walls, large window with city skyline, potted plant in the corner, ceiling lights, filing cabinet against the far wall, clean tiled floor"])
    negative = NEGATIVE + ", 1girl, 1boy, person, people, human, silhouette, character, mascot, creature, monster, eyes, face, black blob, stick figure, shadow figure, chair, office chair, desk"
    run(base_url, sprite_workflow(prompt, negative, seed, f"overtime/{level}_background", (1216, 832), use_lora=False), ROOT / "assets/layers" / level / "background.png")


def gen_desk(base_url: str, seeds: list) -> None:
    """La mesa con el ordenador como capa propia sobre verde; se dibuja DELANTE de la chica,
    así sus manos quedan sobre el teclado y la mesa tapa las muñecas."""
    for seed in seeds:
        prompt = ", ".join(x for x in [TRIGGER, STYLE, DESK_PROMPT, GREEN] if x)
        negative = NEGATIVE + ", 1girl, 1boy, person, people, human, hands, chair, window, wall, floor, shadow, gradient background"
        print(f"desk seed {seed}:", end="", flush=True)
        run(base_url, sprite_workflow(prompt, negative, seed, f"overtime/desk", (1024, 768)), ROOT / "assets/layers/props/raw" / f"desk_{seed}.png")


def gen_girl(base_url: str, wanted: list) -> None:
    seed_offset = int(os.environ.get("SEED_OFFSET", "0"))
    for key in wanted:
        pose, top, bottom = key.split("_")
        text = GIRL_POSES[pose]
        if pose == "hot":
            text = text.format(solo=SOLO[(top, bottom)])
        prompt = ", ".join(x for x in [TRIGGER, STYLE, "1girl, solo", CANDELA, CLOTHES[(top, bottom)], text, GREEN] if x)
        # Misma semilla para todas las variantes de una pose: solo cambia la ropa.
        seed = SEED + list(GIRL_POSES).index(pose) + seed_offset
        print(f"girl {key} seed {seed}:", end="", flush=True)
        run(base_url, sprite_workflow(prompt, NEG_SPRITE + ", 1boy, male", seed, f"overtime/girl_{key}"), ROOT / "assets/layers/girl/raw" / f"{key}.png")


def gen_men(base_url: str, wanted: list) -> None:
    coworkers = json.loads((ROOT / "data/coworkers.json").read_text())
    for key in wanted:
        who, act = key.split("_")
        man = coworkers[who]
        prompt = ", ".join(x for x in [TRIGGER, STYLE, "1boy, solo, adult male, masculine, office worker", man.get("look", ""), MAN_ACTS[act], GREEN] if x)
        seed = int(man.get("sprite_seed", SEED)) + list(MAN_ACTS).index(act) * 7
        print(f"man {key}:", end="", flush=True)
        run(base_url, sprite_workflow(prompt, NEG_SPRITE + ", 1girl, woman, female, girl, breasts", seed, f"overtime/man_{key}", (832, 1216)), ROOT / "assets/layers/men/raw" / f"{key}.png")


PAIR_ACTS = {
    # Ella sentada en su silla girada hacia él; él de pie delante. Un solo dibujo con los dos.
    "oral": ("(1girl and 1boy:1.3), hetero, couple, {girl}, {clothes}, sitting on a black office chair turned toward him, "
             "facing right, leaning forward, (fellatio:1.4), (penis in mouth:1.3), eyes looking up at him, one hand on his hip, "
             "{man}, standing in front of her on the right, facing left, pants pulled down to the knees, hand on her head, looking down at her, smirk"),
    "titjob": ("(1girl and 1boy:1.3), hetero, couple, {girl}, {clothes}, sitting on a black office chair turned toward him, "
               "facing right, leaning forward, (paizuri:1.4), (penis between breasts:1.3), pressing her breasts together with both hands, looking up at him, mouth open, "
               "{man}, standing in front of her on the right, facing left, pants pulled down to the knees, hands on her shoulders, looking down at her, smirk"),
    "sex": ("(1girl and 1boy:1.3), hetero, couple, {girl}, {clothes}, standing, bent over forward at the waist, hands on a black office desk on the left, "
            "facing left, looking at the monitor, ass pushed back, (sex from behind:1.4), (doggystyle:1.2), "
            "{man}, standing right behind her on the right, facing left, pants pulled down to the knees, hands on her hips, thrusting, smirk"),
}


def gen_pair(base_url: str, act: str, who: str, clothes_key: tuple, seeds: list, out_dir: Path) -> None:
    """Máster de pareja sobre verde, una imagen por semilla, para elegir el bueno a mano."""
    coworkers = json.loads((ROOT / "data/coworkers.json").read_text())
    man = coworkers[who]
    man_desc = f"1boy, adult male, masculine, office worker, {man.get('look', 'short brown hair, dress shirt and tie')}"
    body = PAIR_ACTS[act].format(girl=CANDELA, clothes=CLOTHES[clothes_key], man=man_desc)
    prompt = ", ".join(x for x in [TRIGGER, STYLE, body, "full body, from side, wide shot, both characters fully visible, heads fully visible", GREEN] if x)
    negative = NEGATIVE + ", 2girls, 3girls, multiple girls, 2boys, window, wall, floor, ceiling, plant, shadow, gradient background, cropped head, out of frame"
    for seed in seeds:
        print(f"{act} {who} seed {seed}:", end="", flush=True)
        run(base_url, sprite_workflow(prompt, negative, seed, f"overtime/pair_{act}_{who}", (1216, 1024)), out_dir / f"{act}_{who}_{seed}.png")


def main() -> None:
    pod = os.environ.get("HEARTLINE_POD")
    if not pod:
        sys.exit("Falta HEARTLINE_POD")
    base_url = f"https://{pod}-8188.proxy.runpod.net"
    what = sys.argv[1] if len(sys.argv) > 1 else "girl"
    rest = sys.argv[2:]
    if what == "background":
        gen_background(base_url, rest[0] if rest else "desk_tuesday", int(rest[1]) if len(rest) > 1 else SEED)
    elif what == "girl":
        default = [f"sit_{t}_{b}" for t in ("top", "notop") for b in ("bottom", "nobottom")] + [f"hot_{t}_{b}" for (t, b) in SOLO] + ["bent_top_bottom", "bent_notop_bottom", "bent_top_nobottom", "bent_notop_nobottom", "kneel_top_bottom", "titjob_notop_bottom"]
        gen_girl(base_url, rest or default)
    elif what == "desk":
        gen_desk(base_url, [int(x) for x in rest[0].split(",")] if rest else [9001, 9002, 9003])
    elif what == "pair":
        act = rest[0]
        who = rest[1] if len(rest) > 1 else "dani"
        seeds = [int(x) for x in rest[2].split(",")] if len(rest) > 2 else [8101, 8102, 8103, 8104]
        clothes = {"oral": ("top", "bottom"), "titjob": ("notop", "bottom"), "sex": ("notop", "nobottom")}[act]
        gen_pair(base_url, act, who, clothes, seeds, ROOT / ".godot/art_tests/pairs")
    elif what == "men":
        coworkers = json.loads((ROOT / "data/coworkers.json").read_text())
        default = [f"{w}_{a}" for w in coworkers if coworkers[w].get("kind") == "coworker" for a in MAN_ACTS]
        gen_men(base_url, rest or default)


if __name__ == "__main__":
    main()
