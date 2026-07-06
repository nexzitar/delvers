#!/bin/zsh
# Assembles the trailer into docs/trailer/delvers_chapter1.mp4.
# Preferred: Movie Maker master (true 30fps + audio):
#   godot --path . --write-movie capture/proto3d/renders/trailer/master.avi \\
#     --fixed-fps 30 --resolution 1920x1080 res://capture/trailer_shot.tscn
# Fallback: PNG segment dirs from a realtime run of trailer_shot.tscn.
set -e
cd "$(dirname "$0")/.."
mkdir -p docs/trailer capture/proto3d/renders/trailer/encoded

python3 - <<'EOF'
import json, os, subprocess

src = "capture/proto3d/renders/trailer"
manifest = json.load(open(f"{src}/manifest.json"))
order = sorted(manifest.keys())
master = f"{src}/master.avi"
parts = []

if os.path.exists(master):
    fps = 30.0
    for name in order:
        info = manifest[name]
        start = info["start_frame"] / fps
        end = info["end_frame"] / fps
        dur = end - start
        out = f"{src}/encoded/{name}.mp4"
        subprocess.run([
            "ffmpeg", "-y", "-ss", f"{start:.3f}", "-to", f"{end:.3f}",
            "-i", master,
            "-vf", (f"fade=t=in:st=0:d=0.4,"
                    f"fade=t=out:st={max(0.0, dur - 0.45):.2f}:d=0.45,"
                    "scale=1920:-2,format=yuv420p"),
            "-af", (f"afade=t=in:st=0:d=0.4,"
                    f"afade=t=out:st={max(0.0, dur - 0.45):.2f}:d=0.45"),
            "-r", "30", "-c:v", "libx264", "-crf", "21", "-preset", "medium",
            "-c:a", "aac", "-b:a", "192k",
            out,
        ], check=True, capture_output=True)
        parts.append(out)
        print(f"cut {name}: {start:.1f}s - {end:.1f}s")
else:
    for name in order:
        info = manifest[name]
        frames, seconds = info["frames"], info["seconds"]
        if frames == 0:
            continue
        fps = frames / seconds
        out = f"{src}/encoded/{name}.mp4"
        subprocess.run([
            "ffmpeg", "-y", "-framerate", f"{fps:.3f}",
            "-i", f"{src}/{name}/frame_%05d.png",
            "-vf", (f"fade=t=in:st=0:d=0.4,"
                    f"fade=t=out:st={max(0.0, seconds - 0.45):.2f}:d=0.45,"
                    "scale=1920:-2,format=yuv420p"),
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
