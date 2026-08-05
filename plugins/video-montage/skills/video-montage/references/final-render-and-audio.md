# Final Render (Overlays + Audio Mixing) — video-montage reference

Loaded on demand from `SKILL.md`. Read this for the ONE-PASS final render (all overlays + music + ducking)
and for audio-quality rules. True-peak fix (mandatory last step) is in `SKILL.md §8`.

## Audio Rules

### Normalization
- **loudnorm** (good): raises average level evenly, minimal noise amplification
- **Compressor** (bad for post): pumps up noise between words, makes quiet parts loud
- **afftdn** (bad): creates "barrel" / underwater effect on clean recordings
- YouTube normalizes DOWN (loud → -14 LUFS) but NEVER UP (quiet stays quiet)
- Record at -12 to -6 dB peaks → loudnorm to -14 LUFS → clean result

### Multi-scene volume equalization
- Measure all scenes first, find the average (~-21 LUFS typical for OBS)
- Boost quiet scenes with simple `volume=XdB` filter; for Windows auto-gain drift use a linear volume ramp
- Per-scene equalization BEFORE concatenation; loudnorm AFTER all cuts (last step)

### Cascading AAC degradation — CRITICAL
- Each AAC encode→decode cycle loses quality irreversibly; raising bitrate above 256k does NOT recover it
- **256k AAC is the practical ceiling for speech** (transparent at 128k single-pass)
- **For future videos:** WAV/PCM as intermediate, encode AAC only ONCE at final step:
  `OBS (AAC) → extract WAV → all processing in WAV → final AAC 256k (one encode)`

### Windows audio issues
- **Communication Mode** silently reduces mic volume → Control Panel → Sound → Communications → "Do nothing"
- **Auto gain** gradually changes mic level → disable in Sound settings → Input device properties

## Final Render: Overlays + Audio Mixing — ONE PASS

### THE GOLDEN RULE: Everything in ONE ffmpeg command
**ALL overlays (text, emoji, images) + ALL audio (music, SFX, ducking) = ONE render pass.**
Multiple `-i` inputs are NOT multiple renders — ffmpeg reads them all simultaneously. Avoids cascading quality loss.

### 🎵 Music under voiceover — THE professional method (EQ pocket + gentle duck) — LOCKED 2026-06-22
**The mistake we made first:** heavy sidechain duck (ratio 1.8, music dipping toward silence under speech) → music "dissolves into noise", not heard as music. This is the #1 amateur error (confirmed by research: over-ducking >9-12 dB or burying the bed 20-25 dB below a *compressed* voice kills it).

**Professional fix = carve frequency space, don't crush volume.** Put ALL music tracks on one bus, EQ-carve a vocal "pocket", then duck GENTLY:
```
[bg][intr][outro] → amix=normalize=0 →
  equalizer=f=1500:t=q:w=1.2:g=-4   # vocal-intelligibility pocket (1-2 kHz) — the key move
  equalizer=f=350:t=q:w=1.5:g=-3    # de-mud low-mid
  → sidechaincompress(threshold=0.05:ratio=2:attack=20:release=700)  # gentle: only ~2-6 dB dip, fast recovery
[voice][music_ducked][kick...] → amix=normalize=0:duration=first
```
- **EQ pocket at ~1.5 kHz (-3 to -5 dB) does the separation** — so music stays LOUD and clearly audible while the voice cuts through. Duck then only needs to be gentle.
- **Dip music only 2-6 dB during speech, NEVER to silence.** Pads/cinematic: 2-4 dB, slow (attack 20ms, release 600-1000ms). Busy beds: up to 6-9 dB, ratio 2-4.
- **Levels (relative to voice at -14 LUFS):** busy bg bed ≈ 16-18 dB below (≈ -30 LUFS); **cinematic pad (Interstellar-style) only ~8-12 dB below** (≈ -25 LUFS) + EQ pocket — pads have low transient energy and don't mask consonants, so they can sit louder.
- **Pick the LOUD/melodic part of a cinematic track** (seek past quiet intros with `atrim=START:END`) — a quiet ambient intro at low level under voice = "noise". (Verify track loudness over time with `volumedetect` per 15s.)
- **SFX accents (kick/whoosh on chapter cards) bypass the duck** — short, play full, mixed separately.
- Sources: BBC/W3C 20 dB rule (but -12-15 dB for *compressed* voice), iZotope EQ cheat-sheet, sidechain ducking guides. Researched 2026-06-22.

### CRITICAL: `amix normalize=0`
**ALWAYS use `normalize=0` with amix.** Without it, amix divides each input by 1/N — voice loses 50-66% volume (dropped -19 dB → -31 dB in testing).

### Workflow
1. **Collect all overlay requests:** exact timecodes (MM:SS → sec), text, duration, type. Build a table.
2. **Create PNG overlays with Pillow** (canvas MUST match video res, e.g. 2560x1440; `stroke_width`+`stroke_fill`; test on extracted frame first — instant). See `references/playbooks.md` C5.
3. **Test on a 30-40 s clip** containing ≥1 drawtext AND ≥1 PNG overlay + audio mixing (verify ducking + normalize=0). Show user, get approval.
4. **Run full render in background** (`run_in_background`). Expected ~0.8-1.0x for 1440p CBR 24M with overlays.

