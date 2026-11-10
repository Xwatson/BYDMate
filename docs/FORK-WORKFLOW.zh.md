# BYDMate Fork 维护手册

> 目标：**在自己的 fork 上长期改代码，同时持续吃到上游更新，不向上游提 PR。**
> 上游 `AndyShaman/BYDMate` 更新极快（2026-03 至 11 月共 1314 次提交、151 个版本 tag，
> 9 月单月 367 次），**还改写过一次历史**（见第 7 节）。
> 所以这套流程的重点不是"怎么合并"，而是**怎么让冲突少到可以忽略**。
>
> 最近一次同步：2026-11-10，从 v3.13.1 同步到 **v4.3.1**（上游改写历史后的首次同步）。

---

## 0. 本地配置

下面这些配置**只存在本地 `.git/config` 里，不会随仓库走**，换台机器或重新 clone 后都会丢。
`scripts/fork-sync.sh` 每次运行都会检查，缺什么补什么（已有的配置不动），所以一般不用手动执行：

```bash
git remote add upstream https://github.com/AndyShaman/BYDMate.git
git remote set-url --push upstream DISABLED_no_push_to_upstream   # 防止手滑推到上游
git config rerere.enabled true          # 记住冲突解法，下次同样冲突自动套用
git config merge.conflictstyle zdiff3   # 冲突标记里同时显示共同祖先，好判断谁改了什么
git fetch upstream --tags
git branch --track main origin/main     # 新 clone 只有 mine；两个远端都有 main 时 git checkout main 会报歧义
```

当前远端：

| 远端 | 地址 | 用途 |
|---|---|---|
| `origin` | `git@github.com:Xwatson/BYDMate.git` | 你的 fork，读写 |
| `upstream` | `https://github.com/AndyShaman/BYDMate.git` | 上游，**只读**（push 已禁用） |

`rerere` 这个配置在本项目里价值很高：像 `SettingsScreen.kt`、`strings.xml` 这种文件会反复在同一位置冲突，
解决过一次之后 Git 会自动复用你的解法。

---

## 1. 分支模型（推荐）

```
upstream/main  ──●──●──●──●──●──●──●──●──▶   上游，你只读
                  ╲              ╲
origin/main    ────●──────────────●─────▶   纯镜像，永远 fast-forward，你不在这写代码
                    ╲              ╲
origin/mine    ──────●──[你的提交]──●──▶     你的真正主干，改代码 / 打包都在这
```

**规则只有两条：**

1. `main` 是上游的镜像，**只用 `--ff-only` 更新，永远不在上面提交**。
2. 所有自己的改动都在 `mine`（名字随意，下文统一用 `mine`）。

这样带来的好处很实在：

- `git diff upstream/main...mine` 一条命令看清"我到底改了什么"，任何时候都不会算错。
- 冲突只在 `mine` 上解决一次，`main` 永远不会冲突。
- 哪天上游自己实现了你的某个魔改，`git revert` 掉你那个提交就行，边界清晰。
- 真搞砸了，`git reset --hard main` 就回到纯上游状态重来。

### 首次建分支

```bash
git checkout -b mine main
git push -u origin mine
```

然后到 GitHub → Settings → General → Default branch，把默认分支改成 **`mine`**。
（这样你在网页上看到的、别人 clone 到的默认就是你的版本。）

> **不想搞两个分支？** 也可以直接在 `main` 上干活，每次 `git merge upstream/main`。
> 简单一点，代价是 `main` 不再是镜像，"我改了什么"要靠 `git log upstream/main..main --no-merges` 去数。
> 本文其余部分对两种方式都适用，只是把 `mine` 换成 `main`。

---

## 2. 日常流程

### 2.1 写自己的代码

```bash
git checkout mine
# ...改代码...
./gradlew :app:testDebugUnitTest    # 建议提交前跑一次
git add -A
git commit -m "feat(xxx): 说明"
git push origin mine
```

功能大一点就从 `mine` 拉临时分支，做完合回 `mine`：

```bash
git checkout -b feat/my-thing mine
# ...改...
git checkout mine && git merge feat/my-thing && git branch -d feat/my-thing
```

### 2.2 同步上游（核心操作）

```bash
# ① 拉上游
git fetch upstream --tags

# ② 看看上游更新了什么（先看再合，别盲合）
git log --oneline main..upstream/main

# ③ main 快进到上游
git checkout main
git merge --ff-only upstream/main
git push origin main

# ④ 把上游合进你的分支
git checkout mine
git merge main

# ⑤ 有冲突就解（见第 3 节），没冲突直接验证
./gradlew :app:testDebugUnitTest
./gradlew assembleDebug

# ⑥ 推上去
git push origin mine
```

