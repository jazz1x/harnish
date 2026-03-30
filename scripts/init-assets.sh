#!/usr/bin/env bash
# init-assets.sh — _base/assets/ 폴더 구조와 index.json을 초기화한다.
#
# Layer: L1 (Storage)
# 의존: common.sh (L1)
# 규칙: L2 이상을 호출하지 않는다.
#
# 사용법:
#   init-assets.sh                          # 기본 경로
#   init-assets.sh --base-dir /path/to/assets
#   init-assets.sh --quiet                  # 출력 없이
#
# 기존 index.json이 있으면 구조만 보강하고 thresholds/version을 최신으로 마이그레이션

set -euo pipefail

CURRENT_VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ASSET_BASE="$(resolve_base_dir)"
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --base-dir) ASSET_BASE="$2"; shift 2;;
        --quiet)    QUIET=true; shift;;
        *) shift;;
    esac
done

log() { $QUIET || echo "$*"; }

# 디렉토리 구조 보장
for dir in patterns failures guardrails snippets decisions .meta .meta/pending .archive .compressed; do
    mkdir -p "$ASSET_BASE/$dir"
done

INDEX_FILE="$ASSET_BASE/.meta/index.json"

if [[ ! -f "$INDEX_FILE" ]]; then
    # 신규 생성
    cat > "$INDEX_FILE" << EOF
{
  "version": "${CURRENT_VERSION}",
  "thresholds": {
    "compression_trigger": 5,
    "skillification_stability": 3,
    "guardrail_consolidation": 3
  },
  "counts": {},
  "tag_index": {}
}
EOF
    log "✓ index.json 생성"
else
    # 기존 파일 마이그레이션: 버전 확인 후 누락 필드 보충
    EXISTING_VERSION=$(jq -r '.version // "0.0.0"' "$INDEX_FILE")

    # thresholds에 누락된 키가 있으면 추가
    UPDATED=$(jq --arg ver "$CURRENT_VERSION" '
        .version = $ver |
        .thresholds.compression_trigger //= 5 |
        .thresholds.skillification_stability //= 3 |
        .thresholds.guardrail_consolidation //= 3 |
        .counts //= {} |
        .tag_index //= {}
    ' "$INDEX_FILE")

    echo "$UPDATED" > "${INDEX_FILE}.tmp" && mv "${INDEX_FILE}.tmp" "$INDEX_FILE"

    if [[ "$EXISTING_VERSION" != "$CURRENT_VERSION" ]]; then
        log "✓ index.json 마이그레이션: ${EXISTING_VERSION} → ${CURRENT_VERSION}"
    fi
fi

log "✓ _base/assets/ 초기화 완료 ($ASSET_BASE)"
