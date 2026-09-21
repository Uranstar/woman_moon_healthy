import Foundation

/// 经期周期计算引擎
struct CycleCalculator {
    // MARK: - 预测下一个周期开始日
    static func predictNextCycleStart(from lastStartDate: Date, cycleLength: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: cycleLength, to: lastStartDate) ?? lastStartDate
    }

    // MARK: - 预测排卵日
    /// 排卵日落在周期第 `cycleLength - lutealLength` 天；由于第 N 天对应起始日加 N-1 天，
    /// 这里必须减 1，否则会比 `fertilityWindow` 算出的排卵日整体晚一天。
    static func predictOvulationDay(from cycleStartDate: Date, cycleLength: Int, lutealLength: Int = 14) -> Date {
        let ovulationDay = max(cycleLength - lutealLength, 1)
        return Calendar.current.date(byAdding: .day, value: ovulationDay - 1, to: cycleStartDate) ?? cycleStartDate
    }

    // MARK: - 计算当前天在周期中的位置
    static func dayOfCycle(from cycleStartDate: Date, to date: Date = Date()) -> Int {
        let days = Calendar.current.dateComponents([.day], from: cycleStartDate, to: date).day ?? 0
        return days + 1
    }

    // MARK: - 判断当前周期阶段
    /// - Parameter date: 待判断的日期，默认取当前时间。显式传入以便单元测试固定时间点。
    static func currentPhase(
        from cycleStartDate: Date,
        cycleLength: Int = 28,
        periodLength: Int = 5,
        lutealLength: Int = 14,
        to date: Date = Date()
    ) -> CyclePhase {
        let safeCycleLength = max(cycleLength, 1)
        let currentDay = dayOfCycle(from: cycleStartDate, to: date)
        // 早于周期起始日时钳到第一天，避免取模后得到负数
        let normalizedDay = ((max(currentDay, 1) - 1) % safeCycleLength) + 1

        let ovulatoryStart = max(cycleLength - lutealLength, periodLength + 1)

        // 用比较而非 switch range：短周期（如 20 天）下原实现的
        // `case (periodLength+1)...(cycleLength-lutealLength-1)` 会构造出
        // 下界大于上界的 ClosedRange，直接触发 "Range requires lowerBound <= upperBound" 崩溃。
        if normalizedDay <= periodLength {
            return .menstrual
        } else if normalizedDay < ovulatoryStart {
            return .follicular
        } else if normalizedDay < ovulatoryStart + 3 {
            return .ovulatory
        } else {
            return .luteal
        }
    }

    // MARK: - 获取某阶段的所有日期范围
    static func dateRangeForPhase(
        _ phase: CyclePhase,
        from cycleStartDate: Date,
        cycleLength: Int = 28,
        periodLength: Int = 5,
        lutealLength: Int = 14
    ) -> (start: Date, end: Date)? {
        let calendar = Calendar.current

        let ranges: [(Int, Int)] = [
            (1, periodLength),                                              // 经期
            (periodLength + 1, cycleLength - lutealLength - 1),            // 卵泡期
            (cycleLength - lutealLength, cycleLength - lutealLength + 2),  // 排卵期
            (cycleLength - lutealLength + 3, cycleLength)                  // 黄体期
        ]

        let phaseIndex = CyclePhase.allCases.firstIndex(of: phase) ?? 0
        let (startDay, endDay) = ranges[phaseIndex]

        guard let start = calendar.date(byAdding: .day, value: startDay - 1, to: cycleStartDate),
              let end = calendar.date(byAdding: .day, value: endDay - 1, to: cycleStartDate) else {
            return nil
        }

        return (start, end)
    }

    // MARK: - 生成周期预测列表 (未来3个月)
    static func generatePredictions(
        from lastStartDate: Date,
        cycleLength: Int,
        periodLength: Int,
        months: Int = 3
    ) -> [CycleRecord] {
        // `for i in 1...months` 在 months <= 0 时会构造下界大于上界的 ClosedRange，
        // 触发 "Range requires lowerBound <= upperBound" 运行时崩溃。
        // 当前调用方都传 6，但这是库函数，不该由调用方保证入参合法性。
        guard months > 0 else { return [] }

        var predictions: [CycleRecord] = []
        let calendar = Calendar.current

        // 从下一个周期开始：起点那天已有真实记录，再生成一条预测会造成同日重复
        for i in 1...months {
            let startDate = calendar.date(byAdding: .day, value: i * cycleLength, to: lastStartDate) ?? lastStartDate
            let endDate = calendar.date(byAdding: .day, value: periodLength - 1, to: startDate)
            let predictedEndDate = calendar.date(byAdding: .day, value: cycleLength - 1, to: startDate)

            let record = CycleRecord(
                startDate: startDate,
                endDate: endDate,
                predictedEndDate: predictedEndDate,
                phase: .menstrual,
                isPredicted: true
            )
            predictions.append(record)
        }

        return predictions
    }

    // MARK: - 计算同房/受孕窗口期
    static func fertilityWindow(from cycleStartDate: Date, cycleLength: Int, lutealLength: Int = 14) -> (start: Date, end: Date) {
        let ovulationDay = cycleLength - lutealLength
        // 受孕窗口: 排卵日前5天到排卵日后1天
        let calendar = Calendar.current
        let ovulationDate = calendar.date(byAdding: .day, value: ovulationDay - 1, to: cycleStartDate) ?? cycleStartDate
        let windowStart = calendar.date(byAdding: .day, value: -5, to: ovulationDate) ?? ovulationDate
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: ovulationDate) ?? ovulationDate
        return (windowStart, windowEnd)
    }
}
