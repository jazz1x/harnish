"""promote-pending — deduplicate /tmp pending JSONL and promote to asset store."""
import hashlib
import json
import os
import sys
from pathlib import Path
from .common import resolve_base_dir
from .io import compact_json
from .record import _cmd_record as _record_cmd_direct


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

    base = resolve_base_dir(args.base_dir)
    pending_file = Path(f"/tmp/harnish-pending-{session}.jsonl")

    if not pending_file.exists():
        print(compact_json({"status": "no_pending", "promoted": 0,
                          "deduplicated": 0, "skipped": 0}))
        return 0

    if pending_file.stat().st_size == 0:
        print(compact_json({"status": "empty", "promoted": 0,
                          "deduplicated": 0, "skipped": 0}))
        return 0

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
        print(compact_json({"status": "empty", "promoted": 0,
                          "deduplicated": 0, "skipped": 0}))
        return 0

    if args.dry_run:
        out = {
            "status": "dry_run",
            "promoted": unique_count,
            "deduplicated": dedup_count,
            "candidates": unique,
        }
        print(compact_json(out))
        return 0

    # Promote each unique entry
    short_session = session[:8]
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
        tags = f"auto,tool:{tool},session:{short_session}"
        context = f"auto-promoted from pending (occurrences: {occurrences})"

        try:
            _record_asset_direct(
                type_="failure",
                tags=tags,
                title=title,
                body=output,
                context=context,
                scope="project",
                session_id=session,
                base_dir=str(base),
            )
            promoted += 1
        except Exception:
            skipped += 1

    out = {
        "status": "promoted",
        "promoted": promoted,
        "deduplicated": dedup_count,
        "skipped": skipped,
    }
    print(compact_json(out))
    return 0


def _pid_hash() -> str:
    return hashlib.md5(str(os.getpid()).encode()).hexdigest()[:8]


def _record_asset_direct(type_: str, tags: str, title: str, body: str,
                          context: str, scope: str, session_id: str,
                          base_dir: str) -> None:
    """Call record logic directly (no subprocess)."""
    from .asset import TYPE_EXTRAS, VALID_TYPES, _append_record
    from .common import slugify
    from .init import init_assets
    from .io import jsonl_read
    from datetime import datetime, timezone
    from pathlib import Path

    base = Path(base_dir)
    if not base.is_dir():
        init_assets(base_dir=str(base), quiet=True)

    asset_file = base / "harnish-assets.jsonl"
    slug = slugify(title)
    existing_slugs = {r.get("slug") for r in jsonl_read(asset_file)}
    if slug in existing_slugs:
        base_slug = slug
        counter = 2
        while slug in existing_slugs:
            slug = f"{base_slug}-{counter}"
            counter += 1

    tag_list = [t.strip() for t in tags.split(",") if t.strip()]
    now_utc = datetime.now(timezone.utc)
    date_str = now_utc.strftime("%Y-%m-%d")
    iso_ts = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")

    record: dict = {
        "type": type_,
        "slug": slug,
        "title": title,
        "tags": tag_list,
        "date": date_str,
        "scope": scope,
        "body": body,
        "context": context,
        "session": session_id,
        "schema_version": "0.0.2",
        "last_accessed_at": iso_ts,
        "access_count": 0,
    }
    record.update(TYPE_EXTRAS.get(type_, {}))
    _append_record(asset_file, record)
