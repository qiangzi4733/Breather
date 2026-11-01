import Foundation
import Testing
@testable import BreatherCore

private let settings = BreakSettings(workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 2, postponeMinutes: 5)

@Suite struct BreakSchedulerTests {
    @Test func workEndsWithShortBreak() {
        var s = BreakScheduler(settings: settings)
        #expect(s.advance(by: 25 * 60 - 1) == nil)
        #expect(s.advance(by: 1) == .breakStarted(.short))
        #expect(s.remaining == 5 * 60)
    }

    @Test func breakEndsBackToWork() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        #expect(s.advance(by: 5 * 60) == .breakFinished(.short))
        #expect(s.phase == .working)
        #expect(s.remaining == 25 * 60)
    }

    @Test func everyNthBreakIsLong() {
        var s = BreakScheduler(settings: settings)
        #expect(s.startBreakNow() == .breakStarted(.short))
        s.skipBreak()
        #expect(s.upcomingBreak == .long)
        #expect(s.startBreakNow() == .breakStarted(.long))
        s.skipBreak()
        #expect(s.startBreakNow() == .breakStarted(.short))
    }

    @Test func postponeKeepsSameBreak() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        s.skipBreak()
        s.startBreakNow() // 第 2 轮：长休息
        #expect(s.postponeBreak() == .long)
        #expect(s.isPostponed)
        #expect(s.remaining == 5 * 60)
        #expect(s.advance(by: 5 * 60) == .breakStarted(.long))
        #expect(s.workSessionsCompleted == 2)
    }

    @Test func pausedDoesNotAdvance() {
        var s = BreakScheduler(settings: settings)
        s.pause()
        #expect(s.advance(by: 60 * 60) == nil)
        #expect(s.remaining == 25 * 60)
        s.resume()
        s.advance(by: 60)
        #expect(s.remaining == 24 * 60)
    }

    @Test func updatingSettingsKeepsElapsedTime() {
        var s = BreakScheduler(settings: settings)
        s.advance(by: 10 * 60)
        var longer = settings
        longer.workMinutes = 50
        s.update(settings: longer)
        #expect(s.remaining == 40 * 60)

        var shorter = settings
        shorter.workMinutes = 5
        s.update(settings: shorter)
        #expect(s.remaining == 0)
        #expect(s.advance(by: 1) == .breakStarted(.short))
    }

    @Test func resetAfterAwayRestartsCycle() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        s.resetAfterAway()
        #expect(s.phase == .working)
        #expect(s.workSessionsCompleted == 0)
        #expect(s.upcomingBreak == .short)
    }

    @Test func tickAdvancesNormally() {
        var s = BreakScheduler(settings: settings)
        s.advance(by: 25 * 60 - 2)
        #expect(s.tick(elapsed: 1) == .none)
        #expect(s.tick(elapsed: 1) == .event(.breakStarted(.short)))
    }

    @Test func longSleepWhileWorkingRestartsCycle() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        s.skipBreak()
        s.advance(by: 20 * 60)
        #expect(s.tick(elapsed: 15 * 60) == .returnedFromAway(wasOnBreak: false))
        #expect(s.remaining == 25 * 60)
        #expect(s.workSessionsCompleted == 0)
    }

    @Test func longSleepDuringBreakCountsAsBreak() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        #expect(s.tick(elapsed: 2 * 60 * 60) == .returnedFromAway(wasOnBreak: true))
        #expect(s.phase == .working)
    }

    @Test func shortSleepJustAdvances() {
        // 超过睡眠阈值但不够一次长休息：只当作时间流逝
        var s = BreakScheduler(settings: settings)
        #expect(s.tick(elapsed: 10 * 60) == .none)
        #expect(s.remaining == 15 * 60)
        #expect(s.tick(elapsed: 14 * 60 + 59) == .none)
        #expect(s.tick(elapsed: 2 * 60) == .event(.breakStarted(.short)))
    }

    @Test func sleepWhilePausedStaysPaused() {
        var s = BreakScheduler(settings: settings)
        s.advance(by: 5 * 60)
        s.pause()
        #expect(s.tick(elapsed: 3 * 60 * 60) == .none)
        #expect(s.isPaused)
        #expect(s.remaining == 20 * 60)
    }

    @Test func remainingFractionCountsDown() {
        var s = BreakScheduler(settings: settings)
        #expect(s.remainingFraction == 1)
        s.advance(by: 25 * 60 / 4)
        #expect(s.remainingFraction == 0.75)
        s.startBreakNow()
        #expect(s.remainingFraction == 1)
    }

    @Test func actionsOutsideBreakAreIgnored() {
        var s = BreakScheduler(settings: settings)
        #expect(s.skipBreak() == nil)
        #expect(s.postponeBreak() == nil)
        s.startBreakNow()
        #expect(s.startBreakNow() == nil)
    }

    // MARK: 休息前预告

    @Test func warningInLastMinute() {
        var s = BreakScheduler(settings: settings)
        s.advance(by: 24 * 60 - 1)
        #expect(!s.isWarning)
        s.advance(by: 1)
        #expect(s.isWarning)
        s.pause()
        #expect(!s.isWarning)
        s.resume()
        s.advance(by: 60)
        #expect(!s.isWarning)
        #expect(s.isOnBreak)
    }

    @Test func warningCanBeTurnedOff() {
        var quiet = settings
        quiet.warnBeforeBreak = false
        var s = BreakScheduler(settings: quiet)
        s.advance(by: 24 * 60 + 30)
        #expect(!s.isWarning)
    }

    @Test func noWarningWhenPhaseIsShorterThanLead() {
        var short = settings
        short.postponeMinutes = 1
        var s = BreakScheduler(settings: short)
        s.startBreakNow()
        s.postponeBreak()
        #expect(!s.isWarning)
    }

    @Test func postponeUpcomingKeepsCycleCount() {
        var s = BreakScheduler(settings: settings)
        s.advance(by: 24 * 60 + 30)
        #expect(s.postponeUpcomingBreak() == .short)
        #expect(s.isPostponed)
        #expect(s.remaining == 5 * 60)
        #expect(s.workSessionsCompleted == 1)
        // 推迟的时段里再推迟一次，仍是同一次休息
        s.advance(by: 4 * 60 + 30)
        #expect(s.postponeUpcomingBreak() == .short)
        #expect(s.workSessionsCompleted == 1)
        #expect(s.advance(by: 5 * 60) == .breakStarted(.short))
        s.skipBreak()
        #expect(s.upcomingBreak == .long)
    }

    // MARK: 空闲检测

    @Test func idleWhileWorkingFreezesThenRestartsCycle() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        s.skipBreak()
        s.advance(by: 5 * 60)
        #expect(s.tick(elapsed: 1, idle: 15 * 60 - 1) == .none)
        #expect(s.away == nil)
        #expect(s.tick(elapsed: 1, idle: 15 * 60) == .none)
        #expect(s.away == .idle)
        let frozen = s.remaining
        #expect(s.tick(elapsed: 1, idle: 45 * 60) == .none)
        #expect(s.remaining == frozen)
        #expect(!s.isWarning)
        #expect(s.tick(elapsed: 1, idle: 1) == .returnedFromAway(wasOnBreak: false))
        #expect(s.away == nil)
        #expect(s.remaining == 25 * 60)
        #expect(s.workSessionsCompleted == 0)
    }

    @Test func breakEndingWhileAwayWaitsForReturn() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        s.advance(by: 5 * 60 - 1)
        #expect(s.tick(elapsed: 1, idle: 4 * 60) == .event(.breakFinished(.short)))
        #expect(s.away == .afterBreak)
        #expect(s.tick(elapsed: 1, idle: 14 * 60) == .none)
        #expect(s.remaining == 25 * 60)
        // 回来后从完整的一段开始，循环计数不重置
        #expect(s.tick(elapsed: 1, idle: 0.5) == .none)
        #expect(s.away == nil)
        #expect(s.workSessionsCompleted == 1)
        _ = s.tick(elapsed: 1, idle: 0)
        #expect(s.remaining == 25 * 60 - 1)
    }

    @Test func breakEndingWhilePresentStartsWorkRightAway() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        s.advance(by: 5 * 60 - 1)
        #expect(s.tick(elapsed: 1, idle: 1) == .event(.breakFinished(.short)))
        #expect(s.away == nil)
    }

    @Test func displayKeptAwakeWhileWorkingIsNotAway() {
        var s = BreakScheduler(settings: settings)
        s.advance(by: 60)
        #expect(s.tick(elapsed: 1, idle: 20 * 60, displayKeptAwake: true) == .none)
        #expect(s.away == nil)
        #expect(s.remaining == 25 * 60 - 61)
    }

    @Test func displayKeptAwakeDoesNotHideAbsenceWhenBreakEnds() {
        // 去洗手间时后台视频还在播：休息结束仍要等人回来
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        s.advance(by: 5 * 60 - 1)
        #expect(s.tick(elapsed: 1, idle: 4 * 60, displayKeptAwake: true) == .event(.breakFinished(.short)))
        #expect(s.away == .afterBreak)
        #expect(s.tick(elapsed: 1, idle: 6 * 60, displayKeptAwake: true) == .none)
        #expect(s.away == .afterBreak)
        #expect(s.remaining == 25 * 60)
        #expect(s.tick(elapsed: 1, idle: 0.5, displayKeptAwake: true) == .none)
        #expect(s.away == nil)
    }

    @Test func idleDuringBreakDoesNotInterruptIt() {
        var s = BreakScheduler(settings: settings)
        s.startBreakNow()
        #expect(s.tick(elapsed: 1, idle: 60 * 60) == .none)
        #expect(s.away == nil)
        #expect(s.remaining == 5 * 60 - 1)
    }

    @Test func idleIgnoredWhilePaused() {
        var s = BreakScheduler(settings: settings)
        s.pause()
        #expect(s.tick(elapsed: 1, idle: 60 * 60) == .none)
        #expect(s.away == nil)
    }

    @Test func startingBreakOrRestartingClearsAway() {
        var s = BreakScheduler(settings: settings)
        _ = s.tick(elapsed: 1, idle: 60 * 60)
        #expect(s.away == .idle)
        s.restartWork()
        #expect(s.away == nil)
        _ = s.tick(elapsed: 1, idle: 60 * 60)
        #expect(s.startBreakNow() == .breakStarted(.short))
        #expect(s.away == nil)
    }
}

@Suite struct BreakStatsTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func recordsPerDay() {
        var stats = BreakStats()
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        stats.record(.completed, on: day1, calendar: calendar)
        stats.record(.completed, on: day1, calendar: calendar)
        stats.record(.skipped, on: day2, calendar: calendar)
        #expect(stats.stats(on: day1, calendar: calendar) == DayStats(completed: 2))
        #expect(stats.stats(on: day2, calendar: calendar) == DayStats(skipped: 1))

        let recent = stats.recentDays(3, endingAt: day2, calendar: calendar)
        #expect(recent.map(\.stats) == [DayStats(), DayStats(completed: 2), DayStats(skipped: 1)])
    }

    @Test func settingsDecodeFillsMissingKeys() throws {
        let data = Data(#"{"workMinutes": 40}"#.utf8)
        let decoded = try JSONDecoder().decode(BreakSettings.self, from: data)
        #expect(decoded.workMinutes == 40)
        #expect(decoded.shortBreakMinutes == BreakSettings.default.shortBreakMinutes)
        #expect(decoded.warnBeforeBreak)
    }
}
