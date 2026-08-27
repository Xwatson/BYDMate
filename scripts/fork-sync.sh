#!/usr/bin/env bash
# fork-sync.sh [work-branch]
#
# Fork 自有脚本（上游没有这个文件，不会冲突）。
#
# 把 upstream/main 同步进这个 fork：
#   1. fetch upstream（含 tag）
#   2. 列出上游的新提交
#   3. 把 main fast-forward 到 upstream/main（main 是纯镜像，绝不在上面提交）
#   4. 把 main 合并进工作分支（默认 mine）
#
# 不会自动 push，也不会自动跑测试 —— 合并结果由你自己确认后再推。
#
#   ./scripts/fork-sync.sh          # 工作分支用 mine
#   ./scripts/fork-sync.sh main     # 单分支模式：直接把上游合进 main
set -euo pipefail

WORK="${1:-mine}"
MIRROR="main"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die() { printf '\n\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

git remote get-url upstream >/dev/null 2>&1 \
  || die "没有 upstream 远端。先执行： git remote add upstream https://github.com/AndyShaman/BYDMate.git"

# 未跟踪文件不影响合并，只看已跟踪文件的改动
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  die "有未提交的改动。先 commit 或 stash，再同步。"
fi

say "① 拉取上游"
git fetch upstream --tags --prune

NEW=$(git rev-list --count "$MIRROR..upstream/main")
if [ "$NEW" -eq 0 ]; then
  say "上游没有新提交，$MIRROR 已是最新。"
else
  say "② 上游有 $NEW 个新提交"
  git log --oneline --no-merges "$MIRROR..upstream/main" | head -40
  [ "$NEW" -gt 40 ] && echo "  ... 共 $NEW 个，只列前 40 个"

  # 顺便提示上游是否发了新版本
  LATEST_TAG=$(git tag -l 'v*' --sort=-v:refname | head -1 || true)
  [ -n "$LATEST_TAG" ] && echo "" && echo "上游最新 tag: $LATEST_TAG"
fi

if [ "$WORK" = "$MIRROR" ]; then
  # 单分支模式：直接把上游合进 main
  say "③ 把 upstream/main 合并进 $MIRROR"
  git checkout "$MIRROR"
  git merge upstream/main || die "合并冲突 —— 解完后跑 git merge --continue；想放弃跑 git merge --abort"
else
  say "③ 把 $MIRROR 快进到 upstream/main"
  git checkout "$MIRROR"
  git merge --ff-only upstream/main \
    || die "$MIRROR 无法 fast-forward —— 说明你在 $MIRROR 上提交过东西。把那些提交 cherry-pick 到 $WORK，再 git reset --hard upstream/main"

  git rev-parse --verify "$WORK" >/dev/null 2>&1 \
    || die "分支 $WORK 不存在。先执行： git checkout -b $WORK $MIRROR"

  say "④ 把 $MIRROR 合并进 $WORK"
  git checkout "$WORK"
  git merge "$MIRROR" || die "合并冲突 —— 解完后跑 git merge --continue；想放弃跑 git merge --abort
提示：在 $WORK 上合并时  --ours = 你的，--theirs = 上游的"
fi

say "✓ 同步完成，当前在 $(git rev-parse --abbrev-ref HEAD)"
cat <<'NEXT'

接下来自己确认：

  git diff --stat upstream/main...HEAD    # 我的改动还在吗
  ./gradlew :app:testDebugUnitTest        # 跑测试
  ./gradlew :app:lintDebug                # 跑 lint
  ./gradlew assembleDebug                 # 能出包

都通过后再推：

  git push origin main
  git push origin HEAD
NEXT
