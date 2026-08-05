# ИИмерсивный Skills

Claude Code plugin marketplace by [@art.immersive](https://youtube.com/@art.immersive). These are the skills I actually run in production to cut and ship videos for the channel — not demos written to be published.

## Install

```
/plugin marketplace add ArtCog/skills
/plugin install video-montage@artcog
```

Updates arrive on their own: I push here, your copy follows.

## What's inside

### `video-montage` — mechanical video editing through ffmpeg

Cuts silence off the **voice track** rather than the mix. That distinction is the whole point: a demo scene with game or app audio no longer blocks silence removal, because the noise never reaches the detector. Then scene concat, subtitles on one standard, overlays, circular webcam PiP, colour grade, and a final YouTube render on NVENC.

The thresholds inside were tuned by ear on real footage and locked — `threshold=0.06`, `margin 0.12s/0.10s`. They are not defaults and should not be reset to any.

`SKILL.md` holds the decisions; seven reference files sit beside it and load only when the agent needs them, so the skill costs nothing in context until it fires.

**Note:** the skill text is written in Russian. The ffmpeg commands, flags, and file paths are language-neutral, and Claude reads the instructions rather than you — but if you plan to read along, expect Russian.

## Other environments

Plugins are a Claude Code mechanism. For Claude chat, ChatGPT, and Codex CLI the same skills are packaged as archives on [guide.arturx.art](https://guide.arturx.art), with per-environment install steps.

## License

MIT. Take it, change it, ship with it.

---

## По-русски

Маркетплейс плагинов для Claude Code от [@art.immersive](https://youtube.com/@art.immersive). Здесь скиллы, которыми я реально монтирую ролики для канала, а не написанные ради публикации.

### Установка

```
/plugin marketplace add ArtCog/skills
/plugin install video-montage@artcog
```

Обновления прилетают сами: я пушу сюда — у тебя обновляется.

### Что внутри

**`video-montage` — механический монтаж через ffmpeg.** Режет паузы **по голосовой дорожке**, а не по общему миксу. В этом весь смысл: демка, где шумит игра или приложение, больше не мешает вырезать тишину, потому что шум просто не доходит до детектора. Дальше — склейка сцен, субтитры по единому стандарту, оверлеи, круглая вебка, цветокоррекция, финальный рендер под YouTube на NVENC.

Пороги внутри выставлены на слух на реальных роликах и зафиксированы: `threshold=0.06`, `margin 0.12s/0.10s`. Это не значения по умолчанию, и возвращать их к умолчанию не надо.

`SKILL.md` держит решения, семь справочников рядом агент подтягивает только когда они нужны — пока скилл не сработал, он не занимает контекст.

### Другие среды

Плагины — механизм Claude Code. Для чата Claude, ChatGPT и Codex те же скиллы лежат архивами на [guide.arturx.art](https://guide.arturx.art) — там же расписано, куда какой класть.

### Лицензия

MIT. Бери, правь, используй.
