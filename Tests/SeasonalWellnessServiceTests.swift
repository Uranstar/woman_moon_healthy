import XCTest
@testable import WomenMoon

/// 节气养生服务的单元测试。
///
/// 覆盖季节划分边界与节气详情的透传，确保首页节气卡与节气饮食页取到一致的数据。
final class SeasonalWellnessServiceTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - 季节划分

    func testSeasonMappingForAllTwelveMonths() {
        let expected: [Int: Season] = [
            1: .winter, 2: .winter, 3: .spring,
            4: .spring, 5: .spring, 6: .summer,
            7: .summer, 8: .summer, 9: .autumn,
            10: .autumn, 11: .autumn, 12: .winter,
        ]

        for month in 1...12 {
            XCTAssertEqual(
                SeasonalWellnessService.currentSeason(for: date(2026, month, 15)),
                expected[month],
                "\(month) 月应归入 \(expected[month]!.rawValue) 季"
            )
        }
    }

    /// 边界月：3/6/9/12 月的第一天与最后一天都应落在同一季节内
    func testSeasonBoundaryMonthsAreInternallyConsistent() {
        for (month, expected) in [(3, Season.spring), (6, .summer), (9, .autumn), (12, .winter)] {
            for day in [1, 15, 28] {
                XCTAssertEqual(
                    SeasonalWellnessService.currentSeason(for: date(2026, month, day)),
                    expected,
                    "\(month) 月 \(day) 日应属于 \(expected.rawValue) 季"
                )
            }
        }
    }

    func testSeasonElementsFollowFivePhasesMapping() {
        XCTAssertEqual(Season.spring.element, "木")
        XCTAssertEqual(Season.summer.element, "火")
        XCTAssertEqual(Season.autumn.element, "金")
        XCTAssertEqual(Season.winter.element, "水")
    }

    func testSeasonOrgansArePairedViscera() {
        XCTAssertEqual(Season.spring.organs, ["肝", "胆"])
        XCTAssertEqual(Season.summer.organs, ["心", "小肠"])
        XCTAssertEqual(Season.autumn.organs, ["肺", "大肠"])
        XCTAssertEqual(Season.winter.organs, ["肾", "膀胱"])
    }

    func testEverySeasonHasElementAndOrgans() {
        for season in [Season.spring, .summer, .autumn, .winter] {
            XCTAssertFalse(season.element.isEmpty, "\(season.rawValue) 季缺少五行属性")
            XCTAssertEqual(season.organs.count, 2, "\(season.rawValue) 季应关联两个脏腑")
        }
    }

    // MARK: - 当前节气

    func testCurrentSolarTermMatchesTermEngine() {
        let sample = date(2026, 7, 23)
        let fromService = SeasonalWellnessService.currentSolarTerm(for: sample)
        let fromEngine = SeasonalTerms.currentTermName(for: sample)

        XCTAssertEqual(fromService?.name, fromEngine, "服务层与引擎层返回的节气名应一致")
        XCTAssertEqual(fromService?.name, "大暑")
    }

    func testCurrentSolarTermIsNeverNilForAnyDayOfYear() {
        for month in 1...12 {
            for day in [1, 5, 15, 25] {
                XCTAssertNotNil(
                    SeasonalWellnessService.currentSolarTerm(for: date(2026, month, day)),
                    "\(month) 月 \(day) 日应能取到节气详情"
                )
            }
        }
    }

    // MARK: - 养生建议透传

    func testWellnessAdviceMirrorsSolarTerm() {
        guard let term = SeasonalWellnessService.currentSolarTerm(for: date(2026, 7, 23)) else {
            return XCTFail("未能取到 2026 年大暑详情")
        }
        let advice = SeasonalWellnessService.wellnessAdvice(for: term)

        XCTAssertEqual(advice.termName, term.name)
        XCTAssertEqual(advice.termDescription, term.description)
        XCTAssertEqual(advice.dietAdvice, term.dietRecommendations)
        XCTAssertEqual(advice.lifestyleAdvice, term.lifestyleRecommendations)
        XCTAssertEqual(advice.exerciseAdvice, term.exerciseRecommendations)
        XCTAssertEqual(advice.seasonalFoods, term.seasonalFoods)
        XCTAssertEqual(advice.healthTips, term.healthTips)
    }

    /// 首页节气卡展示的是 `seasonalFoods.prefix(6)`。
    /// 实测各节气为 4–5 项，取不满 6 属正常，但绝不能为空 —— 否则卡片会留白。
    func testSeasonalFoodsIsNonEmptyForEveryTerm() {
        for name in SeasonalTerms.termDatabase.keys {
            guard let term = SeasonalTerms.detail(for: name) else { continue }
            XCTAssertFalse(
                term.seasonalFoods.isEmpty,
                "\(name) 的时令食材为空，首页节气卡会留白"
            )
        }
    }

    /// 节气卡的详情页会展示饮食/起居/运动三类建议，任一为空都会出现空区块
    func testEveryTermHasAllAdviceSections() {
        for name in SeasonalTerms.termDatabase.keys {
            guard let term = SeasonalTerms.detail(for: name) else { continue }
            XCTAssertFalse(term.description.isEmpty, "\(name) 缺少节气描述")
            XCTAssertFalse(term.dietRecommendations.isEmpty, "\(name) 缺少饮食建议")
            XCTAssertFalse(term.lifestyleRecommendations.isEmpty, "\(name) 缺少起居建议")
            XCTAssertFalse(term.exerciseRecommendations.isEmpty, "\(name) 缺少运动建议")
        }
    }

    func testSeasonalFoodsConvenienceMatchesCurrentTerm() {
        let sample = date(2026, 7, 23)
        let foods = SeasonalWellnessService.seasonalFoods(for: sample)
        let expected = SeasonalWellnessService.currentSolarTerm(for: sample)?.seasonalFoods ?? []
        XCTAssertEqual(foods, expected)
    }
}