或者直接跑封装好的脚本（做完 ①②③④ 并停在冲突处等你处理）：

```bash
./scripts/fork-sync.sh
```

脚本还会顺手补齐第 0 节的本地配置；上游改写过历史时，它会识别出来并给出处理步骤后停下（第 7 节）。

### 2.3 跟稳定版而不是跟 main（建议）

从 v3.19.7（2026-10 初）开始，上游大多在 `fix/post-X.Y.Z` 这类分支上开发、发版时再合并进 main，
main 的末端通常就是最新的发布 tag。但仍有版本是直接在 main 上提交的（如 v4.0.2、v4.2.0），
如果你不想被开发中状态波及，可以只合并打了 tag 的发布版：

```bash
git fetch upstream --tags
git tag -l 'v*' --sort=-v:refname | head -5     # 看最新几个版本
git describe --tags upstream/main               # 只输出 tag 名 = main 末端正好是发布版
git checkout mine
git merge v4.3.1                                 # 合并指定发布版
```

日常我推荐这个方式，除非你在追某个还没发版的修复。

---

## 3. 冲突：预防 >> 解决

### 3.1 最重要的一条原则

> **新增文件永不冲突，修改上游文件必冲突。**
> 每次动手前先问一句："这个改动能不能放进一个新文件里？"

### 3.2 冲突高发区（按 v3.13.1 → v4.3.1 的 684 次非合并提交统计，不含测试）

| 文件 | 上游改动频率 | 建议做法 |
|---|---|---|
| `CHANGELOG.md` | 249/684 —— 最高 | **别碰。** 自己的变更写到新建的 `CHANGELOG.fork.md` |
| `res/values*/strings.xml`（6 种语言） | 每种约 134/684 | **别往里加。** 在同一个 `values/` 目录下新建 `strings_fork.xml`，Android 会自动合并所有 xml，零冲突。注意加了默认（俄语）就要给其余 5 种语言都加，否则 lint 报 MissingTranslation |
| `ui/settings/SettingsViewModel.kt`（3284 行） | 82/684 | 逻辑放新的 ViewModel / UseCase |
| `service/TrackingService.kt`（2401 行） | 73/684 | 新逻辑写成独立类，在 tick 里插一行调用 |
| `app/build.gradle.kts` | 72/684 | **别改 versionCode / versionName**，上游每次发版都动这两行，必冲突。加依赖时写在 `dependencies {}` 最末尾 |
| `ui/settings/SettingsScreen.kt`（4841 行） | 64/684 | 新设置项抽成独立 Composable 放新文件，这里只留一行调用 |
| `README*.md` | 48+33+27 | **别碰。** 自己的说明写进 `docs/` 下的新文件 |
| `data/automation/ActionDispatcher.kt`、`ui/automation/AutomationViewModel.kt`、`AutomationScreen.kt`（5088 行） | 42、41、34 | 自动化是上游近期主战场，加新动作尽量走新文件 |
| `agent/AgentTools.kt`（3131 行） | 36/684 | 新工具另起文件，这里只注册 |
| `ui/tech/TechPanelViewModel.kt` / `TechPanelScreen.kt` | 28、25 | v3.14 新增的「技术」界面，还在快速迭代 |
| `helper/HelperDaemon.kt`（3615 行） | 28/684 | 非必要不动，这里的时序注释全是踩坑换来的 |
| `di/AppModule.kt` | 25/684 | 自己的依赖单独建一个 `di/ForkModule.kt`；Room 迁移链也在这里（见 4.6） |
| `app/lint-baseline.xml`、`config/detekt/baseline.xml` | 自动生成 | 冲突时直接 `git checkout --theirs` 取上游，再本地重新生成 |

### 3.3 解冲突时的手感

在 `mine` 上执行 `git merge main` 时：

- `--ours` = **你的**（`mine`）
- `--theirs` = **上游的**（`main`）

（这个方向很容易记反，冲突时先 `git status` 确认自己在哪个分支上合并。）

```bash
git status                              # 看哪些文件冲突

git checkout --theirs app/lint-baseline.xml   # 整份用上游的
git checkout --ours   docs/我的文件.md         # 整份用自己的
# 其余手工编辑，处理完：
git add <文件>

git merge --continue
# 或者放弃这次合并，回到合并前：
git merge --abort
```

把某个文件彻底还原成上游版本（放弃自己在这文件上的全部改动）：

