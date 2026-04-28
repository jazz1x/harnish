"""query-assets — search and format asset records."""
import json
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from .common import resolve_base_dir, resolve_asset_file
from .io import jsonl_read, compact_json


def register(sub):
    p = sub.add_parser("query-assets", help="search JSONL asset store")
    p.add_argument("--tags", required=True)
    p.add_argument("--types", default="")
    p.add_argument("--format", dest="fmt", default="json",
                   choices=["json", "text", "inject"])
    p.add_argument("--limit", type=int, default=5)
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.set_defaults(func=_cmd_query)


def _cmd_query(args) -> int:
    return query_assets(
        tags=args.tags,
        types=args.types,
        fmt=args.fmt,
        limit=args.limit,
        base_dir=args.base_dir,
    )


def query_assets(tags: str, types: str = "", fmt: str = "json",
                 limit: int = 5, base_dir: "str | None" = None) -> int:
    base = resolve_base_dir(base_dir)
    asset_file = base / "harnish-assets.jsonl"

    query_tags = [t.strip() for t in tags.split(",") if t.strip()]
    query_types = [t.strip() for t in types.split(",") if t.strip()] if types else []

    def empty_result():
        tag_list = query_tags
        if fmt == "json":
            out = {"query": {"tags": tag_list, "types": [], "limit": limit},
                   "results": [], "count": 0}
            print(compact_json(out))
        elif fmt == "text":
            print("(검색 결과 없음)")
        else:  # inject
            print("### 관련 자산 (asset-recorder)\n")
            print("(관련 자산 없음)")
        return 0

    if not asset_file.exists() or asset_file.stat().st_size == 0:
        return empty_result()

    # Filter records
    results = []
    for record in jsonl_read(asset_file):
        if record.get("compressed") is True:
            continue
        if query_types and record.get("type") not in query_types:
            continue
        rec_tags = record.get("tags", [])
        if any(qt in rec_tags for qt in query_tags):
            results.append(record)
        if len(results) >= limit:
            break

    if not results:
        return empty_result()

    # Write-back: update access_count + last_accessed_at for matched records
    matched_slugs = {r["slug"] for r in results}
    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    updated_records = []
    for record in jsonl_read(asset_file):
        if record.get("slug") in matched_slugs:
            record = dict(record)
            record["last_accessed_at"] = now_utc
            record["access_count"] = record.get("access_count", 0) + 1
        updated_records.append(record)

    # Atomic rewrite
    lines = "\n".join(compact_json(r) for r in updated_records) + "\n"
    with tempfile.NamedTemporaryFile(
        dir=asset_file.parent, delete=False, suffix=".tmp", mode="w", encoding="utf-8"
    ) as f:
        tmp = Path(f.name)
        f.write(lines)
    tmp.replace(asset_file)

    # Output
    if fmt == "json":
        out = {
            "query": {"tags": query_tags, "types": query_types, "limit": limit},
            "results": results,
            "count": len(results),
        }
        print(compact_json(out))

    elif fmt == "text":
        for r in results:
            body_preview = r.get("body", "")[:50]
            tag_str = ",".join(r.get("tags", []))
            print(f"[{r.get('type')}] {r.get('title')} ({r.get('date')}) — {body_preview}")
            print(f"  tags: {tag_str} | scope: {r.get('scope')}\n")

    else:  # inject
        print("### 관련 자산 (asset-recorder)\n")
        for r in results:
            type_ = r.get("type", "")
            hdr = "[" + type_
            if r.get("level"):
                hdr += f"/{r['level']}"
            if r.get("confidence"):
                hdr += f"/{r['confidence']}"
            if r.get("stability") is not None:
                hdr += f"/s{r['stability']}"
            hdr += "]"
            body_preview = r.get("body", "")[:120]
            ctx = r.get("context") or "(none)"
            line = f"- **{hdr} {r.get('title')}**: {body_preview}"
            line += f"\n  - context: {ctx}"
            if r.get("resolved") is not None:
                line += f" | resolved: {r['resolved']}"
            print(line)

    return 0
