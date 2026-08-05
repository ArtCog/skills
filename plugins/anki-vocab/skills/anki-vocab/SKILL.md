---
name: anki-vocab
description: Adds vocabulary flashcards to the user's own Anki collection via AnkiConnect. Use when the user wants vocabulary from any source — a video, article, podcast, pasted text, an image, or words sent directly in chat — translated and/or saved as Anki cards, in any language pair. Requires Anki desktop with the AnkiConnect add-on running.
---

# anki-vocab

Turn vocabulary from any source into flashcards in the user's own Anki collection, in whatever language pair they are learning.

**Core principle: match the user's existing conventions (deck, note type, card direction). Never invent structure they didn't ask for.**

## The process

### 1. Connect

Anki desktop must be running with the AnkiConnect add-on (add-on code `2055492159`, listens on `http://127.0.0.1:8765`).

```bash
curl -s http://127.0.0.1:8765 -d '{"action":"version","version":6}'
```

No response → tell the user to open Anki and install AnkiConnect (Tools → Add-ons → Get Add-ons → `2055492159`, restart Anki). Stop until it responds.

### 2. Know the user

If you don't already know their preferences (check your memory first), ask once and remember:

- **target deck** — fetch `deckNames` and offer the real list;
- **language pair and card direction** — e.g. meaning in their native language on the front and the target-language item on the back (reversed recall), or target item on the front;
- **note type**, if they have a custom one.

If the current request already answers these, don't ask — proceed.

### 3. Get the material

The source can be anything. What matters is the capability it maps to:

- **Media URL (video, podcast, lecture)** → transcript via captions only, never download the media (Hard rule 4).
- **Text** (pasted, article, book excerpt, subtitles file) → read it directly.
- **Image / screenshot** → read the text from the image.
- **Words or sentences sent in chat** ("add this word", "translate these and save") → the message itself is the material.

### 4. Extract what's worth a card

- If the source *teaches* specific items (a "10 expressions" video, a textbook list) — take exactly those, don't invent extras.
- Otherwise extract items genuinely worth learning at the user's level: expressions, collocations, non-obvious words. Skip vocabulary the user clearly already knows.
- Single words sent directly → card them as-is.

### 5. Build the cards

One item per card, short front.

- **Front:** meaning in the user's native language, plus register when it matters *(colloquial / formal / business)*.
- **Back:** the target-language item in `<b>bold</b>`; the grammar the target language needs (gender/article, plural, verb forms, governed prepositions — whatever applies); 1–3 example sentences, taken from the source when there is one, otherwise natural ones; a one-line usage or etymology note only if genuinely memorable.
- Direction and fields follow the user's stated preference (step 2), not this default.

### 6. Confirm

Show the proposed cards as a front/back table in chat. If the user already named the deck and told you to add — add immediately and report. Otherwise wait for approval.

### 7. Add and verify

`addNotes` (whole batch in one request), then `findNotes` on the batch's source tag to confirm the count. Report: deck, number of cards, tag.

## Hard rules

These come from real observed failures. Violating any of them corrupts the user's collection or wastes their bandwidth.

1. **Never put non-ASCII text in a shell command line.** Non-Latin scripts/emoji in inline `curl -d '...'` get mangled (guaranteed on Windows). Always write the JSON payload to a temp file (UTF-8, no BOM) and send it:
   ```bash
   curl -s http://127.0.0.1:8765 --data-binary @payload.json
   ```
2. **Never create a deck the user didn't explicitly confirm.** Match the user's stated deck against real `deckNames` — spoken/typed names are often mangled ("Deutsch TC1" for "🔸DEUTSCH - C1🔸"). Pick the closest real deck; if nothing plausibly matches, show the list and ask.
3. **Match the deck's existing note type.** Inspect existing notes in the target deck and reuse their model and field layout. Deck names with spaces or emoji must be quoted in search queries: `{"query": "\"deck:My Deck\""}`. If `findNotes` returns `[]`, verify the query isn't silently broken before concluding the deck is empty; only a truly empty deck falls back to `Basic`. If the deck mixes several models: prefer the model of notes tagged `anki-vocab::*` (your own earlier batches), then the user's remembered preference, then ask once.
4. **Never download media to get a transcript.** Captions only:
   ```bash
   yt-dlp --skip-download --write-subs --write-auto-subs --sub-lang "<lang>.*" --convert-subs srt -o "%(id)s" "<url>"
   ```
   `<lang>` = the media's native language (`yt-dlp --dump-json --skip-download` → `.language`), never hardcoded `en`. No captions → tell the user; don't fall back to downloading audio/video without asking.
5. **Tag every card with its source:** `anki-vocab::yt::<channel>::<video-id>` for videos, `anki-vocab::chat`, `anki-vocab::text`, `anki-vocab::image`, etc. **Anki splits tags on spaces** — slugify every part (`Deutsch mit Rieke` → `Deutsch-mit-Rieke`) or the tag silently falls apart into fragments.

## Adapting to a specific language

Step 5 is deliberately language-neutral. If the user wants language-specific detail on their cards (pitch accent for Japanese, aspect pairs for Russian verbs, tones for Mandarin, separable-prefix marks for German…), treat it as a preference: remember it and apply it from then on. If the user explicitly asks to make it a permanent rule of the skill, edit this SKILL.md — add their rule under step 5.

## AnkiConnect quick reference

All calls: `POST http://127.0.0.1:8765` with `{"action": "...", "version": 6, "params": {...}}`.

| Action | Use |
|---|---|
| `deckNames`, `modelNames`, `modelFieldNames` | discover the user's setup |
| `findNotes` → `notesInfo` | inspect existing conventions |
| `addNotes` | add cards (batch) |
| `changeDeck`, `deleteNotes` | fix mistakes |
| `multi` | several actions in one request |

Example `addNotes` payload (English-learner example; fields follow the user's convention):

```json
{"action": "addNotes", "version": 6, "params": {"notes": [{
  "deckName": "English C1",
  "modelName": "Basic",
  "fields": {"Front": "meaning in the user's native language (colloquial)", "Back": "<b>to fizzle out</b><br>The project fizzled out after the funding ended."},
  "tags": ["anki-vocab::chat"]
}]}}
```

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Non-ASCII inline in `curl -d` | `'utf-8' codec can't decode byte`, mangled cards | payload file + `--data-binary @file` |
| Trusting the user's spoken deck name | duplicate deck, cards lost in it | fuzzy-match against `deckNames` |
| Unquoted deck name in search query | `findNotes` silently returns `[]` → wrong model chosen | quote `"deck:NAME"`; verify empty ≠ broken query |
| Downloading media for a transcript | hundreds of MB wasted | `--skip-download`, captions only |
| Hardcoding `en` subtitles | no or wrong-language transcript | use the media's native language |
| Untagged cards | batch can't be found or undone | `anki-vocab::<source>` tag on every card |
| Spaces inside a tag | Anki splits it into fragment tags | slugify with hyphens |
| Deck has several models, one picked by guess | cards inconsistent with the user's convention | prior `anki-vocab` batch → memory → ask |
