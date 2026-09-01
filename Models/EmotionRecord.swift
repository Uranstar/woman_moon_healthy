import Foundation
import SwiftData

@Model
final class EmotionRecord {
    var id: UUID
    var date: Date
    var mood: Mood
    var emotions: [EmotionTag]
    var trigger: String?
    var notes: String
    var cyclePhase: CyclePhase?
    var dayOfCycle: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mood: Mood = .neutral,
        emotions: [EmotionTag] = [],
        trigger: String? = nil,
        notes: String = "",
        cyclePhase: CyclePhase? = nil,
        dayOfCycle: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.mood = mood
        self.emotions = emotions
        self.trigger = trigger
        self.notes = notes
        self.cyclePhase = cyclePhase
        self.dayOfCycle = dayOfCycle
        self.createdAt = Date()
    }
}
