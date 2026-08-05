# Subtitle Standard (Russian / Cyrillic) — video-montage reference

Loaded on demand from `SKILL.md`. THE locked standard for burned-in subtitles so every session produces
**identical** subtitles. Based on Netflix Russian Timed Text Style Guide + BBC Subtitle Guidelines
(sources at bottom). Brand styling (Geist / colors) overrides the generic font only.

## The #1 rule that broke last time: CASING

**Use sentence case — normal Russian capitalization, EXACTLY as written. Never random/ALL-CAPS.**
- Capital letter only at the **start of a sentence** and for **proper nouns** (GLM, Opus, Claude Code, Z.ai, имена).
- The rest is lowercase. Do NOT uppercase whole words/lines for "emphasis" — *all caps = shouting* (BBC).
- The SAME casing rule for every subtitle in the project. No mixing.
- Emphasis = **brand accent color on the anchor word** (green `#3CE5B0`), NOT capitalization, NOT a bigger font.
- (ALL-CAPS is allowed ONLY for short on-screen UI labels, per Netflix — not for spoken dialogue.)

## Locked numeric spec

| Parameter | Value | Source |
|---|---|---|
| Max lines per subtitle | **2** (landscape 16:9); 3 only for vertical 9:16 | Netflix / BBC |
| Max characters per line | **≤ 42**; aim **37–39** for Cyrillic (glyphs wider) | Netflix RU (42) / BBC (37–42) |
| Reading speed | **≤ 17 CPS** (adult). SDH up to 20. Children ≤ 13 | Netflix RU |
| Min duration on screen | **≥ 0.83 s**, never flash | BBC (~0.3 s/word) |
| Max duration on screen | ~7 s | Netflix |
| Min gap between subtitles | ≥ 2 frames (no touching) | Netflix |
| Line break | at natural clause boundary; balance line lengths; never split a noun+adjective or preposition+noun | BBC |
| Casing | **sentence case** (see above) | BBC / Netflix RU |

## Brand styling («Осциллограф» — overrides generic Arial/white)

- **Font: Geist Bold** — `C:\MONTAGE\fonts\Geist-Bold.ttf` (full Cyrillic). NO Impact/Tahoma/Arial, no serif.
- **ONE font size for the whole project** (his pain: sizes varied). Default height ≈ **4.5% of frame height**:
  - 1080p → `FontSize ≈ 48`
  - 1440p → `FontSize ≈ 64`
- **Base color:** brand ink `#E8EDEB` (near-white). **Outline:** black, `Outline ≈ 3` (1080p) / `4` (1440p), `Shadow 1` — for contrast on any footage.
- **Emphasis word:** brand accent green `#3CE5B0` (recolor that word only). Never bigger font, never caps.
- **Position:** lower-center, `Alignment=2`, `MarginV ≈ 70` (1080p) / `95` (1440p). Keep clear of important on-screen content (per `references/playbooks.md` C5 placement rule).

## How to build (consistent every time)

1. Transcribe with `transcribe.py` (word timings). **Fix Whisper mishears by MEANING** before writing subs (e.g. "дешевле" not "решили", "Z.ai" not "ZAE"), and apply correct Russian capitalization/punctuation — the raw transcript is lowercase/uncased garbage, do not burn it as-is.
2. Segment into ≤2-line cues respecting CPL ≤39 and CPS ≤17; break at clause boundaries.
3. Build the cue file with **one** consistent style:
   - SRT + `force_style` (simple), or ASS (for per-word accent color / karaoke — see `references/effects.md`).
4. Burn in with NVENC (force the locked style — do NOT rely on the SRT's own casing/size):
```bash
# 1440p brand subtitles (sentence case, Geist, ink + black outline, green accent via ASS \c)
ffmpeg -i video.mp4 -vf "subtitles=subs.srt:fontsdir='C\:/MONTAGE/fonts':force_style='FontName=Geist,FontSize=64,PrimaryColour=&H00EBEDE8,OutlineColour=&H00000000,BorderStyle=1,Outline=4,Shadow=1,Alignment=2,MarginV=95'" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a aac -b:a 256k output.mp4
```
   - ASS/SRT colors are **BGR hex** `&HAABBGGRR`: ink `#E8EDEB` → `&H00EBEDE8`; accent `#3CE5B0` → `&H00B0E53C`; black → `&H00000000`.
   - `FontName=Geist` requires `fontsdir` pointing at `C:\MONTAGE\fonts` (where `Geist-Bold.ttf` lives).
5. Verify on 2–3 extracted frames that casing/size/position are uniform before the full render.

## Quick checklist (every subtitle job)
- [ ] Sentence case, no random caps · [ ] one font size everywhere · [ ] Geist · [ ] ≤2 lines, ≤39 CPL
- [ ] ≤17 CPS, ≥0.83 s each · [ ] ink + black outline; green only for the emphasized word · [ ] lower-center, clear of important content

## Sources
- [Netflix — Russian Timed Text Style Guide](https://partnerhelp.netflixstudios.com/hc/en-us/articles/215346638-Russian-Timed-Text-Style-Guide) (17 CPS adult, ≤42 CPL, max 2 lines, sentence case for dialogue)
- [Netflix — Timed Text General Requirements](https://partnerhelp.netflixstudios.com/hc/en-us/articles/215758617-Timed-Text-Style-Guide-General-Requirements)
- [BBC Subtitle Guidelines](https://www.clevercast.com/bbc-subtitling-guidelines/) (mixed case — all caps = shouting; 37–42 CPL; min ~0.3 s/word; ≤2 lines)
