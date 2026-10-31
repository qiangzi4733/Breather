import AppKit
import BreatherCore
import SwiftUI

/// 休息前 1 分钟在屏幕右上角弹出的预告浮窗。
/// 和休息遮罩一样不激活 App，也不主动成为 key window，用户正在打的字不会被它截走
@MainActor
final class BreakWarningController {
    private var panel: NSPanel?

    var isVisible: Bool { panel != nil }

    func show(model: AppModel) {
        guard panel == nil else { return }

        let host = NSHostingView(rootView: BreakWarningView(model: model))
        host.setFrameSize(host.fittingSize)

        let panel = WarningPanel(
            contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.hidesOnDeactivate = false
        // 浮窗里没有输入框，点按钮时也不需要成为 key window
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        // 放在主屏（带菜单栏的那块）右上角，和系统通知的位置一致
        if let screen = NSScreen.screens.first {
            let visible = screen.visibleFrame
            let size = host.fittingSize
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 12, y: visible.maxY - size.height - 12))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1
        }
        self.panel = panel
    }

    func hide() {
        guard let closing = panel else { return }
        panel = nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            closing.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { closing.orderOut(nil) }
        }
    }
}

private final class WarningPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct BreakWarningView: View {
    let model: AppModel

    private var kind: BreakKind { model.scheduler.upcomingBreak }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(symbol: "cup.and.saucer.fill", color: .mint, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.remainingText) 后\(kind.displayName)")
                        .font(.headline)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: model.remainingText)
                    Text("先把手头这件事收个尾吧")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            // 浮窗不是 key window，系统按钮会画成失活的灰色，所以自己画底色
            HStack(spacing: 8) {
                pill("推迟 \(model.settings.postponeMinutes) 分钟", fill: Color.primary.opacity(0.08), action: model.postponeUpcomingBreak)
                pill("现在休息", fill: Color.mint, foreground: .white, action: model.startBreakNow)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func pill(_ title: String, fill: Color, foreground: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
