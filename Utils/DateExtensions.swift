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
    func cyclePhase(cycleStartDate: Date, cycleLength: Int = 28, periodLength: Int = 5) -> CyclePhase {
        guard let dayOfCycle = self.dayOfCycle(from: cycleStartDate) else {
            return .menstrual
        }
        let normalizedDay = ((dayOfCycle - 1) % cycleLength) + 1

        switch normalizedDay {
        case 1...periodLength:
            return .menstrual
        case (periodLength + 1)...13:
            return .follicular
        case 14...16:
            return .ovulatory
        case 17...cycleLength:
            return .luteal
        default:
            return .menstrual
        }
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
