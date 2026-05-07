#!/usr/bin/env bats

load "setup.bash"

@test "impl SKILL.md declares mid-loop prohibition" {
  grep -q "Prohibited Mid-Loop" "$REPO_ROOT/skills/impl/SKILL.md"
  grep -q "Context fatigue is not a stop condition" "$REPO_ROOT/skills/impl/SKILL.md"
  grep -q "Mid-loop interruption outside" "$REPO_ROOT/skills/impl/SKILL.md"
}

@test "impl SKILL.ko.md mirrors mid-loop prohibition" {
  grep -q "루프 중단 금지" "$REPO_ROOT/skills/impl/SKILL.ko.md"
  grep -q "컨텍스트 피로는 중단 사유가 아닙니다" "$REPO_ROOT/skills/impl/SKILL.ko.md"
  grep -q "외의 mid-loop 중단 금지" "$REPO_ROOT/skills/impl/SKILL.ko.md"
}

@test "impl SKILL.md references retention-policy as out-of-band ops" {
  [ "$(grep -c "retention-policy" "$REPO_ROOT/skills/impl/SKILL.md")" -ge 2 ]
  grep -q "out-of-band" "$REPO_ROOT/skills/impl/SKILL.md"
  grep -q "asset retention policy" "$REPO_ROOT/skills/impl/SKILL.md"
}

@test "impl SKILL.ko.md mirrors retention-policy out-of-band framing" {
  [ "$(grep -c "retention-policy" "$REPO_ROOT/skills/impl/SKILL.ko.md")" -ge 2 ]
  grep -q "out-of-band" "$REPO_ROOT/skills/impl/SKILL.ko.md"
  grep -q "자산 보존 정책" "$REPO_ROOT/skills/impl/SKILL.ko.md"
}
