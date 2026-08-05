# Operation Playbooks (C1–C13) — video-montage reference

Loaded on demand from `SKILL.md`. One playbook per operation. Critical rules (NVENC, never `-c copy`,
auto-editor only) live in `SKILL.md §1`. Final-render overlays + audio mixing → `references/final-render-and-audio.md`.

### C1. Silence/Pause Removal — normalize, then auto-editor renders DIRECTLY
**Full ordered pipeline + all rationale live in `SKILL.md §1.4` and §1.5.** Do NOT export XML and re-render with ffmpeg (the old `--export premiere` + `parse_and_render.py` method is DELETED — it duplicated auto-editor's own render and drifted). auto-editor renders per scene in seconds.

```bash
# 1. Normalize to −14 LUFS FIRST (required — un-normalized quiet audio makes the threshold shred words)
ffmpeg-normalize scene.mkv -o scene_norm.mkv -t -14 -tp -1.5 -c:a aac -b:a 256k
# 2. auto-editor on the normalized file, whole file, direct render (flags LOCKED in §1.5)
auto-editor scene_norm.mkv --edit audio:0.14 --margin 0.12s,0.10s --video-codec h264_nvenc --video-bitrate 10M --audio-bitrate 256k --sample-rate 48000 --no-open -o scene_clean.mp4
# 3. §8 True-Peak Fix
```
- Verify a threshold with `--preview` before rendering (no render, seconds): healthy ≈ 40 clips, median ≥1.4 s. Piece-count explosion = threshold too high OR audio not normalized.
- O(n²): always PER SCENE before concat. Long combined file → background it.

### C2. Phrase Removal
1. `transcribe.py` → find exact word timestamps
2. Calculate trim points: word_end + 0.15s buffer
3. Use `ffmpeg -filter_complex` with `trim/atrim + concat` (see `references/multiscene-pipeline.md` Step 4)
4. ALWAYS re-encode with NVENC

### C3. Concatenation
**All clips MUST have identical format** (resolution, fps, pix_fmt). If not → re-encode first.
```bash
# Create file list
printf "file '%s'\n" clip1.mp4 clip2.mp4 > concat.txt
# Concat with re-encode
ffmpeg -f concat -safe 0 -i concat.txt -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a aac -b:a 192k output.mp4
```

**With crossfade**: `concat_clips.py clip1.mp4 clip2.mp4 --transition fade --duration 0.3 --output result.mp4`

### C4. Subtitles
**FIRST read `references/subtitle-standard.md`** — the LOCKED standard (sentence case never all-caps, one font size, Geist, ≤2 lines / ≤39 CPL / ≤17 CPS). The generic command below is superseded by the brand burn-in there.
1. `build_srt.py <transcript.json>` → SRT file (then fix casing/mishears by meaning)
2. Burn in (generic; brand version in subtitle-standard.md):
```bash
ffmpeg -i video.mp4 -vf "subtitles=subs.srt:force_style='FontSize=24,FontName=Arial,Bold=1,PrimaryColour=&Hffffff,OutlineColour=&H000000,Outline=3,Shadow=1,MarginV=80,Alignment=2'" -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p output.mp4
```

### C5. Text Overlays / Lower Thirds

> 🎨 **BRAND OVERLAYS — «Осциллограф» channel (OVERRIDES the generic red-Tahoma / amber-Impact styles below).**
> For branded YouTube videos, ALL on-screen text/accent words use the Video Studio brand canon
> (`C:\Projects\Video\studio\brand-guidelines\default\`), NOT the generic shake styles:
> - **Font:** Geist Bold (weight 700) — baked static TTF at `C:\MONTAGE\fonts\Geist-Bold.ttf` (full Cyrillic).
>   Geist Mono for timecodes/labels. NO serif, NO Impact, NO Tahoma.
> - **Color:** accent green `#3CE5B0` (drawtext `fontcolor=0x3CE5B0`) on dark; `--ink #E8EDEB` for neutral text.
>   Red (`#E5594A`) is RESERVED for danger only. No random yellow/white.
> - **Placement rule:** only on clean backgrounds. NEVER cover important on-screen content
>   (comparison numbers, tables, terminal commands, materials lists). On white pages green text is unreadable → don't.
> - **Motion:** subtle alpha fade-in/out (~0.3s), no jitter/shake. Brand = calm techno-minimalism, not meme-shake.
> - Confirm the EXACT wording with the user before rendering (e.g. they wanted "сделал сам GLM 5.2", not "СДЕЛАЛ САМ").
> Generic red/amber shake (Approaches D/E below) is only for NON-branded/quick edits.

**Decision tree — which approach to use:**
```
Plain text only (no emoji, no strikethrough) → Approach D: drawtext shake
Text + colored emoji (🥲, 🙉, etc.)          → Approach E: Pillow PNG + overlay shake
Strikethrough text                            → Approach E: Pillow PNG (drawtext can't strike)
Image overlay (photo, screenshot)             → Approach F: Image with soft frame
Many timed text entries                       → Approach B: ASS subtitles
```

**CRITICAL LESSONS LEARNED:**
- `drawtext` CANNOT render colored emoji — only monochrome glyphs. Use Pillow + `seguiemj.ttf` + `embedded_color=True`
- `drawtext` CANNOT do strikethrough — use Pillow `draw.line()` for diagonal/horizontal strike
- `amix` with multiple inputs **divides volume by N** by default! ALWAYS use `normalize=0`
- All overlays can be combined in ONE ffmpeg command (multiple drawtext chains + multiple overlay inputs)
- Test on a single frame first (Pillow composite), then render video — much faster iteration

**Brand accent overlay (Geist green) — drawtext with fade, no shake:**
```
drawtext=fontfile='C\:/MONTAGE/fonts/Geist-Bold.ttf':text='сделал сам GLM 5.2':\
  fontcolor=0x3CE5B0:fontsize=92:borderw=4:bordercolor=0x05100C@0.92:\
  x=(w-tw)/2:y=h*0.11:\
  alpha='if(lt(t,T0+0.3),(t-T0)/0.3,if(gt(t,T1-0.3),(T1-t)/0.3,1))':enable='between(t,T0,T1)'
```

---

**Approach D: drawtext with shake animation (generic, NON-branded plain text)**
Best for: quick on-screen text on non-branded edits. Uses red Tahoma Bold + white border + shake.

```bash
drawtext=fontfile='C\:/Windows/Fonts/tahomabd.ttf':\
  text='Anthropic!':\
  fontsize=110:\
  fontcolor=0xFF4444:\
  borderw=4:bordercolor=0xFFFFFF:\
  shadowx=2:shadowy=2:shadowcolor=0x000000@0.8:\
  x=(w-tw)/2+3*sin(t*15):\
  y=(h-th)/2+3*cos(t*12):\
  enable='between(t,START,END)'
```

**Multiple drawtext in one command — chain with commas:**
```bash
[0:v]drawtext=...enable='between(t,100,104)',\
     drawtext=...enable='between(t,200,203)',\
     drawtext=...enable='between(t,300,305)'[vout]
```

---

**Approach E: Pillow PNG overlay (for emoji, strikethrough, styled graphics)**

**Step 1: Create PNG with Pillow (canvas MUST match video resolution, e.g. 2560x1440)**
```python
from PIL import Image, ImageDraw, ImageFont

img = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
tahoma = ImageFont.truetype("C:/Windows/Fonts/tahomabd.ttf", 200)
emoji_font = ImageFont.truetype("C:/Windows/Fonts/seguiemj.ttf", 120)

text = "Ь"
bbox = draw.textbbox((0, 0), text, font=tahoma)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
tx, ty = 1920//2 - tw//2, 1080//2 - th//2

# Use stroke_width + stroke_fill (NOT offset-copy loops) — matches ffmpeg drawtext look
draw.text((tx, ty), text, font=tahoma, fill=(0xFF, 0x44, 0x44, 255), stroke_width=5, stroke_fill=(255,255,255,255))

# Diagonal strikethrough (bottom-left to top-right)
draw.line([(tx-15, ty+th+10), (tx+tw+15, ty-10)], fill=(0xFF, 0x22, 0x22, 255), width=12)

# Colored emoji (MUST use embedded_color=True)
draw.text((tx+tw+50, ty+20), "🥲", font=emoji_font, embedded_color=True)

img.save("overlay.png")
```

**Step 2: Apply PNG overlay in ffmpeg (chain sequentially):**
```bash
[0:v]drawtext=...text1...[td];\
[td][1:v]overlay=3*sin(t*15):3*cos(t*12):enable='between(t,T1,T2)'[ov1];\
[ov1][2:v]overlay=0:0:enable='between(t,T3,T4)'[vout]
```

**Preview on a frame BEFORE rendering video (fast iteration):**
```python
frame = Image.open("test_frame.png").convert("RGBA")
overlay = Image.open("overlay.png")
Image.alpha_composite(frame, overlay).convert("RGB").save("preview.jpg", quality=95)
```

---

**Approach F: Image overlay with soft frame (photos, screenshots)**
```python
from PIL import Image, ImageDraw, ImageFilter

photo = Image.open("photo.png").convert("RGBA")
ratio = 300 / photo.height
photo = photo.resize((int(photo.width * ratio), 300), Image.LANCZOS)

pad = 15
panel = Image.new("RGBA", (photo.width + pad*2 + 40, photo.height + pad*2 + 40), (0, 0, 0, 0))
pdraw = ImageDraw.Draw(panel)
pdraw.rounded_rectangle([20, 20, photo.width+pad+20, photo.height+pad+20],
    radius=20, fill=(0, 0, 0, 160), outline=(100, 200, 255, 180), width=3)
panel = panel.filter(ImageFilter.GaussianBlur(radius=4))
ImageDraw.Draw(panel).rounded_rectangle([20, 20, photo.width+pad+20, photo.height+pad+20],
    radius=20, outline=(100, 200, 255, 140), width=2)

canvas = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))
nx, ny = 1920 - photo.width - 40, 40
canvas.paste(panel, (nx-pad-20, ny-pad-20), panel)
canvas.paste(photo, (nx, ny), photo)
canvas.save("overlay_photo.png")
```

**Approach B: ASS subtitles (for many timed text entries, 10+ items with styles)**
```bash
ffmpeg -y -i scene.mp4 -vf "ass='C\:/path/to/subs.ass'" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a aac -b:a 256k output.mp4
```
ASS tags: `\fad(in_ms,out_ms)`, `\move(x1,y1,x2,y2)`, `\blur`, `\t(style)`.

**Tested fonts (Windows):** `tahomabd.ttf` (generic bold), `seguiemj.ttf` (colored emoji, `embedded_color=True`), `impact.ttf` (meme display), `arialbd.ttf` (subtitles). Brand: `C:\MONTAGE\fonts\Geist-Bold.ttf`.

**IMPORTANT:** All overlays applied in ONE render pass on the final video (collect all timestamps → one ffmpeg command). Trying to "surgically insert" into a rendered video causes artifacts. Overlays go on the FINAL video in one pass, together with background music (see `references/final-render-and-audio.md`).

### C6. B-Roll / Image Overlay
```
python C:\MONTAGE\tools\overlay_image.py video.mp4 image.png --position center --start 30 --duration 5 --fade 0.5
```

### C7. Oval/Circular Webcam Mask

**Step 1: Find exact webcam rectangle coordinates (Pillow pixel analysis). NEVER guess — position varies between recordings.**
```python
from PIL import Image
import numpy as np
img = np.array(Image.open('frame_1080p.png'))
# Find TOP edge: scan rows for sharp brightness jump in webcam x-range
for y in range(800, 950):
    if abs(int(np.mean(img[y-3:y, 50:300, :])) - int(np.mean(img[y:y+3, 50:300, :]))) > 30:
        print(f'Top edge: y={y}'); break
# Find RIGHT edge: scan columns for sharp brightness drop in webcam y-range
for x in range(250, 450):
    if abs(int(np.mean(img[950:1050, x-2:x, :])) - int(np.mean(img[950:1050, x:x+2, :]))) > 30:
        print(f'Right edge: x={x}'); break
# LEFT edge: usually x=0. BOTTOM edge: usually y=1080 (frame edge).
```
Key: brightness gradient >30 between adjacent rows/columns. Test at multiple positions.

**Step 1b: Visual verification with colored outlines (RED=rect, GREEN=oval), crop and inspect.**

**Step 2: Apply oval mask with ffmpeg**
```bash
# Variables: CAM_X, CAM_Y, CAM_W, CAM_H = detected webcam rectangle
# CX=CAM_W/2, CY=CAM_H/2, RX=CX-4, RY=CY-4
ffmpeg -y -i input.mp4 -filter_complex "
[0:v]scale=1920:1080,split[main1][main2];
[main2]crop=CAM_W:CAM_H:CAM_X:CAM_Y,format=yuva420p,geq=lum='p(X,Y)':cb='p(X,Y)':cr='p(X,Y)':a='if(lt(pow(X-CX,2)/pow(RX,2)+pow(Y-CY,2)/pow(RY,2),1),255,0)'[oval];
[main1]drawbox=x=CAM_X:y=CAM_Y:w=CAM_W:h=CAM_H:c=0x111111:t=fill[bg];
[bg][oval]overlay=CAM_X:CAM_Y" \
-c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a aac -b:a 256k -r 60 output.mp4
```
**How:** split → crop webcam + geq ellipse alpha → drawbox dark fill under it → overlay back. Corners show dark, center shows face.
**OpenClaw scene2 coords (1080p):** x=0, y=896, w=324, h=184

### C8. Dynamic Zoom
Transcribe → classify: normal (1.0x), emphasis (1.15x), critical (1.3x).

### C9. Speed
**2x**: `-vf "setpts=0.5*PTS" -af "atempo=2.0"`
**0.5x**: `-vf "setpts=2.0*PTS" -af "atempo=0.5"`

### C10. Audio Operations
**Extract**: `ffmpeg -i v.mp4 -vn -c:a copy audio.aac`
**Replace**: `ffmpeg -i v.mp4 -i new.mp3 -c:v copy -map 0:v -map 1:a -shortest out.mp4`
**Normalize**: `ffmpeg -i v.mp4 -af "loudnorm=I=-14:TP=-1.5:LRA=11" -c:v copy out.mp4` (audio-only = `-c:v copy` OK)
**Mix music**: full multi-track guide in `references/final-render-and-audio.md`.

### C11. Audio Normalization
**ALWAYS last step.** One time on final file.
**Option A (BEST — two-pass linear, zero artifacts):**
```bash
ffmpeg-normalize final.mp4 -o output.mp4 -t -14 -tp -1.5 -c:a aac -b:a 192k
```
**Option B (loudnorm one-pass, acceptable):**
```bash
ffmpeg -i final.mp4 -c:v copy -af "loudnorm=I=-14:TP=-1.5:LRA=11" -c:a aac -b:a 192k output.mp4
```
ffmpeg-normalize does two-pass `linear=true` = pure gain, NO compression. One-pass loudnorm is a light compressor — OK but not ideal for clean recordings.

### C12. Color Grading
**Quick cinematic**: `eq=brightness=0.06:contrast=1.15:saturation=1.2` · **Vignette**: `vignette=PI/4`
Always `-pix_fmt yuv420p` and NVENC. One-line LUT grading → `references/effects.md`.

### C13. Viral Subtitles
```
Font: Arial Bold | Size: 60-80px | Color: white | Outline: 3px black
Shadow: 2px offset, black | Position: center-bottom, MarginV=80
```
Word-by-word karaoke captions → `references/effects.md`.
