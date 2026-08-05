# FFmpeg Cookbook — Professional Patterns

## NVENC Presets (RTX 3070)

| Use case | Preset | CQ | Notes |
|----------|--------|-----|-------|
| Quick preview | p1 | 24 | Fastest, lower quality |
| Standard edit | p4 | 20 | Good balance (DEFAULT) |
| Final render | p7 + hq | 18 | Best quality, slower |
| Archive | p4 | 16 | High quality, larger files |

```bash
# Standard (use this by default)
-c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a aac -b:a 192k

# High quality final
-c:v h264_nvenc -preset p7 -tune hq -rc vbr -cq 18 -rc-lookahead 32 -spatial_aq 1 -temporal_aq 1 -pix_fmt yuv420p -c:a aac -b:a 192k

# Quick preview
-c:v h264_nvenc -preset p1 -cq 24 -pix_fmt yuv420p -c:a aac -b:a 128k
```

## Micro-Fades at Edit Points (Industry Standard)

Descript applies 5-sample micro-fades at every edit boundary. This eliminates clicks/pops.

```bash
# 5ms fade at output boundaries
-af "afade=t=in:d=0.005,afade=t=out:st=DURATION-0.005:d=0.005"

# Per-segment micro-fade (in filter_complex):
[0:a]afade=t=out:st=END-0.005:d=0.005[a0];
[1:a]afade=t=in:d=0.005[a1];
[a0][a1]concat=n=2:v=0:a=1[aout]
```

**Why NOT acrossfade for speech**: `acrossfade` fades out the tail of clip1, clipping the last word's ending. For speech, use clean concat with micro-fades instead.

## Professional Audio Chain

```bash
# Full chain: highpass → lowpass → compressor → de-esser → loudnorm
-af "highpass=f=80,lowpass=f=12000,acompressor=threshold=-20dB:ratio=4:attack=10:release=100:makeup=10,equalizer=f=6500:t=q:w=2:g=-4,loudnorm=I=-16:TP=-1.5:LRA=11"

# Or use: python C:\MONTAGE\tools\audio_enhance.py <video>
```

| Stage | Filter | Purpose |
|-------|--------|---------|
| 1 | `highpass=f=80` | Remove room rumble, mic handling noise |
| 2 | `lowpass=f=12000` | Remove hiss, high-frequency noise |
| 3 | `acompressor=threshold=-20dB:ratio=4:attack=10:release=100:makeup=10` | Even out voice dynamics |
| 4 | `equalizer=f=6500:t=q:w=2:g=-4` | De-ess (tame harsh "s" sounds) |
| 5 | `loudnorm=I=-16:TP=-1.5:LRA=11` | Broadcast standard loudness |

## One-Pass Silence Removal (select/aselect)

```bash
ffmpeg -i input.mp4 \
  -vf "select='between(t,0,5.2)+between(t,8.1,15.0)+between(t,16.5,30.0)',setpts=N/FRAME_RATE/TB" \
  -af "aselect='between(t,0,5.2)+between(t,8.1,15.0)+between(t,16.5,30.0)',asetpts=N/SR/TB" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a aac -b:a 192k output.mp4
```

**REQUIRED**: `setpts=N/FRAME_RATE/TB` and `asetpts=N/SR/TB` close gaps between segments.

## xfade + Clean Audio Concat (NOT acrossfade)

```bash
# 2 clips with fade transition — audio: clean concat with micro-fades
ffmpeg -i clip1.mp4 -i clip2.mp4 -filter_complex \
  "[0:v][1:v]xfade=transition=fade:duration=0.3:offset=PREV_DUR-0.3,format=yuv420p[vout]; \
   [0:a]afade=t=out:st=PREV_DUR-0.005:d=0.005[a0]; \
   [1:a]afade=t=in:d=0.005[a1]; \
   [a0][a1]concat=n=2:v=0:a=1[aout]" \
  -map "[vout]" -map "[aout]" -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p output.mp4
```

## J-Cut (Audio Leads Video — Professional Transition)

Audio from clip2 starts ~0.5s before the video transition. Creates smooth, natural flow.

```bash
ffmpeg -i clip1.mp4 -i clip2.mp4 -filter_complex \
  "[0:v][1:v]xfade=transition=fade:duration=0.5:offset=CLIP1_DUR-0.5,format=yuv420p[vout]; \
   [0:a]atrim=0:CLIP1_DUR-0.5,afade=t=out:st=CLIP1_DUR-1.0:d=0.5[a0]; \
   [1:a]afade=t=in:d=0.3[a1]; \
   [a0][a1]concat=n=2:v=0:a=1[aout]" \
  -map "[vout]" -map "[aout]" -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p output.mp4
```

