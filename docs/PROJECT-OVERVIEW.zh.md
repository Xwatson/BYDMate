# BYDMate 项目梳理

> 本文档由 fork 维护者整理，不是上游文件。上游更新不会碰它，可以放心修改。
> 对应上游版本：**v3.13.1 / versionCode 431**（2026-08-26）。

---

## 1. 这是什么

运行在**比亚迪 DiLink 车机**上的原生 Android 应用，用来记录行程、分析真实能耗，并在车机上叠加一批原车没有的功能。

- 已验证车型：方程豹豹3（Leopard 3）；兼容 Sea Lion 07、宋、Atto 3、Seal、汉
- 固件：DiLink 3.0 / 5.0 / 5.1，以及新界面 UI7（OTA V1.6）
- 侧载安装，不走 Google Play，不依赖 GMS
- 上游仓库：`AndyShaman/BYDMate`　本 fork：`Xwatson/BYDMate`
- 许可证：**PolyForm Noncommercial 1.0.0**（源码开放，仅限非商业用途，分发时必须附带许可证与署名）

核心卖点是**绕过原车行车电脑**：原车能耗读数偏低 10–30%，本项目直接读 BMS 数据（`energydata` SQLite + 系统 `autoservice` binder）拿真实值。

**语言注意**：默认资源集 `res/values/` 是**俄语**，`values-zh/` 才是中文。CHANGELOG 和主 README 也都是俄语。

---

## 2. 功能面（对应到代码位置）

| 功能 | 说明 | 主要代码 |
|---|---|---|
| 行程记录 | GPS 轨迹、距离、时长、真实能耗、费用 | `domain/tracker/`、`data/trips/` |
| 充电记录 | AC/DC 自动识别与统计 | `data/charging/` |
| 电池健康 | 温度、SoH、电芯均衡、12V | `domain/battery/`、`data/autoservice/` |
| 自动化 | WHEN→THEN 规则引擎，触发器 → 车辆控制指令 | `data/automation/`、`ui/automation/` |
| 悬浮小组件 | 覆盖在其他应用上的 7 项数据面板 | `ui/widget/` |
| 仪表盘投射 | 把指定应用投到仪表盘，方向盘按键切换 | `cluster/` |
| 分屏 1/3 + 2/3 | 两套实现：自研 freeform 窗口 / UI7 原生分屏 | `split/` |
| HUD 抬头显示 | 导航转向、距离、限速投到前挡风 | `hud/`、`navdata/`、`media/` |
| 盲区摄像头 | 转向灯触发侧方摄像头画面 | `camera/` |
| 语音助手 | 俄语离线 ASR + 本地 TTS + LLM Agent | `voice/`、`agent/` |
| AI 洞察 | 本地规则引擎（默认）或 OpenRouter LLM | `data/remote/InsightsManager.kt` 等 |
| ABRP / Webhook 遥测 | 实时数据推送到 ABRP 或自建服务器 | `data/remote/Iternio*`、`WebhookTelemetryClient.kt` |
| 数据导出 | 行程/充电导出 CSV | `data/backup/` |

---

## 3. 技术栈与构建

**单 Gradle 模块** `:app`，命名空间 `com.bydmate.app`。

```
Kotlin 2.1.0        AGP 8.7.3          JDK 17
Compose BOM 2024.12 + Material 3      Navigation Compose 2.8.5
Room 2.6.1 (KSP)    Hilt 2.53.1       WorkManager 2.9.1
OkHttp 4.12         osmdroid 6.1.20   Coroutines 1.9.0
sherpa-onnx 1.13.3（本地 AAR，见 app/libs/）
hiddenapibypass 4.3   commons-suncalc 3.7   commons-compress 1.27.1
```

**SDK 配置里几个"看起来像 bug 其实是故意的"点**（改之前务必读注释）：

