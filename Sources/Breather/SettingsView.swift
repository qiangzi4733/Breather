import AppKit
import BreatherCore
import Charts
import SwiftUI

/// 用原生工具栏标签页的设置窗口，和系统自带 App 的「设置」一致
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            tabs.transitionOptions = [.allowUserInteraction, .crossfade]
            tabs.addTabViewItem(Self.tab(GeneralSettingsView(model: model), label: String(localized: "通用"), symbol: "gearshape"))
            tabs.addTabViewItem(Self.tab(StatsView(model: model), label: String(localized: "统计"), symbol: "chart.bar.xaxis"))
            tabs.addTabViewItem(Self.tab(AboutView(), label: String(localized: "关于"), symbol: "info.circle"))

            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable]
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        model.refreshLaunchAtLogin()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private static func tab(_ view: some View, label: String, symbol: String) -> NSTabViewItem {
        let host = NSHostingController(rootView: view.frame(width: settingsSize.width, height: settingsSize.height))
        host.sizingOptions = .preferredContentSize
        // 标签页控制器会把选中页的 title 同步成窗口标题，不设就显示「未命名」
        host.title = label
        let item = NSTabViewItem(viewController: host)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

/// 所有标签页同一尺寸，切换时窗口不会忽高忽低
let settingsSize = CGSize(width: 500, height: 600)

// MARK: - 通用

struct GeneralSettingsView: View {
    let model: AppModel

    private var settings: BreakSettings { model.settings }

    var body: some View {
        Form {
            Section {
                row("macbook", .blue, "专注时长") {
                    minutes(binding(\.workMinutes), in: 1...180)
                }
                row("cup.and.saucer.fill", .mint, "短休息") {
                    minutes(binding(\.shortBreakMinutes), in: 1...60)
                }
                row("sofa.fill", .indigo, "长休息") {
                    minutes(binding(\.longBreakMinutes), in: 1...120)
                }
                row("repeat", .orange, "长休息间隔") {
                    stepper("每 \(settings.longBreakEvery) 段", binding(\.longBreakEvery), in: 2...12)
                }
            } header: {
                Text("计时")
            } footer: {
                Text("每专注 \(settings.workMinutes) 分钟休息 \(settings.shortBreakMinutes) 分钟，每 \(settings.longBreakEvery) 段后休息 \(settings.longBreakMinutes) 分钟。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                row("bell.fill", .red, "休息前 1 分钟提醒") {
                    toggle("休息前 1 分钟提醒", binding(\.warnBeforeBreak))
                }
                row("clock.arrow.circlepath", .pink, "推迟时长") {
                    minutes(binding(\.postponeMinutes), in: 1...30)
                }
            } header: {
                Text("提醒")
            } footer: {
                Text("离开电脑超过一次长休息的时长，会当作已经休息过，回来后重新开始一轮。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                row("menubar.rectangle", .gray, "在菜单栏显示倒计时") {
                    toggle("在菜单栏显示倒计时", binding(\.showCountdownInMenuBar))
                }
                row("power", .green, "登录时打开") {
                    toggle("登录时打开", Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                }
            } header: {
                Text("通用")
            } footer: {
                if let error = model.launchAtLoginError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("恢复默认设置") { model.update(settings: .default) }
                        .disabled(settings == .default)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ symbol: String, _ color: Color, _ title: LocalizedStringKey, @ViewBuilder trailing: () -> some View) -> some View {
        LabeledContent {
            trailing()
        } label: {
            HStack(spacing: 10) {
                IconTile(symbol: symbol, color: color)
                Text(title)
            }
        }
    }

    private func minutes(_ value: Binding<Int>, in range: ClosedRange<Int>) -> some View {
        stepper("\(value.wrappedValue) 分钟", value, in: range)
    }

    private func stepper(_ text: LocalizedStringKey, _ value: Binding<Int>, in range: ClosedRange<Int>) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                // 表单里 LabeledContent 的值默认可以被选中，系统设置里不会这样
                .textSelection(.disabled)
            Stepper(text, value: value, in: range)
                .labelsHidden()
        }
    }

    // 标签只是隐藏，不能留空，VoiceOver 靠它读出开关名称。
    // 开关样式的 Toggle 收到辅助功能的「按下」不会切换，VoiceOver 用户就拨不动它，所以显式补上
    private func toggle(_ title: LocalizedStringKey, _ isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityAction { isOn.wrappedValue.toggle() }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<BreakSettings, T>) -> Binding<T> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                var settings = model.settings
                settings[keyPath: keyPath] = newValue
                model.update(settings: settings)
            }
        )
    }
}

