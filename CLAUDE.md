# Breather

常驻 macOS 菜单栏的休息提醒应用（SwiftUI + AppKit，SwiftPM 组织，macOS 14+）。用户是中文使用者，界面文案、代码注释、提交信息都用中文。

## 常用命令

```bash
make test                     # 单元测试（Swift Testing，只覆盖 BreatherCore）
make run                      # 打包 build/Breather.app 并重启运行
make icon                     # 重新生成 Resources/AppIcon.icns
build/Breather.app/Contents/MacOS/Breather --snapshot <目录>   # 离屏渲染各界面 PNG（浅色+深色）
```

没有 .xcodeproj：`scripts/build-app.sh` 把 SwiftPM 产物打包成 `.app`、拷入 Info.plist 和图标、ad-hoc 签名。需要 Xcode 时 `open Package.swift`。

## 结构

- `Sources/BreatherCore`：纯逻辑，不依赖 AppKit。`BreakScheduler` 是不持有时钟的状态机，由外部每秒调用 `tick(elapsed:)`；睡眠检测（间隔够一次长休息就重置循环、暂停中保持暂停）、空闲检测（`tick(elapsed:idle:)` 传入距上次键鼠操作的秒数，离开状态见 `away`）、休息前预告（`isWarning`）也在这里。逻辑改动优先放这里并补测试。
- `Sources/Breather`：`AppModel`（@Observable，计时循环、持久化到 UserDefaults、开机自启）、`MenuBarView`、`BreakOverlay`、`BreakWarning`（休息前预告浮窗）、`UserPresence`（读取空闲时间和阻止显示器休眠的电源断言）、`SettingsView`、共用组件 `Components.swift`、`Snapshot.swift`。
- `AppModel(scheduler:stats:isLive: false)` 不计时、不弹窗、不写磁盘，供快照使用。

## 踩过的坑（改相关代码前先看）

- **休息遮罩必须是 `.nonactivatingPanel` 的 NSPanel，且不能调用 `NSApp.activate()`**：激活 App 会把用户从全屏应用的空间拽到 Breather 其他窗口所在的桌面。
- **菜单栏标签不渲染 `Text` 里内嵌的 `Image`**：`MenuBarLabel` 用 `ImageRenderer` 画成模板图片再显示。
- **设置窗口标题**来自 `NSTabViewController` 同步选中页的 `title`，每个 `NSHostingController` 都要设 `title`，否则显示「未命名」。手动改 `window.title` 会在窗口重新打开后被覆盖。
- **三个设置标签页统一使用 `settingsSize`**，避免切换时窗口高度跳动；新增标签页也用这个尺寸。
- **开关样式的 `Toggle`** 必须有非空标签（`.labelsHidden()` 隐藏），并显式加 `.accessibilityAction`，否则 VoiceOver 拨不动。
- **表单里 `LabeledContent` 的值文字默认可选中**，需要 `.textSelection(.disabled)`。
- **`ProgressRing` 用圆头线帽**，进度为 0 时要隐藏，否则残留一个点。圆环表示剩余时间（`remainingFraction`，从 1 到 0）。
- 休息期间遮罩盖住菜单栏，所以面板在休息时只显示状态，推迟/跳过只在遮罩上。
- 离屏快照画不出窗口背后的模糊和 Liquid Glass，玻璃按钮在快照里只剩文字；真实效果要在真机上看。
- **休息前预告浮窗不主动成为 key window**（不抢用户正在打字的焦点），系统按钮在非 key 窗口里会画成失活的灰色，所以浮窗按钮自己画底色。
- 空闲检测：专注时无键鼠操作 ≥ 一次长休息的时长就冻结计时（菜单栏显示月亮），休息结束时人不在也会冻结。有程序阻止显示器休眠（视频、会议）时不算空闲。真机测试时如果自己一直不动，计时会停住，属于正常行为。

## 真机测试

- Info.plist 里 `LSUIElement = true`，电脑操控（computer use）的后台工具找不到这类应用。需要用 `app_*` 工具时，复制一份到 `~/Applications`，把副本的 `LSUIElement` 改成 false 并重新 `codesign --force --sign -`，测完删掉。正式版的菜单栏图标只能用全屏控制点击。
- 测自然到点的流程时，把 `defaults` 里的 settings 临时改短（专注至少 2 分钟，否则看不到 1 分钟预告）。**先 `defaults export app.breather.Breather <备份>`，测完 `defaults import` 恢复**，用户的设置和统计都存在这个域里。
- 需要用户自己测的：多显示器、提示音、真实睡眠/合盖、注销后开机自启、其他 Mac 上的签名/公证。
