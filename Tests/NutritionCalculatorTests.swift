import XCTest
@testable import WomenMoon

/// 营养计算器的单元测试，校验 Mifflin-St Jeor 公式与宏量营养素换算。
final class NutritionCalculatorTests: XCTestCase {

    // MARK: - BMR

    func testBMRForFemaleMatchesMifflinStJeor() {
        // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
        let bmr = NutritionCalculator.bmr(weightKg: 60, heightCm: 165, age: 30, isFemale: true)
        XCTAssertEqual(bmr, 1320.25, accuracy: 0.01)
    }

    func testBMRForMaleAddsOffset() {
        let male = NutritionCalculator.bmr(weightKg: 60, heightCm: 165, age: 30, isFemale: false)
        let female = NutritionCalculator.bmr(weightKg: 60, heightCm: 165, age: 30, isFemale: true)
        XCTAssertEqual(male - female, 166, accuracy: 0.01, "男性公式与女性相差 166 kcal（-161 与 +5）")
    }

    // MARK: - TDEE

    func testTDEEMultipliers() {
        let bmr = 1400.0
        XCTAssertEqual(NutritionCalculator.tdee(bmr: bmr, activityLevel: .sedentary), 1680, accuracy: 0.01)
        XCTAssertEqual(NutritionCalculator.tdee(bmr: bmr, activityLevel: .lightlyActive), 1925, accuracy: 0.01)
        XCTAssertEqual(NutritionCalculator.tdee(bmr: bmr, activityLevel: .moderatelyActive), 2170, accuracy: 0.01)
        XCTAssertEqual(NutritionCalculator.tdee(bmr: bmr, activityLevel: .veryActive), 2415, accuracy: 0.01)
        XCTAssertEqual(NutritionCalculator.tdee(bmr: bmr, activityLevel: .extraActive), 2660, accuracy: 0.01)
    }

    // MARK: - 热量目标

    func testCalorieTargetAppliesExpectedSurplusOrDeficit() {
        let tdee = 2000.0
        XCTAssertEqual(NutritionCalculator.dailyCalorieTarget(tdee: tdee, goal: .loseWeight), 1500)
        XCTAssertEqual(NutritionCalculator.dailyCalorieTarget(tdee: tdee, goal: .loseFat), 1700)
        XCTAssertEqual(NutritionCalculator.dailyCalorieTarget(tdee: tdee, goal: .gainMuscle), 2300)
        XCTAssertEqual(NutritionCalculator.dailyCalorieTarget(tdee: tdee, goal: .maintain), 2000)
    }

    // MARK: - 宏量营养素

    func testMacroSplitSumsToOne() {
        for goal in Goal.allCases {
            let split = NutritionCalculator.macroSplit(goal: goal)
            XCTAssertEqual(
                split.protein + split.fat + split.carbs, 1.0, accuracy: 0.0001,
                "\(goal.rawValue) 的宏量配比之和应为 1"
            )
        }
    }

    func testMacroGramsFollowCalorieDensity() {
        let calories = 2000.0
        let split = NutritionCalculator.macroSplit(goal: .maintain)

        let protein = NutritionCalculator.dailyProtein(targetCalories: calories, goal: .maintain)
        let fat = NutritionCalculator.dailyFat(targetCalories: calories, goal: .maintain)
        let carbs = NutritionCalculator.dailyCarbs(targetCalories: calories, goal: .maintain)

        XCTAssertEqual(protein, calories * split.protein / 4.0, accuracy: 0.01)
        XCTAssertEqual(fat, calories * split.fat / 9.0, accuracy: 0.01)
        XCTAssertEqual(carbs, calories * split.carbs / 4.0, accuracy: 0.01)
    }

    // MARK: - 周期化调整

    func testCycleAdjustedNutritionByPhase() {
        let base = 1800.0

        let menstrual = NutritionCalculator.cycleAdjustedNutrition(baseCalories: base, phase: .menstrual)
        XCTAssertEqual(menstrual.calories, base + 100)
        XCTAssertTrue(menstrual.extraIron, "经期应提示补铁")

        let luteal = NutritionCalculator.cycleAdjustedNutrition(baseCalories: base, phase: .luteal)
        XCTAssertTrue(luteal.extraMagnesium && luteal.extraB6, "黄体期应提示补镁与 B6")

        let follicular = NutritionCalculator.cycleAdjustedNutrition(baseCalories: base, phase: .follicular)
        XCTAssertEqual(follicular.calories, base)
        XCTAssertFalse(follicular.extraIron || follicular.extraMagnesium || follicular.extraB6)
    }

    // MARK: - 食物换算

    func testCalculateCaloriesScalesByGrams() {
        let entry = NutritionCalculator.calculateCalories(
            foodPer100g: (calories: 200, protein: 10, fat: 5, carbs: 30),
            grams: 250
        )
        XCTAssertEqual(entry.calories, 500, accuracy: 0.01)
        XCTAssertEqual(entry.protein, 25, accuracy: 0.01)
        XCTAssertEqual(entry.fat, 12.5, accuracy: 0.01)
        XCTAssertEqual(entry.carbs, 75, accuracy: 0.01)
        XCTAssertEqual(entry.amountInGrams, 250)
    }

    func testCalculateCaloriesAtOneHundredGramsIsIdentity() {
        let entry = NutritionCalculator.calculateCalories(
            foodPer100g: (calories: 116, protein: 20.4, fat: 0.5, carbs: 0),
            grams: 100
        )
        XCTAssertEqual(entry.calories, 116, accuracy: 0.001)
        XCTAssertEqual(entry.protein, 20.4, accuracy: 0.001)
    }

