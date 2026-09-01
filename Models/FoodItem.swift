import Foundation
import SwiftData

/// 维生素/矿物质含量
struct VitaminContent: Codable, Hashable {
    var name: String       // 如 "维生素C", "铁", "钙"
    var amount: Double     // 含量
    var unit: String       // mg, mcg, IU 等
    var dailyPercentage: Double? // 占每日推荐摄入量的百分比
}

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var category: FoodCategory
    var caloriesPer100g: Double
    var protein: Double       // g/100g
    var fat: Double           // g/100g
    var carbs: Double         // g/100g
    var fiber: Double?        // g/100g
    var sodium: Double?       // mg/100g
    var vitamins: [VitaminContent]
    var isCustom: Bool
    var imageName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: FoodCategory = .staple,
        caloriesPer100g: Double = 0,
        protein: Double = 0,
        fat: Double = 0,
        carbs: Double = 0,
        fiber: Double? = nil,
        sodium: Double? = nil,
        vitamins: [VitaminContent] = [],
        isCustom: Bool = false,
        imageName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.caloriesPer100g = caloriesPer100g
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.fiber = fiber
        self.sodium = sodium
        self.vitamins = vitamins
        self.isCustom = isCustom
        self.imageName = imageName
        self.createdAt = Date()
    }
}

/// 一顿饭中的食物条目 (含具体用量)
struct FoodEntry: Codable, Hashable {
    var foodItemID: UUID
    var foodName: String
    var amountInGrams: Double
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
}

@Model
final class MealRecord {
    var id: UUID
    var date: Date
    var mealType: MealType
    var foods: [FoodEntry]
    var totalCalories: Double
    var totalProtein: Double
    var totalFat: Double
    var totalCarbs: Double
    var notes: String
    var imageData: Data?  // 拍照记录
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType = .breakfast,
        foods: [FoodEntry] = [],
        notes: String = "",
        imageData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.foods = foods
        self.totalCalories = foods.reduce(0) { $0 + $1.calories }
        self.totalProtein = foods.reduce(0) { $0 + $1.protein }
        self.totalFat = foods.reduce(0) { $0 + $1.fat }
        self.totalCarbs = foods.reduce(0) { $0 + $1.carbs }
        self.notes = notes
        self.imageData = imageData
        self.createdAt = Date()
    }
}
