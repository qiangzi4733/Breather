import AppKit
import BreatherCore
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppModel {
    private(set) var scheduler: BreakScheduler
    private(set) var stats: BreakStats
    /// 当天零点。界面按它取「今天」的统计，过了零点由计时循环更新，
    /// 否则 App 不重启时界面不会重画，会一直把昨天的数字当成今天
    private(set) var today = Calendar.current.startOfDay(for: Date())
    private(set) var currentTip = BreakTips.random()
    private(set) var launchAtLoginEnabled = false
    private(set) var launchAtLoginError: String?

    var settings: BreakSettings { scheduler.settings }

    @ObservationIgnored private let overlay = BreakOverlayController()
    @ObservationIgnored private let warning = BreakWarningController()
    @ObservationIgnored private let settingsWindow = SettingsWindowController()
    @ObservationIgnored private var lastTick = Date()
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    private enum Keys {
        static let settings = "settings"
        static let stats = "stats"
    }

    /// 为 false 时不计时、不弹遮罩、不写入磁盘，用于界面快照
    @ObservationIgnored private let isLive: Bool

    convenience init() {
        self.init(
            scheduler: BreakScheduler(settings: Self.load(BreakSettings.self, key: Keys.settings) ?? .default),
            stats: Self.load(BreakStats.self, key: Keys.stats) ?? BreakStats(),
            isLive: true
        )
    }

    init(scheduler: BreakScheduler, stats: BreakStats, isLive: Bool) {
        self.scheduler = scheduler
        self.stats = stats
        self.isLive = isLive
        guard isLive else { return }
        refreshLaunchAtLogin()
        startTicking()
    }

    // MARK: - 计时

    private func startTicking() {
        lastTick = Date()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        // 只在跨天时赋值，避免每秒触发依赖它的界面重画
        let startOfDay = Calendar.current.startOfDay(for: now)
        if startOfDay != today { today = startOfDay }

        let idle = UserPresence.idleSeconds()
        // 电源断言只影响专注时的离开判断，没到离开的时长就不用查
        let displayKeptAwake = idle >= scheduler.awayThreshold && UserPresence.isDisplaySleepPrevented

        switch scheduler.tick(elapsed: elapsed, idle: idle, displayKeptAwake: displayKeptAwake) {
        case .none:
            break
        case .event(let event):
            handle(event)
        case .returnedFromAway(let wasOnBreak):
            // 睡眠前正在休息：人已经离开很久，算作完成了这次休息
            if wasOnBreak { record(.completed) }
        }
        syncOverlay()
        syncWarning()
    }

    /// 休息中，或休息结束了人还没回来，都要盖着屏幕
    var showsOverlay: Bool {
        scheduler.isOnBreak || scheduler.breakAwaitingReturn != nil
    }

    /// 遮罩只在休息开始时弹出，收起则跟着状态走：人回来、睡眠后重置、重新计时都会收起
    private func syncOverlay() {
        guard isLive, !showsOverlay else { return }
        overlay.hide()
    }

    /// 预告浮窗跟着调度器的预告状态走：推迟、暂停、重新计时、改设置后都会自动收起或出现
    private func syncWarning() {
        guard isLive else { return }
        if scheduler.isWarning {
            warning.show(model: self)
        } else {
            warning.hide()
        }
    }

    private func handle(_ event: SchedulerEvent?) {
        switch event {
        case .breakStarted:
            currentTip = BreakTips.random(excluding: currentTip)
            overlay.show(model: self)
        case .breakFinished:
            // 人不在时遮罩留着，换成「休息结束」的样子，等有键鼠操作再由 syncOverlay 收起
            record(.completed)
            NSSound(named: "Glass")?.play()
        case nil:
            break
        }
    }

    // MARK: - 用户操作

    func togglePause() {
        if scheduler.isPaused { scheduler.resume() } else { scheduler.pause() }
        syncWarning()
    }

    func startBreakNow() {
        handle(scheduler.startBreakNow())
        syncWarning()
    }

    /// 预告浮窗上的推迟：休息还没开始就推迟，同样记一次推迟
    func postponeUpcomingBreak() {
        guard scheduler.postponeUpcomingBreak() != nil else { return }
        record(.postponed)
        syncWarning()
    }

    func skipBreak() {
        guard scheduler.skipBreak() != nil else { return }
        record(.skipped)
        overlay.hide()
    }

    func postponeBreak() {
        guard scheduler.postponeBreak() != nil else { return }
        record(.postponed)
        overlay.hide()
    }

    func restartWork() {
        scheduler.restartWork()
        syncOverlay()
        syncWarning()
    }

    func update(settings: BreakSettings) {
        scheduler.update(settings: settings)
        save(settings, key: Keys.settings)
        syncWarning()
    }

    func openSettings() {
        settingsWindow.show(model: self)
    }

    // MARK: - 开机自启

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
        if status == .requiresApproval {
            launchAtLoginError = String(localized: "需要在「系统设置 › 通用 › 登录项」中允许 Breather")
        }
    }

    // MARK: - 展示用

    var remainingText: String {
        let total = max(0, Int(scheduler.remaining.rounded(.up)))
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    var todayStats: DayStats { stats.stats(on: today) }

    // MARK: - 持久化

    private func record(_ outcome: BreakOutcome) {
        stats.record(outcome, on: Date())
        save(stats, key: Keys.stats)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard isLive, let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