- `targetSdk = 29`（对齐原车 TripInfo 应用）：为了在 DiLink 的 Android 12 上保住 legacy 外部存储权限。升到 30+ 会让 `listFiles()` 读不到 `/storage/emulated/0/energydata/`，直接废掉核心数据源。
- `abiFilters = ["arm64-v8a"]`：DiLink 只有 arm64，单 ABI 让 sherpa-onnx 的 native 库体积可控。
- `compileSdk = 34`、`minSdk = 29`。
- lint 用 `app/lint-baseline.xml` 冻结历史问题，新问题会让 CI 失败。

**构建：**

```bash
./gradlew assembleDebug            # 调试包
./gradlew :app:testDebugUnitTest   # 单元测试（约 3.5k 个）
./gradlew :app:lintDebug           # lint
./gradlew assembleRelease          # 需要 keystore.properties，否则报错
```

Release 签名从根目录 `keystore.properties` 读取（已 gitignore）。文件不存在时 `assembleRelease` 会**主动抛异常**，防止发出未签名包；确实需要未签名包时加 `-PallowUnsignedRelease`。产物命名 `BYDMate-v<versionName>.apk`。

**测试：** 333 个测试文件，Robolectric 4.13 + MockK + Turbine + Room testing + MockWebServer。测试 worker 堆设成 2g（默认 512m 会 OOM）。CI 环境下开启 test-retry（最多重试 2 次）吸收已知的测试间污染 flake，本地跑则是严格模式。

**CI**（`.github/workflows/ci.yml`）：lint 每次都跑；单元测试**只在 PR 上跑**（上游的 main 推送前已在本地跑过全量）。

**发版脚本** `scripts/prepare-release.sh X.Y.Z`：把 CHANGELOG 的 `[Unreleased]` 提升为带日期的版本段、修补 compare 链接、打印俄语纯文本 release notes、附上 APK 的 SHA-256。

---

## 4. 代码结构

622 个 Kotlin 文件，主源码约 66k 行。分层大致是 `data → domain → ui`，外加一组"系统层"包做车机 hack。

### 4.1 数据采集：三条并存的通道

这是整个项目最独特的部分。车辆数据有三个来源，互为降级：

1. **`data/local/EnergyDataReader.kt`** — 直接读原车的 SQLite（`/storage/emulated/0/energydata/EC_database.db`）。先复制到应用私有目录再读，避免锁住原车的库。`listFiles()` 拿不到时回退到硬编码文件名。历史行程数据来源。

2. **`data/autoservice/`** — 通过**设备内 ADB**（自己实现的 ADB 协议客户端 `AdbProtocolClient` / `AdbOnDeviceClient` / `AdbKeyStore`）访问系统 `autoservice` binder，按 `(dev, fid)` 逐个读参数。`FidRegistry` 是参数表，`SentinelDecoder` 负责区分"真值"和"哨兵值"（`65535` = 本代车机没这个 fid，`-10013` = 瞬时失败）。**只读**。

3. **`data/nativestack/NativeParsReader.kt`** — 实时参数快照。优先走 helper 守护进程的批量事务 `TX_READ_BATCH`，否则退回逐 fid ADB 读。`BatchReadGate` 是个影子校验门：新的批量通道先并行跑一段时间、和 ADB 结果比对，一致才切到 ACTIVE。

`data/vehicle/VehicleApi.kt` 是统一门面，读走上面的栈，写走 helper。约定很明确：**读失败返回 null，写失败返回 `Result.failure(VehicleWriteError)`，永不抛异常**。

### 4.2 helper 守护进程（`helper/`）——权限的来源

`HelperDaemon.kt`（2370 行）是一个用 `app_process` 拉起的**独立进程，跑在 shell uid 下**。应用本身没有的能力全靠它：写车辆指令、拉起 freeform 窗口、仪表盘投射、给自己 `pm grant` 权限（比如 `READ_LOGS`）。

