import XCTest
@testable import WomenMoon

/// 食材分类映射的单元测试。
///
/// 这是一个曾经让整个食材库"通不了电"的坑：
/// `FoodCategory.rawValue` 是中文展示名（主食/肉类/…），
/// 而 `Resources/FoodDatabase.json` 的 `category` 字段用的是英文键（staple/meat/…）。
/// 用 `FoodCategory(rawValue:)` 反序列化时，**每一条都会解析失败**，
/// 且失败是静默的 —— 不会报错，只是食材一条都进不来。
final class FoodCategoryTests: XCTestCase {

    /// 与 FoodDatabase.json 中实际出现的 category 取值一一对应
    private let seedKeysInDatabase = [
        "staple", "meat", "seafood", "egg", "dairy", "vegetable",
        "fruit", "nut", "beverage", "snack", "supplement", "seasoning",
    ]

    // MARK: - 映射正确性

    func testSeedKeyRoundTripsForEveryCase() {
        for category in FoodCategory.allCases {
            XCTAssertEqual(
                FoodCategory(seedKey: category.seedKey), category,
                "\(category.rawValue) 的 seedKey 无法反解回自身"
            )
        }
    }

    func testSeedKeysAreUnique() {
        let keys = FoodCategory.allCases.map(\.seedKey)
        XCTAssertEqual(Set(keys).count, keys.count, "存在重复的 seedKey")
    }

    func testAllDatabaseSeedKeysResolve() {
        for key in seedKeysInDatabase {
            XCTAssertNotNil(FoodCategory(seedKey: key), "seedKey「\(key)」无法映射到分类")
        }
    }

    func testEveryCategoryIsUsedByTheDatabase() {
        let covered = Set(seedKeysInDatabase.compactMap { FoodCategory(seedKey: $0) })
        XCTAssertEqual(
            covered.count, FoodCategory.allCases.count,
            "内置食材库未覆盖全部分类，缺失：\(Set(FoodCategory.allCases).subtracting(covered).map(\.rawValue))"
        )
    }

    // MARK: - 锁死"不能走 rawValue"这条坑

    /// 中英文两套键必须互不相同，否则说明 seedKey 被误写成了中文，
    /// 那这个映射层就形同虚设
    func testSeedKeyIsNeverEqualToRawValue() {
        for category in FoodCategory.allCases {
            XCTAssertNotEqual(
                category.seedKey, category.rawValue,
                "\(category.rawValue) 的 seedKey 与展示名相同，中英文映射层失效"
            )
        }
    }

    /// 用一个英文 seedKey 去走 rawValue 初始化必须失败 —— 这正是当初的 bug 成因
    func testRawValueInitializerRejectsEnglishSeedKeys() {
        XCTAssertNil(
            FoodCategory(rawValue: "staple"),
            "`FoodCategory(rawValue:)` 不应接受英文 seedKey；若此处返回非 nil，说明映射逻辑被改动"
        )
    }

    func testSeedKeyInitializerRejectsChineseDisplayNames() {
        XCTAssertNil(FoodCategory(seedKey: "主食"))
        XCTAssertNil(FoodCategory(seedKey: "肉类"))
    }

    func testUnknownSeedKeyReturnsNil() {
        XCTAssertNil(FoodCategory(seedKey: "unknown_category"))
        XCTAssertNil(FoodCategory(seedKey: ""))
    }

    // MARK: - 真实数据文件校验

    /// 直接读取 `Resources/FoodDatabase.json`，验证每一条的 category 都能映射。
    /// 若测试宿主未暴露 app bundle，本用例会跳过而不是误报失败。
    func testEveryFoodItemInDatabaseHasMappableCategory() throws {
        let items = try loadFoodDatabase()

        XCTAssertGreaterThanOrEqual(items.count, 118, "内置食材条目数少于预期，扩充的数据可能未写入")

        var unmapped: Set<String> = []
        for item in items {
            guard let category = item["category"] as? String else {
                XCTFail("存在缺少 category 字段的条目：\(item["name"] ?? "?")")
                continue
            }
            if FoodCategory(seedKey: category) == nil {
                unmapped.insert(category)
            }
        }

        XCTAssertTrue(
            unmapped.isEmpty,
            "以下 category 取值无法映射到 FoodCategory：\(unmapped.sorted().joined(separator: "、"))"
        )
    }

    func testEveryFoodItemHasNameAndCalories() throws {
        let items = try loadFoodDatabase()

        for item in items {
            XCTAssertNotNil(item["name"] as? String, "存在缺少 name 的条目")
            XCTAssertNotNil(item["caloriesPer100g"] as? Double, "「\(item["name"] ?? "?")」缺少热量值")
        }
    }

    func testFoodNamesAreUnique() throws {
        let items = try loadFoodDatabase()
        let names = items.compactMap { $0["name"] as? String }
        let duplicates = Dictionary(grouping: names, by: { $0 })
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        XCTAssertTrue(duplicates.isEmpty, "食材库存在重名条目：\(duplicates.joined(separator: "、"))")
    }

    func testNutritionValuesAreNonNegative() throws {
        let items = try loadFoodDatabase()

        for item in items {
            let name = item["name"] as? String ?? "?"
            for key in ["caloriesPer100g", "protein", "fat", "carbs", "fiber"] {
                if let value = item[key] as? Double {
                    XCTAssertGreaterThanOrEqual(value, 0, "「\(name)」的 \(key) 为负数")
                }
            }
        }
    }

    // MARK: - Helper

    private func loadFoodDatabase() throws -> [[String: Any]] {
        for bundle in [Bundle.main, Bundle(for: FoodCategoryTests.self)] {
            guard let url = bundle.url(forResource: "FoodDatabase", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { continue }
            return array
        }
        throw XCTSkip("未能定位 FoodDatabase.json（测试宿主可能未暴露 app bundle 资源）")
    }
}
