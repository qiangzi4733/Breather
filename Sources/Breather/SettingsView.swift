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
            let tabs = SettingsTabViewController()
            tabs.tabStyle = .toolbar
            tabs.transitionOptions = [.allowUserInteraction, .crossfade]
            tabs.addTabViewItem(Self.tab(GeneralSettingsView(model: model), label: "通用", symbol: "gearshape"))
            tabs.addTabViewItem(Self.tab(StatsView(model: model), label: "统计", symbol: "chart.bar.xaxis"))
            tabs.addTabViewItem(Self.tab(AboutView(), label: "关于", symbol: "info.circle"))

            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable]
            window.toolbarStyle = .preference
            window.title = tabs.tabViewItems.first?.label ?? ""
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        model.refreshLaunchAtLogin()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private static func tab(_ view: some View, label: String, symbol: String) -> NSTabViewItem {
        let host = NSHostingController(rootView: view)
        host.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: host)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

/// 窗口标题跟随当前标签页，和系统设置窗口一致
private final class SettingsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        view.window?.title = tabViewItem?.label ?? ""
    }
}

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
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("提醒") {
                row("clock.arrow.circlepath", .pink, "推迟时长") {
                    minutes(binding(\.postponeMinutes), in: 1...30)
                }
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
        .frame(width: 500, height: 600)
    }

    private func row(_ symbol: String, _ color: Color, _ title: String, @ViewBuilder trailing: () -> some View) -> some View {
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

    private func stepper(_ text: String, _ value: Binding<Int>, in range: ClosedRange<Int>) -> some View {
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
    private func toggle(_ title: String, _ isOn: Binding<Bool>) -> some View {
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

    private struct Bar: Identifiable {
        let id = UUID()
        let day: Date
        let outcome: String
        let count: Int
    }

    private var week: [(date: Date, stats: DayStats)] {
        model.stats.recentDays(7, endingAt: Date())
    }

    private var bars: [Bar] {
        week.flatMap { day, stats in
            [
                Bar(day: day, outcome: "完成", count: stats.completed),
                Bar(day: day, outcome: "推迟", count: stats.postponed),
                Bar(day: day, outcome: "跳过", count: stats.skipped),
            ]
        }
    }

    private var weekSummary: String {
        let completed = week.reduce(0) { $0 + $1.stats.completed }
        let total = week.reduce(0) { $0 + $1.stats.completed + $1.stats.skipped }
        guard total > 0 else { return "还没有休息记录" }
        return "共完成 \(completed) 次 · 完成率 \(completed * 100 / total)%"
    }

    var body: some View {
        let today = model.todayStats
        Form {
            Section("今天") {
                HStack(spacing: 0) {
                    tile("checkmark.circle.fill", .mint, today.completed, "完成")
                    Divider().frame(height: 36)
                    tile("clock.arrow.circlepath", .orange, today.postponed, "推迟")
                    Divider().frame(height: 36)
                    tile("forward.end.fill", .gray, today.skipped, "跳过")
                }
                .padding(.vertical, 6)
            }

            Section {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("日期", bar.day, unit: .day),
                        y: .value("次数", bar.count),
                        width: .ratio(0.5)
                    )
                    .foregroundStyle(by: .value("结果", bar.outcome))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale(["完成": Color.mint, "推迟": Color.orange, "跳过": Color.gray.opacity(0.6)])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)
                .padding(.vertical, 6)
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text("最近 7 天")
                    Spacer()
                    Text(weekSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 470)
    }

    private func tile(_ symbol: String, _ color: Color, _ value: Int, _ title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 关于

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
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
        .frame(width: 500, height: 300)
    }
}
