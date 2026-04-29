"""Asset dataclass, type metadata, abstract/localize operations."""
import sys
import tempfile
from pathlib import Path
from .common import resolve_base_dir, resolve_asset_file
from .io import jsonl_read, jsonl_rewrite, compact_json

VALID_TYPES = {"failure", "pattern", "guardrail", "snippet", "decision"}

# Per-type extra fields (mirrors bash case statement in record-asset.sh)
TYPE_EXTRAS: dict[str, dict] = {
    "failure":  {"resolved": True},
    "pattern":  {"stability": 1},
    "snippet":  {"stability": 1},
    "guardrail": {"level": "soft"},
    "decision": {"confidence": "medium"},
}


# ── abstract-asset / localize-asset ──────────────────────────────────────────

def register(sub):
    p_abs = sub.add_parser("abstract-asset", help="abstract project asset to generic scope")
    p_abs.add_argument("--slug", required=True)
    p_abs.add_argument("--base-dir", dest="base_dir", default=None)
    p_abs.set_defaults(func=_cmd_abstract)

    p_loc = sub.add_parser("localize-asset", help="localize generic asset to project scope")
    p_loc.add_argument("--slug", required=True)
    p_loc.add_argument("--base-dir", dest="base_dir", default=None)
    p_loc.set_defaults(func=_cmd_localize)


def _cmd_abstract(args) -> int:
    asset_file = resolve_asset_file(args.base_dir)
    if not asset_file.exists():
        sys.stderr.write(f"오류: {asset_file} 없음\n")
        return 1
    original = _find_by_slug(asset_file, args.slug)
    if original is None:
        sys.stderr.write(f"오류: slug '{args.slug}' 없음\n")
        return 1
    abstracted = dict(original)
    abstracted["scope"] = "generic"
    abstracted["slug"] = original["slug"] + "-generic"
    abstracted["context"] = original.get("context", "") + " (추상화)"
    _append_record(asset_file, abstracted)
    print(compact_json({"status": "abstracted", "slug": abstracted["slug"]}))
    return 0


def _cmd_localize(args) -> int:
    asset_file = resolve_asset_file(args.base_dir)
    if not asset_file.exists():
        sys.stderr.write(f"오류: {asset_file} 없음\n")
        return 1
    original = _find_by_slug(asset_file, args.slug)
    if original is None:
        sys.stderr.write(f"오류: slug '{args.slug}' 없음\n")
        return 1
    localized = dict(original)
    localized["scope"] = "project"
    localized["slug"] = original["slug"] + "-local"
    localized["context"] = original.get("context", "") + " (로컬화)"
    _append_record(asset_file, localized)
    print(compact_json({"status": "localized", "slug": localized["slug"]}))
    return 0


# ── helpers ───────────────────────────────────────────────────────────────────

def _find_by_slug(asset_file: Path, slug: str) -> "dict | None":
    for record in jsonl_read(asset_file):
        if record.get("slug") == slug:
            return record
    return None


def _append_record(asset_file: Path, record: dict) -> None:
    """Atomic copy+append+rename pattern (mirrors bash record-asset)."""
    asset_file.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=asset_file.parent, delete=False, suffix=".tmp", mode="w", encoding="utf-8"
    ) as f:
        tmp = Path(f.name)
        # copy existing
        if asset_file.exists():
            with open(asset_file, "r", encoding="utf-8") as src:
                for line in src:
                    f.write(line)
        f.write(compact_json(record) + "\n")
    tmp.replace(asset_file)