```bash
git checkout upstream/main -- app/src/main/kotlin/com/bydmate/app/xxx/Yyy.kt
```

### 3.4 随时确认"我改了什么"

```bash
git diff --stat upstream/main...mine     # 概览
git diff upstream/main...mine            # 全量 diff
git log --oneline --no-merges upstream/main..mine   # 只看我的提交
```

**合并完成后建议跑一次 `--stat`**，确认自己的改动没被上游的代码悄悄覆盖掉。

---

## 4. Fork 特有的坑（很重要）

### 4.1 应用内更新检查会指向上游

`app/src/main/kotlin/com/bydmate/app/service/UpdateChecker.kt:28` 硬编码了：

```kotlin
private const val GITHUB_API = "https://api.github.com/repos/AndyShaman/BYDMate/releases/latest"
```

你的构建会去查**上游**的最新版并提示更新，点下载装的是上游的 APK。因为签名不同，会安装失败。三种处理：

1. **不动**（推荐）——把它当成"上游发新版了"的提醒，看到提示就去同步代码重新打包，别点下载。
2. 改成你自己的仓库——那你就得在自己 repo 里发 release，否则永远提示"已是最新"。
3. 在应用内设置里关掉自动检查（`UpdateChecker.setAutoCheckEnabled(false)` 对应的开关）。

### 4.2 语音模型下载地址**不要**改

```
voice/TtsVoiceCatalog.kt:35   → 上游 release tag `tts-voices-v1` 的 vits-ru-multi.tar.bz2
voice/TtsModelManager.kt:214  → 同 tag 的 stress-ru.tar.bz2
```

这两个必须继续指向上游，否则语音包 404 下不下来（除非你在自己 repo 传一份同名 asset）。
第 4.1 节改 URL 的时候，别顺手把这两个一起改了。

### 4.3 签名与安装

- Release 签名读根目录 `keystore.properties`（已 gitignore），你需要自己生成一个 keystore。
- **用自己的签名打出来的包，和官方 APK 签名不同 → 不能覆盖安装。**
  必须先卸载官方版，而卸载会清掉所有行程/充电数据。
  **卸载前先在应用设置里导出 CSV / 做备份。**
- 想让官方版和自己的版本并存？需要改 `applicationId`——但代码里有 **14 处硬编码字面量** `"com.bydmate.app…"`
  （v3.13.1 时是 10 处，还在增加）：`helper/HelperBinderProtocol.kt` 的 `APP_PACKAGE`、binder 描述符、
  广播 action、推送回调描述符、无障碍/通知监听的组件名；`AutomationEngine`、`ClusterProbeRunner`、
  `FidRecorderReceiver`、`BootReceiver` 的广播 action；`TrackingService` 里 appop 和
  `WRITE_SECURE_SETTINGS` 的授权目标。它们用的是字符串常量不是 `BuildConfig.APPLICATION_ID`。
  改了 applicationId 而不改这些，helper 守护进程会找不到组件、功能大面积失效。**不建议走这条路。**
  （核对命令：`grep -rn '"com\.bydmate\.app' app/src/main/kotlin`）

### 4.4 GitHub Actions 在 fork 上默认是关的

去你 fork 的 **Actions** 标签页手动启用。启用后注意 `.github/workflows/ci.yml` 的触发条件是：

```yaml
on:
  push:
    branches: [main]      # ← 只认 main
  pull_request:
```

（上游 CI：单元测试只在 PR 上跑，`lintDebug` 和 `detekt` 每次都跑；detekt 是 v3.15.4 加的。）
如果你按第 1 节把主力分支放在 `mine`，push 到 `mine` **不会触发 CI**。
想让 `mine` 也跑 CI，**别改 `ci.yml`**（那是上游文件），
新建一个 `.github/workflows/fork-ci.yml`（新文件永不冲突）：

```yaml
name: Fork CI
on:
  push:
    branches: [mine]
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '17'
      - uses: gradle/actions/setup-gradle@v5
      - run: ./gradlew :app:testDebugUnitTest --stacktrace
      - run: ./gradlew :app:lintDebug --stacktrace
      - run: ./gradlew :app:detekt --stacktrace
```

### 4.5 许可证约束

**PolyForm Noncommercial 1.0.0**：可以随便改、可以分发，但

- **仅限非商业用途**；
- 分发时必须一并给出许可证全文（或其 URL），并保留这一行：
  `Required Notice: Copyright AndyShaman (https://github.com/AndyShaman/BYDMate)`

