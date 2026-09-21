import XCTest
@testable import WomenMoon

/// 用户档案的单元测试。
///
/// `bmi` 曾误用 `targetWeight`（目标体重）计算，且在未设置目标体重时恒为 nil，
/// 导致营养建议与 AI 上下文长期拿到错误的身体数据。这里锁死正确行为。
final class UserProfileTests: XCTestCase {

    func testBMUsesCurrentWeightNotTargetWeight() {
        let profile = UserProfile(
            name: "测试用户",
            weight: 60,
            targetWeight: 50,
            height: 160
        )

        // 60 / 1.6^2 = 23.44
        XCTAssertEqual(profile.bmi ?? -1, 23.44, accuracy: 0.01)
    }

    func testBMIIsAvailableEvenWithoutTargetWeight() {
        let profile = UserProfile(weight: 55, targetWeight: nil, height: 165)
        XCTAssertNotNil(profile.bmi, "未设目标体重时 BMI 仍应可用")
        XCTAssertEqual(profile.bmi ?? -1, 55 / (1.65 * 1.65), accuracy: 0.01)
    }

    func testBMIIsNilWhenHeightOrWeightIsZero() {
        XCTAssertNil(UserProfile(weight: 0, height: 160).bmi)
        XCTAssertNil(UserProfile(weight: 60, height: 0).bmi)
    }

    func testAgeIsDerivedFromBirthDate() {
        let birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        let profile = UserProfile(birthDate: birthDate)
        XCTAssertEqual(profile.age, 30)
    }

    func testCurrentCyclePhaseDelegatesToCalculator() {
        let cycleStart = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let profile = UserProfile(
            cycleLength: 28,
            periodLength: 5,
            lastCycleStartDate: cycleStart
        )

        XCTAssertEqual(
            profile.currentCyclePhase,
            CycleCalculator.currentPhase(from: cycleStart, cycleLength: 28, periodLength: 5),
            "档案的阶段判定应与周期计算引擎一致"
        )
    }

    func testCurrentCyclePhaseFallsBackToFollicularWithoutStartDate() {
        XCTAssertEqual(UserProfile().currentCyclePhase, .follicular)
    }

    func testCurrentCyclePhaseIsMenstrualOnStartDay() {
        let profile = UserProfile(cycleLength: 28, periodLength: 5, lastCycleStartDate: Date())
        XCTAssertEqual(profile.currentCyclePhase, .menstrual, "周期起始日当天应判定为经期")
    }

    /// 回归：短周期不得让档案的阶段判定崩溃。
    /// `CycleTrackerView` 里还有一份手写的判定副本，那条路径此前正是崩溃点。
    func testCurrentCyclePhaseDoesNotCrashForShortCycle() {
        for cycleLength in [8, 15, 20, 21] {
            for periodLength in [2, 5, 10] {
                let profile = UserProfile(
                    cycleLength: cycleLength,
                    periodLength: periodLength,
                    lastCycleStartDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
                )
                _ = profile.currentCyclePhase
            }
        }
    }

    func testBMIForKnownReferenceValue() {
        // 身高 170cm、体重 65kg → 65 / 1.7² = 22.49
        let profile = UserProfile(weight: 65, height: 170)
        XCTAssertEqual(profile.bmi ?? -1, 22.49, accuracy: 0.01)
    }

    func testBMIReflectsCurrentWeightAfterChange() {
        let profile = UserProfile(weight: 70, height: 165)
        let before = profile.bmi
        profile.weight = 60
        let after = profile.bmi

        XCTAssertNotNil(before)
        XCTAssertNotNil(after)
        XCTAssertLessThan(after!, before!, "体重下降后 BMI 应随之下降")
    }

    /// 记录当前行为：`age` 只做日期差，不校验出生日期是否在未来。
    /// 编辑态出生日期选择器没有上限，可选出未来日期，此测试固化该风险点，
    /// 一旦上游加了钳位，本用例会失败并提示更新。
    func testAgeIsNegativeWhenBirthDateIsInTheFuture() {
        let future = Calendar.current.date(byAdding: .year, value: 5, to: Date())!
        XCTAssertLessThan(UserProfile(birthDate: future).age, 0)
    }
}
