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

/// 人不在电脑前时计时冻结，等有键鼠操作再继续
public enum AwayState: Equatable, Sendable {
    /// 专注时离开太久，算作已经休息过，回来后循环从头开始
    case idle
    /// 休息结束时人不在，回来后才开始下一段专注。遮罩保持显示，免得人走开时屏幕内容露出来
    case afterBreak(BreakKind)
}

/// 工作/休息循环的状态机。不持有时钟，由外部按实际流逝的时间调用 `tick(elapsed:)` 推进。
public struct BreakScheduler: Sendable {
    public private(set) var settings: BreakSettings
    public private(set) var phase: Phase = .working
    public private(set) var remaining: TimeInterval
    public private(set) var isPaused = false
    public private(set) var away: AwayState?
    /// 自上次重置以来完成的工作段数，用于决定哪一次是长休息
    public private(set) var workSessionsCompleted = 0
    /// 被推迟的休息；推迟结束后仍是这一次休息，不重新计数
    private var postponedBreak: BreakKind?
    /// 最近开始的这次休息是否推迟过。休息结束、跳过、睡眠重置后仍保留，供记录统计时读取
    public private(set) var breakWasPostponed = false

    public init(settings: BreakSettings) {
        self.settings = settings
        self.remaining = settings.workDuration
    }

    public var isOnBreak: Bool {
        if case .onBreak = phase { true } else { false }
    }

    public var isPostponed: Bool { postponedBreak != nil }

    /// 休息结束了但人还没回来时，刚结束的那次休息
    public var breakAwaitingReturn: BreakKind? {
        if case .afterBreak(let kind) = away { kind } else { nil }
    }

    /// 休息前多久开始预告
    public static let warningLead: TimeInterval = 60

    /// 处于休息前的预告时段。阶段本身不足预告时长时（比如很短的推迟）不预告，免得刚推迟完又弹出来
    public var isWarning: Bool {
        settings.warnBeforeBreak && phase == .working && !isPaused && away == nil
            && currentPhaseDuration > Self.warningLead && remaining <= Self.warningLead
    }

    /// 当前阶段的总时长，用于计算进度
    public var currentPhaseDuration: TimeInterval {
        switch phase {
        case .working: postponedBreak == nil ? settings.workDuration : settings.postponeDuration
        case .onBreak(let kind): settings.breakDuration(kind)
        }
    }

    /// 当前阶段剩余时间的比例，从 1 递减到 0，用于倒计时圆环
    public var remainingFraction: Double {
        let total = currentPhaseDuration
        guard total > 0 else { return 0 }
        return min(1, max(0, remaining / total))
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

    /// 距上次键鼠操作不到这么久，就认为人在电脑前
    public static let presenceThreshold: TimeInterval = 5

    /// 专注时没有键鼠操作超过这么久，算作已经离开休息过，和睡眠的判断标准一致
    public var awayThreshold: TimeInterval {
        max(Self.sleepGapThreshold, settings.breakDuration(.long))
    }

    /// 按两次 tick 之间实际流逝的时间推进。间隔长到足以算作一次长休息时，视为已经休息过，
    /// 循环从头开始；暂停中则保持暂停，不因为睡眠而被恢复。
    /// `idle` 是距上次键鼠操作的秒数：专注时离开太久同样视为休息过，休息结束时人不在则等回来再计时。
    /// `displayKeptAwake` 表示有程序阻止显示器休眠（视频、会议），只在专注时用来避免误判离开
    public mutating func tick(elapsed: TimeInterval, idle: TimeInterval = 0, displayKeptAwake: Bool = false) -> TickOutcome {
        guard !isPaused else { return .none }
        if elapsed > Self.sleepGapThreshold, elapsed >= settings.breakDuration(.long) {
            let wasOnBreak = isOnBreak
            resetAfterAway()
            return .returnedFromAway(wasOnBreak: wasOnBreak)
        }

        if let state = away {
            // 回来以键鼠操作为准，后台开始播放的视频不代表人回来了
            guard idle < Self.presenceThreshold else { return .none }
            away = nil
            if state == .idle {
                resetAfterAway()
                return .returnedFromAway(wasOnBreak: false)
            }
            return .none
        }

        // 专注时看视频、开会，人在看屏幕只是没动键鼠，不算离开
        if phase == .working, idle >= awayThreshold, !displayKeptAwake {
            away = .idle
            return .none
        }

        let event = advance(by: elapsed)
        // 休息时遮罩盖住了所有屏幕，不可能在看视频，人在不在只看键鼠操作
        if case .breakFinished(let kind) = event, idle >= Self.presenceThreshold {
            away = .afterBreak(kind)
        }
        return event.map(TickOutcome.event) ?? .none
    }

    @discardableResult
    public mutating func advance(by elapsed: TimeInterval) -> SchedulerEvent? {
        guard !isPaused, away == nil, elapsed > 0 else { return nil }
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
        away = nil
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

    /// 预告时段里推迟：这一次休息算作已经到点，推迟结束后仍是这一次休息
    @discardableResult
    public mutating func postponeUpcomingBreak() -> BreakKind? {
        guard phase == .working, !isPaused, away == nil else { return nil }
        let kind: BreakKind
        if let postponed = postponedBreak {
            kind = postponed
        } else {
            workSessionsCompleted += 1
            kind = self.kind(forSession: workSessionsCompleted)
        }
        postponedBreak = kind
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
        away = nil
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
        breakWasPostponed = postponedBreak != nil
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
