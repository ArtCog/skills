# Multi-Scene Montage Pipeline — video-montage reference

Loaded on demand from `SKILL.md`. Read this when assembling a full video from multiple OBS scenes
(trim → normalize → silence-removal → concat → final 1440p). Critical rules (NVENC, `-c copy`,
auto-editor) live in `SKILL.md §1` — they always apply.

**The proven workflow for assembling video from multiple OBS scenes:**

### Key terminology:
- **Scene** = one finished unit in ready/ (e.g. `scene13_final.mp4`). One scene = one topic segment in the final video.
- **Multi-part scene** = one scene recorded in several takes (e.g. scene7 = `scene7.mkv` + `scene7.2.mkv` + `scene7.3.mkv` + `scene7.4.mkv` + `scene7.5.mkv`). Each PART goes through the full pipeline INDIVIDUALLY, then parts are concatenated into one scene_final.mp4.
- **Simple scene** = one scene from one recording file. Goes through the pipeline as-is.
- **Final concat** = joining ALL finished scenes into the final video for YouTube upload. This is Step 6.

**CRITICAL DISTINCTION:** "concat parts of a multi-part scene" (Step 5b) ≠ "final concat of all scenes" (Step 6). Parts are joined AFTER auto-editor. Scenes are joined AFTER all scenes are ready.

### Step 1: Trim each scene
- Transcribe cut points to find exact word boundaries
- Use `ffmpeg -i <input> -t <end> ...NVENC... <output>` or `ffmpeg -i <input> -ss <start> ...NVENC... <output>`
- ALWAYS re-encode (NVENC), NEVER `-c copy`

### Step 2: Normalize audio to -14 LUFS ⚠️ BEFORE auto-editor!
**CRITICAL: Normalize BEFORE silence removal, NOT after.**
Without normalization, quiet scenes get over-cut by auto-editor (threshold treats quiet speech as silence).
Normalization equalizes all scenes → threshold 0.15 works consistently across all scenes.

```bash
ffmpeg-normalize scene.mp4 -o scene_norm.mp4 -t -14 -tp -1.5 -c:a aac -b:a 256k
```

- Scenes with volume drift (Windows auto-gain): fix BEFORE normalizing:
  ```bash
  ffmpeg -y -i input.mp4 -af "volume=-4dB:enable='gte(t,240)'" -c:v copy -c:a aac -b:a 256k output.mp4
  ```
- Verify: `ffmpeg -i <file> -af loudnorm=print_format=summary -f null -` → should show ~-14 LUFS

### Step 3: Ensure uniform format
- ALL scenes must match: resolution, fps, pix_fmt, codec
- If any scene differs (e.g. 1440p30 vs 1080p60): re-encode with `-vf "scale=1920:1080" -r 60`
- Verify before concat: `ffprobe -select_streams v -show_entries stream=width,height,r_frame_rate,pix_fmt`

### Step 4: Remove specific phrases (if needed)
- Transcribe the relevant section to find exact timestamps
- Use `ffmpeg -filter_complex` with `trim/atrim + concat`:
```bash
ffmpeg -i input.mkv -filter_complex \
  "[0:v]trim=0:END1,setpts=PTS-STARTPTS[v1]; \
   [0:v]trim=START2,setpts=PTS-STARTPTS[v2]; \
   [0:a]atrim=0:END1,asetpts=PTS-STARTPTS[a1]; \
   [0:a]atrim=START2,asetpts=PTS-STARTPTS[a2]; \
   [v1][a1][v2][a2]concat=n=2:v=1:a=1[vout][aout]" \
  -map "[vout]" -map "[aout]" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p \
  -c:a aac -b:a 256k output.mp4
```

### Step 5: Remove silences PER SCENE (auto-editor) ⚠️ BEFORE concat!
**CRITICAL: Remove silences from each scene INDIVIDUALLY, not from the combined file.**
auto-editor has O(n²) performance — 2 min scene = 18 sec, but 25 min combined = 30+ min.
Processing each scene separately: total ~2-3 min. Processing combined: 30+ min.

