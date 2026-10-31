import Foundation

public struct BreakTip: Equatable, Sendable {
    /// SF Symbol 名称
    public let symbol: String
    public let text: String

    public init(symbol: String, text: String) {
        self.symbol = symbol
        self.text = text
    }
}

public enum BreakTips {
    // 文案按 App 主 bundle 里的 Localizable.strings 翻译，测试环境下保持中文原文
    public static let all = [
        BreakTip(symbol: "eye", text: String(localized: "看看窗外 6 米以外的地方，让眼睛放松一下")),
        BreakTip(symbol: "wind", text: String(localized: "闭上眼睛，慢慢深呼吸 5 次")),
        BreakTip(symbol: "figure.walk", text: String(localized: "站起来走一走，倒杯水喝")),
        BreakTip(symbol: "arrow.triangle.2.circlepath", text: String(localized: "转转脖子：左右各慢慢转 5 圈")),
        BreakTip(symbol: "figure.cooldown", text: String(localized: "耸耸肩，再用力向后打开胸口")),
        BreakTip(symbol: "figure.flexibility", text: String(localized: "双手交叉向上伸展，拉长整个身体")),
        BreakTip(symbol: "eye.circle", text: String(localized: "用力眨眼 10 次，缓解眼睛干涩")),
        BreakTip(symbol: "hand.raised", text: String(localized: "活动一下手腕和手指，放松打字的肌肉")),
        BreakTip(symbol: "leaf", text: String(localized: "离开屏幕，看看身边的绿植或远处的风景")),
        BreakTip(symbol: "figure.strengthtraining.functional", text: String(localized: "做 10 个深蹲，让血液流动起来")),
        BreakTip(symbol: "figure.stand", text: String(localized: "坐直，下巴微收，感受一下现在的姿势")),
        BreakTip(symbol: "hands.sparkles", text: String(localized: "把手掌搓热，轻轻捂在眼睛上")),
    ]

    public static func random(excluding current: BreakTip? = nil) -> BreakTip {
        let pool = all.filter { $0 != current }
        return pool.randomElement() ?? all[0]
    }
}