    func testCalculateCaloriesWithZeroGramsIsZero() {
        let entry = NutritionCalculator.calculateCalories(
            foodPer100g: (calories: 500, protein: 10, fat: 10, carbs: 10),
            grams: 0
        )
        XCTAssertEqual(entry.calories, 0, accuracy: 0.001)
        XCTAssertEqual(entry.protein, 0, accuracy: 0.001)
    }

    // MARK: - 补全周期化调整的缺口

    /// 原测试只覆盖了经期、黄体期、卵泡期，漏了排卵期
    func testOvulatoryAddsFiftyCaloriesWithoutSupplements() {
        let adjusted = NutritionCalculator.cycleAdjustedNutrition(baseCalories: 1800, phase: .ovulatory)
        XCTAssertEqual(adjusted.calories, 1850)
        XCTAssertFalse(adjusted.extraIron)
        XCTAssertFalse(adjusted.extraMagnesium)
        XCTAssertFalse(adjusted.extraB6)
    }

    func testLutealAddsOneHundredFiftyCalories() {
        let adjusted = NutritionCalculator.cycleAdjustedNutrition(baseCalories: 1800, phase: .luteal)
        XCTAssertEqual(adjusted.calories, 1950)
    }

    /// 只有经期与黄体期需要额外补剂，卵泡期与排卵期都维持基础建议。
    /// （注意：这两期的补剂标记完全相同，因此不能用"四种组合互不相同"来断言）
    func testOnlyMenstrualAndLutealPhaseRecommendSupplements() {
        for phase in CyclePhase.allCases {
            let adjusted = NutritionCalculator.cycleAdjustedNutrition(baseCalories: 1800, phase: phase)
            let hasSupplementAdvice = adjusted.extraIron || adjusted.extraMagnesium || adjusted.extraB6

            switch phase {
            case .menstrual, .luteal:
                XCTAssertTrue(hasSupplementAdvice, "\(phase.rawValue) 应给出补剂建议")
            case .follicular, .ovulatory:
                XCTAssertFalse(hasSupplementAdvice, "\(phase.rawValue) 不应给出补剂建议")
            }
        }
    }

    /// 经期补铁、黄体期补镁与 B6 —— 这是两条最核心的周期营养规则
    func testPhaseSpecificSupplementRules() {
        let menstrual = NutritionCalculator.cycleAdjustedNutrition(baseCalories: 1800, phase: .menstrual)
        XCTAssertTrue(menstrual.extraIron, "经期应提示补铁")
        XCTAssertFalse(menstrual.extraB6, "经期不涉及 B6")

        let luteal = NutritionCalculator.cycleAdjustedNutrition(baseCalories: 1800, phase: .luteal)
        XCTAssertFalse(luteal.extraIron, "黄体期不涉及补铁")
        XCTAssertTrue(luteal.extraMagnesium, "黄体期应提示补镁")
        XCTAssertTrue(luteal.extraB6, "黄体期应提示补 B6")
    }

    // MARK: - 宏量配比的完整覆盖

    func testEveryGoalProducesPositiveMacroGrams() {
        for goal in Goal.allCases {
            let calories = 1800.0
            XCTAssertGreaterThan(
                NutritionCalculator.dailyProtein(targetCalories: calories, goal: goal), 0,
                "\(goal.rawValue) 的蛋白质目标应为正数"
            )
            XCTAssertGreaterThan(
                NutritionCalculator.dailyFat(targetCalories: calories, goal: goal), 0,
                "\(goal.rawValue) 的脂肪目标应为正数"
            )
            XCTAssertGreaterThan(
                NutritionCalculator.dailyCarbs(targetCalories: calories, goal: goal), 0,
                "\(goal.rawValue) 的碳水目标应为正数"
            )
        }
    }

    /// 宏量克数换算回热量后应等于目标热量（4/9/4 密度的一致性检验）
    func testMacroGramsReconstructTargetCalories() {
        for goal in Goal.allCases {
            let calories = 2000.0
            let reconstructed = NutritionCalculator.dailyProtein(targetCalories: calories, goal: goal) * 4
                + NutritionCalculator.dailyFat(targetCalories: calories, goal: goal) * 9
                + NutritionCalculator.dailyCarbs(targetCalories: calories, goal: goal) * 4
            XCTAssertEqual(
                reconstructed, calories, accuracy: 0.01,
                "\(goal.rawValue) 的三大宏量按 4/9/4 换算后应还原出目标热量"
            )
        }
    }

    // MARK: - 输入范围的防御性检查

    /// UI 的 Slider 下限（30kg / 130cm）下 BMR 必须为正，
    /// 否则 `dailyCalorieTarget` 会算出负的热量目标并直接显示给用户。
    func testBMRStaysPositiveAtUILowerBounds() {
        let bmr = NutritionCalculator.bmr(weightKg: 30, heightCm: 130, age: 80)
        XCTAssertGreaterThan(bmr, 0, "界面允许的最小身高体重组合下 BMR 仍应为正")
    }

    /// 记录当前行为：`bmr` 不做任何钳位，越界输入会得到负数。
    /// 该值仅在绕过 UI Slider 时可能出现，此测试用于固化契约 —— 调用方需自行保证入参合法。
    func testBMRDoesNotClampDegenerateInput() {
        XCTAssertEqual(NutritionCalculator.bmr(weightKg: 0, heightCm: 0, age: 0), -161, accuracy: 0.01)
    }
}
