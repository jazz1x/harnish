#!/usr/bin/env bash
# detect-asset.sh — Claude Code hook에서 호출. 자산 감지 + pending 관리.
#
# 노이즈 줄이기: 단순 오류, 테스트 실행, 읽기 전용 작업은 무시.
# pending은 /tmp에 저장 (세션 내 임시 데이터, RAG 오염 방지).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
RAG_FILE="$BASE/harnish-rag.jsonl"

# hook은 조용히 실패해야 함
trap 'exit 0' ERR

# .harnish/ 없으면 무시
[[ -d "$BASE" ]] || exit 0

# 세션 해시
SESSION_HASH="${CLAUDE_SESSION_ID:-$(echo "$$" | md5sum | cut -c1-8)}"
PENDING_FILE="/tmp/harnish-pending-${SESSION_HASH}.jsonl"

# pending 파일이 있으면 RAG에 자산 개수 보고
if [[ -f "$PENDING_FILE" ]] && [[ -s "$PENDING_FILE" ]]; then
    PENDING_COUNT=$(wc -l < "$PENDING_FILE" | xargs)
    echo "harnish: ${PENDING_COUNT}건 pending 자산 감지됨"
fi

exit 0
