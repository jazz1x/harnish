"""promote-pending — deduplicate /tmp pending JSONL and promote to asset store."""
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from .asset import TYPE_EXTRAS
from .common import resolve_base_dir, slugify
from .init import init_assets
from .io import jsonl_read, jsonl_rewrite, compact_json


def register(sub):
    p = sub.add_parser("promote-pending", help="promote pending events to asset store")
    p.add_argument("--session", default="")
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.add_argument("--dry-run", action="store_true", default=False)
    p.set_defaults(func=_cmd_promote)


def _cmd_promote(args) -> int:
    session = args.session
    if not session:
        session = os.environ.get("CLAUDE_SESSION_ID") or _pid_hash()
    result = promote_pending(session, args.base_dir, dry_run=args.dry_run)
    print(compact_json(result))
    return 0


def promote_pending(session: str, base_dir: "str | None", dry_run: bool = False) -> dict:
    base = resolve_base_dir(base_dir)
    pending_file = Path(f"/tmp/harnish-pending-{session}.jsonl")

    if not pending_file.exists():
        return {"status": "no_pending", "promoted": 0, "deduplicated": 0, "skipped": 0}

    if pending_file.stat().st_size == 0:
        return {"status": "empty", "promoted": 0, "deduplicated": 0, "skipped": 0}

    # Load all pending records
    records = []
    with open(pending_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                pass

    total_count = len(records)

    # Deduplicate: key = tool + first non-empty line of output (truncated 50)
    seen: dict[str, dict] = {}
    counts: dict[str, int] = {}
    for r in records:
        tool = r.get("tool", "")
        output = r.get("output", "")
        first_line = next(
            (ln.strip() for ln in output.split("\n") if ln.strip()), ""
        )[:50]
        key = tool + "|" + first_line
        if key not in seen:
            seen[key] = r
        counts[key] = counts.get(key, 0) + 1

    unique = [
        {
            "tool": r.get("tool", ""),
            "output": r.get("output", ""),
            "session": r.get("session", ""),
            "date": r.get("date", ""),
            "occurrences": counts[k],
        }
        for k, r in seen.items()
    ]

    unique_count = len(unique)
    dedup_count = total_count - unique_count

    if unique_count == 0:
        return {"status": "empty", "promoted": 0, "deduplicated": 0, "skipped": 0}

    if dry_run:
        return {
            "status": "dry_run",
            "promoted": unique_count,
            "deduplicated": dedup_count,
            "candidates": unique,
        }

    # Ensure .harnish/ exists
    if not base.is_dir():
        init_assets(base_dir=str(base), quiet=True)

    asset_file = base / "harnish-assets.jsonl"

    # Load existing records once — build slug set for dedup
    existing_records = list(jsonl_read(asset_file))
    existing_slugs: set[str] = {r.get("slug") for r in existing_records}

    short_session = session[:8]
    now_utc = datetime.now(timezone.utc)
    date_str = now_utc.strftime("%Y-%m-%d")
    iso_ts = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")

    new_records = []
    promoted = 0
    skipped = 0

    for entry in unique:
        output = entry.get("output", "")
        if not output:
            skipped += 1
            continue

        first_line = next(
            (ln.strip() for ln in output.split("\n") if ln.strip()), ""
        )
        if not first_line:
            skipped += 1
            continue

        title = first_line[:60]
        tool = entry.get("tool", "")
        occurrences = entry.get("occurrences", 1)
        tag_list = ["auto", f"tool:{tool}", f"session:{short_session}"]
        context = f"auto-promoted from pending (occurrences: {occurrences})"

        # Slug dedup against existing + already-allocated in this batch
        slug = slugify(title)
        all_slugs = existing_slugs | {r["slug"] for r in new_records}
        if slug in all_slugs:
            base_slug = slug
            counter = 2
            while slug in all_slugs:
                slug = f"{base_slug}-{counter}"
                counter += 1

        record: dict = {
            "type": "failure",
            "slug": slug,
            "title": title,
            "tags": tag_list,
            "date": date_str,
            "scope": "project",
            "body": output,
            "context": context,
            "session": session,
            "schema_version": "0.0.2",
            "last_accessed_at": iso_ts,
            "access_count": 0,
        }
        record.update(TYPE_EXTRAS.get("failure", {}))
        new_records.append(record)
        promoted += 1

    if new_records:
        jsonl_rewrite(asset_file, existing_records + new_records)

    return {"status": "promoted", "promoted": promoted, "deduplicated": dedup_count, "skipped": skipped}


def _pid_hash() -> str:
    return hashlib.md5(str(os.getpid()).encode()).hexdigest()[:8]
