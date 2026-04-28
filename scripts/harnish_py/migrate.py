"""migrate — schema backfill for harnish-assets.jsonl."""
import json
import os
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from .common import resolve_base_dir, resolve_asset_file
from .io import jsonl_read, atomic_write, compact_json


def register(sub):
    p = sub.add_parser("migrate", help="schema migration with backfill")
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.add_argument("--target", default="0.0.2")
    p.set_defaults(func=_cmd_migrate)


def _cmd_migrate(args) -> int:
    base = resolve_base_dir(args.base_dir)
    asset_file = base / "harnish-assets.jsonl"
    log_file = base / "harnish-migration-log.jsonl"

    if not asset_file.exists():
        print(compact_json({"status": "no-op", "reason": "asset file absent"}))
        return 0

    if asset_file.stat().st_size == 0:
        print(compact_json({"status": "no-op", "reason": "asset file empty"}))
        return 0

    # Backup
    now_epoch = int(time.time())
    bak = Path(str(asset_file) + f".bak.{now_epoch}")
    import shutil
    shutil.copy2(asset_file, bak)

    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    migrated = 0
    skipped = 0
    new_records = []

    for r in jsonl_read(asset_file):
        current_version = r.get("schema_version", "0.0.1")
        if current_version == "0.0.1":
            r = dict(r)
            r["schema_version"] = args.target
            r.setdefault("last_accessed_at", r.get("date", "1970-01-01"))
            r.setdefault("access_count", 0)
            migrated += 1
        else:
            skipped += 1
        new_records.append(r)

    # Atomic rewrite
    lines = "\n".join(compact_json(r) for r in new_records)
    if lines:
        lines += "\n"
    with tempfile.NamedTemporaryFile(
        dir=asset_file.parent, delete=False, suffix=".tmp", mode="w", encoding="utf-8"
    ) as f:
        tmp = Path(f.name)
        f.write(lines)
    tmp.replace(asset_file)

    # Log
    log_entry = {
        "ts": now_utc,
        "from": "0.0.1",
        "to": args.target,
        "migrated": migrated,
        "skipped": skipped,
        "backup": str(bak),
    }
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(compact_json(log_entry) + "\n")

    # Retain only latest 3 backups
    bak_files = sorted(asset_file.parent.glob("harnish-assets.jsonl.bak.*"),
                       key=lambda p: p.stat().st_mtime, reverse=True)
    for old_bak in bak_files[3:]:
        try:
            old_bak.unlink()
        except Exception:
            pass

    print(compact_json({"status": "migrated", "migrated": migrated,
                        "skipped": skipped, "backup": str(bak)}))
    return 0
