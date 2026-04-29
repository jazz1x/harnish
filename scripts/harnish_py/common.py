"""Common helpers — mirrors common.sh resolve_* functions and slugify."""
import hashlib
import os
import re
from pathlib import Path


def resolve_base_dir(base_dir: "str | None" = None) -> Path:
    """Priority: explicit arg > ASSET_BASE_DIR env > CWD/.harnish"""
    if base_dir:
        return Path(base_dir)
    env = os.environ.get("ASSET_BASE_DIR")
    if env:
        return Path(env)
    return Path.cwd() / ".harnish"


def resolve_progress_file(base_dir: "str | None" = None) -> Path:
    return resolve_base_dir(base_dir) / "harnish-current-work.json"


def resolve_asset_file(base_dir: "str | None" = None) -> Path:
    return resolve_base_dir(base_dir) / "harnish-assets.jsonl"


def resolve_legacy_asset_file(base_dir: "str | None" = None) -> Path:
    return resolve_base_dir(base_dir) / "harnish-rag.jsonl"


def resolve_rag_file(base_dir: "str | None" = None) -> Path:
    """Deprecated alias — kept for external caller compatibility."""
    return resolve_asset_file(base_dir)


def slugify(text: str) -> str:
    """Produce a URL-safe slug.

    1. Lowercase + replace non-alnum with hyphens, collapse/strip, limit 60.
    2. If empty or only hyphens (i.e. non-ASCII input), fall back to md5[:12].
    Mirrors common.sh slugify() exactly.
    """
    ascii_slug = re.sub(r"[^a-z0-9-]", "-", text.lower())
    ascii_slug = re.sub(r"-+", "-", ascii_slug).strip("-")[:60]
    if ascii_slug and ascii_slug != "-":
        return ascii_slug
    return hashlib.md5(text.encode()).hexdigest()[:12]
