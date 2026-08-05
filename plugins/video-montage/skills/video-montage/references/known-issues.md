# Known Issues & Anti-Patterns — video-montage reference

Loaded on demand from `SKILL.md`. The non-negotiable "never do this" list. Core rules in `SKILL.md §1`.

### FATAL — will cause visible problems:
1. **`-c copy` for cuts** → frozen frames (keyframe issue). ALWAYS re-encode.
2. **select/aselect filters** → audio/video desync on long files. NEVER use.
3. **Self-made cut scripts** → desync, missed pauses, garbage. Use auto-editor.
4. **afftdn noise reduction** → "barrel" / underwater sound on clean recordings. Don't use.
5. **Compressor for normalization** → pumps noise between words. Use loudnorm instead.
6. **`| tail -N` on long commands** → hides progress, looks frozen. Use `run_in_background`.
7. **Mixing fps in concat** (30fps + 60fps with `-c copy`) → duplicate/frozen frames. Re-encode first.

### WARNINGS:
8. **bash exit 127**: Long python commands → restart session or use powershell.exe.
9. **CUDA Toolkit required**: `cublas64_12.dll` needs CUDA 12.6.
10. **large-v3 ~3 GB**: Downloads on first run. Cached at `~/.cache/huggingface/hub/`.
11. **xfade → yuv444p**: ALWAYS add `-pix_fmt yuv420p`. Without it, WMP error 0x80004005.
12. **AAC re-encoding**: Don't re-encode AAC >2 times. Normalize each source separately.
13. **Windows auto-gain**: Gradually changes mic volume. Disable in Sound settings.
