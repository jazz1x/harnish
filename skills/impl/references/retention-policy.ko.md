# 자산 보존 정책

> `scripts/purge-assets.sh`에서 참조하는 TTL + purge 규칙.
> 정책 파일 파서가 나올 때까지는 hardcoded default 사용; 이 파일은 의도를 기록.

## 기본값

- `default_ttl_days`: 180
- `safety_window_hours`: 24 (안전 창 — 자산 생성 후 이 기간 이내는 purge 제외)

## 유형별 규칙

| 유형 | ttl_days | min_access_count | 근거 |
|---|---|---|---|
| decision | 365 | 1 | 결정은 1년 보존. 한 번도 조회 안 됐으면 후보. |
| failure | 90 | — | 실패 사례는 3개월. 최근 실수 학습 가치. |
| snippet | 180 | — | 코드 스니펫 6개월. |
| pattern | 영구 (`-1`) | — | 패턴은 영구 보존. |
| guardrail | 영구 (`-1`) | — | 가드레일은 영구 보존. |

## 플로우

1. `purge-assets.sh` (기본 `--dry-run`) 호출
2. 각 레코드에 대해:
   - `ttl_days < 0` → 제외
   - `(now - created_at) < safety_window` → 제외
   - `(now - created_at) <= ttl_days * 86400` → 제외 (TTL 미도래)
   - `min_access_count` 있고 `access_count < min_access_count` → 후보
   - 그 외 → 후보
3. 후보들을 `harnish-rag-archive.jsonl`에 append
4. 원본에서 후보 제거