- `HelperBootstrap.kt` 是唯一的生命周期持有者，`ensureRunning()` 幂等收敛到"当前 APK 版本对应的、活着的唯一 daemon"。
- **版本感知**：daemon 的 CLASSPATH 在 spawn 时冻结，应用升级后旧 daemon 还能应答 ping 但缺新的 handler。所以用实时查询 `TX_GET_VERSION` 判断陈旧，而不是靠 SharedPreferences 记账（后者会漂移）。
- **降级通道**：部分固件（DiLink 3.0）禁止 shell 域 `addService`，此时 daemon 改用广播把 binder 直接投递给 `HelperBinderReceiver`。该 receiver 必须 `exported`（发送方是 shell uid 不是应用自己），靠 **spawn token + interface descriptor** 双重认证。
- `data/vehicle/WriteAllowlist.kt` 是写指令白名单，加上按车速的安全限制（行驶中禁开窗/天窗/解锁等）。

### 4.3 服务与生命周期

- `service/TrackingService.kt`（1621 行）是应用心跳：前台定位服务，驱动 GPS 采样、参数轮询、行程追踪、自动化 tick、ABRP/Webhook 推送。
- `service/BootReceiver.kt` + `ServiceStartWorker.kt`：开机自启走 WorkManager（`BOOT_COMPLETED` / `QUICKBOOT_POWERON` / `USER_PRESENT`，priority 9900）。
- `data/loop/SharedAdaptiveLoop.kt`：自适应轮询节奏（行驶 1s / 充电 8s / 停车 30s）。
- WorkManager 默认初始化器在 Manifest 里被 `tools:node="remove"` 关掉，改由 Hilt 提供配置。

### 4.4 本地存储

Room，`AppDatabase` **schema version 18**，14 张表，17 个迁移全部写在 `di/AppModule.kt`（`MIGRATION_1_2` … `MIGRATION_17_18`）。schema JSON 导出在 `app/schemas/`，并被同时挂到 debug 和 release 的 assets 里（`MigrationTestHelper` 需要）。

实体：Trip / TripPoint / TripTombstone / Charge / ChargePoint / Setting / IdleDrain / BatterySnapshot / Rule / RuleLog / Place / OdometerSample / LastState / VehicleWriteLog。

`DataThinningWorker` 定期抽稀轨迹点控制库体积。

### 4.5 系统层功能包

| 包 | 干什么 | 关键点 |
|---|---|---|
| `cluster/` | 仪表盘投射 + 方向盘按键 | `SteeringWheelKeyService` 是 AccessibilityService；UI7 有独立的 frame 实现 |
| `split/` | 分屏 | `Split37Engine`（自研 freeform，靠 helper）与 `NativeSplitLauncher`（UI7 原生）双实现 |
| `hud/` | 抬头显示 | 通过 SOME/IP 网关 `com.ts.car.someip.service` 推 protobuf |
| `camera/` | 盲区摄像头 | 探测 AVM 摄像头；有帧冻结看门狗，卡住会自动重开 |
| `navdata/` + `media/` | 导航信息提取 | 通知监听 + 无障碍读屏，从 Yandex 导航等抓转向指引，喂给 HUD 和仪表盘 |
| `voice/` | 俄语语音 | GigaAM 离线 ASR + sherpa-onnx piper VITS TTS，模型从上游 GitHub release 下载 |
| `agent/` | LLM Agent | `AgentTools.kt` 约 32 个工具，可读车辆数据、控车、规划路线、跑自动化 |
| `diagnostics/` | 日志录制 | 需要 `READ_LOGS`，由 daemon 自授权 |

### 4.6 UI

纯 Compose + Material 3，底部导航四个 tab（Dashboard / Trips / Charges / Settings）。屏幕在 `ui/` 下按功能分包。`ui/widget/` 是系统级悬浮窗（`SYSTEM_ALERT_WINDOW`），不是 AppWidget。

本地化：`values`(ru，默认) / `values-en` / `values-zh` / `values-pl` / `values-pt` / `values-be`，通过 `AppCompatDelegate.setApplicationLocales` 支持应用内单独切语言。

---

## 5. 权限与隐私姿态

