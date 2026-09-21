import XCTest
@testable import WomenMoon

/// 运动推荐表的单元测试。
///
/// `ExercisePlan.recommended(for:)` 是纯静态表，同时被运动 Tab 的「周期运动指南」、
/// 「各阶段推荐」折叠区、以及 AI 计划生成失败时的降级路径使用 ——
/// 一旦某个阶段缺项或出现空名称，三处界面会同时出问题。
final class ExercisePlanTests: XCTestCase {

    // MARK: - 结构完整性

    func testEveryPhaseHasRecommendations() {
        for phase in CyclePhase.allCases {
            let exercises = ExercisePlan.recommended(for: phase)
            XCTAssertFalse(exercises.isEmpty, "\(phase.rawValue) 缺少推荐运动")
        }
    }

    func testEveryPhaseHasExactlyThreeExercises() {
        for phase in CyclePhase.allCases {
            XCTAssertEqual(
                ExercisePlan.recommended(for: phase).count, 3,
                "\(phase.rawValue) 应推荐 3 项运动"
            )
        }
    }

    func testExerciseNamesAreUniqueWithinEachPhase() {
        for phase in CyclePhase.allCases {
            let names = ExercisePlan.recommended(for: phase).map(\.name)
            XCTAssertEqual(
                Set(names).count, names.count,
                "\(phase.rawValue) 内存在重名运动：\(names.joined(separator: "、"))"
            )
        }
    }

    func testEveryExerciseHasNameAndNotes() {
        for phase in CyclePhase.allCases {
            for exercise in ExercisePlan.recommended(for: phase) {
                XCTAssertFalse(exercise.name.isEmpty, "\(phase.rawValue) 存在无名运动")
                XCTAssertNotNil(exercise.notes, "\(phase.rawValue) 的「\(exercise.name)」缺少说明文案")
                XCTAssertFalse(exercise.notes?.isEmpty ?? true, "\(phase.rawValue) 的「\(exercise.name)」说明文案为空")
            }
        }
    }

    /// 每项运动至少要有时长或组数之一，否则界面上的信息行会是空白
    func testEveryExerciseHasDurationOrSets() {
        for phase in CyclePhase.allCases {
            for exercise in ExercisePlan.recommended(for: phase) {
                let hasDuration = (exercise.durationMinutes ?? 0) > 0
                let hasSets = (exercise.sets ?? 0) > 0 && (exercise.reps ?? 0) > 0
                XCTAssertTrue(
                    hasDuration || hasSets,
                    "\(phase.rawValue) 的「\(exercise.name)」既无时长也无组数"
                )
            }
        }
    }

    func testDurationsAndSetsArePositiveWhenPresent() {
        for phase in CyclePhase.allCases {
            for exercise in ExercisePlan.recommended(for: phase) {
                if let duration = exercise.durationMinutes {
                    XCTAssertGreaterThan(duration, 0, "「\(exercise.name)」时长应为正数")
                }
                if let sets = exercise.sets {
                    XCTAssertGreaterThan(sets, 0, "「\(exercise.name)」组数应为正数")
                }
                if let reps = exercise.reps {
                    XCTAssertGreaterThan(reps, 0, "「\(exercise.name)」次数应为正数")
                }
            }
        }
    }

    // MARK: - 周期阶段语义

    /// 经期应以低强度活动为主，不应出现力量训练或 HIIT
    func testMenstrualRecommendationsAreLowIntensity() {
        let types = Set(ExercisePlan.recommended(for: .menstrual).map(\.type))
        XCTAssertFalse(types.contains(.hiit), "经期不应推荐 HIIT")
        XCTAssertFalse(types.contains(.strength), "经期不应推荐力量训练")
        XCTAssertFalse(types.contains(.running), "经期不应推荐跑步")
    }

    /// 卵泡期与排卵期是雌激素高峰期，应包含高强度项目
    func testPeakPhasesIncludeHighIntensityWork() {
        for phase in [CyclePhase.follicular, .ovulatory] {
            let types = Set(ExercisePlan.recommended(for: phase).map(\.type))
            XCTAssertTrue(
                types.contains(.hiit) || types.contains(.strength),
                "\(phase.rawValue) 应包含高强度项目"
            )
        }
    }

    /// 排卵期强度应不低于卵泡期（组数更多或时长更长）
    func testOvulatoryIntensityIsAtLeastFollicular() {
        let follicular = ExercisePlan.recommended(for: .follicular)
        let ovulatory = ExercisePlan.recommended(for: .ovulatory)

        let follicularStrength = follicular.first { $0.type == .strength }
        let ovulatoryStrength = ovulatory.first { $0.type == .strength }

        XCTAssertNotNil(follicularStrength)
        XCTAssertNotNil(ovulatoryStrength)
        XCTAssertGreaterThanOrEqual(
            ovulatoryStrength!.sets ?? 0, follicularStrength!.sets ?? 0,
            "排卵期的力量训练组数不应少于卵泡期"
        )
    }

    /// 四个阶段的推荐组合必须互不相同，否则「各阶段推荐」折叠区内容重复
    func testEachPhaseProducesDistinctRecommendations() {
        let signatures = CyclePhase.allCases.map { phase in
            ExercisePlan.recommended(for: phase).map(\.name).joined(separator: "|")
        }
        XCTAssertEqual(Set(signatures).count, signatures.count, "不同阶段的推荐运动出现了重复组合")
    }

    func testAllExerciseTypesAreMappedToDisplayNames() {
        for type in ExerciseType.allCases {
            XCTAssertFalse(type.rawValue.isEmpty, "运动类型 \(type) 缺少中文展示名")
        }
    }
}
