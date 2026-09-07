import Foundation

/// 提醒文案与形态的选择器。
///
/// 复习提醒会在到点后每小时重复一次，直到用户把今天的复习清空。为了不让重复
/// 提醒变成同一句话的机械循环，这里给每次触发挑一句不同的文案，并在小灵动岛
/// （只有一行字）和大灵动岛（额外列出待复习内容）之间切换。
///
/// 选择是**确定性**的：同一个 dedup key + 同一份状态永远得到同一句文案和同一
/// 种形态。随机感来自 key 里的小时序号，而不是真正的 `random()`，这样探针可以
/// 断言行为，重复渲染同一帧也不会让文案跳动。
enum IslandReminderCopy {

    /// 到点后的第一次提醒：正常、克制。
    static let reviewOpeners: [String] = [
        "您需要复习",
        "该复习啦",
        "今天的复习在等你",
        "到点了，复习一下"
    ]

    /// 之后每小时的重复提醒：语气逐渐调皮，避免重复感。
    static let reviewNudges: [String] = [
        "复习还在排队哦",
        "记忆正在悄悄溜走",
        "再不复习就要忘光啦",
        "你的复习清单想你了",
        "花几分钟，把今天收个尾",
        "艾宾浩斯正在看着你",
        "偷偷提醒：还没复习完",
        "今天的复习还差一点点"
    ]

    static let todoOpeners: [String] = [
        "您有待办要处理",
        "待办清单在等你",
        "还有任务没完成"
    ]

    static let todoNudges: [String] = [
        "待办还没清空哦",
        "任务还在等你打勾",
        "再推进一项就轻松了"
    ]

    /// 为一次提醒挑选文案。
    /// - Parameters:
    ///   - kind: 复习还是待办。
    ///   - repeatIndex: 当天第几次提醒，0 表示到点后的首次提醒。
    ///   - key: 该次提醒的 dedup key，用来打散选择。
    static func message(for kind: IslandReminderKind, repeatIndex: Int, key: String) -> String {
        let openers = kind == .review ? reviewOpeners : todoOpeners
        let nudges = kind == .review ? reviewNudges : todoNudges
        let pool = repeatIndex <= 0 ? openers : nudges
        guard pool.isEmpty == false else { return kind.message }
        return pool[index(for: key, salt: 17, upperBound: pool.count)]
    }

    /// 为一次提醒挑选形态。首次提醒固定用小灵动岛（打扰最小），
    /// 之后的重复提醒在大/小之间交替偏随机，重复提醒越多越倾向展开大形态。
    static func style(
        for kind: IslandReminderKind,
        repeatIndex: Int,
        key: String,
        hasListContent: Bool
    ) -> IslandReminderBannerStyle {
        guard repeatIndex > 0 else { return .compact }
        // 没有可列出的复习内容时，大形态里只剩一句话，不值得占那么大面积。
        guard hasListContent else { return .compact }
        return index(for: key, salt: 31, upperBound: 2) == 0 ? .compact : .expanded
    }

    /// 稳定的字符串散列（FNV-1a 变体）。`hashValue` 每次进程启动都会变，
    /// 会让同一次提醒在重新渲染时抖动，所以这里自己算。
    private static func index(for key: String, salt: UInt64, upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325 &+ salt
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return Int(hash % UInt64(upperBound))
    }
}
