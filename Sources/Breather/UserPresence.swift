import BreatherCore
import CoreGraphics
import Foundation
import IOKit.pwr_mgt

/// 判断用户是否在电脑前
enum UserPresence {
    /// 距上次键鼠操作的秒数。有程序阻止显示器休眠（播放视频、开会、演示）时，
    /// 人在看屏幕只是没动键鼠，按在场处理
    static func idleSeconds() -> TimeInterval {
        // 任意输入事件
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        // 查询电源断言要跨进程，只在可能被判为离开时才查
        guard idle >= BreakScheduler.presenceThreshold else { return idle }
        return isDisplaySleepPrevented ? 0 : idle
    }

    private static var isDisplaySleepPrevented: Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let dict = status?.takeRetainedValue() as? [String: Int]
        else { return false }
        // 头文件里的常量是 CFSTR 宏，Swift 里用不了，直接写字符串
        return (dict["PreventUserIdleDisplaySleep"] ?? 0) > 0 || (dict["NoDisplaySleepAssertion"] ?? 0) > 0
    }
}
