import Foundation

/// 一次到点休息的最终结果。推迟不是结果，推迟过的休息最终仍会完成或被跳过
public enum BreakOutcome: Sendable {
    case completed
    case completedAfterPostpone
    case skipped
}

public struct DayStats: Codable, Equatable, Sendable {
    /// 完成的休息，含推迟后才完成的
    public var completed = 0
    /// `completed` 中推迟过的那部分
    public var completedAfterPostpone = 0
    public var skipped = 0

    public init(completed: Int = 0, completedAfterPostpone: Int = 0, skipped: Int = 0) {
        self.completed = completed
        self.completedAfterPostpone = completedAfterPostpone
        self.skipped = skipped
    }

    /// 到点的休息次数
    public var due: Int { completed + skipped }
    public var completedOnTime: Int { completed - completedAfterPostpone }

    private enum CodingKeys: String, CodingKey {
        case completed, completedAfterPostpone, skipped
    }

    // 旧版本没有 completedAfterPostpone，按准时完成处理；旧版本按操作次数记的 postponed 无法还原到每次休息，直接忽略
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completed = try c.decodeIfPresent(Int.self, forKey: .completed) ?? 0
        completedAfterPostpone = try c.decodeIfPresent(Int.self, forKey: .completedAfterPostpone) ?? 0
        skipped = try c.decodeIfPresent(Int.self, forKey: .skipped) ?? 0
    }
}

/// 一段时间的汇总
public struct StatsSummary: Equatable, Sendable {
    public var total = DayStats()
    /// 有到点休息的天数。没开电脑、还没安装的日子不算，免得把日均拉低
    public var activeDays = 0

    public init(_ days: [DayStats]) {
        for day in days {
            total.completed += day.completed
            total.completedAfterPostpone += day.completedAfterPostpone
            total.skipped += day.skipped
            if day.due > 0 { activeDays += 1 }
        }
    }

    /// 使用日的日均完成次数，没有使用日时为 nil
    public var dailyAverage: Double? {
        activeDays > 0 ? Double(total.completed) / Double(activeDays) : nil
    }

    /// 完成率：完成 ÷ 到点，没有到点的休息时为 nil
    public var completionRate: Double? {
        total.due > 0 ? Double(total.completed) / Double(total.due) : nil
    }

    /// 准时率：没推迟就完成的 ÷ 到点
    public var onTimeRate: Double? {
        total.due > 0 ? Double(total.completedOnTime) / Double(total.due) : nil
    }
}

/// 按天累计的休息记录，键为本地日期 "yyyy-MM-dd"
public struct BreakStats: Codable, Equatable, Sendable {
    public private(set) var days: [String: DayStats] = [:]

    public init() {}

    public mutating func record(_ outcome: BreakOutcome, on date: Date, calendar: Calendar = .current) {
        let key = Self.key(for: date, calendar: calendar)
        var day = days[key] ?? DayStats()
        switch outcome {
        case .completed:
            day.completed += 1
        case .completedAfterPostpone:
            day.completed += 1
            day.completedAfterPostpone += 1
        case .skipped:
            day.skipped += 1
        }
        days[key] = day
    }

    public func stats(on date: Date, calendar: Calendar = .current) -> DayStats {
        days[Self.key(for: date, calendar: calendar)] ?? DayStats()
    }

    /// 最近 `count` 天（含 `endingAt` 当天），按时间正序
    public func recentDays(_ count: Int, endingAt date: Date, calendar: Calendar = .current) -> [(date: Date, stats: DayStats)] {
        let today = calendar.startOfDay(for: date)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, stats(on: day, calendar: calendar))
        }
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
