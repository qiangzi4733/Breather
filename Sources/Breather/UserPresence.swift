import BreatherCore
import CoreGraphics
import Foundation
import IOKit.pwr_mgt

/// 判断用户是否在电脑前
enum UserPresence {
    /// 距上次键鼠操作的秒数
    static func idleSeconds() -> TimeInterval {
        // 任意输入事件
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// 有程序阻止显示器休眠（播放视频、开会、演示）。查询要跨进程，调用方只在需要时才查
    static var isDisplaySleepPrevented: Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let dict = status?.takeRetainedValue() as? [String: Int]
        else { return false }
        // 头文件里的常量是 CFSTR 宏，Swift 里用不了，直接写字符串
        return (dict["PreventUserIdleDisplaySleep"] ?? 0) > 0 || (dict["NoDisplaySleepAssertion"] ?? 0) > 0
    }
}