```bash
# For each scene (1-5 min each → seconds per scene). Flags LOCKED in SKILL.md §1.5 (input must be _norm from Step 2):
auto-editor scene1_norm.mp4 --edit audio:0.14 --margin 0.12s,0.10s --video-codec h264_nvenc --video-bitrate 10M --audio-bitrate 256k --sample-rate 48000 --no-open -o scene1_final.mp4
```

If working on already-combined file (no choice), use `nohup ... & disown` and expect 20-30 min.

### Step 5b: Concat parts of MULTI-PART scenes ⚠️ AFTER auto-editor!
**For scenes recorded in multiple takes (e.g. scene7 = 5 files, scene12 = 2 files).**

**NEVER concat parts before auto-editor. Process EACH PART through Steps 1-5 INDIVIDUALLY, then concat the FINISHED parts.**

```
CORRECT order for multi-part scenes:
  Part A: trim → normalize → auto-editor → partA_final.mp4
  Part B: trim → normalize → auto-editor → partB_final.mp4
  Part C: trim → normalize → auto-editor → partC_final.mp4
  Then: concat partA_final + partB_final + partC_final → scene_final.mp4

WRONG (NEVER do this):
  trim A, trim B, trim C → concat → normalize → auto-editor
  ❌ auto-editor on concat = O(n²), artifacts at join points, wrong normalization
```

**Concat command for multi-part scenes (NOT the final YouTube concat!):**
```bash
printf "file 'partA_final.mp4'\nfile 'partB_final.mp4'\n..." > concat_scene.txt
ffmpeg -f concat -safe 0 -i concat_scene.txt \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p \
  -c:a aac -b:a 256k \
  scene_final.mp4
```

This applies to: scene7 (5 parts), scene12 (2 parts), scene16 (2 parts), and any future multi-part scenes.

### Step 6: Final concatenation — YouTube-optimized (LOCKED)
**All scenes must be individually processed (Steps 1-5) before concatenation.**

**1440p upscale is DEFAULT** — YouTube assigns VP9/AV1 codec instead of AVC1, significantly better viewer quality.

```bash
# Create file list
printf "file '%s'\n" scene1_final.mp4 scene2_final.mp4 ... > concat.txt

# YouTube-optimized concat with 1440p upscale (LOCKED settings — 2026-04-11, updated bitrate+level)
ffmpeg -f concat -safe 0 -i concat.txt \
  -vf "scale=2560:1440:flags=lanczos" \
  -c:v h264_nvenc -preset p7 -tune hq \
  -profile:v high -level 5.1 \
  -rc cbr -b:v 24M \
  -g 120 -bf 2 \
  -spatial-aq 1 -temporal-aq 1 -aq-strength 10 \
  -rc-lookahead 32 \
  -pix_fmt yuv420p \
  -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
  -movflags +faststart \
  -c:a aac -b:a 384k -ar 48000 \
  FINAL.mp4
```

**⚠️ CRITICAL (learned 2026-05-26): the concat DEMUXER above can catastrophically fail on multi-source projects.**
When scenes come from different encode chains (auto-editor outputs + externally-rendered hooks/promos + files that went through an extra audio-only re-encode), the demuxer can produce a BROKEN file **even though every input reports CFR 60**. Symptoms: final duration wildly longer than expected (e.g. 7490s instead of 1278s), tiny bitrate (~900 kbps instead of 24M), and a huge `drop=NNNNN` count in the log (most frames discarded). The file still "decodes clean" but is garbage.

