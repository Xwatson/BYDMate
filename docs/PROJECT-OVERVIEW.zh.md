# BYDMate 项目梳理

> 本文档由 fork 维护者整理，不是上游文件。上游更新不会碰它，可以放心修改。
> 对应上游版本：**v4.3.1 / versionCode 519**（2026-11-06）。
> 上一版梳理基于 v3.13.1，两版之间的主要变化见第 8 节。

---

## 1. 这是什么

运行在**比亚迪 DiLink 车机**上的原生 Android 应用，用来记录行程、分析真实能耗，并在车机上叠加一批原车没有的功能。

- 已验证车型：方程豹豹3（Leopard 3，作者自己的车）；兼容 Sea Lion 07、宋、元 UP、Atto 3、Seal、汉等
- **v4.0 起支持 DM-i / DM-o 混动**（宋 Pro/Plus、唐 L、Seal U、豹 5/7/8、Sealion 06 等），靠车辆自己的计数器自动识别，无需设置
- 固件：DiLink 3.0 / 4.0（Android 10）、DiLink 5.0 / 5.1（Android 12），新界面 UI7（OTA V1.6），也适配了 Android 14 车机
- 侧载安装，不走 Google Play，不依赖 GMS
- 上游仓库：`AndyShaman/BYDMate`　本 fork：`Xwatson/BYDMate`
- 许可证：**PolyForm Noncommercial 1.0.0**（源码开放，仅限非商业用途，分发时必须附带许可证与署名）

核心卖点是**绕过原车行车电脑**：原车能耗读数偏低 10–30%，本项目直接读 BMS 数据（`energydata` SQLite + 系统 `autoservice` binder）拿真实值。

**语言注意**：

- 默认资源集 `res/values/` 是**俄语**，`values-zh/` 才是中文。CHANGELOG 和主 README 也都是俄语（README 另有 `.zh.md`、`.en.md`）。
- **语音助手只支持俄语**，而且是作者有意为之：离线识别用的 GigaAM v3 是俄语模型，离线快捷命令是一张固定的俄语短语表。
  作者的理由是原车语音助手已经支持中文和英语，没必要再做。对中文用户来说，语音相关功能基本用不上。

---

## 2. 功能面（对应到代码位置）