## Color Grading

```bash
# Quick cinematic look (no LUT needed)
-vf "eq=brightness=0.06:contrast=1.15:saturation=1.2"

# With 3D LUT file (.cube)
-vf "lut3d=file=cinematic.cube"

# Vignette (darken edges — cinematic feel)
-vf "vignette=PI/4"

# Combine: color grade + vignette
-vf "eq=brightness=0.06:contrast=1.15:saturation=1.2,vignette=PI/4"
```

## Transport Stream Concatenation (fast, no re-encode)

```bash
ffmpeg -i clip1.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts clip1.ts
ffmpeg -i clip2.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts clip2.ts
ffmpeg -i "concat:clip1.ts|clip2.ts" -c copy -bsf:a aac_adtstoasc output.mp4
```

30x faster than re-encoding, but no transitions possible.

## Circular Crop Mask

```bash
# Make video region circular (diameter=SIZE)
scale=250:250,format=yuva420p,geq=lum='p(X,Y)':cb='p(X,Y)':cr='p(X,Y)':a='if(lt(pow(X-125,2)+pow(Y-125,2),pow(122,2)),255,0)'
```

## Lower Third with Fade

```bash
drawtext=text='Speaker Name':fontsize=28:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=10:\
x=w-tw-40:y=h-80:\
enable='between(t,5,12)':\
alpha='if(lt(t-5,0.5),(t-5)/0.5,if(lt(12-t,0.5),(12-t)/0.5,1))'
```

## PiP Overlay with Timing

```bash
ffmpeg -i main.mp4 -i overlay.mp4 \
  -filter_complex "[1:v]scale=320:-1[pip];[0:v][pip]overlay=W-340:20:enable='between(t,10,30)'" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a copy output.mp4
```

## Subtitle Burn-In with Styling

```bash
# Standard (clean, readable)
ffmpeg -i video.mp4 \
  -vf "subtitles=subs.srt:force_style='FontSize=24,FontName=Arial,Bold=1,PrimaryColour=&Hffffff,OutlineColour=&H000000,Outline=3,Shadow=1,MarginV=80,Alignment=2'" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a copy output.mp4

# Viral style (large, bold, eye-catching)
ffmpeg -i video.mp4 \
  -vf "subtitles=subs.srt:force_style='FontSize=70,FontName=Arial,Bold=1,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=4,Shadow=2,ShadowColour=&H80000000,MarginV=80,Alignment=2'" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a copy output.mp4
```

## Image Overlay with Fade In/Out

```bash
ffmpeg -i video.mp4 -i image.png \
  -filter_complex "[1:v]format=rgba,fade=t=in:st=10:d=0.5:alpha=1,fade=t=out:st=14.5:d=0.5:alpha=1[img];[0:v][img]overlay=(W-w)/2:(H-h)/2:enable='between(t,9.9,15.1)'" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p -c:a copy output.mp4
```

## Ken Burns Effect (Zoom/Pan on Still Image)

```bash
# Slow zoom in over 10 seconds
ffmpeg -loop 1 -i image.jpg -t 10 \
  -vf "zoompan=z='min(zoom+0.001,1.3)':d=300:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1920x1080:fps=30" \
  -c:v h264_nvenc -preset p4 -cq 20 -pix_fmt yuv420p output.mp4
```

## Audio Normalization

```bash
# EBU R128 broadcast standard (-16 LUFS for YouTube)
ffmpeg -i video.mp4 -af loudnorm=I=-16:TP=-1.5:LRA=11 -c:v copy output.mp4
```

## Mix Background Music (with ducking)

```bash
ffmpeg -i video.mp4 -i music.mp3 \
  -filter_complex "[1:a]volume=0.15[bg];[0:a][bg]amix=inputs=2:duration=first[aout]" \
  -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 192k output.mp4
```

## Audio Ducking (auto-reduce music when voice present)

```bash
ffmpeg -i voice_video.mp4 -i music.mp3 \
  -filter_complex "[1:a]sidechaincompress=threshold=0.04:ratio=4:attack=200:release=1000[bg];[0:a][bg]amix=inputs=2:duration=first[aout]" \
  -map 0:v -map "[aout]" -c:v copy output.mp4
```

## Windows Path Notes

- Use forward slashes in ffmpeg: `C:/MONTAGE/input/video.mp4`
- Or escape backslashes: `C:\\MONTAGE\\input\\video.mp4`
- Wrap paths with spaces in quotes
- For filter_complex with special chars: `-filter_complex_script file.txt`