**Fix: use the concat FILTER instead** — it decodes every input and rebuilds PTS from scratch; `fps=60` normalizes any hidden VFR. Build it programmatically for N inputs:
```bash
# files=(scene1_final.mp4 scene2_final.mp4 ... sceneN_final.mp4)
args=(); filter=""; i=0
for f in "${files[@]}"; do args+=(-i "$f"); filter+="[$i:v:0][$i:a:0]"; i=$((i+1)); done
filter+="concat=n=${#files[@]}:v=1:a=1[cv][a];[cv]fps=60,scale=2560:1440:flags=lanczos,setsar=1[vs]"
ffmpeg -y "${args[@]}" -filter_complex "$filter" -map "[vs]" -map "[a]" \
  -c:v h264_nvenc -preset p7 -tune hq -profile:v high -level 5.1 \
  -rc cbr -b:v 24M -g 120 -bf 2 -spatial-aq 1 -temporal-aq 1 -aq-strength 10 -rc-lookahead 32 \
  -pix_fmt yuv420p -colorspace bt709 -color_primaries bt709 -color_trc bt709 -movflags +faststart \
  -c:a aac -b:a 384k -ar 48000 FINAL.mp4
```
Demuxer is OK for truly identical-origin files; the **filter is the safe default when sources are mixed**. ALWAYS verify `final duration ≈ sum of scene durations` after concat (the cheapest way to catch this failure).

**Why these settings:**
- `-rc cbr -b:v 24M` — YouTube recommended for 1440p60. CBR forces stable 24 Mbps even on static talking head. VBR/CQ tested and gave only 8 Mbps on talking-head → YouTube degrades quality. 12M was for 1080p; 24M is the correct rate for 1440p (verified 2026-04-11)
- `-preset p7 -tune hq` — maximum NVENC quality, no rush for final file
- `-profile:v high -level 5.1` — H.264 Level 5.1 required for 2560x1440@60fps. Level 4.2 only supports up to 1920x1080 → causes "Invalid Level" error at 1440p
- `-g 120` — GOP 2 seconds at 60fps, YouTube standard for fast DASH/HLS segmentation
- `-bf 2` — B-frames for compression efficiency
- `-spatial-aq 1 -temporal-aq 1 -aq-strength 10` — adaptive quantization: preserves face detail and stabilizes flat backgrounds
- `-colorspace bt709 -color_primaries bt709 -color_trc bt709` — explicit SDR color tags, prevents YouTube color misinterpretation
- `-movflags +faststart` — moov atom at start, YouTube begins processing during upload
- `-c:a aac -b:a 384k -ar 48000` — high quality audio source for YouTube re-encode (YouTube serves 128k to viewers)
- 1440p upscale → YouTube assigns VP9/AV1 codec instead of AVC1 (even for viewers watching at 1080p, the source is VP9 = sharper)

**Expected output:** ~24 Mbps, ~13 GB for 75 min video.

**Do NOT use for concat:**
- `-fflags +genpts+igndts` — can cause A/V desync with B-frames
- `-c copy` — frozen frames
- `-level 4.2` with 1440p — Invalid Level error, use 5.1+
- VBR/constqp/CQ without target bitrate — gives 8 Mbps on talking-head, YouTube degrades quality

### Step 6b: Pre-concat loudness verification
**ALWAYS verify all scenes before final concat.** Expected: -13.7 to -14.1 LUFS (deviation <0.4 dB).

```bash
# Verify LUFS of all scenes (run in background — takes ~5 min for 25 scenes)
cd scenes_for_concat && for f in *.mp4; do
  lufs=$(ffmpeg -hide_banner -i "$f" -af loudnorm=print_format=summary -f null - 2>&1 | grep "Input Integrated" | sed "s/.*: *//")
  printf "%-25s %s\n" "$f" "$lufs"
done
```

**Do NOT use `grep -P`** — Git Bash on Windows doesn't support Perl regex. Use `sed` or `python3` for parsing.

### Step 7: Final audio normalization — NOT NEEDED
Audio normalization is done PER SCENE in Step 2 (before auto-editor). All scenes are already -14 LUFS. No additional normalization needed on the final file.

After the final concat, ALWAYS run the True Peak Fix (`SKILL.md §8`).
