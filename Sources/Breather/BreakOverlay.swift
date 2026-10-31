import AppKit
import BreatherCore
import SwiftUI

/// 休息时覆盖所有显示器的全屏遮罩
@MainActor
final class BreakOverlayController {
    private var windows: [NSWindow] = []
    private weak var model: AppModel?

    init() {
        // 休息期间插拔显示器，重新铺满所有屏幕
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.windows.isEmpty, let model = self.model else { return }
                self.show(model: model, animated: false)
            }
        }
    }

    func show(model: AppModel, animated: Bool = true) {
        removeWindows()
        self.model = model

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.setFrame(screen.frame, display: false)
            window.hidesOnDeactivate = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false

            let blur = NSVisualEffectView()
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.appearance = NSAppearance(named: .darkAqua)

            let host = NSHostingView(rootView: BreakOverlayView(model: model))
            host.frame = blur.bounds
            host.autoresizingMask = [.width, .height]
            blur.addSubview(host)
            window.contentView = blur

            window.alphaValue = animated ? 0 : 1
            window.orderFrontRegardless()
            windows.append(window)
        }

        // 不激活整个 App：激活会把用户从全屏应用的空间切到 Breather 其他窗口所在的桌面
        windows.first?.makeKey()

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.6
                for window in windows { window.animator().alphaValue = 1 }
            }
        }
    }

    func hide() {
        let closing = windows
        windows.removeAll()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            for window in closing { window.animator().alphaValue = 0 }
        } completionHandler: {
            MainActor.assumeIsolated {
                for window in closing { window.orderOut(nil) }
            }
        }
    }

    private func removeWindows() {
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
    }
}

/// 不激活 App 的面板，按钮照样能点，也能盖在全屏应用上面。
/// 无边框窗口默认不能成为 key window，按钮会点不动
private final class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct BreakOverlayView: View {
    let model: AppModel

    @State private var isBreathing = false

    private var scheduler: BreakScheduler { model.scheduler }
    private var kind: BreakKind {
        if case .onBreak(let kind) = scheduler.phase { kind } else { .short }
    }

    var body: some View {
        ZStack {
            AmbientBackground(kind: kind)

            VStack(spacing: 0) {
                Spacer()

                // 跟着呼吸节奏缓慢缩放的建议图标
                Image(systemName: model.currentTip.symbol)
                    .font(.system(size: 34, weight: .medium))
                    .frame(width: 88, height: 88)
                    .glassCircle()
                    .scaleEffect(isBreathing ? 1.06 : 0.94)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isBreathing)

                Text(kind == .long ? "好好休息一会儿" : "休息一下吧")
                    .font(.system(size: 40, weight: .bold))
                    .padding(.top, 28)

                Text(model.currentTip.text)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                    .padding(.top, 10)

                ZStack {
                    ProgressRing(progress: scheduler.progress, lineWidth: 8, tint: .white, track: .white.opacity(0.14))
                    VStack(spacing: 4) {
                        Text(model.remainingText)
                            .font(.system(size: 72, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.default, value: model.remainingText)
                        Text("\(kind.displayName) · \(Int(model.settings.breakDuration(kind) / 60)) 分钟")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(width: 280, height: 280)
                .padding(.vertical, 48)

                HStack(spacing: 14) {
                    Button(action: model.postponeBreak) {
                        Label("推迟 \(model.settings.postponeMinutes) 分钟", systemImage: "clock.arrow.circlepath")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    Button(action: model.skipBreak) {
                        Label("跳过", systemImage: "forward.end.fill")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                }
                .font(.title3.weight(.medium))
                .controlSize(.extraLarge)
                .glassButton()

                Spacer()

                Text("今天已完成 \(model.todayStats.completed) 次休息")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 40)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isBreathing = true }
    }
}

/// 模糊背景上缓慢漂移的柔和色块，短休息偏青绿，长休息偏靛紫
private struct AmbientBackground: View {
    let kind: BreakKind

    @State private var drift = false

    private var colors: [Color] {
        kind == .long ? [.indigo, .purple, .pink] : [.teal, .mint, .blue]
    }

    var body: some View {
        GeometryReader { geo in
            let size = max(geo.size.width, geo.size.height)
            ZStack {
                Color.black.opacity(0.3)
                glow(colors[0], diameter: size * 0.8)
                    .offset(x: drift ? -size * 0.16 : -size * 0.26, y: drift ? -size * 0.1 : -size * 0.18)
                glow(colors[1], diameter: size * 0.7)
                    .offset(x: drift ? size * 0.24 : size * 0.14, y: drift ? size * 0.14 : size * 0.04)
                glow(colors[2], diameter: size * 0.6)
                    .offset(x: drift ? size * 0.04 : size * 0.18, y: drift ? -size * 0.22 : -size * 0.08)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
    }

    /// 径向渐变自带柔和边缘，不需要对整屏做模糊
    private func glow(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.4), color.opacity(0)], center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
    }
}
