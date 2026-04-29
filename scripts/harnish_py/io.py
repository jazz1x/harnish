"""I/O helpers — atomic writes, JSONL iteration, SHA-256.

Mirrors honne's io.py pattern exactly.
"""
import hashlib
import json
import sys
import tempfile
from pathlib import Path
from typing import Iterator

# Compact JSON — matches jq -c output (no spaces after : and ,)
_COMPACT = {"ensure_ascii": False, "separators": (",", ":")}


def compact_json(obj) -> str:
    """Serialize to compact JSON (matches jq -c output)."""
    return json.dumps(obj, **_COMPACT)


def atomic_write(path: "Path | str", data: "bytes | str") -> None:
    """Write data to a temporary file, then atomically rename to target."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        data = data.encode("utf-8")
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False, suffix=".tmp") as f:
        temp_path = Path(f.name)
        f.write(data)
    temp_path.replace(path)


def jsonl_read(path: "Path | str") -> Iterator[dict]:
    """Iterate JSONL records. Handles multi-line JSON objects (jq compat).

    Yields nothing if file is missing or empty.
    """
    p = Path(path)
    if not p.exists():
        return
    with open(p, "r", encoding="utf-8") as f:
        buf = ""
        for line in f:
            stripped = line.strip()
            if not stripped:
                continue
            buf += stripped
            try:
                obj = json.loads(buf)
                yield obj
                buf = ""
            except json.JSONDecodeError:
                buf += " "  # accumulate for multi-line JSON
        if buf.strip():
            sys.stderr.write(f"warning: jsonl_read: incomplete JSON at EOF in {p}\n")


def jsonl_append(path: "Path | str", record: dict) -> None:
    """Append a single JSONL record. Uses append + flush (no rename)."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a", encoding="utf-8") as f:
        f.write(compact_json(record) + "\n")
        f.flush()


def jsonl_rewrite(path: "Path | str", records: list) -> None:
    """Atomically rewrite an entire JSONL file from a list of dicts."""
    lines = "\n".join(compact_json(r) for r in records)
    if lines:
        lines += "\n"
    atomic_write(path, lines)


def sha256_file(path: "Path | str") -> str:
    """Compute the SHA-256 hex digest of a file."""
    path = Path(path)
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(8192):
            hasher.update(chunk)
    return hasher.hexdigest()
