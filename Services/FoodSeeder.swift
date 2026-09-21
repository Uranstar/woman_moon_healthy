import Foundation
import SwiftData
import os

/// 把打包在 App 内的 `FoodDatabase.json` 导入 SwiftData。
///
/// 背景：这份 JSON 一直被打进 bundle，但项目里**没有任何代码读取它**，
/// 加上 `FoodCategory` 的 `rawValue` 是中文、JSON 里却是英文键，
/// 于是「食材库」和「从食材库选择」永远是空的，用户只能逐条手输。
enum FoodSeeder {

    private static let logger = Logger(subsystem: "com.womenmoon.app", category: "food")

    /// 与 FoodDatabase.json 中单条记录对应的解码模型
    private struct SeedFood: Decodable {
        let name: String
        let category: String
        let caloriesPer100g: Double
        let protein: Double
        let fat: Double
        let carbs: Double
        let fiber: Double?
        let sodium: Double?
    }

    /// 仅在食材库为空时导入，避免重复写入、也避免覆盖用户自建的食物。
    ///
    /// - Returns: 本次实际导入的条数（已有数据时为 0）
    @discardableResult
    static func seedIfNeeded(modelContext: ModelContext) -> Int {
        let existing: Int
        do {
            existing = try modelContext.fetchCount(FetchDescriptor<FoodItem>())
        } catch {
            logger.error("读取食材库数量失败，跳过导入：\(error.localizedDescription, privacy: .public)")
            return 0
        }

        guard existing == 0 else {
            logger.debug("食材库已有 \(existing) 条记录，跳过内置数据导入")
            return 0
        }

        return importBuiltInFoods(modelContext: modelContext)
    }

    /// 强制导入内置食物（供设置页「恢复内置食材库」使用）
    @discardableResult
    static func importBuiltInFoods(modelContext: ModelContext) -> Int {
        guard let url = Bundle.main.url(forResource: "FoodDatabase", withExtension: "json") else {
            logger.error("找不到 FoodDatabase.json，请确认它已加入 target 的 Copy Bundle Resources")
            return 0
        }

        do {
            let data = try Data(contentsOf: url)
            let seeds = try JSONDecoder().decode([SeedFood].self, from: data)
            guard !seeds.isEmpty else {
                logger.error("FoodDatabase.json 解析结果为空")
                return 0
            }

            var unknownCategories: Set<String> = []
            var imported = 0

            for seed in seeds {
                guard let category = FoodCategory(seedKey: seed.category) else {
                    // 不静默丢弃：记下无法识别的分类，便于及时补映射
                    unknownCategories.insert(seed.category)
                    continue
                }
                modelContext.insert(
                    FoodItem(
                        name: seed.name,
                        category: category,
                        caloriesPer100g: seed.caloriesPer100g,
                        protein: seed.protein,
                        fat: seed.fat,
                        carbs: seed.carbs,
                        fiber: seed.fiber,
                        sodium: seed.sodium,
                        isCustom: false
                    )
                )
                imported += 1
            }

            try modelContext.save()

            if !unknownCategories.isEmpty {
                logger.error("以下分类未能识别，已跳过：\(unknownCategories.sorted().joined(separator: ", "), privacy: .public)")
            }
            logger.info("已导入 \(imported) 条内置食材")

            // 全部条目都因分类无法识别而被跳过，说明映射表与数据文件已脱节
            if imported == 0 {
                logger.error("没有任何食材被导入，请检查 FoodCategory.seedKey 与 FoodDatabase.json 是否一致")
            }
            return imported

        } catch {
            logger.error("导入内置食材失败：\(error.localizedDescription, privacy: .public)")
            return 0
        }
    }
}