| 功能 | 说明 | 主要代码 |
|---|---|---|
| 行程记录 | GPS 轨迹、距离、时长、真实能耗、费用。没有 energydata 的车型改为后台轮询原生记录。v4.3 起行程窗口全屏，可沿图表拖动回放，按速度 / 能耗给轨迹着色 | `domain/tracker/`、`data/trips/`、`ui/trips/` |
| 充电记录 | AC/DC 自动识别与统计，可手动补录 | `data/charging/`、`ui/charges/` |
| 电价与费用 | 电价是带生效日期的时间段，可追溯修改并自动重算；计入充电损耗；混动车另有油价 | `domain/cost/`（`TariffSchedule`、`CostCalculator`） |
| **技术面板** | v3.14 新增，v4.3 成为底部第二个标签。实时参数分卡片：电池、BMS 限值、电芯压差、电机与逆变器、车况（胎压示意图、PM2.5）、电池历史（SoH、满充、校准），卡片可拖动排序 | `ui/tech/` |
| **故障码诊断** | v4.1 起，仅在 P 挡按需读取各 ECU 故障码，按 BYD 维修手册解码（`assets/dtc/` 约 3.8 MB 的 TSV 库），可发到 Telegram；v4.2 起可清除（实验性） | `helper/dtc/`、`data/dtc/`、`ui/tech/Dtc*` |
| **混动支持** | 自动识别 EV / HYBRID，油量、燃油续航、发动机转速、L/100km，行程按车辆计数器分摊油耗 | `data/nativestack/VehicleKindDetector.kt` 等 |
| 自动化 | WHEN→THEN 规则引擎。新增：规则分享 / 导入（JSON）、试运行、拖动排序、一次性定时条件、方向盘按键触发、单条规则最多 20 个动作 | `data/automation/`、`ui/automation/` |
| **Telegram 机器人** | 熄火报告（车况、最近一次行程、TRIP 计数器等可选）、自动化里的「发送报告」动作、配置备份、日志、故障码；可接入群组 | `data/telegram/`、`helper/offreport/`、`data/backup/TelegramBackupSink.kt` |
| **配置备份** | 「保存配置」可按部分选择（数据表 / 设置与电价 / 密钥），按日 / 周 / 月自动备份，恢复时也可只恢复一部分 | `data/backup/`、`ui/restore/` |
| 悬浮小组件 | 覆盖在其他应用上的数据面板，可设成只在桌面显示 | `ui/widget/` |
| 仪表盘投射 | 把指定应用投到仪表盘，方向盘按键切换；仪表盘音乐卡片显示任意播放器的曲目 | `cluster/`、`media/` |
| 分屏 1/3 + 2/3 | 两套实现：自研 freeform 窗口 / UI7 原生分屏；可绑定方向盘按键，记住上次的应用组合 | `split/` |
| HUD 抬头显示 | 导航转向、距离、限速投到前挡风；三种输出方式 + 「HUD 检测」向导；可由自动化 / 语音开关 | `hud/`、`navdata/`、`media/` |
| 盲区摄像头 | 打转向灯时弹出侧方摄像头画面，可竖放、可两路都投到仪表盘 | `camera/` |
| 语音助手 | 俄语离线 ASR（GigaAM v3）+ 本地 TTS（sherpa-onnx VITS）或在线 TTS + LLM 智能体（约 36 个工具），有驾驶员记忆和当日对话记忆 | `voice/`、`agent/` |
| AI 洞察 | 本地规则引擎（默认）或 OpenRouter LLM | `data/remote/InsightsManager.kt`、`LocalInsightEngine.kt` |
| ABRP / Webhook 遥测 | 实时数据推送到 ABRP 或自建服务器 | `data/remote/Iternio*`、`WebhookTelemetryClient.kt` |
| **ADB 自动恢复** | 2606 及以后的固件每次重启都会关掉 ADB，应用通过 Android 无线调试 + TLS 握手自动把 5555 端口拉起来 | `data/autoservice/AdbRestore*`、`AdbTls.kt` |
| 车机系统选项 | 经 Wi-Fi 连 BYD 云（给只有中国 SIM 卡的车用）、方向盘旋钮暂停、锁定时区、打开原车隐藏的语言对话框 | `data/autoservice/CloudOverWifiManager.kt`、`data/settings/TimezoneLock.kt` |

---

## 3. 技术栈与构建

**两个 Gradle 模块**（v3.13.1 时只有一个）：

- `:app`：命名空间和 applicationId 都是 `com.bydmate.app`
- `:bydauto-stubs`：纯 Java 模块，是 BYD 隐藏框架类 `android.hardware.bydauto.*`（`IBYDAutoListener`、`BYDAutoEventValue`、46 个 `AbsBYDAuto*Listener`）的**编译期桩**。
  `:app` 以 `compileOnly` 依赖它，不打进 APK，真类由车机自己的 `framework.jar` 提供；单元测试以 `testImplementation` 引入。
  桩代码由 `scripts/gen-bydauto-listener-stubs.py` 从反编译的固件生成。

```
Kotlin 2.1.0        AGP 8.7.3          KSP 2.1.0-1.0.29     JDK 17
Compose BOM 2024.12.01 + Material 3    Navigation Compose 2.8.5
Room 2.6.1 (KSP)    Hilt 2.53.1        WorkManager 2.9.1
OkHttp 4.12         osmdroid 6.1.20    Coroutines 1.9.0
sherpa-onnx 1.13.3（本地 AAR，见 app/libs/）
hiddenapibypass 4.3   commons-suncalc 3.7   commons-compress 1.27.1
bcpkix-jdk18on 1.85   ← 新增：给 ADB TLS 握手生成自签 X.509 证书
```

