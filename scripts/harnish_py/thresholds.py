"""check-thresholds — tag frequency report with compression warnings."""
import json
import sys
from collections import Counter
from .common import resolve_base_dir, resolve_asset_file
from .io import jsonl_read, compact_json


def register(sub):
    p = sub.add_parser("check-thresholds", help="report tag counts with warnings")
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.add_argument("--threshold", type=int, default=5)
    p.set_defaults(func=_cmd_thresholds)


def _cmd_thresholds(args) -> int:
    out = check_thresholds_str(base_dir=args.base_dir, threshold=args.threshold)
    if out:
        print(out)
    return 0


def check_thresholds_str(base_dir: "str | None" = None,
                          threshold: int = 5) -> str:
    """Return the threshold report as a string (empty string if no assets)."""
    base = resolve_base_dir(base_dir)
    asset_file = base / "harnish-assets.jsonl"

    if not asset_file.exists() or asset_file.stat().st_size == 0:
        return "자산 없음"

    tag_counts: Counter = Counter()
    for r in jsonl_read(asset_file):
        if r.get("compressed"):
            continue
        for tag in r.get("tags", []):
            # Replicate jq .tags[] output: JSON string (with quotes)
            tag_counts[compact_json(tag)] += 1

    if not tag_counts:
        return ""

    lines = []
    for tag_json, count in sorted(tag_counts.items(), key=lambda x: -x[1]):
        if count >= threshold:
            lines.append(f"{tag_json}({count}건) ⚠ 압축 권장")
        else:
            lines.append(f"{tag_json}({count}건)")
    return "\n".join(lines)