// MARK: - 统计

struct StatsView: View {
    let model: AppModel

    private struct Day: Identifiable {
        let date: Date
        let stats: DayStats
        var id: Date { date }
    }

    private var week: [Day] {
        model.stats.recentDays(7, endingAt: model.today).map { Day(date: $0.date, stats: $0.stats) }
    }

    var body: some View {
        let week = week
        let summary = StatsSummary(week.map(\.stats))

        Form {
            Section {
                todaySummary
                    .padding(.vertical, 8)
            }

            Section("最近 7 天") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        metric("日均完成", averageText(summary.dailyAverage))
                        Spacer()
                        metric("准时率", rateText(summary.onTimeRate), alignment: .center)
                        Spacer()
                        metric("完成率", rateText(summary.completionRate), alignment: .trailing)
                    }
                    chart(week, average: summary.dailyAverage)
                    HStack(spacing: 14) {
                        legend(Self.onTimeColor, "准时完成")
                        legend(Self.lateColor, "推迟后完成")
                        legend(Self.skippedColor, "跳过")
                        if summary.dailyAverage != nil {
                            HStack(spacing: 5) {
                                Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: 14, y: 0)) }
                                    .stroke(Color.secondary, style: Self.averageLineStyle)
                                    .frame(width: 14, height: 1)
                                Text("日均")
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text("日均只计算有休息记录的日子")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: 今天

    private var todaySummary: some View {
        let today = model.todayStats
        let rate = StatsSummary([today]).completionRate
        return HStack(spacing: 18) {
            // 标签放在圆环外面，英文「Completion rate」塞不进圆环
            VStack(spacing: 6) {
                ZStack {
                    ProgressRing(progress: rate ?? 0, lineWidth: 8, tint: .mint)
                    Text(rateText(rate))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 72, height: 72)
                Text("完成率")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("今天")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("完成 \(today.completed) 次休息")
                    .font(.title2.weight(.semibold))
                // 三项互不重叠，加起来就是今天到点的休息次数
                Text("准时 \(today.completedOnTime) · 推迟后完成 \(today.completedAfterPostpone) · 跳过 \(today.skipped)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 图表：从下到上依次是准时完成、推迟后完成、跳过，整根柱子是到点的休息

    private static let onTimeColor = Color.mint
    private static let lateColor = Color.orange
    private static let skippedColor = Color.primary.opacity(0.12)

    private func chart(_ week: [Day], average: Double?) -> some View {
        let peak = week.map(\.stats.due).max() ?? 0
        return Chart {
            ForEach(week) { day in
                // 不堆叠、从高到低依次画，矮的盖在高的上面
                bar(day, "到点", day.stats.due, Self.skippedColor)
                bar(day, "完成", day.stats.completed, Self.lateColor.gradient)
                bar(day, "准时完成", day.stats.completedOnTime, Self.onTimeColor.gradient)
            }

            if let average {
                RuleMark(y: .value("日均", average))
                    .lineStyle(Self.averageLineStyle)
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYScale(domain: 0...max(4, Double(peak) * 1.15))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        if Calendar.current.isDate(date, inSameDayAs: model.today) {
                            Text("今天")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        } else {
                            Text(date, format: .dateTime.weekday(.narrow))
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel()
            }
        }
        .frame(height: 210)
        .overlay {
            if peak == 0 {
                Text("还没有休息记录")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bar(_ day: Day, _ label: LocalizedStringKey, _ value: Int, _ style: some ShapeStyle) -> some ChartContent {
        BarMark(
            x: .value("日期", day.date, unit: .day),
            y: .value(label, value),
            width: .ratio(0.42),
            stacking: .unstacked
        )
        .foregroundStyle(style)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private static let averageLineStyle = StrokeStyle(lineWidth: 1, dash: [4, 3])

    private func metric(_ title: LocalizedStringKey, _ value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private func legend(_ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
        }
    }

    private func averageText(_ average: Double?) -> String {
        guard let average else { return "—" }
        return String(localized: "\(average, format: .number.precision(.fractionLength(1))) 次")
    }

    private func rateText(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return "\(Int((rate * 100).rounded(.down)))%"
    }
}

// MARK: - 关于

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(localized: "开发版")
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text("Breather")
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 4)
            Text("版本 \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("专注之后，记得好好休息。")
                .font(.callout)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
