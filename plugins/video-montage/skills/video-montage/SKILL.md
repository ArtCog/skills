---
name: video-montage
description: Use when doing MECHANICAL video/audio operations on existing files — cutting, trimming, removing silence/pauses, concatenating scenes, subtitles, overlays, B-roll, PiP/circular webcam, zoom, speed, color grade, audio normalize/mix, final YouTube render. Triggers on video, montage, монтаж, вырезать, склеить, сцена, ffmpeg, render, рендер, субтитры, переходы, наложение, PiP, B-roll, overlay, silence, паузы, тишина, аудио, audio, громкость, normalize, круглая голова, zoom, цветокоррекция, color grade.
argument-hint: "video-file or command"
---

# Video Montage — Mechanical Shop (dispatcher)

This skill is the **mechanical cutting/rendering shop** (`C:\MONTAGE`). It holds critical rules inline and
routes to `references/*.md` for detailed playbooks. Heavy detail loads only when you need it.

## 0. Decision Tree — Start Here

> 🧭 **СНАЧАЛА — какой это цех?** Этот skill = МЕХАНИКА (точные ffmpeg-операции над готовым файлом).
> Если задача РЕДАКТОРСКАЯ — «сделай из сырья ролик по смыслу», убрать **фальстарты / оговорки /
> неудачные дубли**, или нужна **motion graphics / анимация** — это **studio**
> (`C:\Projects\Video\studio`, Video-Use + Hyperframes), НЕ этот skill. СТОП, иди туда.
> Полный роутер — `C:\Projects\Video\CLAUDE.md`. Ниже — только для механических задач.
>
> 🎬 **«Смонтируй ХУК» / голос и визуал — РАЗНЫЕ записи OBS (sidecar)?** Это РЕДАКТУРА, не голая механика.
> **СНАЧАЛА используй skill `video-hook-montage`** (редакторский поток: голос-спайн, чекпоинт темпа,
> удаление read-script кадров, визуал по смыслу без повторов, бренд-надписи, ask-vs-auto, hard lessons).
> Этот SKILL вызывается им ПОТОМ — только для механического рендера утверждённого плана.
>
> **Нужны И механика, И анимация?** Гибрид: монтаж собирает «скелет» (нарезка/тишина/склейка) и
> финализирует (1440p + музыка + true-peak), студия украшает между. Порядок — «Гибридный конвейер» в роутере.
>
> 📁 **Файловая гигиена (правило пользователя; пути приведены к канону 2026-07-15):** дом ролика —
> `C:\Projects\Video\<slug>\`: сырьё → `raw/`, ВСЁ промежуточное (cut, norm, тесты, wav, эксперименты) →
> `work/`, ТОЛЬКО готовые сцены/финалы → `renders/`. `C:\MONTAGE\` = общий инструментарий (tools/fonts/
> luts/_assets), НЕ дом проекта. После публикации ролика — skill `post-publish-cleanup`.

> ✂️ **«УБЕРИ ПАУЗЫ» — THE CANON (LOCKED 2026-07-11). Единственный разрешённый порядок.**
> Никакой самодеятельности: НЕ понижать порог под тихую запись, НЕ резать сырой звук, НЕ выдумывать значения.
> ```bash
> # 0. INPUT CHECK (5 sec) — mean тише −24 LUFS? СТОП: скажи пользователю «микрофон тихий, чини гейн в OBS», не крути порог!
> ffmpeg -i <raw> -map 0:a:0 -af volumedetect -f null -          # смотри mean_volume
> # 1. NORMALIZE first (protects quiet letters «к», «п» from being cut)
> ffmpeg-normalize <raw> -o <norm>.mkv -t -14 -tp -1.5 -c:a aac -b:a 256k
> # 2. PREVIEW GATE (no render): healthy = median clip ≥1.4s, ~40 clips per 2-3 min. Piece explosion → НЕ рендерить, разберись.
> auto-editor <norm>.mkv --edit audio:0.14 --margin 0.12s,0.10s --preview
> # 3. CUT (whole file, direct render)
> auto-editor <norm>.mkv --edit audio:0.14 --margin 0.12s,0.10s --video-codec h264_nvenc --video-bitrate 10M --audio-bitrate 256k --sample-rate 48000 --no-open -o <clean>.mp4
> # 4. §8 TRUE-PEAK FIX (mandatory) + verify: duration ≈ preview forecast, input_tp ≤ −1.0
> ```
> margin: `0.12s` защищает начала слов — НЕ уменьшать; хвост `0.10s` = плотность (пользователь может попросить 0.07). Детали/почему — §1.4, §1.5.
>
> 🔀 **РОУТЕР — первый шаг для ЛЮБОГО «убери паузы» (агент делает сам, пользователю ветки знать не нужно).**
> **Цель: резать ВСЕГДА по голосу пользователя, есть фон или нет.**
> 1. `ffprobe` — сколько аудиодорожек? Если две — сравнить разностью: `-filter_complex "[0:a:0][0:a:1]join=inputs=2:channel_layout=quad,pan=stereo|c0=c0-c2|c1=c1-c3,volumedetect" -f null -`. max ≈ −91 dB = дорожки идентичны, разделения нет.
> 2. Есть валидная голосовая дорожка (две разные, stream 1 = MIC) → **ветка Б, всегда** — даже если фон тихий/отсутствует (результат тот же, поведение предсказуемое). Это дефолт для всех записей OBS после 2026-07-11.
> 3. Одна дорожка / идентичны (старые или чужие файлы) → голосовой дорожки нет, по голосу резать не по чему → **ветка А** (канон выше) + предупредить пользователя, что резка по миксу и паузы с шумом останутся.
> 4. В ветке Б фон смысловой (чужая речь, TTS, музыка) → **СПРОСИТЬ пользователя**: «резать по голосу (фон порвётся на склейках) или по миксу (вырежется мало)?»
>
> ✂️ **ВЕТКА Б — ДЕМО-СЦЕНА (в записи шумит игра/приложение). Проверено на реальной записи и принято 2026-07-11.**
> Запись multi-track OBS: audio **stream 0 = микс** (голос+демо, для зрителя), **stream 1 = чистый MIC** (для резки). Тишину детектить ТОЛЬКО по голосу.
> По миксу резать НЕЛЬЗЯ: шум демо = «речь» для порога (замер: по миксу вырезалось −8%, по голосу −33% того же файла).
> **threshold=0.06 — LOCKED 2026-07-15.** Подтверждён на слух на полном ролике fable-test (сравнивали 0.04/0.05/0.06): выдохи/дыхание режутся, слова целы. 0.03 оставлял дыхание — не откатываться.
> ```bash
> # Б0. дорожки: должно быть 2 аудиопотока; пик голоса ≈ −6±2 dB (порог — доля от ПИКА дорожки: случайный щелчок сдвинет линию)
> ffprobe -v error -show_entries stream=index,codec_type -of compact <raw>.mkv
> ffmpeg -i <raw>.mkv -map 0:a:1 -af volumedetect -f null -
> # Б1. PREVIEW обязательно. СЫРОЙ файл: нормализация ДО резки на демо-записи уходит в динамический режим и убивает зазор речь/пауза
> auto-editor <raw>.mkv --edit "audio:threshold=0.06,stream=1" --margin 0.12s,0.10s --preview
> # Б2. рез: все дорожки режутся синхронно по решениям голосовой и сохраняются в выводе (проверено v29.3.1)
> auto-editor <raw>.mkv --edit "audio:threshold=0.06,stream=1" --margin 0.12s,0.10s --video-codec h264_nvenc --video-bitrate 10M --audio-bitrate 256k --sample-rate 48000 --no-open -o <cut>.mp4
> # Б3. §8 true-peak; в финал идёт МИКС. Нормализация −14 — на финальном мастере, НЕ здесь
> ffmpeg -y -i <cut>.mp4 -map 0:v:0 -map 0:a:0 -c:v copy -af "alimiter=limit=0.75:level=false:attack=3:release=30" -c:a aac -b:a 384k -ar 48000 -movflags +faststart <final>.mp4
> ```
> Голос для транскрипции/субтитров — из `<cut>.mp4` (там a:1 жив), в `<final>` его уже нет. Ветка А (чистая голосовая сцена) = канон выше, без изменений.
> ⚠️ **ВЫБОР ВЕТКИ — ПО ТИПУ ФОНА (проверено тестом 2026-07-11: фон-речь рвалась на склейках):**
> - Фон = **несмысловой шум** (клики, интерфейс, эффекты игры) → ветка Б (рез по своему голосу). Скачки шума на склейках не слышны.
> - Фон = **смысловое аудио** (чужая речь, TTS/голос ИИ из арены, музыка с мелодией) → резка по своему голосу ОБРУБИТ его на полуслове.
>   Варианты: (1) фон важен → резать по МИКСУ (ветка А: пауза = молчат ОБА; вырежется мало — это правильно); (2) фон неважен → ветка Б,
>   обрубки принять или замьютить фон; (3) точечно защитить реплики фона → `--add-in START,STOP`. Спросить пользователя, если тип фона неочевиден.
> - **Фоновую музыку не запекать в запись вообще** — она кладётся отдельным непрерывным слоем на финальном рендере (references/final-render-and-audio.md) и потому не рвётся.
> Noise floor: после MIC-цепочки OBS шум пауз на голос-дорожке −37…−40 dB; линия порога 0.06 при пике −6 ≈ −30.4 dB — зазор ~7-10 dB. Резка закапризничала → смотреть сюда первым делом (гейн/гейт в OBS), НЕ крутить порог вслепую.

```
User request → which reference to read:

