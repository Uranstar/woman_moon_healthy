import Foundation

/// 营养计算器
struct NutritionCalculator {
    // MARK: - 计算基础代谢率 (Mifflin-St Jeor 公式)
    static func bmr(weightKg: Double, heightCm: Double, age: Int, isFemale: Bool = true) -> Double {
        if isFemale {
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        } else {
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        }
    }

    // MARK: - 每日总消耗 (TDEE)
    static func tdee(bmr: Double, activityLevel: ActivityLevel) -> Double {
        let multiplier: Double
        switch activityLevel {
        case .sedentary: multiplier = 1.2
        case .lightlyActive: multiplier = 1.375
        case .moderatelyActive: multiplier = 1.55
        case .veryActive: multiplier = 1.725
        case .extraActive: multiplier = 1.9
        }
        return bmr * multiplier
    }

    // MARK: - 根据目标计算每日热量
    static func dailyCalorieTarget(tdee: Double, goal: Goal) -> Double {
        switch goal {
        case .loseWeight: return tdee - 500   // 减重: 赤字500kcal
        case .loseFat: return tdee - 300       // 减脂: 赤字300kcal
        case .gainMuscle: return tdee + 300    // 增肌: 盈余300kcal
        case .maintain: return tdee
        }
    }

    // MARK: - 宏量营养素配比
    static func macroSplit(goal: Goal) -> (protein: Double, fat: Double, carbs: Double) {
        switch goal {
        case .loseWeight:
            return (0.35, 0.30, 0.35)  // 高蛋白
        case .loseFat:
            return (0.40, 0.25, 0.35)  // 高蛋白低碳水
        case .gainMuscle:
            return (0.30, 0.25, 0.45)  // 高碳水
        case .maintain:
            return (0.25, 0.30, 0.45)  // 均衡
        }
    }

    /// 每日蛋白质目标 (克) — 1g蛋白质 = 4kcal
    static func dailyProtein(targetCalories: Double, goal: Goal = .maintain) -> Double {
        let split = macroSplit(goal: goal)
        return (targetCalories * split.protein) / 4.0
    }

    /// 每日脂肪目标 (克) — 1g脂肪 = 9kcal
    static func dailyFat(targetCalories: Double, goal: Goal = .maintain) -> Double {
        let split = macroSplit(goal: goal)
        return (targetCalories * split.fat) / 9.0
    }

    /// 每日碳水目标 (克) — 1g碳水 = 4kcal
    static func dailyCarbs(targetCalories: Double, goal: Goal = .maintain) -> Double {
        let split = macroSplit(goal: goal)
        return (targetCalories * split.carbs) / 4.0
    }

    // MARK: - 根据周期阶段调整营养建议
    static func cycleAdjustedNutrition(
        baseCalories: Double,
        phase: CyclePhase
    ) -> (calories: Double, extraIron: Bool, extraMagnesium: Bool, extraB6: Bool) {
        switch phase {
        case .menstrual:
            // 经期: 微微增加热量 + 补充铁
            return (baseCalories + 100, extraIron: true, extraMagnesium: true, extraB6: false)
        case .follicular:
            // 卵泡期: 标准
            return (baseCalories, extraIron: false, extraMagnesium: false, extraB6: false)
        case .ovulatory:
            // 排卵期: 代谢增加
            return (baseCalories + 50, extraIron: false, extraMagnesium: false, extraB6: false)
        case .luteal:
            // 黄体期: 增加镁和B6
            return (baseCalories + 150, extraIron: false, extraMagnesium: true, extraB6: true)
        }
    }

    // MARK: - 计算食物热量
    static func calculateCalories(foodPer100g: (calories: Double, protein: Double, fat: Double, carbs: Double), grams: Double) -> FoodEntry {
        let ratio = grams / 100.0
        return FoodEntry(
            foodItemID: UUID(),
            foodName: "",
            amountInGrams: grams,
            calories: foodPer100g.calories * ratio,
            protein: foodPer100g.protein * ratio,
            fat: foodPer100g.fat * ratio,
            carbs: foodPer100g.carbs * ratio
        )
    }
}