质量工具（v3.15.4 新增）：**detekt 1.23.8**（存量问题冻结在 `config/detekt/baseline.xml`，只有新问题会失败）、
**kover 0.9.9**（覆盖率，只出报告不卡门槛）、**kotest-property 6.2.5**（属性测试）。`org.gradle.jvmargs` 提到了 4 GB。

**SDK 配置里几个"看起来像 bug 其实是故意的"点**（改之前务必读注释）：

- `targetSdk = 29`（对齐原车 TripInfo 应用）：为了在 DiLink 的 Android 12 上保住 legacy 外部存储权限。升到 30+ 会让 `listFiles()` 读不到 `/storage/emulated/0/energydata/`，直接废掉核心数据源。
- `abiFilters = ["arm64-v8a"]`：DiLink 只有 arm64，单 ABI 让 sherpa-onnx 的 native 库体积可控。
- `compileSdk = 34`、`minSdk = 29`。
- lint 用 `app/lint-baseline.xml` 冻结历史问题，新问题会让 CI 失败。翻译是全的（baseline 里没有 MissingTranslation），只加默认语言的字符串会让 lint 失败。

**构建（需要 JDK 17 + Android SDK 34）：**

```bash
./gradlew assembleDebug              # 调试包
./gradlew :app:testDebugUnitTest     # 单元测试（约 7.6k 个）
./gradlew :app:lintDebug             # lint
./gradlew :app:detekt                # 静态检查
./gradlew :app:koverHtmlReportDebug  # 覆盖率报告
./gradlew assembleRelease            # 需要 keystore.properties，否则报错
```

Release 签名从根目录 `keystore.properties` 读取（已 gitignore）。文件不存在时 `assembleRelease` 会**主动抛异常**，防止发出未签名包；确实需要未签名包时加 `-PallowUnsignedRelease`。产物命名 `BYDMate-v<versionName>.apk`。

**测试：** 696 个测试文件、约 7.6k 个 `@Test`、约 12.8 万行，**比主代码还多**。Robolectric 4.13 + MockK + Turbine + Room testing + MockWebServer + kotest-property。
测试 worker 堆设成 2g（默认 512m 会 OOM）。CI 环境下开启 test-retry（最多重试 2 次）吸收已知的测试间污染 flake，本地跑则是严格模式。

**CI**（`.github/workflows/ci.yml`）：lint 和 detekt 每次都跑；单元测试**只在 PR 上跑**（上游推 main 之前已在本地跑过全量）。

**脚本**（`scripts/`）：

| 脚本 | 用途 |
|---|---|
| `prepare-release.sh X.Y.Z` | 把 CHANGELOG 的 `[Unreleased]` 提升为版本段、修补 compare 链接、打印俄语 release notes 和 APK 的 SHA-256 |
| `agent-eval.sh` | 用真实模型跑语音智能体的评测集（`AgentEvalCases.kt`），花 token，发版前手动跑 |
| `fid-record.sh` | 在车机上订阅整个 BYD 设备的全部 fid，把变化写进 Download；仅 `-test` 构建可用 |
| `gen-bydauto-listener-stubs.py` | 生成 `:bydauto-stubs` 的桩代码和记录器用的 listener 子类 |
| `fork-sync.sh` | **fork 自有**，同步上游，见 `FORK-WORKFLOW.zh.md` |

---

## 4. 代码结构

主源码 506 个 Kotlin 文件、约 12 万行（v3.13.1 时约 6.6 万行，不到三个月几乎翻倍）。
分层大致是 `data → domain → ui`，外加一组"系统层"包做车机 hack。

