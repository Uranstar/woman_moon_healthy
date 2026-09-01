import Foundation
import SwiftData

/// 集中管理经期记录、预测和周期事件的逻辑
@MainActor
class CycleService {

    // MARK: - 记录经期

    /// 记录一次真实经期，更新 UserProfile.lastCycleStartDate，刷新预测
    func recordPeriod(
        startDate: Date,
        endDate: Date?,
        symptoms: [Symptom],
        flowIntensity: Int,
        notes: String,
        modelContext: ModelContext,
        profile: UserProfile
    ) {
        let allRecords = fetchAllRecords(modelContext: modelContext)
        let existing = allRecords.first(where: {
            !$0.isPredicted && $0.startDate.isSameDay(as: startDate)
        })

        if let record = existing {
            record.endDate = endDate
            record.symptoms = symptoms
            record.flowIntensity = flowIntensity
            record.notes = notes
        } else {
            let record = CycleRecord(
                startDate: startDate,
                endDate: endDate,
                phase: .menstrual,
                symptoms: symptoms,
                flowIntensity: flowIntensity,
                notes: notes,
                isPredicted: false
            )
            modelContext.insert(record)
        }

        try? modelContext.save()

        // 更新 UserProfile.lastCycleStartDate 为最新真实记录
        updateLastCycleStartDate(profile: profile, modelContext: modelContext)

        // 刷新预测
        refreshPredictions(modelContext: modelContext, profile: profile)
    }

    // MARK: - 保存当日详情

    /// 从 DayDetailView 保存某一天的经期数据
    func saveDayDetail(
        date: Date,
        symptoms: [Symptom],
        flowIntensity: Int,
        notes: String,
        modelContext: ModelContext,
        profile: UserProfile
    ) {
        if flowIntensity > 0 || !symptoms.isEmpty || !notes.isEmpty {
            recordPeriod(
                startDate: date,
                endDate: flowIntensity > 0 ? Calendar.current.date(byAdding: .day, value: 1, to: date) : nil,
                symptoms: symptoms,
                flowIntensity: flowIntensity,
                notes: notes,
                modelContext: modelContext,
                profile: profile
            )
        } else {
            // 如果所有字段都为空，删除该日的记录（如果有）
            let allRecords = fetchAllRecords(modelContext: modelContext)
            if let existing = allRecords.first(where: {
                !$0.isPredicted && $0.startDate.isSameDay(as: date)
            }) {
                modelContext.delete(existing)
                try? modelContext.save()
                updateLastCycleStartDate(profile: profile, modelContext: modelContext)
                refreshPredictions(modelContext: modelContext, profile: profile)
            }
        }
    }

    // MARK: - 预测管理

    /// 删除所有预测记录，基于最新真实数据重新生成
    func refreshPredictions(
        modelContext: ModelContext,
        profile: UserProfile,
        months: Int = 6
    ) {
        // 删除所有旧预测
        deleteAllPredictions(modelContext: modelContext)

        let allRecords = fetchAllRecords(modelContext: modelContext)
        let realRecords = allRecords.filter { !$0.isPredicted }

        // 确定预测起点：最新真实记录的 startDate
        guard let lastRealStartDate = realRecords.map(\.startDate).max() else {
            // 没有真实记录，用 UserProfile 的数据
            guard let profileStart = profile.lastCycleStartDate else { return }
            let predictions = CycleCalculator.generatePredictions(
                from: profileStart,
                cycleLength: profile.cycleLength,
                periodLength: profile.periodLength,
                months: months
            )
            for p in predictions { modelContext.insert(p) }
            try? modelContext.save()
            return
        }

        // 用真实记录计算平均周期长度
        let avgCycle = averageCycleLength(from: realRecords) ?? profile.cycleLength
        let avgPeriod = averagePeriodLength(from: realRecords) ?? profile.periodLength

        let predictions = CycleCalculator.generatePredictions(
            from: lastRealStartDate,
            cycleLength: avgCycle,
            periodLength: avgPeriod,
            months: months
        )
        for p in predictions { modelContext.insert(p) }
        try? modelContext.save()
    }

    // MARK: - 周期事件

    /// 保存或更新某一天的周期事件（排卵迹象等）
    func saveCycleEvent(
        date: Date,
        type: CycleEventType,
        value: String,
        notes: String,
        modelContext: ModelContext
    ) {
        let allEvents = fetchAllEvents(modelContext: modelContext)
        let existing = allEvents.first(where: {
            $0.date.isSameDay(as: date) && $0.type == type
        })

        if let event = existing {
            event.value = value
            event.notes = notes
        } else {
            let event = CycleEvent(date: date, type: type, value: value, notes: notes)
            modelContext.insert(event)
        }
        try? modelContext.save()
    }

    // MARK: - 查询辅助

    /// 最新真实记录
    func latestRealRecord(in records: [CycleRecord]) -> CycleRecord? {
        records.filter { !$0.isPredicted }.max(by: { $0.startDate < $1.startDate })
    }

    /// 平均周期长度（基于连续真实记录的间隔）
    func averageCycleLength(from records: [CycleRecord]) -> Int? {
        let real = records.filter { !$0.isPredicted }.sorted { $0.startDate < $1.startDate }
        guard real.count >= 2 else { return nil }
        var gaps: [Int] = []
        for i in 1..<real.count {
            let gap = Calendar.current.dateComponents([.day], from: real[i - 1].startDate, to: real[i].startDate).day ?? 0
            if gap > 0 { gaps.append(gap) }
        }
        guard !gaps.isEmpty else { return nil }
        return Int(round(Double(gaps.reduce(0, +)) / Double(gaps.count)))
    }

    /// 平均经期天数（基于有 endDate 的真实记录）
    func averagePeriodLength(from records: [CycleRecord]) -> Int? {
        let real = records.filter { !$0.isPredicted && $0.endDate != nil }
        guard !real.isEmpty else { return nil }
        let durations = real.compactMap { $0.duration }.map { $0 + 1 }
        guard !durations.isEmpty else { return nil }
        return Int(round(Double(durations.reduce(0, +)) / Double(durations.count)))
    }

    /// 有效周期起点：优先最新真实记录，否则 UserProfile.lastCycleStartDate
    func effectiveCycleStartDate(records: [CycleRecord], profile: UserProfile) -> Date? {
        latestRealRecord(in: records)?.startDate ?? profile.lastCycleStartDate
    }

    /// 获取指定日期的所有周期事件
    func eventsForDate(_ date: Date, in events: [CycleEvent]) -> [CycleEvent] {
        events.filter { $0.date.isSameDay(as: date) }
    }

    // MARK: - Private Helpers

    private func fetchAllRecords(modelContext: ModelContext) -> [CycleRecord] {
        var descriptor = FetchDescriptor<CycleRecord>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllEvents(modelContext: ModelContext) -> [CycleEvent] {
        var descriptor = FetchDescriptor<CycleEvent>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteAllPredictions(modelContext: ModelContext) {
        let allRecords = fetchAllRecords(modelContext: modelContext)
        for record in allRecords where record.isPredicted {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }

    private func updateLastCycleStartDate(profile: UserProfile, modelContext: ModelContext) {
        let allRecords = fetchAllRecords(modelContext: modelContext)
        let realRecords = allRecords.filter { !$0.isPredicted }
        if let latestStart = realRecords.map(\.startDate).max() {
            profile.lastCycleStartDate = latestStart
            try? modelContext.save()
        }
    }
}
