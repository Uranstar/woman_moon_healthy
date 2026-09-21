import XCTest
@testable import WomenMoon

/// 周期计算引擎的单元测试。
///
/// 覆盖两类风险：一是日期推算的算错一天，二是短周期下阶段判定崩溃。
final class CycleCalculatorTests: XCTestCase {

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private var startDate: Date { makeDate(2026, 1, 1) }

    // MARK: - 日期推算

    func testPredictNextCycleStart() {
        let next = CycleCalculator.predictNextCycleStart(from: startDate, cycleLength: 28)
        XCTAssertEqual(next, makeDate(2026, 1, 29))
    }

    func testPredictNextCycleStartHonoursCustomLength() {
        let next = CycleCalculator.predictNextCycleStart(from: startDate, cycleLength: 32)
        XCTAssertEqual(next, makeDate(2026, 2, 2))
    }

    func testDayOfCycleIsOneBased() {
        XCTAssertEqual(CycleCalculator.dayOfCycle(from: startDate, to: startDate), 1)
        XCTAssertEqual(CycleCalculator.dayOfCycle(from: startDate, to: makeDate(2026, 1, 10)), 10)
    }

    func testPredictOvulationDay() {
        // 28 天周期、黄体期 14 天 → 第 14 天排卵，即 1 月 14 日
        let ovulation = CycleCalculator.predictOvulationDay(from: startDate, cycleLength: 28, lutealLength: 14)
        XCTAssertEqual(ovulation, makeDate(2026, 1, 14))
    }

    /// 排卵日必须与受孕窗口的中心一致，两者曾因 off-by-one 相差一天
    func testOvulationDayMatchesFertilityWindowCentre() {
        let ovulation = CycleCalculator.predictOvulationDay(from: startDate, cycleLength: 28, lutealLength: 14)
        let window = CycleCalculator.fertilityWindow(from: startDate, cycleLength: 28, lutealLength: 14)
        // 窗口为排卵日前 5 天到后 1 天
        let expectedCentre = Calendar.current.date(byAdding: .day, value: -5, to: window.start)!
        XCTAssertEqual(ovulation, Calendar.current.startOfDay(for: expectedCentre))
    }

    func testFertilityWindowSurroundsOvulation() {
        let window = CycleCalculator.fertilityWindow(from: startDate, cycleLength: 28, lutealLength: 14)
        XCTAssertEqual(Calendar.current.startOfDay(for: window.start), makeDate(2026, 1, 9))
        XCTAssertEqual(Calendar.current.startOfDay(for: window.end), makeDate(2026, 1, 15))
    }

    // MARK: - 阶段判定

    func testPhaseBoundariesForStandardCycle() {
        // 经期 1-5，卵泡期 6-13，排卵期 14-16，黄体期 17-28
        let expectations: [(Int, CyclePhase)] = [
            (1, .menstrual), (5, .menstrual),
            (6, .follicular), (13, .follicular),
            (14, .ovulatory), (16, .ovulatory),
            (17, .luteal), (28, .luteal),
        ]
        for (day, expected) in expectations {
            let date = Calendar.current.date(byAdding: .day, value: day - 1, to: startDate)!
            XCTAssertEqual(
                CycleCalculator.currentPhase(from: startDate, to: date),
                expected,
                "第 \(day) 天应为 \(expected.description)"
            )
        }
    }

    func testPhaseWrapsAfterCycleLength() {
        // 第 29 天应回到下一周期的经期第一天
        let date = Calendar.current.date(byAdding: .day, value: 28, to: startDate)!
        XCTAssertEqual(CycleCalculator.currentPhase(from: startDate, to: date), .menstrual)
    }

    // MARK: - 回归：短周期不应崩溃

    func testShortCycleDoesNotCrash() {
        // 20 天周期下，原实现的 `case 6...5` 会构造非法 ClosedRange 并崩溃
        for day in 1...20 {
            let date = Calendar.current.date(byAdding: .day, value: day - 1, to: startDate)!
            _ = CycleCalculator.currentPhase(
                from: startDate, cycleLength: 20, periodLength: 5, lutealLength: 14, to: date
            )
        }
    }