最大的几个文件：`ui/automation/AutomationScreen.kt`（5088 行）、`ui/settings/SettingsScreen.kt`（4841）、
`helper/HelperDaemon.kt`（3615）、`ui/settings/SettingsViewModel.kt`（3284）、`agent/AgentTools.kt`（3131）、
`service/TrackingService.kt`（2401）、`split/SplitSessionManager.kt`（2279）、`cluster/ClusterProjectionManager.kt`（2279）。

### 4.1 数据采集：四条并存的通道

这是整个项目最独特的部分。车辆数据有四个来源，互为补充或降级：

1. **`data/local/EnergyDataReader.kt`** — 直接读原车的 SQLite（`/storage/emulated/0/energydata/EC_database.db`）。先复制到应用私有目录再读，避免锁住原车的库。`listFiles()` 拿不到时回退到硬编码文件名。历史行程数据来源，由 `HistoryImporter` 导入。

2. **`data/autoservice/`** — 通过**设备内 ADB**（自己实现的 ADB 协议客户端 `AdbProtocolClient` / `AdbOnDeviceClient` / `AdbKeyStore`）访问系统 `autoservice` binder，按 `(dev, fid)` 逐个读参数。`FidRegistry` 是参数表，`SentinelDecoder` 负责区分"真值"和"哨兵值"（`65535` = 本代车机没这个 fid，`-10013` = 瞬时失败）。**只读**。
   v3.15 起还能走 ADB 的 **STLS（无线调试）握手**：`AdbTls` + `AdbCertificate`，供 ADB 自动恢复使用。

3. **`data/nativestack/NativeParsReader.kt`** — 实时参数快照。优先走 helper 守护进程的批量事务 `TX_READ_BATCH`，否则退回逐 fid ADB 读。`BatchReadGate` 是个影子校验门：新的批量通道先并行跑一段时间、和 ADB 结果比对，一致才切到 ACTIVE。
   v3.15.3 起参数地址从**固件自带的 fid 目录**解析（`FidCatalog` / `FidResolver`），不再硬编码豹3 的常量，这是宋 Plus 等车型能出数据的关键。

4. **推送通道（v3.16 新增）** — `helper/push/` + `data/push/`。守护进程以 shell uid 向 BYD 厂商设备（灯光、变速箱、ADAS、车身四类）**逐个 fid** 注册 listener（应用 uid 注册会被拒），
   事件攒一小批后通过 `TX_PUSH_EVENT` 推给应用的回调 binder；应用侧 `FidPushChannel` 用和轮询**同一套解码器与取值校验**（`FidMap` + `FieldGuards`）把值补进实时快照，再发成 Flow。
   **轮询仍是唯一可信来源**，推送只是让值在两次轮询之间提前更新。转向灯、挡位、车门、盲区等由此做到即时响应，自动化的这类条件从 v3.17.1 起按事件触发。
   它取代了旧的 `data/subscription/`。

`data/vehicle/VehicleApi.kt` 是统一门面，读走上面的栈，写走 helper。约定很明确：**读失败返回 null，写失败返回 `Result.failure(VehicleWriteError)`，永不抛异常**。
写指令按功能拆成了一组 Channel（座椅、车窗、天窗、驾驶模式、电池预热、方向盘加热、HUD 开关……），很多带"写后回读确认"。

### 4.2 helper 守护进程（`helper/`）——权限的来源

`HelperDaemon.kt`（3615 行）是一个用 `app_process` 拉起的**独立进程，跑在 shell uid 下**。应用本身没有的能力全靠它：写车辆指令、拉起 freeform 窗口、仪表盘投射、给自己 `pm grant` 权限。
`HelperBinderProtocol.kt` 定义了 17 个事务码。v3.13.1 之后它多了三个子包（`push/` 来自 v3.16，`offreport/` 来自 v3.19，`dtc/` 来自 v4.1）：

