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
}
