from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from mutagen import File
from mutagen.id3 import ID3, ID3NoHeaderError


@dataclass(frozen=True)
class Track:
    path: Path
    title: str
    artist: str
    album: str
    duration_seconds: float
    cover_data: bytes | None


def ensure_music_dir(root: Path) -> Path:
    music_dir = root / "music"
    music_dir.mkdir(parents=True, exist_ok=True)
    return music_dir


def _read_id3_tag(path: Path, frame_id: str) -> str:
    try:
        tags = ID3(path)
    except ID3NoHeaderError:
        return ""
    frame = tags.get(frame_id)
    if frame is None:
        return ""
    text = getattr(frame, "text", None)
    if not text:
        return ""
    return str(text[0])


def _read_cover_data(path: Path) -> bytes | None:
    try:
        tags = ID3(path)
    except ID3NoHeaderError:
        return None
    for key in tags.keys():
        if key.startswith("APIC"):
            frame = tags.get(key)
            if frame and getattr(frame, "data", None):
                return bytes(frame.data)
    return None


def _iter_mp3_files(music_dir: Path) -> Iterable[Path]:
    return sorted(music_dir.rglob("*.mp3"), key=lambda item: item.name.lower())


def load_tracks(music_dir: Path) -> list[Track]:
    tracks: list[Track] = []
    for path in _iter_mp3_files(music_dir):
        audio = File(path)
        duration = 0.0
        if audio and getattr(audio, "info", None) and getattr(audio.info, "length", None):
            duration = float(audio.info.length)

        title = _read_id3_tag(path, "TIT2") or path.stem
        artist = _read_id3_tag(path, "TPE1")
        album = _read_id3_tag(path, "TALB")
        cover_data = _read_cover_data(path)

        tracks.append(
            Track(
                path=path,
                title=title,
                artist=artist,
                album=album,
                duration_seconds=duration,
                cover_data=cover_data,
            )
        )

    return tracks
