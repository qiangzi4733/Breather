import AppKit
import BreatherCore
import SwiftUI

/// 用示例数据把各个界面离屏渲染成 PNG（浅色 + 深色），方便不打开 App 也能检查 UI。
/// 注意：离屏渲染不会画出窗口背后的模糊和玻璃折射效果。
@MainActor
enum Snapshot {
    static func run(outputDirectory dir: URL) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var working = BreakScheduler(settings: .default)
        working.startBreakNow()
        working.skipBreak()
        working.advance(by: 9 * 60 + 18)
        let workingModel = AppModel(scheduler: working, stats: sampleStats(), isLive: false)

        var onBreak = working
        onBreak.startBreakNow()
        onBreak.advance(by: 104)
        let breakModel = AppModel(scheduler: onBreak, stats: sampleStats(), isLive: false)

        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            render(MenuBarView(model: workingModel), name: "menu-\(name)", appearance: appearance, to: dir)
            render(MenuBarView(model: breakModel), name: "menu-break-\(name)", appearance: appearance, to: dir)
            render(GeneralSettingsView(model: workingModel).frame(width: settingsSize.width, height: settingsSize.height), name: "settings-general-\(name)", appearance: appearance, to: dir)
            render(StatsView(model: workingModel).frame(width: settingsSize.width, height: settingsSize.height), name: "settings-stats-\(name)", appearance: appearance, to: dir)
            render(AboutView().frame(width: settingsSize.width, height: settingsSize.height), name: "settings-about-\(name)", appearance: appearance, to: dir)
        }

        var longBreak = BreakScheduler(settings: BreakSettings(longBreakEvery: 2))
        longBreak.startBreakNow()
        longBreak.skipBreak()
        longBreak.startBreakNow()
        longBreak.advance(by: 312)
        let longBreakModel = AppModel(scheduler: longBreak, stats: sampleStats(), isLive: false)

        for (name, model) in [("overlay", breakModel), ("overlay-long", longBreakModel)] {
            // 遮罩下面垫一张近似桌面的深色渐变，模拟模糊后的壁纸
            let overlay = ZStack {
                LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.24), Color(red: 0.22, green: 0.2, blue: 0.3)], startPoint: .top, endPoint: .bottom)
                BreakOverlayView(model: model)
            }
            .frame(width: 1440, height: 900)
            render(overlay, name: name, appearance: .darkAqua, to: dir)
        }

        print("Snapshots written to \(dir.path)")
    }

    private static func sampleStats() -> BreakStats {
        var stats = BreakStats()
        let samples: [(completed: Int, postponed: Int, skipped: Int)] = [(6, 1, 1), (4, 2, 0), (7, 0, 1), (3, 1, 2), (5, 1, 0), (8, 0, 0), (3, 1, 0)]
        for (offset, day) in samples.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: offset - 6, to: Date())!
            for _ in 0..<day.completed { stats.record(.completed, on: date) }
            for _ in 0..<day.postponed { stats.record(.postponed, on: date) }
            for _ in 0..<day.skipped { stats.record(.skipped, on: date) }
        }
        return stats
    }

    private static func render(_ view: some View, name: String, appearance: NSAppearance.Name, to dir: URL) {
        // cacheDisplay 不画窗口底色，垫一层，否则透明背景上看不出深色模式
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: appearance)
        host.frame = CGRect(origin: .zero, size: host.fittingSize)

        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.backgroundColor = .windowBackgroundColor
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -30000, y: -30000))
        window.orderFrontRegardless()

        // 让 SwiftUI 完成布局和首帧渲染
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }
        window.orderOut(nil)
    }
}
