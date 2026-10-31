import BreatherCore
import SwiftUI

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        Image(nsImage: rendered)
    }

    /// 菜单栏标签里文字内嵌的图片不会被画出来，所以把「图标 + 倒计时」整体画成模板图片，
    /// 模板图片还会自动跟随菜单栏的深浅色
    private var rendered: NSImage {
        let content = HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
            if model.settings.showCountdownInMenuBar {
                Text(model.remainingText)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.black)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }

    private var symbol: String {
        if model.scheduler.isOnBreak { return "figure.walk" }
        if model.scheduler.isPaused { return "pause.circle" }
        return "cup.and.saucer"
    }
}

struct MenuBarView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss

    private var scheduler: BreakScheduler { model.scheduler }
    private var tint: Color { scheduler.isPaused ? .secondary : scheduler.phase.tint }

    var body: some View {
        VStack(spacing: 10) {
            header
                .padding(14)
                .moduleBackground()

            controls
                .padding(.vertical, 12)
                .moduleBackground()

            today
                .padding(14)
                .moduleBackground()

            VStack(spacing: 0) {
                MenuRow(title: "设置…", shortcut: "⌘,") {
                    dismiss()
                    model.openSettings()
                }
                .keyboardShortcut(",")
                MenuRow(title: "退出 Breather", shortcut: "⌘Q") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(.top, 2)
        }
        .padding(10)
        .frame(width: 300)
    }

    // MARK: 头部：圆环 + 倒计时

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: scheduler.progress, lineWidth: 6, tint: tint)
                Image(systemName: headerSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(model.remainingText)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: model.remainingText)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var headerSymbol: String {
        if scheduler.isOnBreak { return "figure.walk" }
        if scheduler.isPaused { return "pause.fill" }
        return "cup.and.saucer.fill"
    }

    private var statusTitle: String {
        if case .onBreak(let kind) = scheduler.phase { return "\(kind.displayName)中" }
        if scheduler.isPaused { return "已暂停" }
        return scheduler.isPostponed ? "已推迟" : "距离下次休息"
    }

    private var statusDetail: String {
        if scheduler.isOnBreak { return "离开屏幕，活动一下吧" }
        let next = scheduler.upcomingBreak
        let minutes = Int(model.settings.breakDuration(next) / 60)
        return "接下来 · \(next.displayName) \(minutes) 分钟"
    }

    // MARK: 控制按钮

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 0) {
            if scheduler.isOnBreak {
                CircleIconButton(symbol: "clock.arrow.circlepath", title: "推迟 \(model.settings.postponeMinutes) 分钟", action: model.postponeBreak)
                CircleIconButton(symbol: "forward.end.fill", title: "跳过休息", action: model.skipBreak)
            } else {
                CircleIconButton(
                    symbol: scheduler.isPaused ? "play.fill" : "pause.fill",
                    title: scheduler.isPaused ? "继续" : "暂停",
                    isOn: scheduler.isPaused,
                    tint: .orange,
                    action: model.togglePause
                )
                CircleIconButton(symbol: "cup.and.saucer.fill", title: "现在休息", action: model.startBreakNow)
                CircleIconButton(symbol: "arrow.counterclockwise", title: "重新计时", action: model.restartWork)
            }
        }
    }

    // MARK: 今日统计 + 循环进度

    private var today: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("今天")
                    .font(.headline)
                Spacer()
                Text(cycleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            CycleIndicator(scheduler: scheduler, tint: tint)
            HStack(spacing: 0) {
                stat("完成", model.todayStats.completed, color: .mint)
                stat("推迟", model.todayStats.postponed, color: .orange)
                stat("跳过", model.todayStats.skipped, color: .secondary)
            }
        }
    }

    private var cycleText: String {
        if scheduler.phase == .onBreak(.long) { return "本轮完成" }
        let left = scheduler.sessionsUntilLongBreak
        return left == 1 ? "这一段后长休息" : "再专注 \(left) 段长休息"
    }

    private func stat(_ title: String, _ value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
