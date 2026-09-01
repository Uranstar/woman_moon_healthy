import Foundation
import SwiftData

@Model
final class MedicalRecord {
    var id: UUID
    var date: Date
    var title: String
    var category: MedicalCategory
    var hospital: String?
    var doctor: String?
    var diagnosis: String?
    var prescription: String?
    var images: [Data]?
    var aiAnalysis: String?       // AI 分析摘要
    var tags: [String]
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String = "",
        category: MedicalCategory = .general,
        hospital: String? = nil,
        doctor: String? = nil,
        diagnosis: String? = nil,
        prescription: String? = nil,
        images: [Data]? = nil,
        aiAnalysis: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.category = category
        self.hospital = hospital
        self.doctor = doctor
        self.diagnosis = diagnosis
        self.prescription = prescription
        self.images = images
        self.aiAnalysis = aiAnalysis
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
