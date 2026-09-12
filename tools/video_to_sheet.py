#!/usr/bin/env python3
"""Convierte un bucle mp4 en spritesheet PNG + JSON para Godot (que solo reproduce Theora).

    python3 tools/video_to_sheet.py entrada.mp4 assets/anim/desk_tuesday/fuck_top_bottom_dani [--fps 12] [--width 832]
Genera <salida>.png (rejilla de 8 columnas), <salida>.json {frames, cols, rows, fps, w, h} y <salida>.ogg
(audio estéreo del clip, que Godot reproduce en bucle junto al spritesheet).
"""
import argparse, json, math, subprocess, shutil
from pathlib import Path

FFMPEG = shutil.which("ffmpeg") or str(Path.home() / ".local/bin/ffmpeg")
FFPROBE = shutil.which("ffprobe") or str(Path.home() / ".local/bin/ffprobe")


def convert(video: str, out: str, fps: int = 12, width: int = 832, cols: int = 8) -> dict:
    probe = subprocess.run([FFPROBE, "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,duration", "-of", "json", video], capture_output=True, text=True, check=True)
    st = json.loads(probe.stdout)["streams"][0]
    duration = float(st["duration"])
    h = round(int(st["height"]) * width / int(st["width"]) / 2) * 2
    frames = max(1, round(duration * fps))
    rows = math.ceil(frames / cols)
    outp = Path(out)
    outp.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", video, "-vf", f"fps={fps},scale={width}:{h},tile={cols}x{rows}", "-frames:v", "1", str(outp) + ".png"], check=True)
    # Audio: el encoder Vorbis nativo de ffmpeg solo acepta estéreo.
    audio = subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", video, "-vn", "-ac", "2", "-ar", "44100", "-c:a", "vorbis", "-strict", "-2", "-q:a", "4", str(outp) + ".ogg"])
    meta = {"frames": frames, "cols": cols, "rows": rows, "fps": fps, "w": width, "h": h, "source": Path(video).name, "audio": audio.returncode == 0}
    Path(str(outp) + ".json").write_text(json.dumps(meta, indent=2) + "\n")
    return meta


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("video")
    p.add_argument("out", help="ruta sin extensión")
    p.add_argument("--fps", type=int, default=12)
    p.add_argument("--width", type=int, default=832)
    a = p.parse_args()
    meta = convert(a.video, a.out, a.fps, a.width)
    print(f"{Path(a.out).name}: {meta['frames']} frames @{meta['fps']}fps → {Path(a.out + '.png').stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
