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

    @Test func actionsOutsideBreakAreIgnored() {
        var s = BreakScheduler(settings: settings)
        #expect(s.skipBreak() == nil)
        #expect(s.postponeBreak() == nil)
        s.startBreakNow()
        #expect(s.startBreakNow() == nil)
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
    }
}