"убери паузы / silence"          → CANON block ↑ + §1.4/§1.5
"вырежи фразу / cut phrase"      → references/playbooks.md  (C2)
"склей / concat"                 → references/playbooks.md  (C3) / multiscene-pipeline.md (final concat)
"собери ролик из сцен"           → references/multiscene-pipeline.md  (Steps 1-7)
"субтитры / captions"            → references/subtitle-standard.md  (LOCKED casing/size/CPS) + playbooks.md (C4) / effects.md (karaoke)
"текст на экране / надпись"      → references/playbooks.md  (C5 — brand overlays!)
"картинка / B-roll"              → references/playbooks.md  (C6)
"круглая голова / circle"        → references/playbooks.md  (C7)
"зум / speed / цвет"             → references/playbooks.md  (C8/C9/C12) / effects.md (LUT)
"аудио / музыка / ducking"       → references/final-render-and-audio.md
"финал-рендер (overlays+музыка)" → references/final-render-and-audio.md  → then §8 true-peak
"переходы между сценами"         → references/effects.md  (xfade)
"что-то сломалось / артефакты"   → references/known-issues.md

ANY editing task → Step 1: Check transcript exists. If not → transcribe first (§1.8).
ALWAYS finish ANY render with §8 True Peak Fix.
```

---

## 1. CRITICAL RULES — READ FIRST (always apply, never move to a reference)

### 1.0 RESEARCH before retrying
If something fails or produces bad results **twice** — STOP. Don't try a third time blindly.
Go to the internet (GitHub issues, Stack Overflow, Reddit) — the solution already exists. Research first, code second.

### 1.1 NEVER use `-c copy` (stream copy) for cuts
Stream copy cuts ONLY at keyframes (every 2-4 s). Cut point between keyframes → **frozen frames**. ALWAYS re-encode with NVENC. Quality > speed (RTX 3070 re-encodes 25 min in ~3 min).

### 1.2 NEVER use select/aselect filters for cutting
They cause **A/V desync** on long files (>5 min). Tested and confirmed broken.

### 1.3 NEVER write custom cut/trim scripts
Use ONLY proven tools: `auto-editor` for silence, `ffmpeg trim+concat` for manual cuts. Self-made scripts caused desync, missed pauses, garbage.

### 1.4 Silence removal: auto-editor renders directly, PER SCENE
auto-editor is the ONLY proven tool. Let it render — do NOT parse its XML and re-render with ffmpeg.
**CRITICAL O(n²):** 2 min → 18 s; 25 min → 20-30 min; 1 hour → HOURS. So **ALWAYS remove silence PER SCENE before concat** (each 1-5 min → seconds). Single most important optimization. Long combined file → run with `nohup ... & disown`.

**Default = feed the WHOLE file to auto-editor.** Do NOT split it or hand-protect ranges unless Artur explicitly says so (splitting is mainly a hook thing + rare cases).

**NORMALIZE TO −14 LUFS *BEFORE* auto-editor — this is a REQUIRED step, not optional (proven 2026-07-11).**
The `audio:` threshold treats quiet speech as silence. On a quiet recording (Artur's OBS mic runs ~−31 LUFS mean / −6.5 dB peak) the standard threshold `0.14` shreds words into 95+ slivers (median clip 0.35 s = mid-word cuts). Normalize first and the SAME `0.14` behaves correctly (40 clips, median ~1.5 s — measured, identical to raw-at-0.03). So: **do NOT compensate by lowering the threshold — raise the audio first.**
```bash
ffmpeg-normalize <scene>.mkv -o <scene>_norm.mkv -t -14 -tp -1.5 -c:a aac -b:a 256k   # then auto-editor on _norm
```
(Empirically confirmed the practice; the exact mechanism, full-scale vs peak-relative threshold, is NOT cleanly isolated — normalization can revert to dynamic mode on a single quiet file, so don't over-theorize. Just normalize first.)

**Silent-demo trap (still real, separate issue):** a playing demo / B-roll whose desktop audio was recorded low can sit below threshold *even after voice-normalization* (normalization targets the voice, not the demo) → gets cut as "silence" though it's content.
- To check whether a region actually HAS audio, use `ffmpeg -ss S -t D -i f -af volumedetect -f null -` and read **max_volume** — NOT loudnorm "Input Integrated", which gates quiet audio and falsely reports ~-44 LUFS "silence". (Seek with `-ss` AFTER `-i` for an accurate window — `-ss` before `-i` snaps to a keyframe and mismeasures.)
- Keep a flagged range with **`--add-in START,STOP`** (below).

Fix to keep a flagged range, still WHOLE-file (no split): protect it in the same call with **`--add-in START,STOP`** (e.g. `--add-in 65sec,87sec`) — everything outside is still cut at the standard threshold. (`(or audio:0.14 motion:0.02)` also keeps moving video, but motion is easily too sensitive and leaves pauses → prefer `--add-in` for a known range.)

### 1.5 Encode settings — LOCKED, DO NOT CHANGE

**Per-scene / intermediate (NVENC):** `-c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p`
**Audio (always):** `-c:a aac -b:a 256k` (256k minimizes generational loss; never 128k/192k)

**SIMPLE pause-removal pipeline (single scene, ВЕТКА А)** — полные команды уже в CANON-блоке §0
(normalize → preview gate → cut → §8 true-peak); здесь НЕ дублируются. Смысл флагов:
- `--edit audio:0.14` — threshold, valid **only on −14-normalized audio**. On raw quiet audio it shreds words; do NOT drop the threshold to compensate, normalize instead.
- `--margin` — **LOCKED 2026-07-15: default `0.12s,0.10s`** (прошёл весь ролик fable-test). First number = lead-in (protects word *starts*: soft onsets like «э», «п»); second = tail (space after words, kills trailing «аaa» breath). Tight-профиль хвоста `0.07s` — только по явному запросу (хук/плотные сцены). Verify a candidate threshold with `--preview` before rendering (healthy = ~40 clips, median ≥1.4 s; a piece-count explosion = threshold too high / audio not normalized).
- `mincut`/`minclip` — auto-editor defaults `0.2s`/`0.1s` protect short internal consonant gaps (the «к» in «подкупает»); a lead margin ≥0.12s bridges them too. Don't strip them.
- `--sample-rate 48000` — force 48 kHz (auto-editor v29 upsamples to 96 kHz by default → clicks/desync at concat joins with 48 kHz clips).

**Final YouTube concat (1440p) and ffmpeg-normalize settings** → `references/multiscene-pipeline.md`.

### 1.6 ALWAYS `-pix_fmt yuv420p`
xfade and some filters emit yuv444p → WMP can't play it. Always force yuv420p.

### 1.7 ALL montage commands → run in background
**EVERY ffmpeg, ffmpeg-normalize, auto-editor → `run_in_background: true`** (stay available for the user). Launch 2-3 scenes in parallel. NEVER `| tail -N` on these (blocks agent, hides progress). Never wait synchronously.

### 1.8 Transcribe before cutting
Always `transcribe.py` for exact word boundaries. Cut points = word end + 0.15s buffer (never mid-word).

### 1.9 Communicate in Russian
Explain WHAT and WHY, short and clear. The user wants to learn.

---

## 4. Tools Reference

### Python (`C:\MONTAGE\tools\`)
```
transcribe.py <file>                        → word-level transcript JSON (large-v3, CUDA)
detect_scenes.py <file>                     → scene boundary JSON
concat_clips.py f1 f2 [--transition fade]   → join clips with transitions
overlay_image.py <video> <image> [opts]     → image overlay with fade
build_srt.py <transcript.json>              → SRT subtitle file
verify_output.py <video>                    → verify output integrity
audio_enhance.py <video>                    → professional voice processing
```
**DELETED (do not recreate):** `smart_cut.py` — caused desync, unusable.

### CLI
```
auto-editor <file> ... -o <out>   → silence removal (ONLY method; LOCKED flags in §1.5)
ffmpeg-normalize <file> -o <out> -t -14 -tp -1.5 -c:a aac -b:a 256k   → -14 LUFS (last step)
```

---

## 8. True Peak Fix — MANDATORY final step after ANY render

**ALWAYS run after ANY render.** No exceptions. ~5 min, video untouched.
```bash
ffmpeg -y -i FINAL.mp4 -c:v copy \
  -af "alimiter=limit=0.75:level=false:attack=3:release=30" \
  -c:a aac -b:a 384k -ar 48000 -movflags +faststart \
  FINAL_fixed.mp4
