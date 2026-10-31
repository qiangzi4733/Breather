# Breather

一个常驻 macOS 菜单栏、提醒你休息的小工具。专注一段时间后，用全屏遮罩把你从屏幕前「请」走一会儿。

<p align="center">
  <img src="docs/images/overlay.jpg" width="720" alt="休息时的全屏遮罩">
</p>

<p align="center">
  <img src="docs/images/menu.png" width="260" alt="菜单栏面板">
  &nbsp;
  <img src="docs/images/warning.png" width="300" alt="休息前 1 分钟的预告浮窗">
</p>

> 截图由离屏渲染生成，画不出真实的毛玻璃和 Liquid Glass 效果，按钮底色在截图里会偏淡。

## 功能

- **专注 / 休息循环**：默认专注 25 分钟、短休息 5 分钟，每 4 段来一次 15 分钟长休息，时长都可调
- **休息前 1 分钟预告**：右上角弹出小浮窗，可以先推迟或直接开始休息；浮窗不抢焦点，正在打的字不会被打断
- **全屏休息遮罩**：覆盖所有显示器，也能盖在全屏应用上，附带放松眼睛、伸展身体的小建议；可「推迟」或「跳过」
- **知道你不在**：
  - 离开电脑超过一次长休息的时长，当作已经休息过，回来后重新开始一轮
  - 休息结束时人不在，等你回来再开始计时
  - 播放视频、开会等阻止显示器休眠时，不会误判成离开
  - 睡眠、合盖同理
- **菜单栏倒计时**：面板里可暂停、立即休息、重新计时，查看今天完成 / 推迟 / 跳过的次数
- **统计**：最近 7 天的完成情况和完成率
- **登录时打开**

<p align="center">
  <img src="docs/images/settings.png" width="360" alt="设置">
  &nbsp;
  <img src="docs/images/stats.png" width="360" alt="统计">
</p>

## 安装

目前没有发布编译好的版本，需要从源码构建。

要求：macOS 14 或更高版本；构建需要 Xcode 26 或更高版本（用到了 macOS 26 的 Liquid Glass API，在旧系统上运行时会自动退回半透明材质）。

```bash
git clone https://github.com/qiangzi4733/Breather.git
cd Breather
make run
```

`make run` 会生成 `build/Breather.app` 并启动，它只出现在菜单栏，不会出现在程序坞。想长期使用，把它拖进「应用程序」文件夹，再在设置里打开「登录时打开」。

应用只做了本地 ad-hoc 签名，没有公证。在自己电脑上构建的可以直接运行；拷到其他 Mac 上，第一次打开时 Gatekeeper 会拦截，需要在「系统设置 › 隐私与安全性」里允许。

## 隐私

- 不联网，不收集任何数据
- 设置和统计只保存在本机的 `UserDefaults`（域名 `app.breather.Breather`）
- 空闲检测只读取「距上次键鼠操作过了多少秒」，不记录任何按键内容，也不需要辅助功能权限

## 开发

```bash
make test                     # 单元测试（Swift Testing）
make run                      # 打包 build/Breather.app 并重启运行
make icon                     # 重新生成 Resources/AppIcon.icns
build/Breather.app/Contents/MacOS/Breather --snapshot <目录>   # 离屏渲染各界面 PNG（浅色 + 深色）
```

项目用 Swift Package Manager 组织，没有 `.xcodeproj`。需要用 Xcode 时执行 `open Package.swift`。

- `Sources/BreatherCore`：纯逻辑，不依赖 AppKit。计时状态机 `BreakScheduler` 不持有时钟，由外部每秒推进，睡眠、空闲、预告的判断都在这里，便于测试
- `Sources/Breather`：应用本体，包括菜单栏面板、预告浮窗、全屏遮罩、设置窗口
- `scripts/build-app.sh`：把 SwiftPM 编译出的可执行文件打包成带签名的 `.app`
- `Tests/BreatherCoreTests`：状态机和统计的单元测试

更详细的实现约定和踩过的坑见 [CLAUDE.md](CLAUDE.md)。

## 许可证

[MIT](LICENSE)
