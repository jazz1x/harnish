#!/usr/bin/env bash
# query-assets.sh — L2 Operation: 자산 검색 API
#
# Layer: L2 (Operation)
# 역할: 태그/유형 기반으로 자산을 검색하고 결과를 반환한다.
# 의존: common.sh (L1)
#
# 사용법:
#   bash query-assets.sh --tags "docker,build" [--types "guardrail,pattern"] [--format json|text|inject] [--limit 5] [--base-dir _base/assets]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ═══════════════════════════════════════
# 인수 파싱
# ═══════════════════════════════════════
TAGS=""
TYPES=""
FORMAT="json"
LIMIT=5
BASE_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tags)     TAGS="$2"; shift 2 ;;
        --types)    TYPES="$2"; shift 2 ;;
        --format)   FORMAT="$2"; shift 2 ;;
        --limit)    LIMIT="$2"; shift 2 ;;
        --base-dir) BASE_DIR="$2"; shift 2 ;;
        *) echo "알 수 없는 옵션: $1" >&2; exit 1 ;;
    esac
done

# 필수 인수 검증
if [[ -z "$TAGS" ]]; then
    echo "오류: --tags 필수" >&2
    echo "사용법: query-assets.sh --tags \"docker,build\" [--types \"guardrail,pattern\"] [--format json|text|inject] [--limit 5]" >&2
    exit 1
fi

# base dir 해석
if [[ -z "$BASE_DIR" ]]; then
    BASE_DIR="$(resolve_base_dir)"
fi

INDEX_FILE="${BASE_DIR}/.meta/index.json"

# 인덱스 파일 존재 확인
if [[ ! -f "$INDEX_FILE" ]]; then
    echo "오류: index.json 없음: $INDEX_FILE" >&2
    exit 1
fi

# ═══════════════════════════════════════
# 태그/유형 배열 파싱
# ═══════════════════════════════════════
IFS=',' read -ra QUERY_TAGS <<< "$TAGS"
# 태그 trim
for i in "${!QUERY_TAGS[@]}"; do
    QUERY_TAGS[$i]=$(echo "${QUERY_TAGS[$i]}" | xargs)
done

QUERY_TYPES=()
if [[ -n "$TYPES" ]]; then
    IFS=',' read -ra QUERY_TYPES <<< "$TYPES"
    for i in "${!QUERY_TYPES[@]}"; do
        QUERY_TYPES[$i]=$(echo "${QUERY_TYPES[$i]}" | xargs)
    done
fi

# ═══════════════════════════════════════
# 검색 로직
# ═══════════════════════════════════════
# 후보 파일 수집 — 디렉토리 직접 스캔
# (index.json의 tag_index는 카운트 정수 — 파일 배열 아님. 직접 스캔이 정확함)
# ═══════════════════════════════════════

# jq가 없으면 종료
if ! command -v jq &>/dev/null; then
    echo "오류: jq가 필요합니다 (apt install jq)" >&2
    exit 1
fi

TAG_QUERY=$(printf '"%s",' "${QUERY_TAGS[@]}")
TAG_QUERY="[${TAG_QUERY%,}]"

# 유형 → 디렉토리 이름 변환 (failure→failures 등)
type_to_dir() {
    case "$1" in
        failure)   echo "failures" ;;
        pattern)   echo "patterns" ;;
        guardrail) echo "guardrails" ;;
        snippet)   echo "snippets" ;;
        decision)  echo "decisions" ;;
        *)         echo "${1}s" ;;
    esac
}