Manifest 声明了一批"普通应用拿不到"的权限：`PACKAGE_USAGE_STATS`、`READ_LOGS`（均由 helper daemon `pm grant` 自授）、`SYSTEM_ALERT_WINDOW`、`RECORD_AUDIO`、`CAMERA`、`READ_CONTACTS`、`REQUEST_INSTALL_PACKAGES`、后台定位。

隐私设计上：所有核心功能（行程、充电、自动化、本地洞察、离线语音）**完全本地运行、不需要联网**。云端功能（OpenRouter LLM、ABRP、Webhook、Exa/Zai 搜索、天气）默认关闭，手动填 key 才启用。

---

## 6. 上游的工程习惯

摸清这些能让合并顺手很多：

- **提交信息**：`type(scope): 描述 (#issue)`，如 `fix(blindspot): ...`、`feat(diagnostics): ...`、`chore: v3.13.1 / versionCode 431`。混用英语和俄语。
- **发版节奏很快**：2026-03 至 08 共 644 次提交（5 月峰值 217 次/月），112 个 tag。三天一个小版本是常态。
- **每次发版必动** `app/build.gradle.kts`（versionCode + versionName）和 `CHANGELOG.md`。
- 注释密度高，很多注释解释的是"为什么不能改成看起来更合理的写法"（固件坑、时序坑）。**改代码前先读注释**。
- `.gitignore` 里排除了 `CLAUDE.md`、`.claude/`、`docs/plans/`、`docs/research/`、`docs/superpowers/`、`.mcp.json` —— 上游是重度 AI 辅助开发，这些是他的本地工作文件。

---

## 7. 一眼看懂的目录树

```
BYDMate/
├── app/
│   ├── build.gradle.kts        ← 版本号在这（每次上游发版都变）
│   ├── lint-baseline.xml       ← 自动生成
│   ├── libs/                   ← sherpa-onnx AAR
│   ├── schemas/                ← Room schema JSON
│   └── src/
│       ├── main/kotlin/com/bydmate/app/
│       │   ├── agent/          LLM Agent（32 工具）
│       │   ├── camera/         盲区摄像头
│       │   ├── cluster/        仪表盘投射 + 方向盘按键
│       │   ├── data/
│       │   │   ├── automation/ 规则引擎
│       │   │   ├── autoservice/ADB → 系统 binder（只读）
│       │   │   ├── charging/   充电检测
│       │   │   ├── local/      Room + energydata 读取
│       │   │   ├── loop/       自适应轮询
│       │   │   ├── nativestack/实时参数快照
│       │   │   ├── remote/     OpenRouter / ABRP / Webhook / 洞察
│       │   │   ├── repository/ 仓库层
│       │   │   ├── trips/      行程记录
│       │   │   └── vehicle/    VehicleApi 门面 + 写白名单
│       │   ├── di/             Hilt 模块（Room 迁移也在这）
│       │   ├── domain/         计算：能耗 / 续航 / SoC 插值 / 行程追踪
│       │   ├── helper/         shell uid 守护进程 ★
│       │   ├── hud/            抬头显示
│       │   ├── media/          媒体会话 + 导航通知解析
│       │   ├── navdata/        导航指引抽取
│       │   ├── service/        前台服务 / 开机自启 / 更新检查
│       │   ├── split/          分屏
│       │   ├── ui/             Compose 界面
│       │   ├── util/           崩溃日志 / GCJ-02 坐标转换
│       │   └── voice/          俄语 ASR + TTS
│       ├── main/res/values*/   六语言 strings.xml
│       └── test/               333 个测试文件
├── docs/
│   ├── PROJECT-OVERVIEW.zh.md  ← 本文（fork 自有）
│   ├── FORK-WORKFLOW.zh.md     ← fork 维护手册（fork 自有）
│   ├── mockups/                HTML 设计稿
│   └── screenshots/
├── scripts/prepare-release.sh
├── CHANGELOG.md                （俄语）
└── README.md / .en.md / .zh.md
```

★ = 读代码时建议优先看的地方。
