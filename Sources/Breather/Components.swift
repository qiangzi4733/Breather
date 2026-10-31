import BreatherCore
import SwiftUI

// MARK: - 配色

extension Phase {
    /// 专注用系统强调色，休息用薄荷绿
    var tint: Color {
        switch self {
        case .working: .accentColor
        case .onBreak: .mint
        }
    }
}

extension BreakKind {
    var displayName: String {
        switch self {
        case .short: "短休息"
        case .long: "长休息"
        }
    }
}

// MARK: - 进度圆环

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat
    var tint: Color
    var track: Color = .primary.opacity(0.1)

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // 圆头线帽在长度为 0 时仍会画出一个点
                .opacity(progress > 0 ? 1 : 0)
        }
        .animation(.linear(duration: 1), value: progress)
    }
}

// MARK: - 循环进度：一排小胶囊表示这一轮里完成了几段专注

struct CycleIndicator: View {
    let scheduler: BreakScheduler
    var tint: Color

    var body: some View {
        let total = max(1, scheduler.settings.longBreakEvery)
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(color(for: index, total: total))
                    .frame(height: 4)
            }
        }
    }

    private func color(for index: Int, total: Int) -> Color {
        let done: Int
        if scheduler.phase == .onBreak(.long) {
            done = total
        } else {
            let remainder = scheduler.workSessionsCompleted % total
            done = remainder == 0 && scheduler.isOnBreak ? total : remainder
        }
        if index < done { return tint }
        if index == done && !scheduler.isOnBreak { return tint.opacity(0.4) }
        return .primary.opacity(0.1)
    }
}

// MARK: - 控制中心风格的圆形按钮

struct CircleIconButton: View {
    let symbol: String
    let title: String
    var isOn = false
    var tint: Color = .accentColor
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(isHovering ? 0.16 : 0.09)))
                    }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 原生菜单样式的行：悬停时强调色高亮

struct MenuRow: View {
    let title: String
    var shortcut: String?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .foregroundStyle(isHovering ? Color.white.opacity(0.8) : Color.secondary)
                }
            }
            .foregroundStyle(isHovering ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.accentColor : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - 系统设置风格的彩色图标块

struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

// MARK: - 卡片与玻璃效果

extension View {
    /// 控制中心里的模块底色
    func moduleBackground(cornerRadius: CGFloat = 14) -> some View {
        background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// macOS 26 上使用 Liquid Glass，旧系统退回到半透明材质
    @ViewBuilder
    func glassCircle() -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: .circle)
        } else {
            background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }
}