### Command structure template
```bash
ffmpeg -y \
  -i video.mp4 \
  -i overlay1.png -i overlay2.png ... \        # PNG overlays
  -i stinger.mp3 \                              # SFX
  -stream_loop N -i music.mp3 \                 # looped tracks
  -filter_complex "
    [0:v]                                        # VIDEO CHAIN:
    drawtext=...enable='between(t,S1,E1)',       # plain text (chainable with commas)
    drawtext=...enable='between(t,S2,E2)'
    [td];
    [td][1:v]overlay=SHAKE:enable='...'[ov1];    # PNG overlays (sequential chain)
    [ov1][2:v]overlay=0:0:enable='...'[vout];    # images without shake

    [0:a]VOICE_PROCESSING,asplit=2[speech][sc];  # AUDIO CHAIN:
    [N:a]TRACK_PROCESSING[track1];               # each track: volume, fade, delay
    [M:a]BG_VOLUME_AUTOMATION[bg];               # background: complex volume envelope
    [bg][sc]sidechaincompress=...[bg_ducked];     # ducking on background only
    [speech][track1][bg_ducked]...amix=inputs=N:normalize=0:duration=first[aout]
  " \
  -map "[vout]" -map "[aout]" \
  -c:v h264_nvenc ... -c:a aac -b:a 384k \
  output.mp4
```

### Generic drawtext shake style (NON-branded — Impact, amber). For the channel brand use Geist green, see playbooks C5.
```
drawtext=fontfile='C\:/Windows/Fonts/impact.ttf':\
  fontsize=110:fontcolor=0xFFBB00:\
  borderw=3:bordercolor=0x000000:\
  shadowx=2:shadowy=2:shadowcolor=0x000000@0.8:\
  x=(w-tw)/2+3*sin(t*15):\
  y=(h-th)/2-h*0.15+3*cos(t*12):\
  text='TEXT':enable='between(t,START,END)'
```
- Position: center horizontal, 15% above center. Shake: `3*sin(t*15)` x, `3*cos(t*12)` y.
- Chain multiple: separate with commas, NO semicolon between drawtext filters.

### PNG overlay with shake
```
[prev][N:v]overlay=3*sin(t*15):3*cos(t*12):enable='between(t,START,END)'[next]
```
- Images WITHOUT shake: `overlay=0:0:enable='...'`. PNG canvas MUST match video resolution. Chain `[ov1]→[ov2]→...→[vout]`.

### Audio mixing parameters (LOCKED — tested 2026-04-12)

| Parameter | Value | Why |
|---|---|---|
| Background music volume | **0.078 (7.8%)** | Subtle atmosphere. Tested 6-21%, 7.8% = final |
| Intro music ("начало") | 0.14 (14%) | Sets mood, fades out before background starts |
| Cinematic insert volume | 0.19 (19%) | Intentional musical moment |
| Kick/percussion volume | 0.135 (13.5%) | Energy for action sections |
| Outro volume | 0.19 (19%) | Closing music |
| **Background during inserts** | **0% (OFF)** | **CRITICAL: background MUST be silent when any other music plays. NEVER overlap.** |
| Music `-ss 15` | Skip 15 sec | Trim quiet intro of looped track |
| `stream_loop -1` | Loop forever | Short track → covers entire video |
| Ducking ratio | **1.8** | Soft — music dips during speech, doesn't vanish |
| Ducking threshold | 0.02 | Triggers on voice |
| Ducking attack | 300ms | Smooth fade down |
| Ducking release | 2500ms | Slow return — feels natural |
| `amix normalize=0` | **CRITICAL** | Prevents voice volume loss |
| `duration=first` | Match video length | All tracks trimmed to video duration |

### Volume automation for background music (fade out for inserts, fade back in)
```
volume='if(lt(t,T_START),0,
  if(lt(t,T_FADEIN_END),VOL*(t-T_START)/FADE_DUR,
  if(lt(t,T_FADEOUT_START),VOL,
  if(lt(t,T_FADEOUT_END),VOL*(T_FADEOUT_END-t)/FADE_DUR,
  0))))':eval=frame
```
Nest multiple `if()` for multiple sections. Each section: `0→fade_in→hold→fade_out→0→...`

### Voice boost (Windows auto-gain compensation) — apply BEFORE asplit, only if drift
```
volume='if(lt(t,4),1.6,if(lt(t,10),1.3,1.0))':eval=frame
```

### adelay for timed audio inserts
```
[N:a]adelay=MILLISECONDS|MILLISECONDS,volume=VOL,afade=...,atrim=0:END,asetpts=PTS-STARTPTS[name]
```
- `adelay` in **milliseconds** (120000 = 120 s). `adelay` MUST be BEFORE `atrim`. `afade` st= values are absolute (include the delay offset). `amix duration=first` trims everything to video length.

### Errors we made (learn from them)

| Error | What happened | Fix |
|---|---|---|
| `amix` without `normalize=0` | Voice lost 10+ dB | Always `normalize=0` |
| Pillow offset-copy borders | Looked different from drawtext | Use `stroke_width` + `stroke_fill` |
| PNG at 1920x1080 on 1440p video | Overlays too small/wrong position | Canvas MUST match video resolution |
| drawtext colored emoji | Black/monochrome glyphs | Pillow PNG + seguiemj.ttf + `embedded_color=True` |
| drawtext strikethrough | Not possible | Pillow `draw.line()` |
| `atrim` before `adelay` | Audio ended early | Always `adelay` → `atrim` |
| Ducking ratio=6 | Music vanished | Reduced to 1.8 |
| Testing overlays on full video | Slow iteration | Test on single frame (Pillow composite — instant) |
| Surgical insertion with `-c copy` | Frozen frames at splice | Always re-encode with NVENC |

### Do NOT:
- `normalize=1` (default amix) — kills voice volume
- `ratio=6` ducking — music disappears
- Music with vocals — competes with speech
- Skip `afade` on music — abrupt start/end
- `-c:v copy` when changing audio with `-ss` — frozen frames
- drawtext colored emoji — use Pillow PNG
- Test overlay styles on full video — test on extracted frame first
