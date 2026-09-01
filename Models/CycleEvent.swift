import Foundation
import SwiftData

@Model
final class CycleEvent {
    var id: UUID
    var date: Date
    var typeRawValue: String   // SwiftData #Predicate 不支持 enum，用 rawValue 存储
    var value: String          // mucus type / test result / temperature / marker label
    var notes: String
    var createdAt: Date

    var type: CycleEventType {
        get { CycleEventType(rawValue: typeRawValue) ?? .otherNote }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        type: CycleEventType,
        value: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.typeRawValue = type.rawValue
        self.value = value
        self.notes = notes
        self.createdAt = Date()
    }
}
