import Foundation
import SwiftData

@Model
final class HealthMetric {
    var id: UUID
    var date: Date
    var type: MetricType
    var value: Double
    var unit: String
    var source: DataSource
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: MetricType,
        value: Double,
        unit: String = "",
        source: DataSource = .manual
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.value = value
        self.unit = unit.isEmpty ? type.defaultUnit : unit
        self.source = source
        self.createdAt = Date()
    }
}

extension MetricType {
    var defaultUnit: String {
        switch self {
        case .weight: return "kg"
        case .bodyFat: return "%"
        case .waist, .hip, .thigh, .arm, .chest: return "cm"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .bodyFat: return "figure.arms.open"
        case .waist: return "figure.stand"
        case .hip: return "figure.stand.dress"
        case .thigh: return "figure.walk"
        case .arm: return "figure.arms.open"
        case .chest: return "heart.fill"
        }
    }
}
