import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var birthDate: Date
    var cycleLength: Int       // 默认28天
    var periodLength: Int      // 默认5天
    var lutealLength: Int      // 黄体期长度，默认14天
    var isCycleRegular: Bool   // 周期是否规律
    var goals: [Goal]
    var weight: Double         // kg，当前体重
    var targetWeight: Double?
    var height: Double         // cm
    var activityLevel: ActivityLevel
    var lastCycleStartDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        birthDate: Date = Date(),
        cycleLength: Int = 28,
        periodLength: Int = 5,
        lutealLength: Int = 14,
        isCycleRegular: Bool = true,
        goals: [Goal] = [],
        weight: Double = 50,
        targetWeight: Double? = nil,
        height: Double = 160,
        activityLevel: ActivityLevel = .moderatelyActive,
        lastCycleStartDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        self.lutealLength = lutealLength
        self.isCycleRegular = isCycleRegular
        self.goals = goals
        self.weight = weight
        self.targetWeight = targetWeight
        self.height = height
        self.activityLevel = activityLevel
        self.lastCycleStartDate = lastCycleStartDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var bmi: Double? {
        guard let latestWeight = targetWeight else { return nil }
        let heightM = height / 100
        return latestWeight / (heightM * heightM)
    }

    var currentCyclePhase: CyclePhase {
        guard let startDate = lastCycleStartDate else { return .follicular }
        return Date().cyclePhase(
            cycleStartDate: startDate,
            cycleLength: cycleLength,
            periodLength: periodLength
        )
    }
}
