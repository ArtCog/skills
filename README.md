# ИИмерсивный Skills

Claude Code plugin marketplace by [@art.immersive](https://youtube.com/@art.immersive). These are the skills I actually run in production to cut and ship videos for the channel — not demos written to be published.

## Install

```
/plugin marketplace add ArtCog/skills
/plugin install video-montage@artcog
/plugin install checkpoint@artcog
/plugin install anki-vocab@artcog
```

Updates arrive on their own: I push here, your copy follows.

## What's inside

### `checkpoint` — hand the project to the next session

Writes where the work actually stands into `STATE.md`, so the next session — or a different agent entirely, Codex or otherwise — picks up without you re-explaining anything. It answers one question: what are we standing on right now. Not what the project is (that's `AGENTS.md`), not the history (that's git).

It runs **only when you ask**. Never on its own, however finished the work looks — deciding that a block is closed is your call, not the agent's.

The discipline is in what the file refuses to hold: solved questions get deleted, and a lesson that hardened into a permanent project rule moves out to `AGENTS.md`. That's what keeps it short enough to stay read.

### `anki-vocab` — vocabulary into your own Anki

Point it at anything — a video, an article, a screenshot, or a single word typed in chat — and it builds flashcards in the deck you already use, for whatever language pair you're learning. Front, back, direction and note type follow **your** conventions; it inspects the deck rather than inventing structure.

Video sources use captions only (`yt-dlp --skip-download`), so a lecture costs you nothing in bandwidth. Every batch is tagged by source, so it can always be found or undone.

Needs Anki desktop running with the AnkiConnect add-on (code `2055492159`). No other dependency beyond `curl`.

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
/plugin install checkpoint@artcog
/plugin install anki-vocab@artcog
```

Обновления прилетают сами: я пушу сюда — у тебя обновляется.

### Что внутри

**`checkpoint` — передать проект следующей сессии.** Записывает в `STATE.md`, на чём работа стоит прямо сейчас, чтобы новая сессия — или вообще другой агент — продолжила без пересказа. Отвечает на один вопрос: где мы стоим. Не что за проект (это `AGENTS.md`) и не историю (это git).

Запускается **только когда попросишь**. Никогда сам, каким бы законченным ни выглядел блок — момент «работа закрыта» выбираешь ты.

Дисциплина файла в том, чего он не хранит: решённый вопрос удаляется, а грабля, ставшая постоянным правилом проекта, уезжает в `AGENTS.md`. За счёт этого он остаётся достаточно коротким, чтобы его читали.

**`anki-vocab` — слова в твою собственную Anki.** Дай что угодно — видео, статью, скриншот или одно слово в чате — и получишь карточки в той колоде, которой пользуешься, для любой языковой пары. Перед, оборот, направление и тип заметки берутся из **твоих** привычек: скилл смотрит колоду, а не выдумывает структуру.

Из видео тянутся только субтитры (`yt-dlp --skip-download`), так что лекция не стоит ни мегабайта трафика. Каждая партия помечается тегом источника — её всегда можно найти или откатить.

Нужен запущенный Anki с аддоном AnkiConnect (код `2055492159`). Больше ничего, кроме `curl`.

**`video-montage` — механический монтаж через ffmpeg.** Режет паузы **по голосовой дорожке**, а не по общему миксу. В этом весь смысл: демка, где шумит игра или приложение, больше не мешает вырезать тишину, потому что шум просто не доходит до детектора. Дальше — склейка сцен, субтитры по единому стандарту, оверлеи, круглая вебка, цветокоррекция, финальный рендер под YouTube на NVENC.

Пороги внутри выставлены на слух на реальных роликах и зафиксированы: `threshold=0.06`, `margin 0.12s/0.10s`. Это не значения по умолчанию, и возвращать их к умолчанию не надо.

`SKILL.md` держит решения, семь справочников рядом агент подтягивает только когда они нужны — пока скилл не сработал, он не занимает контекст.

### Другие среды

Плагины — механизм Claude Code. Для чата Claude, ChatGPT и Codex те же скиллы лежат архивами на [guide.arturx.art](https://guide.arturx.art) — там же расписано, куда какой класть.

### Лицензия

MIT. Бери, правь, используй.
