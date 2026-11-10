#!/usr/bin/env bash
# fork-sync.sh [work-branch]
#
# Fork 自有脚本（上游没有这个文件，不会冲突）。
#
# 把 upstream/main 同步进这个 fork：
#   0. 补齐本地配置：upstream 远端、禁推、rerere、zdiff3、本地 main 分支
#      （这些只存在 .git/config 里，重新 clone 之后都会丢）
#   1. fetch upstream（含 tag）
#   2. 列出上游的新提交
#   3. 把 main fast-forward 到 upstream/main（main 是纯镜像，绝不在上面提交）
#      上游改写过历史（force-push）时没法快进：脚本会识别出来，给出处理步骤后停下
#   4. 把 main 合并进工作分支（默认 mine）
#
# 不会自动 push，也不会自动跑测试 —— 合并结果由你自己确认后再推。
#
#   ./scripts/fork-sync.sh          # 工作分支用 mine
#   ./scripts/fork-sync.sh main     # 单分支模式：直接把上游合进 main
set -euo pipefail

WORK="${1:-mine}"
MIRROR="main"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/AndyShaman/BYDMate.git}"
NO_PUSH="DISABLED_no_push_to_upstream"

say()     { printf '\n\033[1m%s\033[0m\n' "$*"; }
note()    { printf '  %s\n' "$*"; }
die()     { printf '\n\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }
has_ref() { git rev-parse --verify --quiet "$1" >/dev/null; }

# 未跟踪文件不影响合并，只看已跟踪文件的改动
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  die "有未提交的改动。先 commit 或 stash，再同步。"
fi

say "⓪ 检查本地配置"
# 缺什么补什么，已经有的（包括你自己改过的）一律不动
if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream "$UPSTREAM_URL"
  note "已添加 upstream 远端：$UPSTREAM_URL"
fi
if ! git config --get remote.upstream.pushurl >/dev/null; then
  git remote set-url --push upstream "$NO_PUSH"
  note "已禁止向 upstream 推送"
fi
if ! git config --get rerere.enabled >/dev/null; then
  git config rerere.enabled true
  note "已开启 rerere（记住冲突解法）"
fi
if ! git config --get merge.conflictstyle >/dev/null; then
  git config merge.conflictstyle zdiff3
  note "冲突标记已改为 zdiff3（同时显示共同祖先）"
fi

say "① 拉取上游"
git fetch upstream --tags --prune

if ! has_ref "refs/heads/$MIRROR"; then
  # 刚 clone 下来只有 origin/main。两个远端都有 main 时，git checkout main 会因为歧义直接失败，
  # 所以这里显式建出来
  if has_ref "refs/remotes/origin/$MIRROR"; then
    git branch --quiet --track "$MIRROR" "origin/$MIRROR"
    note "本地没有 $MIRROR 分支，已从 origin/$MIRROR 建立"
  else
    git branch --quiet --no-track "$MIRROR" upstream/main
    note "本地没有 $MIRROR 分支，已从 upstream/main 建立"
  fi
fi
has_ref "refs/heads/$WORK" || die "分支 $WORK 不存在。先执行： git checkout -b $WORK $MIRROR"

NEW=$(git rev-list --count "$MIRROR..upstream/main")
if [ "$NEW" -eq 0 ]; then
  say "上游没有新提交，$MIRROR 已是最新。"
else
  say "② 上游有 $NEW 个新提交（只列最近 40 个，不含合并提交）"
  # 用 -n 截断，不要 | head：输出超过管道缓冲区时 head 先退出，git 收到 SIGPIPE，
  # 在 pipefail 下整个脚本会以 141 无声退出
  git log --oneline --no-merges -n 40 "$MIRROR..upstream/main"
  LATEST_TAG=$(git for-each-ref --count=1 --sort=-v:refname --format='%(refname:short)' 'refs/tags/v*')
  if [ -n "$LATEST_TAG" ]; then
    printf '\n上游最新 tag: %s\n' "$LATEST_TAG"
  fi
fi

# main 不是 upstream/main 的祖先时，要么上游改写了历史，要么有人在 main 上提交过。
# 改写历史（filter-repo / rebase）会保留作者、作者时间和标题，只换哈希，据此区分两种情况。
if ! git merge-base --is-ancestor "$MIRROR" upstream/main; then
  OLD=$(git rev-parse --short "$MIRROR")
  EXTRA=$(git rev-list --count "$MIRROR" --not upstream/main)
  TWINS=$(( $(LC_ALL=C comm -12 \
    <(git log --format='%at %ae %s' "$MIRROR" --not upstream/main | LC_ALL=C sort -u) \
    <(git log --format='%at %ae %s' upstream/main | LC_ALL=C sort -u) | wc -l) ))

  step() { printf '  %-54s # %s\n' "$1" "$2"; }
  REWRITE_HELP="照下面做（说明见 docs/FORK-WORKFLOW.zh.md 第 7 节）：

$(step "git branch backup/$WORK-before-rewrite $WORK" "先留备份")
$(step "git checkout $MIRROR && git reset --hard upstream/main" "镜像直接对齐上游")
$(step "git rebase --onto upstream/main $OLD $WORK" "只把你自己的提交挪过去")
$(step "git diff --stat $OLD backup/$WORK-before-rewrite" "改写前你的改动")
$(step "git diff --stat upstream/main $WORK" "改写后你的改动，应和上一条一致")
$(step "git push --force-with-lease origin $MIRROR $WORK" "两个分支都要强推")"

  if [ "$WORK" = "$MIRROR" ]; then
    # 单分支模式下 main 上本来就有你自己的提交，只在出现"孪生提交"时才拦
    if [ "$TWINS" -gt 0 ]; then
      die "上游改写了历史（force-push）：$MIRROR 里有 $TWINS 个提交在上游有哈希不同的新版本。
直接合并会让这些提交出现两份，还会冒出大量假冲突。处理方法见 docs/FORK-WORKFLOW.zh.md 第 7 节。"
    fi
  elif [ "$TWINS" -eq "$EXTRA" ]; then
    die "上游改写了历史（force-push）：$MIRROR 上有 $EXTRA 个提交不在 upstream/main 里，
但每一个都能在上游找到作者、时间、标题都相同的新版本，只是哈希变了。
$MIRROR 是纯镜像，这时既没法快进，也不要直接合并（每个提交会出现两份，还会冒出几百个假冲突）。
$REWRITE_HELP"
  elif [ "$TWINS" -eq 0 ]; then
    die "$MIRROR 无法 fast-forward：上面有 $EXTRA 个上游没有的提交，说明有人直接在 $MIRROR 上提交过。

  git log --oneline $MIRROR --not upstream/main     # 看是哪些提交

把它们 cherry-pick 到 $WORK，再执行 git checkout $MIRROR && git reset --hard upstream/main"
  else
    die "$MIRROR 无法 fast-forward，两种情况同时出现了：
  - $((EXTRA - TWINS)) 个提交上游没有：有人直接在 $MIRROR 上提交过，先把它们 cherry-pick 到 $WORK
  - $TWINS 个提交在上游有哈希不同的新版本：上游改写了历史

  git log --oneline $MIRROR --not upstream/main     # 看是哪些提交

处理完第一种之后，$REWRITE_HELP"
  fi
fi

if [ "$WORK" = "$MIRROR" ]; then
  # 单分支模式：直接把上游合进 main
  say "③ 把 upstream/main 合并进 $MIRROR"
  git checkout "$MIRROR"
  git merge upstream/main || die "合并冲突 —— 解完后跑 git merge --continue；想放弃跑 git merge --abort"
else
  say "③ 把 $MIRROR 快进到 upstream/main"
  git checkout "$MIRROR"
  git merge --ff-only upstream/main

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
  ./gradlew :app:lintDebug :app:detekt    # lint + detekt（上游 CI 跑的就是这两项）
  ./gradlew assembleDebug                 # 能出包

都通过后再推：

  git push origin main
  git push origin HEAD
NEXT
