# Music Player (Python Desktop)

Local desktop music player that reads .mp3 files from the `music` folder and presents them in a smooth, iPod-style coverflow UI.

## Features
- Auto-scan the `music` folder for .mp3 files
- Coverflow carousel (Qt Quick) with smooth drag + snap animation
- Click on the current cover to play/pause
- Icon-only controls for prev/play/next and refresh
- Seek bar with click/drag to jump to a time
- Auto-advance to next track (wrap-around)

## Setup
1. Install Python 3.12 or 3.11 (PySide6 does not support 3.14 yet).
2. Create a Python virtual environment (optional).
3. Install dependencies:

```bash
pip install -r requirements.txt
```

4. Put .mp3 files into the `music` folder.
5. Run the app:

```bash
python main.py
```

## Controls
- Drag left/right on the coverflow to switch tracks
- Click the center cover to play/pause
- Use Prev/Next icons for navigation (wraps around)
- Use the refresh icon to rescan the folder
- Click/drag the seek bar to jump within the track

## Notes
- The UI is built with Qt Quick (QML) for smooth animations.
- If mp3 playback fails, your system may need the Windows media codecs enabled.