也就是说：**不要删 `LICENSE`，不要删界面里的版权署名**（`strings.xml` 的 `settings_copyright`）。
自己发 APK 给朋友用没问题，卖钱不行。

### 4.6 Room 数据库迁移

自己加表或加字段时，`AppDatabase` 的 `version` 和 `di/AppModule.kt` 里的迁移链**一定会和上游撞车**。
上游涨得很快：v3.13.1 时是 v18，到 v4.3.1 已经是 **v25**（两个多月加了 7 个迁移），
他下次加字段就是 v26，你也用 v26 就冲突了。

如果非要改数据库，稳妥做法是**给自己留一段高位版本号**（比如从 100 开始，写 `MIGRATION_25_100`），
这样上游正常往 26、27 走也不会和你的号段重叠——不过每次合并仍需手工把迁移链接好：
装过你版本的车机数据库已经是 100，上游的 25→26、26→27 不会在它上面执行，
得你把它们的内容再手写成 100→101 补一遍。
能不动数据库就不动；真要存东西，优先用独立的 SharedPreferences 或另建一个 Room 数据库。

### 4.7 `.gitignore` 会吞掉 `CLAUDE.md`

上游 `.gitignore` 排除了 `CLAUDE.md`、`.claude/`、`.mcp.json`、`docs/plans/`、`docs/research/`、
`docs/superpowers/`、`docs/DECISIONS.md`、`PHILOSOPHY.md`、`CONTEXT.md`（作者重度使用 AI 辅助开发，这些是他的本地文件）。
如果你想给这个 fork 提交一份 `CLAUDE.md`，`git add` 会静默跳过它。**别改 `.gitignore`**（上游文件），
用 `git add -f CLAUDE.md` 强制加入一次即可，之后它被跟踪，忽略规则就不再生效。

---

## 5. 速查表

```bash
# ── 同步 ──────────────────────────────────────────
git fetch upstream --tags               # 拉上游
git log --oneline main..upstream/main   # 上游更新了什么
git tag -l 'v*' --sort=-v:refname|head  # 上游最新几个发布版
./scripts/fork-sync.sh                  # 一键：拉上游 + main 快进 + 合进 mine

# ── 我的改动 ──────────────────────────────────────
git diff --stat upstream/main...mine    # 我改了哪些文件
git diff upstream/main...mine           # 我改了什么
git log --oneline --no-merges upstream/main..mine   # 我的提交列表

# ── 冲突 ──────────────────────────────────────────
git status                              # 哪些文件冲突
git checkout --ours <文件>               # 用我的版本（mine）
git checkout --theirs <文件>             # 用上游版本（main）
git checkout upstream/main -- <文件>     # 该文件彻底还原成上游的
git merge --continue                    # 解完继续
git merge --abort                       # 放弃这次合并

# ── 验证 ──────────────────────────────────────────
./gradlew :app:testDebugUnitTest        # 单元测试（约 7.6k 个，需要 JDK 17 + Android SDK 34）
./gradlew :app:lintDebug                # lint
./gradlew :app:detekt                   # 静态检查（只有新问题会失败）
./gradlew :app:koverHtmlReportDebug     # 覆盖率报告（只出报告，不卡门槛）
./gradlew assembleDebug                 # 出调试包
./gradlew assembleRelease               # 出签名包（需 keystore.properties）

# ── 上游改写了历史（第 7 节）─────────────────────────
git merge-base --is-ancestor main upstream/main || echo "main 无法快进"
git log --oneline main --not upstream/main   # 多出来的提交：上游有同名新版本 = 改写；没有 = 有人在 main 上提交过

# ── 后悔药 ────────────────────────────────────────
git merge --abort                       # 合并中途放弃
git rebase --abort                      # 变基中途放弃
git reset --hard origin/mine            # 回到已推送的状态
git reset --hard main                   # 回到纯上游状态（丢弃所有本地改动！）
git reflog                              # 找回任何"弄丢"的提交
```

---

## 6. 三个检查清单

**每次同步上游后：**

- [ ] `git diff --stat upstream/main...mine` —— 我的改动还在吗？有没有被覆盖？
- [ ] `./gradlew :app:testDebugUnitTest` 通过
- [ ] `./gradlew :app:lintDebug` 通过（新增 lint 问题会失败，baseline 只冻结历史问题）
- [ ] `./gradlew :app:detekt` 通过（同上，baseline 在 `config/detekt/baseline.xml`）
- [ ] `./gradlew assembleDebug` 能出包
- [ ] 上游如果动了 `AppDatabase` 版本，确认迁移链没断
- [ ] 同步了一大段之后，把本文和 `PROJECT-OVERVIEW.zh.md` 里过时的数字（版本、行号、数据库版本）顺手更新
- [ ] `git push origin main mine`

