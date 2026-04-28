#!/usr/bin/env bash
# skillify.sh — JSONL 자산에서 production-grade SKILL.md scaffold 생성
#
# v0.0.5: description에 Triggers 자동 생성, body 구조화 (type별 섹션),
#         references/source-assets.jsonl로 트레이서빌리티 보존.
#         여전히 LLM이 §1 가이드라인 finalize 필요 (autonomous 아님).
#
# 사용법:
#   skillify.sh --tag docker --skill-name docker-patterns [--output-dir skills] [--base-dir .harnish]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
TAG="" SKILL_NAME="" OUTPUT_DIR="skills"

while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)        TAG="$2";        shift 2;;
        --skill-name) SKILL_NAME="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --base-dir)   BASE="$2";       shift 2;;
        *) shift;;
    esac
done

if [[ -z "$TAG" || -z "$SKILL_NAME" ]]; then
    echo "오류: --tag, --skill-name 필수" >&2
    exit 1
fi

ASSET_FILE="$BASE/harnish-assets.jsonl"

if [[ ! -f "$ASSET_FILE" ]]; then
    echo "오류: $ASSET_FILE 없음" >&2
    exit 1
fi

# 해당 태그의 자산 수집
ASSETS=$(jq -c --arg t "$TAG" \
    'select(.tags[] == $t) | select(.compressed != true)' \
    "$ASSET_FILE" 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")
COUNT=$(echo "$ASSETS" | jq 'length')

if [[ "$COUNT" -eq 0 ]]; then
    echo "태그 '$TAG'에 해당하는 자산이 없습니다" >&2
    exit 1
fi

# 타입별 카운트
N_FAILURE=$(echo "$ASSETS"   | jq '[.[] | select(.type == "failure")]   | length')
N_PATTERN=$(echo "$ASSETS"   | jq '[.[] | select(.type == "pattern")]   | length')
N_GUARDRAIL=$(echo "$ASSETS" | jq '[.[] | select(.type == "guardrail")] | length')
N_DECISION=$(echo "$ASSETS"  | jq '[.[] | select(.type == "decision")]  | length')
N_SNIPPET=$(echo "$ASSETS"   | jq '[.[] | select(.type == "snippet")]   | length')

# Triggers 후보 자동 추출 (자산 title의 토큰 빈도 기반)
TRIGGER_CANDIDATES=$(echo "$ASSETS" \
    | jq -r '.[].title' \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c '[:alnum:]\n' ' ' \
    | tr ' ' '\n' \
    | grep -E '^[a-z][a-z0-9]{2,}$' \
    | sort | uniq -c | sort -rn \
    | awk '{print $2}' \
    | head -5 \
    | paste -s -d ',' - || echo "")

# 디렉토리 생성
SKILL_DIR="${OUTPUT_DIR}/${SKILL_NAME}"
REFS_DIR="${SKILL_DIR}/references"
mkdir -p "$REFS_DIR"

# references/source-assets.jsonl — 트레이서빌리티
echo "$ASSETS" | jq -c '.[]' > "${REFS_DIR}/source-assets.jsonl"

# Triggers 문자열 (description용)
BASE_TRIGGERS="\"${TAG}\", \"${TAG} 패턴\", \"${TAG} 가이드\", \"apply ${TAG}\", \"use ${TAG}\""
if [[ -n "$TRIGGER_CANDIDATES" ]]; then
    EXTRA=$(echo "$TRIGGER_CANDIDATES" | tr ',' '\n' | sed 's/^/, "/' | sed 's/$/"/' | tr -d '\n')
    TRIGGER_STR="${BASE_TRIGGERS}${EXTRA}"
else
    TRIGGER_STR="${BASE_TRIGGERS}"
fi

NOW_DATE=$(date +%Y-%m-%d)

# SKILL.md frontmatter + 헤더
cat > "${SKILL_DIR}/SKILL.md" << EOF
---
name: ${SKILL_NAME}
version: 0.0.1
description: >
  ${TAG} 관련 축적 경험 기반 스킬. ${COUNT}건 자산 (failure:${N_FAILURE}, pattern:${N_PATTERN}, guardrail:${N_GUARDRAIL}, decision:${N_DECISION}, snippet:${N_SNIPPET})에서 자동 생성.
  Triggers: ${TRIGGER_STR}.
---

# ${SKILL_NAME}

> 자동 생성된 스킬 초안 — §1 가이드라인을 LLM이 finalize 필요.
> 원본 자산은 \`references/source-assets.jsonl\`에 보존됨.

## 1. 가이드라인 (LLM finalize)

> **TODO**: \`references/source-assets.jsonl\`의 자산을 분석하여 1-3개 가이드라인으로 요약하세요.
> 각 가이드라인은 1-3줄로, "언제 적용 / 무엇을 할 것 / 무엇을 피할 것" 형태로.
> 마치면 이 섹션 헤더의 "(LLM finalize)" 마커를 제거.

## 2. 원본 자산 (${COUNT}건)

EOF

# Type별 섹션 (자산 0건 type은 생략)
emit_section() {
    local section_title="$1"
    local type_key="$2"
    local count="$3"
    [[ "$count" -eq 0 ]] && return
    {
        echo "### ${section_title} (${count})"
        echo ""
        echo "$ASSETS" | jq -r --arg t "$type_key" '
            .[] | select(.type == $t) |
            "- **\(.title)** — \(.body[0:200])\n  - context: \(.context // "(none)")" +
            (if .level       then "\n  - level: \(.level)"             else "" end) +
            (if .confidence  then "\n  - confidence: \(.confidence)"   else "" end) +
            (if .stability   then "\n  - stability: \(.stability)"     else "" end) +
            (if .resolved != null then "\n  - resolved: \(.resolved)" else "" end)
        '
        echo ""
    } >> "${SKILL_DIR}/SKILL.md"
}

emit_section "Failures"   "failure"   "$N_FAILURE"
emit_section "Patterns"   "pattern"   "$N_PATTERN"
emit_section "Guardrails" "guardrail" "$N_GUARDRAIL"
emit_section "Decisions"  "decision"  "$N_DECISION"
emit_section "Snippets"   "snippet"   "$N_SNIPPET"

# 메타데이터
cat >> "${SKILL_DIR}/SKILL.md" << EOF
## 3. 메타데이터

- 생성일: ${NOW_DATE}
- 원본 태그: \`${TAG}\`
- 자산 수: ${COUNT} (failure:${N_FAILURE} | pattern:${N_PATTERN} | guardrail:${N_GUARDRAIL} | decision:${N_DECISION} | snippet:${N_SNIPPET})
- 원본 보존: \`references/source-assets.jsonl\`
- skillify_version: 0.0.5
EOF

# 결과 출력
jq -n -c \
    --arg status "generated" \
    --arg dir "$SKILL_DIR" \
    --argjson count "$COUNT" \
    --argjson n_failure "$N_FAILURE" \
    --argjson n_pattern "$N_PATTERN" \
    --argjson n_guardrail "$N_GUARDRAIL" \
    --argjson n_decision "$N_DECISION" \
    --argjson n_snippet "$N_SNIPPET" \
    '{status:$status, skill_dir:$dir, asset_count:$count,
      breakdown:{failure:$n_failure, pattern:$n_pattern, guardrail:$n_guardrail, decision:$n_decision, snippet:$n_snippet}}'