| 子包 | 干什么 |
|---|---|
| `push/` | 厂商 listener 的注册与事件转发（见 4.1），以及调试用的全量 fid 记录器 `FidRecorder` |
| `dtc/` | 故障码扫描与清除：经厂商 1033 号诊断设备收发 UDS 帧，只访问白名单地址、只发固定请求；每次请求前检查挡位（必须 P）、原车诊断服务的状态属性（`sys.diagmgrsrv.task_bk`，没有这个服务的固件直接提示升级）和请求预算，清除时还检查车速 |
| `offreport/` | 熄火报告：车辆熄火后约 1 秒内应用就会被系统强停（quickboot），守护进程不会。所以由守护进程监听 `BODYWORK_POWER_LEVEL` 判断熄火，先落盘，再赶在网络断开前约 8 秒内发出 Telegram 报告；没发出去的下次启动补发 |

另外保留的机制：

- `data/vehicle/HelperBootstrap.kt` 是唯一的生命周期持有者，`ensureRunning()` 幂等收敛到"当前 APK 版本对应的、活着的唯一 daemon"。
- **版本感知**：daemon 的 CLASSPATH 在 spawn 时冻结，应用升级后旧 daemon 还能应答 ping 但缺新的 handler。所以用实时查询 `TX_GET_VERSION` 判断陈旧，而不是靠 SharedPreferences 记账。
- **降级通道**：部分固件（DiLink 3.0）禁止 shell 域 `addService`，此时 daemon 改用广播把 binder 直接投递给 `HelperBinderReceiver`。该 receiver 必须 `exported`，靠 **spawn token + interface descriptor** 双重认证。
- `data/vehicle/WriteAllowlist.kt` 是写指令白名单，加上按车速的安全限制（行驶中禁开窗/天窗/解锁等；车速未知时也不执行打开类指令）。

### 4.3 服务与生命周期

- `service/TrackingService.kt`（2401 行）是应用心跳：前台定位服务，驱动 GPS 采样、参数轮询、行程追踪、自动化 tick、ABRP/Webhook 推送。
- `service/BootReceiver.kt` + `ServiceStartWorker.kt`：开机自启走 WorkManager。熄火后不再自动拉起服务（v4.0.2 修过"停车时服务挂几个小时"的问题）。
- `data/loop/SharedAdaptiveLoop.kt`：自适应轮询节奏（行驶 1s / 充电 8s / 停车 30s）。
- `platform/LegacyHeadUnit.kt`：判断"老车机"（Android 10 的 DiLink 3.0 / 4.0）的**唯一入口**，按 SDK 版本判断，不看固件指纹。
- WorkManager 默认初始化器在 Manifest 里被 `tools:node="remove"` 关掉，改由 Hilt 提供配置。

### 4.4 本地存储

Room，`AppDatabase` **schema version 25**（v3.13.1 时是 18），16 张表，24 个迁移全部写在 `di/AppModule.kt`（`MIGRATION_1_2` … `MIGRATION_24_25`）。schema JSON 导出在 `app/schemas/`，并被同时挂到 debug 和 release 的 assets 里（`MigrationTestHelper` 需要）。

实体：Trip / TripPoint / TripTombstone / Charge / ChargePoint / Setting / IdleDrain / BatterySnapshot / Rule / RuleLog / Place / OdometerSample / LastState / VehicleWriteLog，
以及新增的 **TariffPeriod**（电价时间段）和 **CounterSnapshot**（计数器快照）。v4.3 起每个轨迹点还存电池功率和累计电量，用于行程回放里的逐点能耗。

`DataThinningWorker` 定期抽稀轨迹点：30 天内保留全分辨率，之后每 5 秒留一个点（以前是每分钟一个）。

### 4.5 系统层功能包