# ① 후보 파일 목록 수집 (OR 조건: 지정된 타입 디렉토리만, 미지정 시 전체)
MATCHED_FILES=""
if [[ ${#QUERY_TYPES[@]} -gt 0 ]]; then
    for qtype in "${QUERY_TYPES[@]}"; do
        dir="${BASE_DIR}/$(type_to_dir "$qtype")"
        if [[ -d "$dir" ]]; then
            while IFS= read -r f; do
                MATCHED_FILES+="${f#${BASE_DIR}/}"$'\n'
            done < <(find "$dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
        fi
    done
else
    while IFS= read -r f; do
        MATCHED_FILES+="${f#${BASE_DIR}/}"$'\n'
    done < <(find "$BASE_DIR" -maxdepth 2 -name "*.md" -type f -not -path "*/.meta/*" 2>/dev/null || true)
fi
MATCHED_FILES=$(echo "$MATCHED_FILES" | sort -u | grep -v '^$' || true)

if [[ -z "$MATCHED_FILES" ]]; then
    # 결과 없음
    case "$FORMAT" in
        json)
            echo '{"query":{"tags":'"$TAG_QUERY"',"types":[],"limit":'"$LIMIT"'},"results":[],"count":0}'
            ;;
        text)
            echo "(검색 결과 없음)"
            ;;
        inject)
            echo "### 관련 자산 (asset-recorder)"
            echo ""
            echo "(관련 자산 없음)"
            ;;
    esac
    exit 0
fi

# ② 각 파일의 frontmatter를 파싱하여 상세 정보를 추출하고 필터·정렬
# 결과를 임시 JSON 배열로 구성
RESULTS="[]"

while IFS= read -r rel_path; do
    [[ -z "$rel_path" ]] && continue

    # 파일 경로 구성
    full_path="${BASE_DIR}/${rel_path}"
    if [[ ! -f "$full_path" ]]; then
        continue
    fi

    # frontmatter 파싱
    fm=$(parse_frontmatter "$full_path")
    asset_type=$(get_field "$fm" "type")
    asset_title=$(get_field "$fm" "title")
    asset_date=$(get_field "$fm" "date")
    asset_tags_raw=$(get_tags "$fm")
    asset_stability=$(get_field "$fm" "stability")
    asset_scope=$(get_field "$fm" "scope")
    asset_level=$(get_field "$fm" "level")

    # summary_line: frontmatter의 summary 또는 body 첫 줄
    summary=$(get_field "$fm" "summary")
    if [[ -z "$summary" ]]; then
        summary=$(parse_body "$full_path" | head -1 | sed 's/^#* *//' | sed 's/\\n/ /g')
    fi

    # ② types 필터
    if [[ ${#QUERY_TYPES[@]} -gt 0 ]]; then
        type_match=false
        for qt in "${QUERY_TYPES[@]}"; do
            if [[ "$asset_type" == "$qt" ]]; then
                type_match=true
                break
            fi
        done
        if [[ "$type_match" == "false" ]]; then
            continue
        fi
    fi

    # ⑤ relevance 점수 계산
    # 매칭 태그 수 × 2 + stability 보너스 + 최신도 보너스
    match_count=0
    for qt in "${QUERY_TAGS[@]}"; do
        if echo "$asset_tags_raw" | grep -qiw "$qt" 2>/dev/null; then
            ((match_count++)) || true
        fi
    done

    score=$((match_count * 2))
    if [[ -n "$asset_stability" && "$asset_stability" =~ ^[0-9]+$ ]]; then
        score=$((score + asset_stability))
    fi

    # 최신도 보너스: 최근 7일 이내면 +1
    if [[ -n "$asset_date" ]]; then
        now_epoch=$(date -u +%s)
        asset_epoch=$(date -u -d "$asset_date" +%s 2>/dev/null || echo "0")
        if [[ "$asset_epoch" -gt 0 ]]; then
            diff_days=$(( (now_epoch - asset_epoch) / 86400 ))
            if [[ $diff_days -le 7 ]]; then
                score=$((score + 1))
            fi
        fi
    fi

    # JSON 항목 구성
    item=$(jq -n \
        --arg file "$rel_path" \
        --arg type "$asset_type" \
        --arg title "$asset_title" \
        --arg date "$asset_date" \
        --arg stability "$asset_stability" \
        --arg level "$asset_level" \
        --arg summary "$summary" \
        --arg scope "${asset_scope:-generic}" \
        --argjson score "$score" \
        '{
            file: $file,
            type: $type,
            title: $title,
            date: $date,
            stability: (if $stability == "" then null else ($stability | tonumber) end),
            level: (if $level == "" then null else $level end),
            summary_line: $summary,
            scope: $scope,
            _score: $score
        }')

    RESULTS=$(echo "$RESULTS" | jq --argjson item "$item" '. + [$item]')

done <<< "$MATCHED_FILES"

# ⑤ 정렬 (score 내림차순) + ⑥ limit 적용
RESULTS=$(echo "$RESULTS" | jq --argjson limit "$LIMIT" '
    sort_by(-._score) | .[:$limit] | map(del(._score))
')

RESULT_COUNT=$(echo "$RESULTS" | jq 'length')

# ═══════════════════════════════════════
# 출력 포맷팅
# ═══════════════════════════════════════
case "$FORMAT" in
    json)
        TYPES_JSON="[]"
        if [[ ${#QUERY_TYPES[@]} -gt 0 ]]; then
            TYPE_QUERY=$(printf '"%s",' "${QUERY_TYPES[@]}")
            TYPES_JSON="[${TYPE_QUERY%,}]"
        fi

        jq -n \
            --argjson tags "$TAG_QUERY" \
            --argjson types "$TYPES_JSON" \
            --argjson limit "$LIMIT" \
            --argjson results "$RESULTS" \
            --argjson count "$RESULT_COUNT" \
            '{
                query: { tags: $tags, types: $types, limit: $limit },
                results: $results,
                count: $count
            }'
        ;;

    text)
        echo "$RESULTS" | jq -r '.[] |
            "[\(.type)] \(.title) (\(.date)) — \(.summary_line)" +
            "\n  tags: \(.file | split("/") | .[0]) | scope: \(.scope)" +
            (if .stability then " | stability: \(.stability)" else "" end) +
            (if .level then " | level: \(.level)" else "" end) +
            "\n"
        '
        ;;

    inject)
        echo "### 관련 자산 (asset-recorder)"
        echo ""

        # 유형별로 그룹화
        for asset_type in guardrail pattern failure snippet decision; do
            type_results=$(echo "$RESULTS" | jq "[.[] | select(.type == \"$asset_type\")]")
            type_count=$(echo "$type_results" | jq 'length')

            if [[ "$type_count" -gt 0 ]]; then
                # 유형명 한글 매핑
                case "$asset_type" in
                    guardrail) label="가드레일" ;;
                    pattern)   label="패턴" ;;
                    failure)   label="실패" ;;
                    snippet)   label="스니펫" ;;
                    decision)  label="결정" ;;
                esac

                echo "**${label} (${type_count}건)**"
                echo "$type_results" | jq -r '.[] |
                    # title 없으면 파일명 슬러그 폴백
                    (.title | if . and . != "" then . else "untitled" end) as $t |
                    # summary_line 80자 트런케이션
                    (.summary_line | if length > 80 then .[0:80] + "…" else . end) as $s |
                    "- [\($t)] \($s)" +
                    (if .level then " (\(.level))" else "" end) +
                    (if .stability then " (stability: \(.stability))" else "" end)
                '
                echo ""
            fi
        done
        ;;

    *)
        echo "오류: 알 수 없는 포맷 '$FORMAT'. json|text|inject 사용" >&2
        exit 1
        ;;
esac

asset_log "$BASE_DIR" "query: tags=$TAGS types=$TYPES format=$FORMAT results=$RESULT_COUNT"