```
**Why:** voice boost, amix summing, loud inserts create True Peak spikes > 0 dBFS (clipping = "gunshot" distortion on consonants). Limiter caps peaks.
- `level=false` — CRITICAL: prevents alimiter boosting volume back up.
- `-c:v copy` — safe (no `-ss` trimming, full pass-through).
- Do NOT use `aresample=192000` (creates NEW inter-sample peaks).

**Verify:** `ffmpeg -i FINAL_fixed.mp4 -af "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json" -f null /dev/null` → `input_tp` ≤ -1.0 dBTP.

---

## 12. YouTube Upload → Cleanup
Video ready? **REQUIRED:** skill `youtube-upload-prep` (subtitles, chapters, thumbnail, description, upload package).
Uploaded & confirmed? **REQUIRED:** skill `post-publish-cleanup` — пайплайн ролика не закончен, пока не убрано.

## 13. Hardware & Installed Tools
- **GPU:** RTX 3070 (NVENC h264_nvenc) · **Python** 3.13 + CUDA 12.6 · **Whisper** faster-whisper large-v3 (CUDA float16)
- **Installed:** pysubs2, auto-subtitle, scenedetect, auto-editor, ffmpeg-normalize, ultralytics
- **Fonts:** `C:\MONTAGE\fonts\` (8 Google Fonts + `Geist-Bold.ttf` brand) + system fonts · **LUTs:** `C:\MONTAGE\luts\` (4 .cube)
- **Project canon (2026-06):** per-video work lives in **`C:\Projects\Video\<ГГГГ-slug>\`** (`raw/ work/ renders/`); finals ONLY in `Video/<slug>/renders/`. `C:\MONTAGE\` is the SHARED toolbox only (`tools/ fonts/ luts/ _assets/`), NOT a project home. Old `C:\MONTAGE\projects\` = legacy. Full canon: `C:\Projects\Video\CLAUDE.md`.

---

## Related skills & docs
- **`video-hook-montage`** — editorial flow for dynamic hooks (voice + separate visual bank). Use it FIRST for hook tasks; it calls this skill for rendering.
- `C:\Projects\Video\DYNAMIC-HOOK-SIDECAR-PIPELINE.md` — full hook editorial playbook + Hard Lessons + Ask-vs-Auto.
- `C:\Projects\Video\CLAUDE.md` / `AGENTS.md` — Video Production router (which shop owns the task).
- `C:\MONTAGE\MONTAGE.md` — workspace folder canon + post-YouTube cleanup rule.
