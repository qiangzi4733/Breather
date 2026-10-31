// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Breather",
    platforms: [.macOS(.v14)],
    targets: [
        // 纯逻辑：计时状态机、设置、统计，不依赖 AppKit，便于测试
        .target(name: "BreatherCore"),
        // 菜单栏应用本体
        .executableTarget(name: "Breather", dependencies: ["BreatherCore"]),
        .testTarget(name: "BreatherCoreTests", dependencies: ["BreatherCore"]),
    ]
)
