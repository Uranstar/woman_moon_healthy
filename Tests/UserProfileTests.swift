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
}
