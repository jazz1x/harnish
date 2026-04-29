"""purge-assets — TTL-based asset purge (dry-run by default)."""
import sys
import time
from datetime import date, datetime
from pathlib import Path
from .common import resolve_base_dir, resolve_asset_file
from .io import jsonl_read, jsonl_rewrite, compact_json

# TTL policy (mirrors purge-assets.sh hardcoded defaults)
TTL_DAYS: dict[str, int] = {
    "decision": 365,
    "failure": 90,
    "snippet": 180,
    "pattern": -1,     # never
    "guardrail": -1,   # never
}
SAFETY_WINDOW_HOURS = 24
SAFETY_SECS = SAFETY_WINDOW_HOURS * 3600


def register(sub):
    p = sub.add_parser("purge-assets", help="TTL-based asset purge (dry-run default)")
    p.add_argument("--execute", action="store_true", default=False)
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.set_defaults(func=_cmd_purge)


def _cmd_purge(args) -> int:
    base = resolve_base_dir(args.base_dir)
    asset_file = base / "harnish-assets.jsonl"
    archive_file = base / "harnish-assets-archive.jsonl"

    if not asset_file.exists():
        print(compact_json({"status": "no-op", "reason": "asset file absent"}))
        return 0

    now_epoch = time.time()
    candidates = []
    survivors = []

    for r in jsonl_read(asset_file):
        if _is_purge_candidate(r, now_epoch):
            candidates.append(r)
        else:
            survivors.append(r)

    if not args.execute:
        print(compact_json({"status": "dry_run", "candidates": candidates,
                            "count": len(candidates)}))
        return 0

    if not candidates:
        print(compact_json({"status": "no_candidates", "purged": 0}))
        return 0

    # Append candidates to archive
    with open(archive_file, "a", encoding="utf-8") as f:
        for c in candidates:
            f.write(compact_json(c) + "\n")

    jsonl_rewrite(asset_file, survivors)

    print(compact_json({"status": "purged", "purged": len(candidates),
                        "archive": str(archive_file)}))
    return 0


def _is_purge_candidate(r: dict, now_epoch: float) -> bool:
    type_ = r.get("type", "")
    ttl = TTL_DAYS.get(type_, 180)
    if ttl < 0:
        return False

    date_str = r.get("date", "1970-01-01")
    try:
        d = datetime.strptime(date_str, "%Y-%m-%d")
        created_epoch = d.timestamp()
    except ValueError:
        created_epoch = 0

    age = now_epoch - created_epoch
    if age <= ttl * 86400:
        return False
    if age <= SAFETY_SECS:
        return False

    # Decision: also require access_count >= 1 to keep
    if type_ == "decision" and r.get("access_count", 0) < 1:
        return True

    return type_ != "decision"