    func testVeryShortCycleDoesNotCrash() {
        // 极端值：周期短于经期长度
        for day in 1...8 {
            let date = Calendar.current.date(byAdding: .day, value: day - 1, to: startDate)!
            _ = CycleCalculator.currentPhase(
                from: startDate, cycleLength: 8, periodLength: 7, lutealLength: 7, to: date
            )
        }
    }

    func testDateBeforeCycleStartDoesNotCrash() {
        let earlier = Calendar.current.date(byAdding: .day, value: -10, to: startDate)!
        XCTAssertEqual(
            CycleCalculator.currentPhase(from: startDate, to: earlier),
            .menstrual,
            "早于周期起始日应钳到经期，而不是返回负数天导致的错误阶段"
        )
    }

    /// Date 扩展与 CycleCalculator 必须给出同一答案，否则界面上会出现两套周期口径
    func testDateExtensionMatchesCalculator() {
        for day in [1, 5, 6, 13, 14, 16, 17, 28] {
            let date = Calendar.current.date(byAdding: .day, value: day - 1, to: startDate)!
            XCTAssertEqual(
                date.cyclePhase(cycleStartDate: startDate, cycleLength: 28, periodLength: 5),
                CycleCalculator.currentPhase(from: startDate, to: date),
                "第 \(day) 天两套实现判定不一致"
            )
        }
    }

    // MARK: - 预测生成

    func testPredictionsStartFromNextCycle() {
        let predictions = CycleCalculator.generatePredictions(
            from: startDate, cycleLength: 28, periodLength: 5, months: 3
        )
        XCTAssertEqual(predictions.count, 3)
        XCTAssertTrue(predictions.allSatisfy { $0.isPredicted })

        let firstStart = Calendar.current.startOfDay(for: predictions[0].startDate)
        XCTAssertEqual(firstStart, makeDate(2026, 1, 29), "首条预测应是下一个周期，而非与真实记录同日")
        XCTAssertTrue(
            predictions.allSatisfy { $0.startDate > startDate },
            "预测记录不应与真实的周期起始日重叠"
        )
    }

    func testGeneratePredictionsCountMatchesRequestedMonths() {
        for months in [1, 3, 6, 12] {
            let predictions = CycleCalculator.generatePredictions(
                from: startDate, cycleLength: 28, periodLength: 5, months: months
            )
            XCTAssertEqual(predictions.count, months, "请求 \(months) 个月应生成 \(months) 条预测")
        }
    }

    /// 回归：`months <= 0` 曾使 `for i in 1...months` 构造非法 ClosedRange 并崩溃
    func testGeneratePredictionsWithNonPositiveMonthsReturnsEmpty() {
        for months in [0, -1, -12] {
            XCTAssertTrue(
                CycleCalculator.generatePredictions(
                    from: startDate, cycleLength: 28, periodLength: 5, months: months
                ).isEmpty,
                "months=\(months) 应返回空数组而不是崩溃"
            )
        }
    }

    func testPredictionDatesAdvanceByExactlyOneCycle() {
        let predictions = CycleCalculator.generatePredictions(
            from: startDate, cycleLength: 28, periodLength: 5, months: 4
        )
        for (index, prediction) in predictions.enumerated() {
            let expected = Calendar.current.date(byAdding: .day, value: (index + 1) * 28, to: startDate)!
            XCTAssertEqual(
                Calendar.current.startOfDay(for: prediction.startDate),
                Calendar.current.startOfDay(for: expected),
                "第 \(index + 1) 条预测的起始日应恰好相隔 \(index + 1) 个周期"
            )
        }
    }

    // MARK: - 边界：跨月跨年与闰年

    func testPredictNextCycleStartCrossesYearBoundary() {
        let next = CycleCalculator.predictNextCycleStart(from: makeDate(2026, 12, 20), cycleLength: 28)
        XCTAssertEqual(next, makeDate(2027, 1, 17))
    }

    func testPredictNextCycleStartHandlesLeapFebruary() {
        // 2028 是闰年，2 月有 29 天
        let next = CycleCalculator.predictNextCycleStart(from: makeDate(2028, 2, 1), cycleLength: 28)
        XCTAssertEqual(next, makeDate(2028, 2, 29))
    }

    // MARK: - 极端参数不应崩溃

