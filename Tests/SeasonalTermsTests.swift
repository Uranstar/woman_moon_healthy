import XCTest
@testable import WomenMoon

/// 24 节气推算引擎的单元测试。
///
/// 背景：原实现硬编码了 2026 年数据，且 `termsForYear(_:)` **完全忽略传入的 year 参数**，
/// 永远返回同一份表 —— 2028 年起节气功能彻底空白。硬编码数据本身也错了 2 天
/// （大暑应为 7 月 23 日，雨水应为 2 月 18 日）。现改为解算太阳视黄经的天文算法。
///
/// 本文件锁定三件事：
/// 1. 任意年份都能返回完整、升序、不重名的 24 个节气；
/// 2. 关键日期的取值与权威数据一致（不是"和上一版一样"，而是"和真实天象一样"）；
/// 3. 跨年空档已消除 —— 1 月 1 日到小寒之间必须回落到上一年冬至。
final class SeasonalTermsTests: XCTestCase {

    /// 节气按北京时间判定，断言必须用同一时区取日期分量，否则会因时差整体偏一天
    private func beijingDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")
            ?? TimeZone(secondsFromGMT: 8 * 3600)!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year!, components.month!, components.day!
        )
    }

    private func beijingDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")
            ?? TimeZone(secondsFromGMT: 8 * 3600)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 标准 24 节气名，按公历年内出现顺序
    private let standardTermNames = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
        "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
        "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
        "寒露", "霜降", "立冬", "小雪", "大雪", "冬至",
    ]

    /// 2026 年 24 节气日期 —— 由算法输出后与权威数据核对确认
    private let expected2026: [String: String] = [
        "小寒": "2026-01-05", "大寒": "2026-01-20", "立春": "2026-02-04", "雨水": "2026-02-18",
        "惊蛰": "2026-03-05", "春分": "2026-03-20", "清明": "2026-04-05", "谷雨": "2026-04-20",
        "立夏": "2026-05-05", "小满": "2026-05-21", "芒种": "2026-06-05", "夏至": "2026-06-21",
        "小暑": "2026-07-07", "大暑": "2026-07-23", "立秋": "2026-08-07", "处暑": "2026-08-23",
        "白露": "2026-09-07", "秋分": "2026-09-23", "寒露": "2026-10-08", "霜降": "2026-10-23",
        "立冬": "2026-11-07", "小雪": "2026-11-22", "大雪": "2026-12-07", "冬至": "2026-12-22",
    ]

    // MARK: - 覆盖任意年份

    func testEveryYearReturnsTwentyFourTerms() {
        for year in [2025, 2026, 2027, 2028, 2030, 2035, 2050] {
            let terms = SeasonalTerms.termsForYear(year)
            XCTAssertEqual(terms.count, 24, "\(year) 年应返回 24 个节气")
        }
    }

    /// 回归：原实现忽略 year 参数，任何年份都返回同一份 2026 年数据
    func testDifferentYearsProduceDifferentDates() {
        let dates2026 = SeasonalTerms.termsForYear(2026).map { beijingDay($0.date) }
        let dates2035 = SeasonalTerms.termsForYear(2035).map { beijingDay($0.date) }
        XCTAssertNotEqual(dates2026, dates2035, "不同年份的节气日期不应完全相同")
        XCTAssertEqual(dates2026.count, dates2035.count)
    }

    func testTermsAreAscendingWithinYear() {
        for year in [2026, 2027, 2035, 2050] {
            let terms = SeasonalTerms.termsForYear(year)
            for index in 1..<terms.count {
                XCTAssertLessThanOrEqual(
                    terms[index - 1].date, terms[index].date,
                    "\(year) 年第 \(index + 1) 个节气的时间早于前一个，排序有误"
                )
            }
        }
    }

    func testTermNamesAreExactlyTheStandardSet() {
        for year in [2026, 2030] {
            let names = SeasonalTerms.termsForYear(year).map(\.name)
            XCTAssertEqual(Set(names).count, 24, "\(year) 年存在重复节气名")
            XCTAssertEqual(names.sorted(), standardTermNames.sorted(), "\(year) 年节气名集合不符合标准 24 节气")
        }
    }

    // MARK: - 与权威数据比对

    func testAllTwentyFourTermsFor2026MatchKnownDates() {
        let terms = SeasonalTerms.termsForYear(2026)
        var actual: [String: String] = [:]
        for term in terms { actual[term.name] = beijingDay(term.date) }

        for (name, expected) in expected2026 {
            XCTAssertEqual(actual[name], expected, "2026 年\(name)日期不符")
        }
    }

    /// 2026 年大暑实际交节于 7 月 23 日 03:12:48（北京时间），算法算得 03:13。
    /// 项目原先硬编码为 7 月 22 日，是明确的数据错误。
    func testMajorHeat2026IsJuly23NotJuly22() {
        let terms = SeasonalTerms.termsForYear(2026)
        guard let daShu = terms.first(where: { $0.name == "大暑" }) else {
            return XCTFail("2026 年未找到大暑")
        }
        XCTAssertEqual(beijingDay(daShu.date), "2026-07-23", "2026 年大暑应为 7 月 23 日")
    }

    /// 2026 年雨水实际为 2 月 18 日，原硬编码表写的是 2 月 19 日
    func testRainWater2026IsFebruary18() {
        let terms = SeasonalTerms.termsForYear(2026)
        guard let yuShui = terms.first(where: { $0.name == "雨水" }) else {
            return XCTFail("2026 年未找到雨水")
        }
        XCTAssertEqual(beijingDay(yuShui.date), "2026-02-18", "2026 年雨水应为 2 月 18 日")
    }

    // MARK: - 当前节气：跨年空档与切换口径

    /// 回归：1 月 1 日到小寒之间（每年约 4 天）原实现返回 nil
    func testEarlyJanuaryFallsBackToPreviousWinterSolstice() {
        for (year, month, day) in [(2026, 1, 1), (2026, 1, 4), (2027, 1, 1)] {
            let name = SeasonalTerms.currentTermName(for: beijingDate(year, month, day))
            XCTAssertEqual(
                name, "冬至",
                "\(year)-\(month)-\(day) 处于上一年冬至区间，不应返回 nil 或错误节气"
            )
        }
    }

    func testTermSwitchesOnSolarTermDayNotMoment() {
        // 小寒 2026-01-05 16:19 才交节，但按日期口径当天就应显示小寒
        XCTAssertEqual(SeasonalTerms.currentTermName(for: beijingDate(2026, 1, 5)), "小寒")
        XCTAssertEqual(SeasonalTerms.currentTermName(for: beijingDate(2026, 1, 4)), "冬至")
    }

    func testCurrentTermNameIsNeverNilForSampledYear() {
        for month in 1...12 {
            for day in [1, 10, 20, 28] {
                let date = beijingDate(2026, month, day)
                XCTAssertNotNil(
                    SeasonalTerms.currentTermName(for: date),
                    "2026-\(month)-\(day) 应能判定出节气"
                )
            }
        }
    }

    func testCurrentTermNameAdvancesAtMajorHeat() {
        XCTAssertEqual(SeasonalTerms.currentTermName(for: beijingDate(2026, 7, 22)), "小暑")
        XCTAssertEqual(SeasonalTerms.currentTermName(for: beijingDate(2026, 7, 23)), "大暑")
    }

    // MARK: - termFor(date:)：仅当天恰逢交节才返回

    func testTermForReturnsNameOnlyOnTheExactDay() {
        XCTAssertEqual(SeasonalTerms.termFor(date: beijingDate(2026, 7, 23)), "大暑")
        XCTAssertEqual(SeasonalTerms.termFor(date: beijingDate(2026, 7, 22)), "", "非交节当日应返回空串")
        XCTAssertEqual(SeasonalTerms.termFor(date: beijingDate(2026, 2, 18)), "雨水")
    }

    // MARK: - 内容库完整性

    func testDetailExistsForAllTwentyFourTerms() {
        XCTAssertEqual(SeasonalTerms.termDatabase.count, 24, "节气详情库应恰好有 24 条")
        for name in standardTermNames {
            XCTAssertNotNil(SeasonalTerms.detail(for: name), "\(name) 缺少详情数据")
        }
    }

    func testEveryTermHasNonEmptySeasonalFoods() {
        for name in standardTermNames {
            guard let detail = SeasonalTerms.detail(for: name) else { continue }
            XCTAssertFalse(detail.seasonalFoods.isEmpty, "\(name) 的时令食材为空，首页节气卡会显示空白")
        }
    }

    func testDetailReturnsNilForUnknownTerm() {
        XCTAssertNil(SeasonalTerms.detail(for: "不存在的节气"))
    }

    // MARK: - 缓存一致性

    /// 按年缓存加锁，重复读取必须返回同一结果
    func testRepeatedLookupsAreStable() {
        let first = SeasonalTerms.termsForYear(2026).map { beijingDay($0.date) }
        let second = SeasonalTerms.termsForYear(2026).map { beijingDay($0.date) }
        XCTAssertEqual(first, second, "同一年的重复查询结果应一致")
    }
}
