"""quality-gate — validate required field completeness of asset records."""
import json
import sys
from .common import resolve_base_dir, resolve_asset_file
from .io import jsonl_read, compact_json


def register(sub):
    p = sub.add_parser("quality-gate", help="check asset field completeness")
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.add_argument("--format", dest="fmt", default="text",
                   choices=["text", "json"])
    p.set_defaults(func=_cmd_quality)


def _cmd_quality(args) -> int:
    base = resolve_base_dir(args.base_dir)
    asset_file = base / "harnish-assets.jsonl"

    if not asset_file.exists() or asset_file.stat().st_size == 0:
        if args.fmt == "json":
            print(compact_json({"status": "empty", "issues": []}))
        else:
            print("자산 없음")
        return 0

    issues = []
    for r in jsonl_read(asset_file):
        if r.get("compressed"):
            continue
        record_issues = []
        if not r.get("type"):
            record_issues.append("type 누락")
        if not r.get("slug"):
            record_issues.append("slug 누락")
        if not r.get("title"):
            record_issues.append("title 누락")
        if not r.get("tags"):
            record_issues.append("tags 비어있음")
        if not r.get("body"):
            record_issues.append("body 비어있음")
        if not r.get("context"):
            record_issues.append("context 비어있음")
        if record_issues:
            n = len(record_issues)
            quality = "poor" if n > 2 else "fair"
            issues.append({
                "slug": r.get("slug"),
                "title": r.get("title"),
                "quality": quality,
                "issues": record_issues,
            })

    if args.fmt == "json":
        print(compact_json({"status": "checked", "issue_count": len(issues),
                            "issues": issues}))
    else:
        if not issues:
            print("품질 게이트 PASS — 모든 자산 완성도 양호")
        else:
            print(f"품질 게이트: {len(issues)}건 보완 필요")
            for issue in issues:
                slug = issue.get("slug") or issue.get("title")
                issue_str = ", ".join(issue["issues"])
                print(f"  [{issue['quality']}] {slug} — {issue_str}")
    return 0
