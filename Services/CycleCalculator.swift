import Foundation

/// 经期周期计算引擎
struct CycleCalculator {
    // MARK: - 预测下一个周期开始日
    static func predictNextCycleStart(from lastStartDate: Date, cycleLength: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: cycleLength, to: lastStartDate) ?? lastStartDate
    }

    // MARK: - 预测排卵日
    static func predictOvulationDay(from cycleStartDate: Date, cycleLength: Int, lutealLength: Int = 14) -> Date {
        let ovulationDay = cycleLength - lutealLength
        return Calendar.current.date(byAdding: .day, value: ovulationDay, to: cycleStartDate) ?? cycleStartDate
    }

    // MARK: - 计算当前天在周期中的位置
    static func dayOfCycle(from cycleStartDate: Date, to date: Date = Date()) -> Int {
        let days = Calendar.current.dateComponents([.day], from: cycleStartDate, to: date).day ?? 0
        return days + 1
    }

    // MARK: - 判断当前周期阶段
    static func currentPhase(
        from cycleStartDate: Date,
        cycleLength: Int = 28,
        periodLength: Int = 5,
        lutealLength: Int = 14
    ) -> CyclePhase {
        let currentDay = dayOfCycle(from: cycleStartDate)
        let normalizedDay = ((currentDay - 1) % cycleLength) + 1

        switch normalizedDay {
        case 1...periodLength:
            return .menstrual
        case (periodLength + 1)...(cycleLength - lutealLength - 1):
            return .follicular
        case (cycleLength - lutealLength)...(cycleLength - lutealLength + 2):
            return .ovulatory
        default:
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
        var predictions: [CycleRecord] = []
        let calendar = Calendar.current

        for i in 0..<months {
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
