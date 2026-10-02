# Audiobook read-along subtitles (SubPlz)

A one-click Windows launcher for [SubPlz](https://github.com/kanjieater/SubPlz). It creates an `.srt` subtitle file timed to the narration for each audiobook, so you can read along while you listen.

## One-time setup

1. Install **Docker Desktop** 4.44.2 or newer: https://www.docker.com/products/docker-desktop/
   (Accept the WSL 2 option and restart the PC if it asks.)
2. Start Docker Desktop and wait until it says **Engine running**.
3. Download `Run-SubPlz.bat` and `run-subplz.ps1` from this repo into the **same folder** (for example, your Desktop).

## Arrange the books

Put each book in its own folder, with its audio and its ebook together:

```
Mushoku Tensei - Jobless Reincarnation\
├── Volume 01\
│   ├── Mushoku Tensei Vol 1.m4b     (audio: one chaptered .m4b works best)
│   └── Mushoku Tensei Vol 1.epub    (text: .epub or .txt)
├── Volume 02\
│   ├── ...
```

If a volume is many MP3s, merge them into one `.m4b` first. [AudioBookConverter](https://github.com/yermak/AudioBookConverter) can do this.

## Run

Double-click **`Run-SubPlz.bat`**. It will:

1. Scan `C:\Users\Nebula PC\Downloads\Mushoku Tensei - Jobless Reincarnation` and list which folders are ready.
2. Ask whether the narration is English or Japanese.
3. Download SubPlz (several GB the first time) and use your NVIDIA GPU if there is one.
4. Write `<audio name>.srt` next to each audio file. It skips folders that already have subtitles.

Then open the audio file in [mpv](https://mpv.io/). The subtitles load automatically.

### Other options (run from PowerShell in the script's folder)

```powershell
# A different folder
.\Run-SubPlz.bat -Root "D:\Audiobooks\Some Book"
# Preview what would be processed, without running anything
.\Run-SubPlz.bat -DryRun
# Redo books that already have subtitles; use a bigger, more accurate model
.\Run-SubPlz.bat -Force -Model turbo
```
