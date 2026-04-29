"""compress-assets — compress tags with N+ records into a summary entry."""
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from .common import resolve_base_dir, resolve_asset_file
from .io import jsonl_read, jsonl_rewrite, compact_json


def register(sub):
    p = sub.add_parser("compress-assets", help="compress high-frequency tag groups")
    p.add_argument("--tag", default="")
    p.add_argument("--all", dest="all_tags", action="store_true", default=False)
    p.add_argument("--threshold", type=int, default=5)
    p.add_argument("--dry-run", action="store_true", default=False)
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.set_defaults(func=_cmd_compress)


def _cmd_compress(args) -> int:
    if not args.tag and not args.all_tags:
        sys.stderr.write("오류: --tag 또는 --all 필수\n")
        return 1

    base = resolve_base_dir(args.base_dir)
    asset_file = base / "harnish-assets.jsonl"

    if not asset_file.exists() or asset_file.stat().st_size == 0:
        print(compact_json({"status": "empty", "compressed": 0}))
        return 0

    all_records = list(jsonl_read(asset_file))
    uncompressed = [r for r in all_records if not r.get("compressed")]

    # Determine target tags
    if args.all_tags:
        tag_counts: Counter = Counter()
        for r in uncompressed:
            for t in r.get("tags", []):
                tag_counts[t] += 1
        target_tags = [t for t, c in tag_counts.items() if c >= args.threshold]
    elif args.tag:
        target_tags = [args.tag]
    else:
        target_tags = []

    if not target_tags:
        print(compact_json({"status": "no_targets", "compressed": 0}))
        return 0

    if args.dry_run:
        candidates = []
        for t in target_tags:
            count = sum(1 for r in uncompressed if t in r.get("tags", []))
            candidates.append({
                "tag": t,
                "count": count,
                "would_compress": count >= args.threshold,
            })
        print(compact_json({"status": "dry_run", "candidates": candidates}))
        return 0

    # Compress
    compressed_count = 0
    records = list(all_records)  # mutable copy

    for target_tag in target_tags:
        matching = [r for r in records
                    if not r.get("compressed") and target_tag in r.get("tags", [])]
        count = len(matching)
        if count < args.threshold and args.all_tags:
            continue

        # Collect titles before marking compressed
        titles = " | ".join(
            f"{r.get('type')}: {r.get('title')}"
            for r in matching[:5]
        )

        # Mark matching records as compressed
        new_records = []
        for r in records:
            if not r.get("compressed") and target_tag in r.get("tags", []):
                r = dict(r)
                r["compressed"] = True
            new_records.append(r)
        records = new_records

        # Add summary entry
        date_str = datetime.now().strftime("%Y-%m-%d")
        summary = {
            "type": "pattern",
            "slug": f"compressed-{target_tag}",
            "title": f"[압축] {target_tag} ({count}건)",
            "tags": [target_tag],
            "date": date_str,
            "scope": "generic",
            "body": f"[{target_tag} × {count}건 압축] {titles}",
            "context": "compress-assets.sh",
            "session": "compress",
            "compressed_summary": True,
        }
        records.append(summary)
        compressed_count += 1

    jsonl_rewrite(asset_file, records)

    print(compact_json({"status": "compressed", "compressed": compressed_count}))
    return 0