| 包 | 干什么 | 关键点 |
|---|---|---|
| `cluster/` | 仪表盘投射 + 方向盘按键 | `SteeringWheelKeyService` 是 AccessibilityService，同时负责自动确认"允许无线调试"对话框 |
| `split/` | 分屏 | `Split37Engine`（自研 freeform，靠 helper）与 `NativeSplitLauncher`（UI7 原生）双实现；Android 10/11 上不可用 |
| `hud/` | 抬头显示 | 通过 SOME/IP 网关 `com.ts.car.someip.service` 推 protobuf；三种输出方式；没有 HUD 的车改投原车仪表导航卡片 |
| `camera/` | 盲区摄像头 | 探测 AVM 摄像头；有帧冻结看门狗；原车 360 全景打开时自动让路 |
| `navdata/` + `media/` | 导航信息与媒体 | 通知监听 + 无障碍读屏，只从 Yandex 导航 / Yandex 地图抓转向指引，喂给 HUD 和仪表盘（2GIS、Waze 只作为路线导航器和投射对象）；仪表盘音乐卡片 |
| `voice/` | 俄语语音 | GigaAM v3 离线 ASR + sherpa-onnx VITS TTS（模型从上游 GitHub release 下载）；在线 TTS 可选 MiniMax / fal.ai / Replicate / OpenRouter |
| `agent/` | LLM 智能体 | `AgentTools.kt` 约 36 个工具；LLM 连接三选：OpenRouter / z.ai / 自建 OpenAI 兼容服务，主连接失败自动切备用；"我在哪""附近充电站"（Overpass） |
| `diagnostics/` | 日志录制 | 需要 `READ_LOGS`（由 daemon 自授）；`Trace` / `TraceJournal` 保留录制开始前的短历史；日志脱敏（去掉电话、坐标、链接）；可发到 Telegram |
| `data/dtc/` | 故障码解析 | 解析守护进程读回的帧，按车型 + 手册解码，生成 Telegram 文本 |
| `data/telegram/` | Telegram | 报告构建、发件箱、熄火报告的"预装填"（把现成的报告交给守护进程） |
| `data/carstatus/` | 原车车况 | 只读 `content://com.byd.carStatusProvider/car_status`：仪表盘告警、保养剩余天数 / 里程 |
| `data/backup/` | 备份 | 分部分备份、自动备份调度、恢复后自检（`PostRestoreCheck`） |

### 4.6 UI

纯 Compose + Material 3，底部导航**六个 tab**：首页 / 技术 / 行程 / 充电 / 自动化 / 设置（`ui/navigation/AppNavigation.kt` 的 `Screen` 枚举）。
屏幕在 `ui/` 下按功能分包。`ui/widget/` 是系统级悬浮窗（`SYSTEM_ALERT_WINDOW`），不是 AppWidget。设置里有"字号"（普通 / 大 / 特大）。

本地化：`values`(ru，默认) / `values-en` / `values-zh` / `values-pl` / `values-pt` / `values-be`，通过 `AppCompatDelegate.setApplicationLocales` 支持应用内单独切语言。

---

## 5. 权限与隐私姿态

Manifest 声明了 22 个权限，其中几个"普通应用拿不到"的由应用自己授予：

- `PACKAGE_USAGE_STATS`、`READ_LOGS`：由 helper daemon / ADB `pm grant` 自授
- `WRITE_SECURE_SETTINGS`（v3.15 新增）：趁 ADB 还活着时自授一次，ADB 自动恢复要用它打开 `adb_wifi_enabled`
- 其余：`SYSTEM_ALERT_WINDOW`、`RECORD_AUDIO`、`CAMERA`、`READ_CONTACTS`、`REQUEST_INSTALL_PACKAGES`、后台定位、`START_ACTIVITIES_FROM_BACKGROUND`

隐私设计上：所有核心功能（行程、充电、自动化、本地洞察、离线语音）**完全本地运行、不需要联网**。
云端功能默认关闭，填了 key 才启用：LLM（OpenRouter / z.ai / 自建）、联网搜索（Exa / z.ai / OpenRouter）、天气（Open-Meteo）、充电站（Overpass）、在线 TTS、ABRP、Webhook、Telegram。
不填任何 key 时，只有更新检查（GitHub API）、行程地图瓦片（OSM 或高德）和用户主动下载的语音模型会离开车机。完整清单见 `README.zh.md` 的「数据与网络」一节。

