import Foundation

public enum BreakKind: String, Codable, Sendable {
    case short
    case long
}

public struct BreakSettings: Codable, Equatable, Sendable {
    public var workMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    /// 每完成多少个工作段来一次长休息
    public var longBreakEvery: Int
    public var postponeMinutes: Int
    public var showCountdownInMenuBar: Bool
    /// 休息前 1 分钟弹出预告
    public var warnBeforeBreak: Bool

    public init(
        workMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        longBreakEvery: Int = 4,
        postponeMinutes: Int = 5,
        showCountdownInMenuBar: Bool = true,
        warnBeforeBreak: Bool = true
    ) {
        self.workMinutes = workMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.longBreakEvery = longBreakEvery
        self.postponeMinutes = postponeMinutes
        self.showCountdownInMenuBar = showCountdownInMenuBar
        self.warnBeforeBreak = warnBeforeBreak
    }

    public static let `default` = BreakSettings()

    public var workDuration: TimeInterval { TimeInterval(workMinutes * 60) }
    public var postponeDuration: TimeInterval { TimeInterval(postponeMinutes * 60) }

    public func breakDuration(_ kind: BreakKind) -> TimeInterval {
        switch kind {
        case .short: TimeInterval(shortBreakMinutes * 60)
        case .long: TimeInterval(longBreakMinutes * 60)
        }
    }

    // 以后新增字段时，旧版本存下的设置缺少的键使用默认值
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BreakSettings.default
        workMinutes = try c.decodeIfPresent(Int.self, forKey: .workMinutes) ?? d.workMinutes
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        longBreakEvery = try c.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? d.longBreakEvery
        postponeMinutes = try c.decodeIfPresent(Int.self, forKey: .postponeMinutes) ?? d.postponeMinutes
        showCountdownInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showCountdownInMenuBar) ?? d.showCountdownInMenuBar
        warnBeforeBreak = try c.decodeIfPresent(Bool.self, forKey: .warnBeforeBreak) ?? d.warnBeforeBreak
    }
}
