#!/usr/bin/env bash
# common.sh — L1 Storage: 공용 함수 라이브러리
#
# Layer: L1 (Storage)
# 역할: 디렉토리·인덱스 관리, 환경 해석, 유틸리티 함수
# 규칙: L2 이상의 스크립트를 호출하지 않는다.
#
# 사용법 (다른 스크립트에서):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/common.sh"

# ═══════════════════════════════════════
# 의존성 체크
# ═══════════════════════════════════════
require_cmd() {
    local cmd="$1" install_hint="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        echo "오류: '$cmd'이(가) 설치되어 있지 않습니다.${install_hint:+ $install_hint}" >&2
        exit 1
    fi
}

require_cmd jq "brew install jq"

# ═══════════════════════════════════════
# 환경 해석
# ═══════════════════════════════════════
# 이 파일이 source된 스크립트의 SCRIPT_DIR을 기준으로 한다.
# SCRIPT_DIR은 source하기 전에 설정되어야 한다.

# 자산 루트 경로 해석
# 우선순위: ASSET_BASE_DIR > CLAUDE_PROJECT_DIR/.harnish > CWD/.harnish
resolve_base_dir() {
    if [[ -n "${ASSET_BASE_DIR:-}" ]]; then
        echo "$ASSET_BASE_DIR"
    elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
        echo "${CLAUDE_PROJECT_DIR}/.harnish"
    else
        echo "$(pwd)/.harnish"
    fi
}

# PROGRESS 파일 경로
resolve_progress_file() {
    echo "$(resolve_base_dir)/harnish-current-work.json"
}

# RAG 자산 파일 경로
resolve_rag_file() {
    echo "$(resolve_base_dir)/harnish-rag.jsonl"
}

# 스킬 디렉토리 (references/ 접근용)
resolve_skill_dir() {
    echo "$(cd "${SCRIPT_DIR:-$(pwd)}/../skills/harnish" && pwd)"
}

# sections.json 경로
resolve_sections_file() {
    echo "$(resolve_skill_dir)/references/sections.json"
}

# ═══════════════════════════════════════
# 슬러그 생성 — 비ASCII 안전
# ═══════════════════════════════════════
# 1차: ASCII 변환 → 유효한 slug면 사용
# 2차: 비ASCII(한국어 등)면 md5 해시 앞 12자
slugify() {
    local input="$1"
    local ascii_slug
    ascii_slug=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-60)
    if [[ -n "$ascii_slug" && "$ascii_slug" != "-" ]]; then
        echo "$ascii_slug"
    else
        local hash
        hash=$(echo -n "$input" | md5sum | cut -c1-12)
        echo "$hash"
    fi
}

