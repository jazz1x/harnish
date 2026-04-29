#!/usr/bin/env bash
# common.sh — L1 Storage: 공용 함수 라이브러리
#
# Layer: L1 (Storage)
# 역할: 디렉토리·인덱스 관리, 환경 해석, 유틸리티 함수
# 규칙: L2 이상의 스크립트를 호출하지 않는다.
#
# v0.1.0: jq 의존 제거 — 모든 JSON 처리는 Python(harnish_py)으로 이전됨.
#          이 파일은 resolve_* 헬퍼와 slugify만 남긴다.
#
# 사용법 (다른 스크립트에서):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/common.sh"

# ═══════════════════════════════════════
# 환경 해석
# ═══════════════════════════════════════

# 자산 루트 경로 해석
# 우선순위: ASSET_BASE_DIR > CWD/.harnish
# 워크트리 격리: CLAUDE_PROJECT_DIR 대신 CWD 기준으로 해석하여
# 워크트리마다 독립된 .harnish/를 갖도록 한다.
resolve_base_dir() {
    if [[ -n "${ASSET_BASE_DIR:-}" ]]; then
        echo "$ASSET_BASE_DIR"
    else
        echo "$(pwd)/.harnish"
    fi
}

# PROGRESS 파일 경로
resolve_progress_file() {
    echo "$(resolve_base_dir)/harnish-current-work.json"
}

# Asset Store 파일 경로 (Tier 1 episodic memory)
resolve_asset_file() {
    echo "$(resolve_base_dir)/harnish-assets.jsonl"
}

# 레거시 RAG 파일 경로 (마이그레이션 감지용; v0.0.4까지는 이 이름이었음)
resolve_legacy_asset_file() {
    echo "$(resolve_base_dir)/harnish-rag.jsonl"
}

# Deprecated alias — 외부 호출자 호환을 위해 유지. 향후 메이저 릴리스에서 제거 예정.
resolve_rag_file() {
    resolve_asset_file
}

# 스킬 디렉토리 (references/ 접근용)
resolve_skill_dir() {
    echo "$(cd "${SCRIPT_DIR:-$(pwd)}/../skills/impl" && pwd)"
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
