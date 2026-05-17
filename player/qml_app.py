from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path

import os

from PySide6.QtCore import QAbstractListModel, QObject, Qt, QTimer, QUrl, Slot, Property, Signal
from PySide6.QtGui import QColor, QFont, QGuiApplication, QImage, QPainter
from PySide6.QtQml import QQmlApplicationEngine
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from player.library import Track, ensure_music_dir, load_tracks


@dataclass(frozen=True)
class TrackItem:
    title: str
    artist: str
    path: str
    cover: str


class TrackModel(QAbstractListModel):
    TitleRole = Qt.UserRole + 1
    ArtistRole = Qt.UserRole + 2
    PathRole = Qt.UserRole + 3
    CoverRole = Qt.UserRole + 4

    countChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._items: list[TrackItem] = []

    def rowCount(self, parent=None) -> int:
        return len(self._items)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        item = self._items[index.row()]
        if role == self.TitleRole:
            return item.title
        if role == self.ArtistRole:
            return item.artist
        if role == self.PathRole:
            return item.path
        if role == self.CoverRole:
            return item.cover
        return None

    def roleNames(self):
        return {
            self.TitleRole: b"title",
            self.ArtistRole: b"artist",
            self.PathRole: b"path",
            self.CoverRole: b"cover",
        }

    @Property(int, notify=countChanged)
    def count(self) -> int:
        return len(self._items)

    @Slot(int, result="QVariantMap")
    def get(self, index: int):
        if index < 0 or index >= len(self._items):
            return {}
        item = self._items[index]
        return {
            "title": item.title,
            "artist": item.artist,
            "path": item.path,
            "cover": item.cover,
        }

    def set_items(self, items: list[TrackItem]) -> None:
        self.beginResetModel()
        self._items = items
        self.endResetModel()
        self.countChanged.emit()


class _MusicEventHandler(FileSystemEventHandler):
    def __init__(self, on_change) -> None:
        super().__init__()
        self._on_change = on_change

    def on_any_event(self, event) -> None:
        if event.is_directory:
            return
        if not str(event.src_path).lower().endswith(".mp3"):
            return
        self._on_change()


class MusicFolderWatcher:
    def __init__(self, path: Path, on_change) -> None:
        self._observer = Observer()
        handler = _MusicEventHandler(on_change)
        self._observer.schedule(handler, str(path), recursive=True)
        self._observer.start()

    def stop(self) -> None:
        self._observer.stop()
        self._observer.join(timeout=1.0)


class TrackStore(QObject):
    def __init__(self, project_root: Path, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._project_root = project_root
        self._music_dir = ensure_music_dir(project_root)
        self._cover_dir = self._music_dir / ".cache_covers"
        self._cover_dir.mkdir(parents=True, exist_ok=True)
        self.model = TrackModel(self)
        self._refresh_timer = QTimer(self)
        self._refresh_timer.setSingleShot(True)
        self._refresh_timer.timeout.connect(self.refresh)

        self._watcher = MusicFolderWatcher(self._music_dir, self._schedule_refresh)
        self.refresh()

    def stop(self) -> None:
        self._watcher.stop()

    def _schedule_refresh(self) -> None:
        if self._refresh_timer.isActive():
            return
        self._refresh_timer.start(250)

    @Slot()
    def refresh(self) -> None:
        tracks = load_tracks(self._music_dir)
        items: list[TrackItem] = []
        used_covers: set[Path] = set()
        for track in tracks:
            cover_path = self._cover_path(track)
            used_covers.add(Path(cover_path))
            items.append(
                TrackItem(
                    title=track.title,
                    artist=track.artist,
                    path=QUrl.fromLocalFile(str(track.path)).toString(),
                    cover=QUrl.fromLocalFile(cover_path).toString(),
                )
            )
        self.model.set_items(items)
        self._prune_cached_covers(used_covers)

    def _cover_path(self, track: Track) -> str:
        if track.cover_data:
            digest = hashlib.md5(track.cover_data).hexdigest()
            path = self._cover_dir / f"{digest}.png"
            if not path.exists():
                image = QImage.fromData(track.cover_data)
                if not image.isNull():
                    image.save(str(path))
                else:
                    self._write_placeholder(path, track.title)
            return str(path)

        digest = hashlib.md5(track.path.as_posix().encode("utf-8")).hexdigest()
        path = self._cover_dir / f"{digest}.png"
        if not path.exists():
            self._write_placeholder(path, track.title)
        return str(path)

    def _write_placeholder(self, path: Path, title: str) -> None:
        image = QImage(240, 240, QImage.Format.Format_ARGB32)
        image.fill(QColor("#1f1f1f"))
        painter = QPainter(image)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setBrush(QColor("#2d2d2d"))
        painter.setPen(QColor("#e6e6e6"))
        painter.setFont(QFont("Segoe UI", 9, QFont.Bold))
        painter.drawRoundedRect(14, 14, 212, 212, 18, 18)
        painter.drawText(image.rect(), Qt.AlignCenter, title[:28])
        painter.end()
        image.save(str(path))

    def _prune_cached_covers(self, used_covers: set[Path]) -> None:
        if not self._cover_dir.exists():
            return
        for entry in self._cover_dir.glob("*.png"):
            if entry not in used_covers:
                try:
                    entry.unlink()
                except OSError:
                    continue


def run() -> int:
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication([])
    app.setApplicationName("Music Player")

    project_root = Path(__file__).resolve().parent.parent
    track_store = TrackStore(project_root)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("trackStore", track_store)
    engine.rootContext().setContextProperty("trackModel", track_store.model)

    qml_path = project_root / "player" / "ui.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not engine.rootObjects():
        return 1

    exit_code = app.exec()
    track_store.stop()
    return exit_code
