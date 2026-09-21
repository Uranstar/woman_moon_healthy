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
}
