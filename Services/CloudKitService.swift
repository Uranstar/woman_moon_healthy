import Foundation
import CloudKit

/// CloudKit 云端同步服务 — 仅同步非敏感数据（食谱、节气数据、补剂信息等）
@MainActor
final class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?

    enum SyncStatus {
        case idle
        case syncing
        case completed
        case failed(Error)
    }

    private init() {
        container = CKContainer(identifier: "iCloud.com.womenmoon.app")
        privateDatabase = container.privateCloudDatabase
    }

    // MARK: - 检查 iCloud 可用性
    func checkAccountStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            syncStatus = .failed(error)
            return false
        }
    }

    // MARK: - 同步食品数据
    func syncFoodItems(_ items: [FoodItem]) async throws {
        syncStatus = .syncing
        defer { syncStatus = .completed }

        for item in items where item.isCustom {
            let record = CKRecord(recordType: "FoodItem")
            record["name"] = item.name
            record["category"] = item.category.rawValue
            record["caloriesPer100g"] = item.caloriesPer100g
            record["protein"] = item.protein
            record["fat"] = item.fat
            record["carbs"] = item.carbs

            do {
                try await privateDatabase.save(record)
            } catch {
                // 如果是冲突，尝试合并
                print("Sync conflict for \(item.name): \(error)")
            }
        }
        lastSyncDate = Date()
    }

    // MARK: - 同步补剂记录
    func syncSupplements(_ records: [SupplementRecord]) async throws {
        syncStatus = .syncing
        defer { syncStatus = .completed }

        for record in records {
            let ckRecord = CKRecord(recordType: "SupplementRecord")
            ckRecord["supplementName"] = record.supplementName
            ckRecord["dosage"] = record.dosage
            ckRecord["timeOfDay"] = record.timeOfDay.rawValue
            ckRecord["date"] = record.date

            do {
                try await privateDatabase.save(ckRecord)
            } catch {
                print("Sync conflict for supplement: \(error)")
            }
        }
        lastSyncDate = Date()
    }

    // MARK: - 获取云端数据
    func fetchFoodItems() async throws -> [CKRecord] {
        let query = CKQuery(recordType: "FoodItem", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let (results, _) = try await privateDatabase.records(matching: query)
        return results.compactMap { _, result in try? result.get() }
    }
}
