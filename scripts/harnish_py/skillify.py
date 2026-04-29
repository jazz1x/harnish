"""skillify — generate SKILL.md scaffold from asset store."""
import json
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from .common import resolve_base_dir, resolve_asset_file
from .io import jsonl_read, compact_json


def register(sub):
    p = sub.add_parser("skillify", help="generate SKILL.md scaffold from assets")
    p.add_argument("--tag", required=True)
    p.add_argument("--skill-name", dest="skill_name", required=True)
    p.add_argument("--output-dir", dest="output_dir", default="skills")
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.set_defaults(func=_cmd_skillify)


def _cmd_skillify(args) -> int:
    base = resolve_base_dir(args.base_dir)
    asset_file = base / "harnish-assets.jsonl"

    if not asset_file.exists():
        sys.stderr.write(f"오류: {asset_file} 없음\n")
        return 1

    assets = [
        r for r in jsonl_read(asset_file)
        if args.tag in r.get("tags", []) and not r.get("compressed")
    ]
    count = len(assets)
    if count == 0:
        sys.stderr.write(f"태그 '{args.tag}'에 해당하는 자산이 없습니다\n")
        return 1

    # Type counts
    def type_count(t):
        return sum(1 for a in assets if a.get("type") == t)

    n_failure = type_count("failure")
    n_pattern = type_count("pattern")
    n_guardrail = type_count("guardrail")
    n_decision = type_count("decision")
    n_snippet = type_count("snippet")

    # Trigger candidates (title token frequency)
    word_counts: Counter = Counter()
    for a in assets:
        title = a.get("title", "").lower()
        for word in re.findall(r"[a-z][a-z0-9]{2,}", title):
            word_counts[word] += 1
    top_words = [w for w, _ in word_counts.most_common(5)]
    trigger_candidates = ",".join(top_words) if top_words else ""

    # Directories
    skill_dir = Path(args.output_dir) / args.skill_name
    refs_dir = skill_dir / "references"
    refs_dir.mkdir(parents=True, exist_ok=True)

    # Save source assets
    with open(refs_dir / "source-assets.jsonl", "w", encoding="utf-8") as f:
        for a in assets:
            f.write(compact_json(a) + "\n")

    # Triggers string
    tag = args.tag
    base_triggers = (
        f'"{tag}", "{tag} 패턴", "{tag} 가이드", '
        f'"apply {tag}", "use {tag}"'
    )
    if trigger_candidates:
        extra = ", ".join(f'"{w}"' for w in top_words)
        trigger_str = f"{base_triggers}, {extra}"
    else:
        trigger_str = base_triggers

    now_date = datetime.now().strftime("%Y-%m-%d")

    # SKILL.md frontmatter + header
    skill_md = skill_dir / "SKILL.md"
    with open(skill_md, "w", encoding="utf-8") as f:
        f.write(f"""---
name: {args.skill_name}
version: 0.0.1
description: >
  {tag} 관련 축적 경험 기반 스킬. {count}건 자산 (failure:{n_failure}, pattern:{n_pattern}, guardrail:{n_guardrail}, decision:{n_decision}, snippet:{n_snippet})에서 자동 생성.
  Triggers: {trigger_str}.
---

# {args.skill_name}

> 자동 생성된 스킬 초안 — §1 가이드라인을 LLM이 finalize 필요.
> 원본 자산은 `references/source-assets.jsonl`에 보존됨.

## 1. 가이드라인 (LLM finalize)

> **TODO**: `references/source-assets.jsonl`의 자산을 분석하여 1-3개 가이드라인으로 요약하세요.
> 각 가이드라인은 1-3줄로, "언제 적용 / 무엇을 할 것 / 무엇을 피할 것" 형태로.
> 마치면 이 섹션 헤더의 "(LLM finalize)" 마커를 제거.

## 2. 원본 자산 ({count}건)

""")

        def emit_section(title_str, type_key, n):
            if n == 0:
                return
            f.write(f"### {title_str} ({n})\n\n")
            for a in assets:
                if a.get("type") != type_key:
                    continue
                body_preview = a.get("body", "")[:200]
                ctx = a.get("context") or "(none)"
                line = f"- **{a.get('title')}** — {body_preview}\n"
                line += f"  - context: {ctx}"
                if a.get("level"):
                    line += f"\n  - level: {a['level']}"
                if a.get("confidence"):
                    line += f"\n  - confidence: {a['confidence']}"
                if a.get("stability") is not None:
                    line += f"\n  - stability: {a['stability']}"
                if a.get("resolved") is not None:
                    line += f"\n  - resolved: {a['resolved']}"
                f.write(line + "\n")
            f.write("\n")

        emit_section("Failures", "failure", n_failure)
        emit_section("Patterns", "pattern", n_pattern)
        emit_section("Guardrails", "guardrail", n_guardrail)
        emit_section("Decisions", "decision", n_decision)
        emit_section("Snippets", "snippet", n_snippet)

        f.write(f"""## 3. 메타데이터

- 생성일: {now_date}
- 원본 태그: `{tag}`
- 자산 수: {count} (failure:{n_failure} | pattern:{n_pattern} | guardrail:{n_guardrail} | decision:{n_decision} | snippet:{n_snippet})
- 원본 보존: `references/source-assets.jsonl`
- skillify_version: 0.1.0
""")

    result = {
        "status": "generated",
        "skill_dir": str(skill_dir),
        "asset_count": count,
        "breakdown": {
            "failure": n_failure,
            "pattern": n_pattern,
            "guardrail": n_guardrail,
            "decision": n_decision,
            "snippet": n_snippet,
        },
    }
    print(compact_json(result))
    return 0