---

## 6. 上游的工程习惯

摸清这些能让合并顺手很多：

- **提交信息**：`type(scope): 描述 (#issue)`，如 `fix(dtc): ...`、`feat(trips): ...`、`chore: release 4.3.1`。早期混用俄语，现在以英语为主。
- **测试先行**：常见的一组提交是 `test(x): red tests for …` → `feat(x): …` → `fix: review fixes …`。测试代码量已经超过主代码。
- **重度 AI 辅助开发**：合并记录里常见 `Merge branch 'worktree-agent-…'`，提交里常见 "codex-аудит / review fixes"。
- **发版节奏极快**：2026-03 至 11 月共 1314 次非合并提交，9 月单月 367 次；v3.13.1 → v4.3.1 的 72 天里发了 40 个版本。
- **分支方式**：v3.19.7（2026-10 初）起，大多在 `fix/post-X.Y.Z` 分支上开发、发版时合并进 main，但也有直接提交到 main 的版本。
- **每次发版必动** `app/build.gradle.kts`（versionCode + versionName）和 `CHANGELOG.md`。
- **改写过一次历史**：v3.13.1 之后，上游把 v3.2.2 之后所有提交里的 USDT 捐赠地址换掉并 force-push，所有哈希都变了。处理方法见 `FORK-WORKFLOW.zh.md` 第 7 节。
- 注释密度高，很多注释解释的是"为什么不能改成看起来更合理的写法"（固件坑、时序坑）。**改代码前先读注释**。
- `.gitignore` 里排除了 `CLAUDE.md`、`.claude/`、`.mcp.json`、`docs/plans/`、`docs/research/`、`docs/superpowers/`、`docs/DECISIONS.md`、`PHILOSOPHY.md`、`CONTEXT.md`，这些是作者的本地工作文件。

---

## 7. 一眼看懂的目录树

```
BYDMate/
├── app/
│   ├── build.gradle.kts        ← 版本号在这（每次上游发版都变）
│   ├── lint-baseline.xml       ← 自动生成
│   ├── libs/                   ← sherpa-onnx AAR
│   ├── schemas/                ← Room schema JSON（1…25）
│   └── src/
│       ├── main/assets/dtc/    ← 故障码解码库（models / manuals / rows / texts .tsv）
│       ├── main/kotlin/com/bydmate/app/
│       │   ├── agent/          LLM 智能体（约 36 个工具）
│       │   ├── camera/         盲区摄像头
│       │   ├── cluster/        仪表盘投射 + 方向盘按键（无障碍服务）
│       │   ├── data/
│       │   │   ├── automation/ 规则引擎
│       │   │   ├── autoservice/ADB → 系统 binder（只读）、ADB TLS、ADB 自动恢复、BYD 云
│       │   │   ├── backup/     分部分备份 / 自动备份 / 恢复自检
│       │   │   ├── carstatus/  原车车况（告警、保养）
│       │   │   ├── charging/   充电检测
│       │   │   ├── dtc/        故障码解析与解码
│       │   │   ├── local/      Room + energydata 读取
│       │   │   ├── loop/       自适应轮询
│       │   │   ├── nativestack/实时参数快照、fid 目录解析、EV/混动识别
│       │   │   ├── push/       推送通道（应用侧）
│       │   │   ├── remote/     OpenRouter / ABRP / Webhook / 洞察
│       │   │   ├── repository/ 仓库层
│       │   │   ├── telegram/   Telegram 报告
│       │   │   ├── trips/      行程记录
│       │   │   └── vehicle/    VehicleApi 门面 + 写白名单 + 各类写入 Channel
│       │   ├── di/             Hilt 模块（Room 迁移也在这）
│       │   ├── diagnostics/    日志录制 / Trace
│       │   ├── domain/         计算：能耗 / 续航 / 电价费用 / 行程追踪
│       │   ├── helper/         shell uid 守护进程 ★（push/ dtc/ offreport/）
│       │   ├── hud/            抬头显示
│       │   ├── media/          媒体会话 + 导航通知解析 + 仪表盘音乐卡片
│       │   ├── navdata/        导航指引抽取
│       │   ├── platform/       老车机（Android 10）判断
│       │   ├── service/        前台服务 / 开机自启 / 更新检查
│       │   ├── split/          分屏
│       │   ├── ui/             Compose 界面（tech/ 是技术面板）
│       │   ├── util/           崩溃日志 / GCJ-02 坐标转换等
│       │   └── voice/          俄语 ASR + TTS
│       ├── main/res/values*/   六语言 strings.xml
│       └── test/               696 个测试文件
├── bydauto-stubs/              ← BYD 隐藏框架类的编译期桩（不进 APK）
├── config/detekt/              ← detekt 配置与 baseline
├── docs/
│   ├── PROJECT-OVERVIEW.zh.md  ← 本文（fork 自有）
│   ├── FORK-WORKFLOW.zh.md     ← fork 维护手册（fork 自有）
│   ├── VOICE_COMMANDS.md       语音命令表（俄语）
│   ├── guides/                 DiLink 5 激活 ADB 的 PDF 指南
│   ├── mockups/                HTML 设计稿
│   └── screenshots/
├── scripts/                    prepare-release / agent-eval / fid-record / gen-stubs / fork-sync
├── CHANGELOG.md                （俄语）
└── README.md / .en.md / .zh.md
```

