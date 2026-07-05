#!/bin/zsh
# Assembles the trailer segments recorded by trailer_shot.tscn into
# docs/trailer/delvers_chapter1.mp4 (30fps h264, fade transitions).
set -e
cd "$(dirname "$0")/.."

SRC="capture/proto3d/renders/trailer"
OUT="docs/trailer"
mkdir -p "$OUT" "$SRC/encoded"

python3 - <<'EOF'
import json, os, subprocess

src = "capture/proto3d/renders/trailer"
manifest = json.load(open(f"{src}/manifest.json"))
order = sorted(manifest.keys())
parts = []
for name in order:
    info = manifest[name]
    frames, seconds = info["frames"], info["seconds"]
    if frames == 0:
        continue
    fps = frames / seconds
    out = f"{src}/encoded/{name}.mp4"
    fade_out = max(0.0, seconds - 0.45)
    subprocess.run([
        "ffmpeg", "-y", "-framerate", f"{fps:.3f}",
        "-i", f"{src}/{name}/frame_%05d.png",
        "-vf", (
            f"fade=t=in:st=0:d=0.4,fade=t=out:st={fade_out:.2f}:d=0.45,"
            "scale=1920:-2,format=yuv420p"
        ),
        "-r", "30", "-c:v", "libx264", "-crf", "21", "-preset", "medium",
        out,
    ], check=True, capture_output=True)
    parts.append(out)
    print(f"encoded {name}: {frames} frames @ {fps:.1f}fps")

with open(f"{src}/concat.txt", "w") as f:
    for p in parts:
        f.write(f"file '{os.path.abspath(p)}'\n")

subprocess.run([
    "ffmpeg", "-y", "-f", "concat", "-safe", "0",
    "-i", f"{src}/concat.txt", "-c", "copy",
    "docs/trailer/delvers_chapter1.mp4",
], check=True, capture_output=True)
print("trailer assembled: docs/trailer/delvers_chapter1.mp4")
EOF
