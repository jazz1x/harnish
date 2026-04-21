# Asset Retention Policy

> TTL + purge rules referenced by `scripts/purge-assets.sh`.
> hardcoded defaults used until policy file parser lands; this file documents the intent.

## Defaults

- `default_ttl_days`: 180
- `safety_window_hours`: 24 (자산 생성 후 이 기간 이내는 purge 제외)

## Per-Type Rules

| Type | ttl_days | min_access_count | Rationale |
|---|---|---|---|
| decision | 365 | 1 | 결정은 1년 보존. 한 번도 조회 안 됐으면 candidate. |
| failure | 90 | — | 실패 사례는 3개월. 최근 실수 학습 가치. |
| snippet | 180 | — | 코드 스니펫 6개월. |
| pattern | never (`-1`) | — | 패턴은 영구 보존. |
| guardrail | never (`-1`) | — | 가드레일은 영구 보존. |

## Flow

1. `purge-assets.sh` (기본 `--dry-run`) 호출
2. 각 레코드에 대해:
   - `ttl_days < 0` → 제외
   - `(now - created_at) < safety_window` → 제외
   - `(now - created_at) <= ttl_days * 86400` → 제외 (TTL 미도래)
   - `min_access_count` 있고 `access_count < min_access_count` → candidate
   - 그 외 → candidate
3. candidates를 `harnish-rag-archive.jsonl`에 append
4. 원본에서 candidates 제거
