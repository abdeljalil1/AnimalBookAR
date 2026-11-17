"""Which book a tool works on: `--book=<id>` (default: animals), from app/assets/ar/books.json.

    BOOK.items      the book's items (animals.json, books/cars/items.json, ...)
    BOOK.data       that file, relative to app/assets/ar
    BOOK.targets    the MindAR targets file, relative to app/assets/ar
    BOOK.pages      folder for the printable page PNGs (book/pages, book/cars/pages)
    BOOK.pdf        the printable PDF
    BOOK.app_pages  folder for the app's page JPGs
    BOOK.thumbs     folder for the app's round thumbnails
    BOOK.photos     folder of the source photos (tool/photos, tool/photos/cars)
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AR = ROOT / "app" / "assets" / "ar"


class Book:
    def __init__(self, book_id):
        cfg = next((b for b in json.loads((AR / "books.json").read_text()) if b["id"] == book_id), None)
        if cfg is None:
            sys.exit(f"no book {book_id!r} in app/assets/ar/books.json")
        self.id = book_id
        self.cfg = cfg
        self.data = cfg["data"]
        self.targets = cfg["targets"]
        self.items = json.loads((AR / self.data).read_text())
        first = book_id == "animals"  # the first book keeps its original paths
        self.pages = ROOT / "book" / ("pages" if first else f"{book_id}/pages")
        self.pdf = ROOT / "book" / ("animal-book.pdf" if first else f"{book_id}/{book_id}-book.pdf")
        self.app_pages = ROOT / "app" / cfg["pagesDir"]
        self.thumbs = ROOT / "app" / cfg["thumbsDir"]
        self.photos = ROOT / "tool" / "photos" / ("" if first else book_id)
        self.vehicles = cfg.get("kind") == "vehicles"


BOOK = Book(next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--book=")), "animals"))
