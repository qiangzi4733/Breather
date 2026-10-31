# Breather

一个常驻 macOS 菜单栏、提醒你休息的小工具。

- 工作/休息循环（默认工作 25 分钟、短休息 5 分钟，每 4 轮一次 15 分钟长休息）
- 到点后全屏遮罩覆盖所有显示器，可「推迟」或「跳过」
- 休息建议文案、每日休息统计、登录时自动启动
- 电脑睡眠/合盖足够久，回来后自动从新的工作段开始

需要 macOS 14+、Xcode 16+。

```bash
make run    # 打包成 build/Breather.app 并启动
make test   # 运行单元测试
```

也可以 `open Package.swift` 用 Xcode 打开开发。

## 结构

- `Sources/BreatherCore` 纯逻辑：计时状态机 `BreakScheduler`、设置、统计、文案
- `Sources/Breather` 应用：菜单栏面板、全屏遮罩、设置窗口
- `scripts/build-app.sh` 把可执行文件打包成带签名的 `.app`
