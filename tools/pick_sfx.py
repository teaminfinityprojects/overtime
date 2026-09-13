#!/usr/bin/env python3
"""Elige, por acto, el candidato de Stable Audio 3 con más actividad (fracción de ventanas de 100 ms
por encima de -30 dB RMS y rango dinámico) y lo copia a assets/sfx/<acto>.ogg.

    python3 tools/pick_sfx.py [.godot/sfx] [--force act=seed ...]   # p. ej. --force hot=2
"""
import re, shutil, subprocess, sys
from collections import defaultdict
from pathlib import Path

FFMPEG = "/opt/homebrew/bin/ffmpeg"


def activity(path: Path) -> tuple[float, float]:
    out = subprocess.run([FFMPEG, "-i", str(path), "-af", "astats=metadata=1:reset=1:length=0.1,ametadata=print:key=lavfi.astats.Overall.RMS_level", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    vals = [float(v) for v in re.findall(r"RMS_level=(-?[0-9.]+)", out)]
    if not vals:
        return 0.0, 0.0
    loud = sum(1 for v in vals if v > -30.0) / len(vals)
    return loud, max(vals) - min(vals)


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else Path(".godot/sfx")
    forced = {a.split("=")[0]: int(a.split("=")[1]) for a in sys.argv[sys.argv.index("--force") + 1:]} if "--force" in sys.argv else {}
    groups: dict[str, list] = defaultdict(list)
    for f in sorted(src.glob("*_[0-9].ogg")):
        act, seed = f.stem.rsplit("_", 1)
        if act.startswith("test"):
            continue
        loud, rng = activity(f)
        groups[act].append((int(seed), loud, rng, f))
    Path("assets/sfx").mkdir(exist_ok=True)
    for act, cands in sorted(groups.items()):
        cands.sort(key=lambda c: (c[1], c[2]), reverse=True)
        best = next((c for c in cands if c[0] == forced.get(act)), cands[0])
        shutil.copy(best[3], f"assets/sfx/{act}.ogg")
        print(f"{act:7s} → semilla {best[0]}   " + "  ".join(f"[{c[0]}] {c[1]*100:3.0f}% audible, {c[2]:4.1f} dB" for c in cands))


if __name__ == "__main__":
    main()
