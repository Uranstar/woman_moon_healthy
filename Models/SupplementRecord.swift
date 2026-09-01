import Foundation
import SwiftData

@Model
final class SupplementRecord {
    var id: UUID
    var date: Date
    var supplementName: String
    var dosage: String           // 如 "500mg"
    var unit: String             // 片/粒/毫升
    var quantity: Double         // 数量
    var timeOfDay: TimeOfDay
    var isTaken: Bool
    var notes: String
    var cyclePhase: CyclePhase?  // 与周期关联
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        supplementName: String = "",
        dosage: String = "",
        unit: String = "片",
        quantity: Double = 1,
        timeOfDay: TimeOfDay = .morning,
        isTaken: Bool = false,
        notes: String = "",
        cyclePhase: CyclePhase? = nil
    ) {
        self.id = id
        self.date = date
        self.supplementName = supplementName
        self.dosage = dosage
        self.unit = unit
        self.quantity = quantity
        self.timeOfDay = timeOfDay
        self.isTaken = isTaken
        self.notes = notes
        self.cyclePhase = cyclePhase
        self.createdAt = Date()
    }
}
