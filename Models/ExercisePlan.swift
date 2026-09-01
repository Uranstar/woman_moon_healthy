import Foundation
import SwiftData

/// 单个运动项
struct Exercise: Codable, Hashable {
    var name: String
    var type: ExerciseType
    var sets: Int?
    var reps: Int?
    var durationMinutes: Int?  // 有氧运动
    var caloriesBurn: Double?
    var notes: String?
}

enum ExerciseType: String, Codable, CaseIterable {
    case yoga = "瑜伽"
    case pilates = "普拉提"
    case strength = "力量训练"
    case hiit = "HIIT"
    case cardio = "有氧"
    case stretching = "拉伸"
    case walking = "散步"
    case running = "跑步"
    case swimming = "游泳"
    case cycling = "骑行"
    case dance = "舞蹈"
    case meditation = "冥想"
    case rest = "休息"
}

@Model
final class ExercisePlan {
    var id: UUID
    var date: Date
    var cyclePhase: CyclePhase
    var dayOfCycle: Int
    var exercises: [Exercise]
    var intensity: Intensity
    var durationMinutes: Int
    var notes: String
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        cyclePhase: CyclePhase = .follicular,
        dayOfCycle: Int = 1,
        exercises: [Exercise] = [],
        intensity: Intensity = .medium,
        durationMinutes: Int = 30,
        notes: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.date = date
        self.cyclePhase = cyclePhase
        self.dayOfCycle = dayOfCycle
        self.exercises = exercises
        self.intensity = intensity
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }

    /// 根据周期阶段获取推荐运动
    static func recommended(for phase: CyclePhase) -> [Exercise] {
        switch phase {
        case .menstrual:
            return [
                Exercise(name: "温和瑜伽", type: .yoga, durationMinutes: 20, notes: "以放松为主"),
                Exercise(name: "拉伸运动", type: .stretching, durationMinutes: 15, notes: "缓解经期不适"),
                Exercise(name: "散步", type: .walking, durationMinutes: 30, notes: "轻度活动促进血液循环"),
            ]
        case .follicular:
            return [
                Exercise(name: "力量训练", type: .strength, sets: 3, reps: 12, notes: "利用雌激素高峰期增肌"),
                Exercise(name: "HIIT", type: .hiit, durationMinutes: 20, notes: "高强度间歇，燃脂效率最高"),
                Exercise(name: "跑步", type: .running, durationMinutes: 30, notes: "提升心肺功能"),
            ]
        case .ovulatory:
            return [
                Exercise(name: "高强度力量训练", type: .strength, sets: 4, reps: 8, notes: "冲击个人纪录的最佳时机"),
                Exercise(name: "HIIT", type: .hiit, durationMinutes: 25, notes: "代谢率最高时期"),
                Exercise(name: "动感单车", type: .cycling, durationMinutes: 40, notes: "高效燃脂"),
            ]
        case .luteal:
            return [
                Exercise(name: "中等强度有氧", type: .cardio, durationMinutes: 35, notes: "稳定情绪，减少水肿"),
                Exercise(name: "普拉提", type: .pilates, durationMinutes: 30, notes: "核心训练"),
                Exercise(name: "游泳", type: .swimming, durationMinutes: 30, notes: "低冲击运动，缓解不适"),
            ]
        }
    }
}
