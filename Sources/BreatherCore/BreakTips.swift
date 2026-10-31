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
    public static let all = [
        BreakTip(symbol: "eye", text: "看看窗外 6 米以外的地方，让眼睛放松一下"),
        BreakTip(symbol: "wind", text: "闭上眼睛，慢慢深呼吸 5 次"),
        BreakTip(symbol: "figure.walk", text: "站起来走一走，倒杯水喝"),
        BreakTip(symbol: "arrow.triangle.2.circlepath", text: "转转脖子：左右各慢慢转 5 圈"),
        BreakTip(symbol: "figure.cooldown", text: "耸耸肩，再用力向后打开胸口"),
        BreakTip(symbol: "figure.flexibility", text: "双手交叉向上伸展，拉长整个身体"),
        BreakTip(symbol: "eye.circle", text: "用力眨眼 10 次，缓解眼睛干涩"),
        BreakTip(symbol: "hand.raised", text: "活动一下手腕和手指，放松打字的肌肉"),
        BreakTip(symbol: "leaf", text: "离开屏幕，看看身边的绿植或远处的风景"),
        BreakTip(symbol: "figure.strengthtraining.functional", text: "做 10 个深蹲，让血液流动起来"),
        BreakTip(symbol: "figure.stand", text: "坐直，下巴微收，感受一下现在的姿势"),
        BreakTip(symbol: "hands.sparkles", text: "把手掌搓热，轻轻捂在眼睛上"),
    ]

    public static func random(excluding current: BreakTip? = nil) -> BreakTip {
        let pool = all.filter { $0 != current }
        return pool.randomElement() ?? all[0]
    }
}
