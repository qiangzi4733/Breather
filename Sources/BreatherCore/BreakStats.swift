import Foundation

public enum BreakOutcome: Sendable {
    case completed
    case skipped
    case postponed
}

public struct DayStats: Codable, Equatable, Sendable {
    public var completed = 0
    public var skipped = 0
    public var postponed = 0

    public init(completed: Int = 0, skipped: Int = 0, postponed: Int = 0) {
        self.completed = completed
        self.skipped = skipped
        self.postponed = postponed
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
        case .completed: day.completed += 1
        case .skipped: day.skipped += 1
        case .postponed: day.postponed += 1
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
