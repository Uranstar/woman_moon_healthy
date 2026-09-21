import Foundation

extension Date {
    /// 判断两个日期是否是同一天
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// 获取当前周期的天数 (从周期开始日算起)
    func dayOfCycle(from cycleStartDate: Date) -> Int? {
        let days = Calendar.current.dateComponents([.day], from: cycleStartDate, to: self).day
        return days.map { $0 + 1 }
    }

    /// 根据周期开始日和当前日期计算所处的周期阶段
    ///
    /// 原先这里自行维护一套硬编码的 13/14/16/17 天边界，与 `CycleCalculator` 的
    /// 判定口径不一致，且 `case 17...cycleLength` 在周期短于 17 天时会构造非法 Range 崩溃。
    /// 改为统一委托给 `CycleCalculator`。
    func cyclePhase(
        cycleStartDate: Date,
        cycleLength: Int = 28,
        periodLength: Int = 5,
        lutealLength: Int = 14
    ) -> CyclePhase {
        CycleCalculator.currentPhase(
            from: cycleStartDate,
            cycleLength: cycleLength,
            periodLength: periodLength,
            lutealLength: lutealLength,
            to: self
        )
    }

    /// 获取当天的节气 (返回空字符串如果不是节气日)
    func solarTerm() -> String {
        SeasonalTerms.termFor(date: self)
    }

    /// 本月的第一天
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }

    /// 本周的第一天 (周一)
    var startOfWeek: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        components.weekday = 2 // 周一
        return calendar.date(from: components)!
    }

    /// 格式化: "2026年6月7日"
    var chineseFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: self)
    }

    /// 格式化: "6月7日"
    var shortChineseFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: self)
    }

    /// 星期几的中文表示
    var weekdayChinese: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }
}