    func testPeriodLongerThanCycleDoesNotCrash() {
        for day in 1...30 {
            let date = Calendar.current.date(byAdding: .day, value: day - 1, to: startDate)!
            _ = CycleCalculator.currentPhase(
                from: startDate, cycleLength: 28, periodLength: 40, lutealLength: 14, to: date
            )
        }
    }

    func testLutealLongerThanCycleDoesNotCrash() {
        for day in 1...30 {
            let date = Calendar.current.date(byAdding: .day, value: day - 1, to: startDate)!
            _ = CycleCalculator.currentPhase(
                from: startDate, cycleLength: 21, periodLength: 5, lutealLength: 30, to: date
            )
        }
    }

    func testSingleDayCycleDoesNotCrash() {
        _ = CycleCalculator.currentPhase(from: startDate, cycleLength: 1, periodLength: 1, lutealLength: 1)
    }

    func testFertilityWindowForShortCycleDoesNotCrash() {
        let window = CycleCalculator.fertilityWindow(from: startDate, cycleLength: 10, lutealLength: 14)
        XCTAssertLessThanOrEqual(window.start, window.end, "窗口的起始不应晚于结束")
    }

    // MARK: - 性质断言：全参数域不变量

    /// 遍历 UI 允许的全部周期参数组合，断言任意一天都能归入某个阶段且不崩溃。
    /// （周期 21–35、经期 2–10 取自 Onboarding / ProfileEdit 的 Slider 范围）
    func testEveryDayOfSupportedParameterRangeMapsToAPhase() {
        for cycleLength in 21...35 {
            for periodLength in 2...10 {
                for lutealLength in 10...16 {
                    let phases = (1...cycleLength).map { day -> CyclePhase in
                        let date = Calendar.current.date(byAdding: .day, value: day - 1, to: startDate)!
                        return CycleCalculator.currentPhase(
                            from: startDate,
                            cycleLength: cycleLength,
                            periodLength: periodLength,
                            lutealLength: lutealLength,
                            to: date
                        )
                    }
                    XCTAssertEqual(phases.count, cycleLength, "周期内每一天都应有一个阶段")
                }
            }
        }
    }

    /// 阶段顺序必须是 经期 → 卵泡期 → 排卵期 → 黄体期，不允许回退。
    /// 回归背景：`CycleTrackerView` 里还有一份手写的阶段判定副本，两套口径若不同步，
    /// 日历配色与详情页文案就会互相矛盾。
    func testPhaseOrderIsMonotonicWithinACycle() {
        let order: [CyclePhase: Int] = [.menstrual: 0, .follicular: 1, .ovulatory: 2, .luteal: 3]

        for cycleLength in 21...35 {
            for periodLength in 2...10 {
                var previous = 0
                for day in 1...cycleLength {
                    let date = Calendar.current.date(byAdding: .day, value: day - 1, to: startDate)!
                    let phase = CycleCalculator.currentPhase(
                        from: startDate, cycleLength: cycleLength, periodLength: periodLength, to: date
                    )
                    let rank = order[phase]!
                    XCTAssertGreaterThanOrEqual(
                        rank, previous,
                        "周期 \(cycleLength) 天 / 经期 \(periodLength) 天时，第 \(day) 天的阶段 \(phase.rawValue) 出现回退"
                    )
                    previous = rank
                }
            }
        }
    }

    /// 第 1 天必须永远是经期 —— 这是"周期起点"的定义，也是日历高亮的依据
    func testFirstDayIsAlwaysMenstrual() {
        for cycleLength in 21...35 {
            for periodLength in 2...10 {
                XCTAssertEqual(
                    CycleCalculator.currentPhase(
                        from: startDate, cycleLength: cycleLength, periodLength: periodLength, to: startDate
                    ),
                    .menstrual,
                    "周期 \(cycleLength) 天 / 经期 \(periodLength) 天的第 1 天应为经期"
                )
            }
        }
    }

    // MARK: - 受孕窗口

    func testFertilityWindowSpansSevenDays() {
        let window = CycleCalculator.fertilityWindow(from: startDate, cycleLength: 28, lutealLength: 14)
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: window.start),
            to: Calendar.current.startOfDay(for: window.end)
        ).day
        XCTAssertEqual(days, 6, "排卵日前 5 天到后 1 天，共跨度 6 天（7 个自然日）")
    }
}