**每次准备改上游文件前：**

- [ ] 这个改动能不能改成"新增文件 + 原文件加一行调用"？
- [ ] 要改的文件在 3.2 的高频表里吗？在的话再想想。
- [ ] 原文件那段代码上面的注释读了吗？（这个项目的注释经常在解释"为什么不能这么改"）

**打包自用前：**

- [ ] `keystore.properties` 存在且指向你自己的 keystore
- [ ] 车机上如果装的是官方版 → 先导出数据，再卸载，再装自己的
- [ ] 别改语音模型的下载 URL（4.2）

---

## 7. 上游改写了历史（force-push）怎么办

### 7.1 发生过什么

2026-11-10 同步时发现：fork 的 `main`（停在 v3.13.1）**不是** `upstream/main` 的祖先，两边的共同祖先退回到了 v3.2.2。
原因是上游在 v3.13.1 之后用 filter-repo 一类的工具**改写了 v3.2.2 之后的全部历史**：
只把 `SUPPORT.md` 和 `ui/settings/DonateDialog.kt` 里的 USDT 捐赠地址从 `0x2491…60B8` 换成了 `0xBca8…b803`，
其余内容、提交信息、作者、作者时间都没变，但 v3.2.2 之后的每个提交哈希都变了。

这时如果照常 `git merge upstream/main`：

- `main` 没法 fast-forward；
- 在 `mine` 上直接合并会出现 **277 个冲突文件**（全是假冲突：两边对同一段代码做了"同样的修改"，但 Git 只看到两条不相干的历史），
  而且之后 `git log` 里每个上游提交都有两份，`git log upstream/main..mine` 再也看不清"我改了什么"。

### 7.2 怎么识别

`main` 是纯镜像，不能快进只有两种可能：

1. 有人直接在 `main` 上提交过；
2. 上游改写了历史。

区分方法：看 `main` 上多出来的提交，在上游能不能找到**作者时间 + 作者邮箱 + 标题完全相同**的"孪生提交"。
改写历史只换哈希，这三样都会保留；真正的本地提交在上游找不到。

```bash
git rev-list --count main --not upstream/main            # 多出来几个
LC_ALL=C comm -12 \
  <(git log --format='%at %ae %s' main --not upstream/main | LC_ALL=C sort -u) \
  <(git log --format='%at %ae %s' upstream/main | LC_ALL=C sort -u) | wc -l   # 其中几个有孪生
```

两个数相等 = 纯改写。2026-11-10 那次是 115 / 115。`scripts/fork-sync.sh` 内置了这个判断，会直接告诉你是哪种情况。

### 7.3 怎么处理（两分支模式）

`main` 是镜像，直接对齐上游；`mine` 上**只把你自己的提交**挪到新历史上：

```bash
OLD=$(git rev-parse main)                                # 记下旧镜像
git branch backup/mine-before-rewrite mine               # 留备份
git checkout main && git reset --hard upstream/main      # 镜像对齐上游
git rebase --onto upstream/main $OLD mine                # 只重放 $OLD..mine 之间你自己的提交
git diff --stat $OLD backup/mine-before-rewrite          # 改写前：你的改动
git diff --stat upstream/main mine                       # 改写后：你的改动，应与上一条一致
git push --force-with-lease origin main mine             # 两个分支都必须强推
```

注意：

- `rebase` 会丢掉合并提交。如果你以前在 `mine` 上合并上游时**在合并提交里解过冲突**（比如改了 `SettingsScreen.kt` 的同一段），
  这些解法不会被重放。所以最后两条 `diff --stat` 一定要对比，不一致就从备份分支把缺的改动找回来。
- 强推之后，其他机器上的旧 clone 也要跟着处理：`git fetch origin && git checkout mine && git reset --hard origin/mine`，
  `main` 同理（先确认那台机器上没有没推上去的提交）。
- 旧历史里的哈希（比如某次 issue 里引用的提交号）在新历史里对不上了，按提交标题去找。

### 7.4 单分支模式

如果你直接在 `main` 上干活，找出上游旧历史在 `main` 里的最后一个提交（一般就是你上次合并进来的上游版本，
例如旧的 `v3.13.1` 提交），把它当作 `$OLD`，执行 `git rebase --onto upstream/main $OLD main`，
再 `git push --force-with-lease origin main`。同样要用 `diff --stat` 前后对比。
