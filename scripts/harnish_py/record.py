"""record-asset — write an asset record to JSONL store."""
import json
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from .asset import TYPE_EXTRAS, VALID_TYPES, _append_record
from .common import resolve_base_dir, resolve_asset_file, slugify
from .init import init_assets
from .io import jsonl_read, compact_json


def register(sub):
    p = sub.add_parser("record-asset", help="record an asset to the JSONL store")
    p.add_argument("--type", dest="type_", default="")
    p.add_argument("--tags", default="")
    p.add_argument("--context", default="")
    p.add_argument("--title", default="")
    p.add_argument("--body", default="")
    p.add_argument("--content", default="")  # alias for --body
    p.add_argument("--body-file", dest="body_file", default="")
    p.add_argument("--session-id", dest="session_id", default="manual")
    p.add_argument("--scope", default="generic")
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.add_argument("--stdin", action="store_true", default=False)
    p.set_defaults(func=_cmd_record)


def _cmd_record(args) -> int:
    type_ = args.type_
    tags = args.tags
    context = args.context
    title = args.title
    body = args.body or args.content
    body_file = args.body_file
    session_id = args.session_id
    scope = args.scope
    base_dir = args.base_dir

    if args.stdin:
        raw = sys.stdin.read()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            sys.stderr.write('{"status":"error","reason":"stdin에 유효한 JSON이 아님"}\n')
            return 1
        type_ = data.get("type", "")
        tag_list = data.get("tags", [])
        tags = ",".join(tag_list) if isinstance(tag_list, list) else str(tag_list)
        context = data.get("context", "")
        title = data.get("title", "")
        body = data.get("body") or data.get("content") or ""
        session_id = data.get("session_id", "stdin")
        scope = data.get("scope", "generic")

    if not type_ or not title:
        sys.stderr.write('{"status":"error","reason":"--type과 --title은 필수"}\n')
        return 1

    if type_ not in VALID_TYPES:
        print(compact_json({"status": "error", "reason": f"unknown type: {type_}"}))
        return 1

    base = resolve_base_dir(base_dir)
    if not base.is_dir():
        init_assets(base_dir=str(base), quiet=True)

    asset_file = base / "harnish-assets.jsonl"

    # body from file
    body_content = body
    if body_file and Path(body_file).is_file():
        body_content = Path(body_file).read_text(encoding="utf-8")

    # slug dedup
    slug = slugify(title)
    existing_slugs = {r.get("slug") for r in jsonl_read(asset_file)}
    if slug in existing_slugs:
        base_slug = slug
        counter = 2
        while slug in existing_slugs:
            slug = f"{base_slug}-{counter}"
            counter += 1

    # tag list
    tag_list = [t.strip() for t in tags.split(",") if t.strip()] if tags else []

    # timestamps
    now_utc = datetime.now(timezone.utc)
    date_str = now_utc.strftime("%Y-%m-%d")
    iso_ts = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")

    # build record
    record: dict = {
        "type": type_,
        "slug": slug,
        "title": title,
        "tags": tag_list,
        "date": date_str,
        "scope": scope,
        "body": body_content,
        "context": context,
        "session": session_id,
        "schema_version": "0.0.2",
        "last_accessed_at": iso_ts,
        "access_count": 0,
    }
    record.update(TYPE_EXTRAS.get(type_, {}))

    _append_record(asset_file, record)

    # RCA quality check
    warnings = []
    if not context:
        warnings.append("context가 비어있습니다")
    if not body_content:
        warnings.append("body가 비어있습니다")
    if not tag_list:
        warnings.append("tags가 비어있습니다")

    if len(warnings) > 2:
        quality = "poor"
    elif warnings:
        quality = "fair"
    else:
        quality = "good"

    result = {
        "status": "recorded",
        "type": type_,
        "slug": slug,
        "tags": tag_list,
        "alerts": [],
        "rca": {"warnings": warnings, "quality": quality},
    }
    print(compact_json(result))
    return 0
