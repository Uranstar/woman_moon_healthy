import XCTest
import SwiftData
@testable import WomenMoon

/// `CycleService` 写路径的单元测试（内存态 SwiftData）。
///
/// **这是此前最大的测试盲区**：全部既有测试都只覆盖 `static func` 纯计算，
/// 没有一个触碰 `ModelContext`。而 `CycleService` 承载了全部数据一致性责任 ——
/// 记录是新增还是更新、预测会不会与真实记录重叠、单日记录会不会吞掉相邻日、
/// 平均周期算得对不对。历史上修的三个数据问题全部落在这里。
///
/// 使用 `isStoredInMemoryOnly: true` 的容器，测试之间互不影响，也不会碰用户数据。
@MainActor
final class CycleServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: CycleService!
    private var profile: UserProfile!

    /// 与 `WomenMoonApp.schema` 保持一致，覆盖全部 10 个模型
    private static let schema = Schema([
        UserProfile.self,
        CycleRecord.self,
        CycleEvent.self,
        HealthMetric.self,
        FoodItem.self,
        MealRecord.self,
        EmotionRecord.self,
        ExercisePlan.self,
        MedicalRecord.self,
        SupplementRecord.self,
    ])

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: Self.schema,
            configurations: [ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true)]
        )
        context = ModelContext(container)
        service = CycleService()
        profile = UserProfile(cycleLength: 28, periodLength: 5, lastCycleStartDate: makeDate(2026, 1, 1))
        context.insert(profile)
        try context.save()
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        service = nil
        profile = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func allRecords() throws -> [CycleRecord] {
        try context.fetch(FetchDescriptor<CycleRecord>())
    }

    private func realRecords() throws -> [CycleRecord] {
        try allRecords().filter { !$0.isPredicted }
    }

    private func predictionRecords() throws -> [CycleRecord] {
        try allRecords().filter(\.isPredicted)
    }

    private func allEvents() throws -> [CycleEvent] {
        try context.fetch(FetchDescriptor<CycleEvent>())
    }

    // MARK: - recordPeriod：新增与更新

    func testRecordPeriodInsertsNewRealRecord() throws {
        service.recordPeriod(
            startDate: makeDate(2026, 1, 1), endDate: makeDate(2026, 1, 5),
            symptoms: [.cramp], flowIntensity: 3, notes: "第一天",
            modelContext: context, profile: profile
        )

        let real = try realRecords()
        XCTAssertEqual(real.count, 1)
        XCTAssertEqual(real[0].flowIntensity, 3)
        XCTAssertEqual(real[0].symptoms, [.cramp])
        XCTAssertEqual(real[0].notes, "第一天")
        XCTAssertFalse(real[0].isPredicted)
    }

    /// 同一天重复记录必须走更新分支，否则日历上会出现两条同日记录
    func testRecordPeriodSameDayUpdatesInsteadOfDuplicating() throws {
        service.recordPeriod(
            startDate: makeDate(2026, 1, 1), endDate: nil,
            symptoms: [.cramp], flowIntensity: 2, notes: "",
            modelContext: context, profile: profile
        )
        service.recordPeriod(
            startDate: makeDate(2026, 1, 1), endDate: makeDate(2026, 1, 4),
            symptoms: [.fatigue], flowIntensity: 4, notes: "改为量多",
            modelContext: context, profile: profile
        )

        let real = try realRecords()
        XCTAssertEqual(real.count, 1, "同日再次记录应更新原记录而非新增")
        XCTAssertEqual(real[0].flowIntensity, 4)
        XCTAssertEqual(real[0].symptoms, [.fatigue])
        XCTAssertNotNil(real[0].endDate)
    }

    /// 不同日期必须各自建记录
    func testRecordPeriodDifferentDaysCreatesSeparateRecords() throws {
        service.recordPeriod(
            startDate: makeDate(2026, 1, 1), endDate: nil,
            symptoms: [], flowIntensity: 3, notes: "",
            modelContext: context, profile: profile
        )
        service.recordPeriod(
            startDate: makeDate(2026, 1, 29), endDate: nil,
            symptoms: [], flowIntensity: 3, notes: "",
            modelContext: context, profile: profile
        )

        XCTAssertEqual(try realRecords().count, 2)
    }

    // MARK: - recordPeriod：副作用

    func testRecordPeriodUpdatesProfileLastCycleStartDate() throws {
        service.recordPeriod(
            startDate: makeDate(2026, 2, 10), endDate: nil,
            symptoms: [], flowIntensity: 3, notes: "",
            modelContext: context, profile: profile
        )

        let updated = Calendar.current.startOfDay(for: profile.lastCycleStartDate!)
        XCTAssertEqual(updated, Calendar.current.startOfDay(for: makeDate(2026, 2, 10)))
    }

    /// ⚠️ 特征化测试：记录当前行为，暴露一个值得商榷的口径。
    ///
    /// `updateLastCycleStartDate` 只在**真实记录**里取最大值，完全无视档案原有的
    /// `lastCycleStartDate`。因此当用户补录一条比现有起始日更早的历史经期时，
    /// 档案里的起始日会被**倒退**，首页的「周期第 N 天」和阶段判定随之整体后移。
    ///
    /// 本用例固化该行为。若决定改为"取记录与档案的较大者"，这里会失败并提示同步更新。
    func testRecordingAnEarlierCycleMovesProfileStartDateBackward() throws {
        let originalStart = profile.lastCycleStartDate!

        service.recordPeriod(
            startDate: makeDate(2025, 12, 1), endDate: nil,
            symptoms: [], flowIntensity: 3, notes: "",
            modelContext: context, profile: profile
        )

        let updatedStart = profile.lastCycleStartDate!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: updatedStart),
            Calendar.current.startOfDay(for: makeDate(2025, 12, 1)),
            "补录更早的经期后，档案起始日被倒退到该记录"
        )
        XCTAssertLessThan(updatedStart, originalStart, "档案起始日确实向后移动了（已知口径，待确认是否有意为之）")
    }

    func testRecordPeriodRefreshesPredictions() throws {
        service.recordPeriod(
            startDate: makeDate(2026, 1, 1), endDate: nil,
            symptoms: [], flowIntensity: 3, notes: "",
            modelContext: context, profile: profile
        )

        let predictions = try predictionRecords()
        XCTAssertEqual(predictions.count, 6, "refreshPredictions 默认生成 6 个月预测")
        XCTAssertTrue(predictions.allSatisfy { $0.startDate > makeDate(2026, 1, 1) })
    }

    // MARK: - refreshPredictions

    func testRefreshPredictionsRebuildsWithoutDuplicating() throws {
        service.refreshPredictions(modelContext: context, profile: profile)
        let first = try predictionRecords().count

        service.refreshPredictions(modelContext: context, profile: profile)
        XCTAssertEqual(try predictionRecords().count, first, "重复刷新不应累积预测记录")
    }

    func testRefreshPredictionsFallsBackToProfileWhenNoRealRecords() throws {
        service.refreshPredictions(modelContext: context, profile: profile)
        XCTAssertEqual(try predictionRecords().count, 6)
        XCTAssertTrue(try realRecords().isEmpty, "刷新预测不应产生真实记录")
    }

    func testRefreshPredictionsInsertsNothingWithoutProfileStartDate() throws {
        profile.lastCycleStartDate = nil
        try context.save()

        service.refreshPredictions(modelContext: context, profile: profile)
        XCTAssertTrue(try predictionRecords().isEmpty, "无起始日时不应生成预测")
    }

    /// 有真实记录时，预测起点必须是最后一条真实记录，而不是档案里的旧值
    func testRefreshPredictionsUsesLatestRealRecordAsAnchor() throws {
        let anchor = CycleRecord(startDate: makeDate(2026, 3, 5), isPredicted: false)
        context.insert(anchor)
        try context.save()

        service.refreshPredictions(modelContext: context, profile: profile)

        let earliest = try predictionRecords().map(\.startDate).min()!
        XCTAssertGreaterThan(earliest, makeDate(2026, 3, 5), "预测应排在真实记录之后")
    }

    func testRefreshPredictionsOnlyRemovesPredictions() throws {
        let real = CycleRecord(startDate: makeDate(2026, 1, 1), isPredicted: false)
        context.insert(real)
        context.insert(CycleRecord(startDate: makeDate(2026, 2, 1), isPredicted: true))
        try context.save()

        service.refreshPredictions(modelContext: context, profile: profile)

        XCTAssertEqual(try realRecords().count, 1, "真实记录不应被预测刷新删除")
    }

    // MARK: - averageCycleLength

    func testAverageCycleLengthRequiresTwoRecords() throws {
        let single = [CycleRecord(startDate: makeDate(2026, 1, 1))]
        XCTAssertNil(service.averageCycleLength(from: single))
        XCTAssertNil(service.averageCycleLength(from: []))
    }

    func testAverageCycleLengthAveragesGaps() throws {
        let records = [
            CycleRecord(startDate: makeDate(2026, 1, 1)),
            CycleRecord(startDate: makeDate(2026, 1, 29)),   // 间隔 28
            CycleRecord(startDate: makeDate(2026, 2, 28)),   // 间隔 30
        ]
        // (28 + 30) / 2 = 29
        XCTAssertEqual(service.averageCycleLength(from: records), 29)
    }

    func testAverageCycleLengthIgnoresPredictedRecords() throws {
        let records = [
            CycleRecord(startDate: makeDate(2026, 1, 1), isPredicted: false),
            CycleRecord(startDate: makeDate(2026, 1, 15), isPredicted: true),
            CycleRecord(startDate: makeDate(2026, 1, 29), isPredicted: false),
        ]
        XCTAssertEqual(service.averageCycleLength(from: records), 28, "预测记录不应参与平均周期计算")
    }

    func testAverageCycleLengthIgnoresNonPositiveGaps() throws {
        // 两条同日记录 → 间隔为 0，应被过滤；仅剩的一条有效间隔决定结果
        let records = [
            CycleRecord(startDate: makeDate(2026, 1, 1)),
            CycleRecord(startDate: makeDate(2026, 1, 1)),
            CycleRecord(startDate: makeDate(2026, 1, 31)),
        ]
        XCTAssertEqual(service.averageCycleLength(from: records), 30)
    }

    // MARK: - averagePeriodLength

    /// `duration + 1` 的口径：1 月 1 日到 1 月 5 日共 5 天（含首尾）
    func testAveragePeriodLengthCountsBothEndpoints() throws {
        let records = [
            CycleRecord(startDate: makeDate(2026, 1, 1), endDate: makeDate(2026, 1, 5)),
        ]
        XCTAssertEqual(service.averagePeriodLength(from: records), 5)
    }

    func testAveragePeriodLengthIgnoresRecordsWithoutEndDate() throws {
        let records = [
            CycleRecord(startDate: makeDate(2026, 1, 1), endDate: nil),
            CycleRecord(startDate: makeDate(2026, 1, 29), endDate: makeDate(2026, 2, 2)),
        ]
        XCTAssertEqual(service.averagePeriodLength(from: records), 5)
    }

    func testAveragePeriodLengthReturnsNilWhenNoEndDates() throws {
        XCTAssertNil(service.averagePeriodLength(from: [
            CycleRecord(startDate: makeDate(2026, 1, 1), endDate: nil),
        ]))
    }

    /// ⚠️ 特征化测试：记录当前缺陷。
    ///
    /// `RecordCycleView` 的结束日期选择器**没有 `in:` 范围限制**，可以选出早于开始日的日期。
    /// 此时 `CycleRecord.duration` 为负，`duration + 1` 仍为负，并被原样计入平均值 ——
    /// 「平均经期」会显示成负数。
    ///
    /// 本用例固化该行为，一旦上游补上校验或钳位，这里会失败并提示同步更新。
    func testAveragePeriodLengthIsCorruptedByReversedDateRange() throws {
        let records = [
            CycleRecord(startDate: makeDate(2026, 1, 10), endDate: makeDate(2026, 1, 7)), // -3 天
        ]
        let average = service.averagePeriodLength(from: records)
        XCTAssertNotNil(average)
        XCTAssertLessThan(average!, 0, "结束日早于开始日时，平均经期为负数（已知缺陷，待修复）")
    }

    // MARK: - saveDayDetail

    func testSaveDayDetailWithEmptyInputsDeletesExistingRecord() throws {
        service.recordPeriod(
            startDate: makeDate(2026, 1, 1), endDate: makeDate(2026, 1, 5),
            symptoms: [.cramp], flowIntensity: 3, notes: "有内容",
            modelContext: context, profile: profile
        )
        XCTAssertEqual(try realRecords().count, 1)

        service.saveDayDetail(
            date: makeDate(2026, 1, 1), symptoms: [], flowIntensity: 0, notes: "",
            modelContext: context, profile: profile
        )

        XCTAssertTrue(try realRecords().isEmpty, "三项全空时应删除该日记录")
    }

    /// `saveDayDetail` 把单日记录的 `endDate` 设为次日，即单日记录占两天
    func testSaveDayDetailSetsEndDateToTheNextDay() throws {
        service.saveDayDetail(
            date: makeDate(2026, 1, 1), symptoms: [], flowIntensity: 2, notes: "",
            modelContext: context, profile: profile
        )

        let real = try realRecords()
        XCTAssertEqual(real.count, 1)
        let end = Calendar.current.startOfDay(for: real[0].endDate!)
        XCTAssertEqual(end, Calendar.current.startOfDay(for: makeDate(2026, 1, 2)))
    }

    /// 仅有症状（无流量）时不应设置 endDate
    func testSaveDayDetailWithSymptomsOnlyLeavesEndDateNil() throws {
        service.saveDayDetail(
            date: makeDate(2026, 1, 3), symptoms: [.headache], flowIntensity: 0, notes: "",
            modelContext: context, profile: profile
        )

        let real = try realRecords()
        XCTAssertEqual(real.count, 1)
        XCTAssertNil(real[0].endDate, "未记录流量时不应产生经期区间")
    }

    func testSaveDayDetailWithNotesOnlyCreatesRecord() throws {
        service.saveDayDetail(
            date: makeDate(2026, 1, 3), symptoms: [], flowIntensity: 0, notes: "只有备注",
            modelContext: context, profile: profile
        )

        XCTAssertEqual(try realRecords().count, 1)
        XCTAssertEqual(try realRecords()[0].notes, "只有备注")
    }

    func testSaveDayDetailDoesNotDeleteRecordsOnOtherDays() throws {
        service.recordPeriod(
            startDate: makeDate(2026, 1, 5), endDate: nil,
            symptoms: [.cramp], flowIntensity: 3, notes: "",
            modelContext: context, profile: profile
        )
        service.saveDayDetail(
            date: makeDate(2026, 1, 1), symptoms: [], flowIntensity: 0, notes: "",
            modelContext: context, profile: profile
        )

        XCTAssertEqual(try realRecords().count, 1, "清空 1 月 1 日不应影响 1 月 5 日的记录")
    }

    // MARK: - saveCycleEvent

    func testSaveCycleEventCreatesThenOverwrites() throws {
        let date = makeDate(2026, 1, 3)

        service.saveCycleEvent(date: date, type: .bbt, value: "36.5", notes: "", modelContext: context)
        XCTAssertEqual(try allEvents().count, 1)

        service.saveCycleEvent(date: date, type: .bbt, value: "36.8", notes: "排卵后", modelContext: context)

        let events = try allEvents()
        XCTAssertEqual(events.count, 1, "同日同类型应覆盖而非新增")
        XCTAssertEqual(events[0].value, "36.8")
        XCTAssertEqual(events[0].notes, "排卵后")
    }

    func testSaveCycleEventKeepsDifferentTypesOnSameDay() throws {
        let date = makeDate(2026, 1, 3)
        service.saveCycleEvent(date: date, type: .bbt, value: "36.5", notes: "", modelContext: context)
        service.saveCycleEvent(date: date, type: .cervicalMucus, value: "蛋清状", notes: "", modelContext: context)
        service.saveCycleEvent(date: date, type: .ovulationTest, value: "阳性", notes: "", modelContext: context)

        XCTAssertEqual(try allEvents().count, 3, "同日不同类型的排卵迹象应各自保留")
    }

    // MARK: - 查询辅助

    func testLatestRealRecordIgnoresPredictions() throws {
        let records = [
            CycleRecord(startDate: makeDate(2026, 1, 1), isPredicted: false),
            CycleRecord(startDate: makeDate(2026, 5, 1), isPredicted: true),
        ]
        let latest = service.latestRealRecord(in: records)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: latest!.startDate),
            Calendar.current.startOfDay(for: makeDate(2026, 1, 1))
        )
    }

    func testEffectiveCycleStartDatePrefersRealRecord() throws {
        let records = [CycleRecord(startDate: makeDate(2026, 3, 1), isPredicted: false)]
        let effective = service.effectiveCycleStartDate(records: records, profile: profile)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: effective!),
            Calendar.current.startOfDay(for: makeDate(2026, 3, 1)),
            "有真实记录时应优先于档案中的起始日"
        )
    }

    func testEffectiveCycleStartDateFallsBackToProfile() throws {
        let effective = service.effectiveCycleStartDate(records: [], profile: profile)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: effective!),
            Calendar.current.startOfDay(for: makeDate(2026, 1, 1))
        )
    }

    func testEventsForDateFiltersByDay() throws {
        let target = makeDate(2026, 1, 3)
        context.insert(CycleEvent(date: target, type: .bbt, value: "36.5", notes: ""))
        context.insert(CycleEvent(date: makeDate(2026, 1, 4), type: .bbt, value: "36.6", notes: ""))
        try context.save()

        let matched = service.eventsForDate(target, in: try allEvents())
        XCTAssertEqual(matched.count, 1)
        XCTAssertEqual(matched[0].value, "36.5")
    }

    // MARK: - 数据完整性

    func testPredictionWindowCoversSixMonths() throws {
        service.recordPeriod(
            startDate: makeDate(2026, 1, 1), endDate: nil,
            symptoms: [], flowIntensity: 3, notes: "",
            modelContext: context, profile: profile
        )

        let predictions = try predictionRecords().sorted { $0.startDate < $1.startDate }
        let last = predictions.last!.startDate
        let monthsAhead = Calendar.current.dateComponents(
            [.month], from: makeDate(2026, 1, 1), to: last
        ).month ?? 0
        XCTAssertGreaterThanOrEqual(monthsAhead, 5, "6 条预测应覆盖约 6 个月")
    }

    func testPredictionsNeverStartOnTheSameDayAsTheRealRecord() throws {
        let start = makeDate(2026, 1, 1)
        service.recordPeriod(
            startDate: start, endDate: nil,
            symptoms: [], flowIntensity: 3, notes: "",
            modelContext: context, profile: profile
        )

        for prediction in try predictionRecords() {
            XCTAssertFalse(
                Calendar.current.isDate(prediction.startDate, inSameDayAs: start),
                "预测不应与真实记录同日，否则日历会出现重叠标记"
            )
        }
    }
}
