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
        if model.scheduler.away != nil { return "moon.zzz" }
        if model.scheduler.isWarning { return "bell" }
        return "cup.and.saucer"
    }
}

struct MenuBarView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss

    private var scheduler: BreakScheduler { model.scheduler }
    private var tint: Color { scheduler.isPaused || scheduler.away != nil ? .secondary : scheduler.phase.tint }

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
                ProgressRing(progress: scheduler.remainingFraction, lineWidth: 6, tint: tint)
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
        if scheduler.away != nil { return "moon.zzz.fill" }
        return "cup.and.saucer.fill"
    }

    private var statusTitle: String {
        if case .onBreak(let kind) = scheduler.phase {
            return kind == .long ? String(localized: "长休息中") : String(localized: "短休息中")
        }
        if scheduler.isPaused { return String(localized: "已暂停") }
        switch scheduler.away {
        case .idle: return String(localized: "你离开了一会儿")
        case .afterBreak: return String(localized: "休息结束")
        case nil: return scheduler.isPostponed ? String(localized: "已推迟") : String(localized: "距离下次休息")
        }
    }

    private var statusDetail: String {
        if scheduler.isOnBreak { return String(localized: "离开屏幕，活动一下吧") }
        switch scheduler.away {
        case .idle: return String(localized: "回来后重新开始一轮")
        case .afterBreak: return String(localized: "回来后开始下一段专注")
        case nil: break
        }
        let next = scheduler.upcomingBreak
        let minutes = Int(model.settings.breakDuration(next) / 60)
        // 英文语序和中文不同，长短休息各用一句完整的文案，不拼接 displayName
        return next == .long
            ? String(localized: "接下来 · 长休息 \(minutes) 分钟")
            : String(localized: "接下来 · 短休息 \(minutes) 分钟")
    }

    // MARK: 控制按钮

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 0) {
            if scheduler.isOnBreak {
                // 休息时全屏遮罩连菜单栏一起盖住，面板里的按钮点不到，推迟和跳过只在遮罩上操作
                Label("推迟或跳过请在休息画面上操作", systemImage: "rectangle.inset.filled")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
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
        if scheduler.phase == .onBreak(.long) { return String(localized: "本轮完成") }
        let left = scheduler.sessionsUntilLongBreak
        return left == 1 ? String(localized: "这一段后长休息") : String(localized: "再专注 \(left) 段长休息")
    }

    private func stat(_ title: LocalizedStringKey, _ value: Int, color: Color) -> some View {
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