★ = 读代码时建议优先看的地方。

---

## 8. v3.13.1 → v4.3.1 主要变化

40 个版本、684 次非合并提交、1140 个文件变动。按主题归纳：

| 主题 | 版本 | 内容 |
|---|---|---|
| 技术面板 | 3.14 → 4.3 | 从首页电池卡片进入的全屏实时参数页，逐步加入 BMS 限值、电机、胎压示意图、PM2.5、电池满充 / 校准提醒，4.3 成为底部标签 |
| 故障码 | 4.1、4.2 | 读取各 ECU 故障码并按 BYD 手册解码，之后可清除；读码方法来自 denza-lab 项目 |
| 混动 | 4.0 | DM-i / DM-o 自动识别、油量与燃油续航、油耗、油价 |
| 推送通道 | 3.16、3.17.1 | 厂商 listener 事件驱动，转向灯 / 挡位 / 车门等即时响应 |
| ADB 自动恢复 | 3.15 | 应对 2606 以后固件重启关 ADB：无线调试 + TLS 握手自动恢复，自动确认系统对话框 |
| 电价 | 3.17 | 电价历史时间段、追溯重算、充电损耗、按电表读数校准 |
| 备份与 Telegram | 3.18 → 3.20 | 分部分保存 / 恢复配置、定时自动备份、Telegram 机器人（熄火报告、备份、日志、群组） |
| 自动化 | 3.16 → 4.3.1 | "切换"类动作、滑块式参数、分享 / 导入、试运行、排序、一次性条件、驾驶模式、电池预热、屏幕开关、HUD 开关、后标灯等 |
| 语音智能体 | 3.15 → 4.3 | "我在哪""附近充电站"、按名字打断、驾驶员记忆与当日记忆、MiniMax 流式 TTS、离线命令改为固定俄语短语表 |
| 行程 | 3.18.1、4.3 | 行程窗口重做：起止里程、温度、可拖动回放、着色轨迹、海拔、片段统计 |
| 导航器 | 3.15.3 → 3.20 | 路线导航可选 Yandex 导航 / Yandex 地图 / 2GIS / Waze |
| 工程 | — | 新增 `:bydauto-stubs` 模块、detekt、kover、kotest；数据库 v18 → v25；主代码约 6.6 万 → 12 万行 |
