import Foundation

public enum Phase: Equatable, Sendable {
    case working
    case onBreak(BreakKind)
}

public enum SchedulerEvent: Equatable, Sendable {
    case breakStarted(BreakKind)
    case breakFinished(BreakKind)
}

public enum TickOutcome: Equatable, Sendable {
    case none
    case event(SchedulerEvent)
    /// 离开（睡眠、合盖）足够久后回来，循环已重置；`wasOnBreak` 表示离开前正在休息
    case returnedFromAway(wasOnBreak: Bool)
}

/// 工作/休息循环的状态机。不持有时钟，由外部按实际流逝的时间调用 `tick(elapsed:)` 推进。
public struct BreakScheduler: Sendable {
    public private(set) var settings: BreakSettings
    public private(set) var phase: Phase = .working
    public private(set) var remaining: TimeInterval
    public private(set) var isPaused = false
    /// 自上次重置以来完成的工作段数，用于决定哪一次是长休息
    public private(set) var workSessionsCompleted = 0
    /// 被推迟的休息；推迟结束后仍是这一次休息，不重新计数
    private var postponedBreak: BreakKind?

    public init(settings: BreakSettings) {
        self.settings = settings
        self.remaining = settings.workDuration
    }

    public var isOnBreak: Bool {
        if case .onBreak = phase { true } else { false }
    }

    public var isPostponed: Bool { postponedBreak != nil }

    /// 当前阶段的总时长，用于计算进度
    public var currentPhaseDuration: TimeInterval {
        switch phase {
        case .working: postponedBreak == nil ? settings.workDuration : settings.postponeDuration
        case .onBreak(let kind): settings.breakDuration(kind)
        }
    }

    public var progress: Double {
        let total = currentPhaseDuration
        guard total > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / total))
    }

    public var upcomingBreak: BreakKind {
        postponedBreak ?? kind(forSession: workSessionsCompleted + 1)
    }

    /// 距离下一次长休息还差几个工作段（含当前这一段）
    public var sessionsUntilLongBreak: Int {
        guard settings.longBreakEvery > 0 else { return 0 }
        let done = workSessionsCompleted % settings.longBreakEvery
        return settings.longBreakEvery - done
    }

    /// 两次 tick 间隔超过这个值，说明电脑睡眠过
    public static let sleepGapThreshold: TimeInterval = 60

    /// 按两次 tick 之间实际流逝的时间推进。间隔长到足以算作一次长休息时，视为已经休息过，
    /// 循环从头开始；暂停中则保持暂停，不因为睡眠而被恢复
    public mutating func tick(elapsed: TimeInterval) -> TickOutcome {
        guard !isPaused else { return .none }
        if elapsed > Self.sleepGapThreshold, elapsed >= settings.breakDuration(.long) {
            let wasOnBreak = isOnBreak
            resetAfterAway()
            return .returnedFromAway(wasOnBreak: wasOnBreak)
        }
        return advance(by: elapsed).map(TickOutcome.event) ?? .none
    }

    @discardableResult
    public mutating func advance(by elapsed: TimeInterval) -> SchedulerEvent? {
        guard !isPaused, elapsed > 0 else { return nil }
        remaining -= elapsed
        guard remaining <= 0 else { return nil }
        switch phase {
        case .working:
            return beginBreak()
        case .onBreak(let kind):
            phase = .working
            remaining = settings.workDuration
            return .breakFinished(kind)
        }
    }

    @discardableResult
    public mutating func startBreakNow() -> SchedulerEvent? {
        guard phase == .working else { return nil }
        isPaused = false
        return beginBreak()
    }

    @discardableResult
    public mutating func skipBreak() -> BreakKind? {
        guard case .onBreak(let kind) = phase else { return nil }
        phase = .working
        remaining = settings.workDuration
        return kind
    }

    @discardableResult
    public mutating func postponeBreak() -> BreakKind? {
        guard case .onBreak(let kind) = phase else { return nil }
        postponedBreak = kind
        phase = .working
        remaining = settings.postponeDuration
        return kind
    }

    public mutating func pause() { isPaused = true }
    public mutating func resume() { isPaused = false }

    /// 重新开始当前工作段
    public mutating func restartWork() {
        phase = .working
        remaining = settings.workDuration
        postponedBreak = nil
        isPaused = false
    }

    /// 长时间离开（睡眠、合盖）后回来：视为已经充分休息，循环从头开始
    public mutating func resetAfterAway() {
        restartWork()
        workSessionsCompleted = 0
    }

    /// 修改设置时保留当前阶段已经过去的时间
    public mutating func update(settings newSettings: BreakSettings) {
        let oldTotal = currentPhaseDuration
        settings = newSettings
        let elapsed = oldTotal - remaining
        remaining = max(0, currentPhaseDuration - elapsed)
    }

    private mutating func beginBreak() -> SchedulerEvent {
        let kind: BreakKind
        if let postponed = postponedBreak {
            kind = postponed
            postponedBreak = nil
        } else {
            workSessionsCompleted += 1
            kind = self.kind(forSession: workSessionsCompleted)
        }
        phase = .onBreak(kind)
        remaining = settings.breakDuration(kind)
        return .breakStarted(kind)
    }

    private func kind(forSession n: Int) -> BreakKind {
        settings.longBreakEvery > 0 && n % settings.longBreakEvery == 0 ? .long : .short
    }
}
