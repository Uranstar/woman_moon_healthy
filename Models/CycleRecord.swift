import Foundation
import SwiftData

@Model
final class CycleRecord {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var predictedEndDate: Date?
    var phase: CyclePhase
    var symptoms: [Symptom]
    var flowIntensity: Int       // 1-5
    var notes: String
    var isPredicted: Bool        // 是否为预测日
    var createdAt: Date

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        predictedEndDate: Date? = nil,
        phase: CyclePhase = .menstrual,
        symptoms: [Symptom] = [],
        flowIntensity: Int = 3,
        notes: String = "",
        isPredicted: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.predictedEndDate = predictedEndDate
        self.phase = phase
        self.symptoms = symptoms
        self.flowIntensity = flowIntensity
        self.notes = notes
        self.isPredicted = isPredicted
        self.createdAt = Date()
    }

    var duration: Int? {
        guard let end = endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: startDate, to: end).day
    }

    var phaseDescription: String {
        switch phase {
        case .menstrual:
            return "经期 - 子宫内膜脱落，身体能量较低，适合温和运动"
        case .follicular:
            return "卵泡期 - 雌激素上升，精力恢复，是运动最佳时期"
        case .ovulatory:
            return "排卵期 - 代谢率最高，适合高强度训练"
        case .luteal:
            return "黄体期 - 孕激素上升，可能情绪波动，适合中等强度运动"
        }
    }
}
