import Foundation
import CloudKit
import os

/// CloudKit 云端同步服务 — 仅同步非敏感数据（自定义食材、补剂记录）。
///
/// ## 当前状态：尚未接入
///
/// 项目里没有任何地方调用本服务，且 `WomenMoon.entitlements` 只声明了 HealthKit，
/// **没有配置 iCloud/CloudKit 能力**。启用前需要：
/// 1. 在 Apple Developer 后台创建容器 `iCloud.com.womenmoon.app`
/// 2. 在 `WomenMoon.entitlements` 增加 `com.apple.developer.icloud-container-identifiers`
///    与 `com.apple.developer.icloud-services`（值为 `CloudKit`）
///
/// 在此之前调用 `CloudKitService.shared` 会失败，故容器改为延迟创建。
///
/// 注意：经期、症状、情绪、医疗记录等敏感数据**不应**上云，
/// 本服务刻意只覆盖自定义食材与补剂两项。
@MainActor
final class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    private let containerIdentifier = "iCloud.com.womenmoon.app"

    private static let logger = Logger(subsystem: "com.womenmoon.app", category: "cloudkit")

    /// 延迟创建。`CKContainer(identifier:)` 在缺少 iCloud entitlement 时会抛异常，
    /// 而此前它写在 `init` 里 —— 任何一次 `CloudKitService.shared` 访问都会崩溃。
    /// 改为首次真正使用云端能力时才构造。
    private lazy var container: CKContainer = CKContainer(identifier: containerIdentifier)
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?

    enum SyncStatus {
        case idle
        case syncing
        case completed
        case failed(Error)
    }

    private init() {}

    // MARK: - 检查 iCloud 可用性
    func checkAccountStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            logger.error("iCloud 账号状态检查失败：\(error.localizedDescription, privacy: .public)")
            syncStatus = .failed(error)
            return false
        }
    }

    // MARK: - 同步食品数据

    /// 基于本地 UUID 生成稳定的 recordID。
    ///
    /// 此前每条记录都用 `CKRecord(recordType:)` 新建，没有指定 recordID，
    /// 于是每同步一次就在云端新增一批重复记录。
    private func recordID(forFood item: FoodItem) -> CKRecord.ID {
        CKRecord.ID(recordName: "food-\(item.id.uuidString)")
    }

    private func recordID(forSupplement record: SupplementRecord) -> CKRecord.ID {
        CKRecord.ID(recordName: "supplement-\(record.id.uuidString)")
    }

    func syncFoodItems(_ items: [FoodItem]) async throws {
        syncStatus = .syncing
        defer { syncStatus = .completed }

        for item in items where item.isCustom {
            // 指定 recordID 即「存在则更新、不存在则创建」
            let record = CKRecord(recordType: "FoodItem", recordID: recordID(forFood: item))
            record["name"] = item.name
            record["category"] = item.category.seedKey
            record["caloriesPer100g"] = item.caloriesPer100g
            record["protein"] = item.protein
            record["fat"] = item.fat
            record["carbs"] = item.carbs

            do {
                try await privateDatabase.save(record)
            } catch {
                // 单条失败不应中断整批同步
                logger.error("食材「\(item.name, privacy: .public)」同步失败：\(error.localizedDescription, privacy: .public)")
            }
        }
        lastSyncDate = Date()
    }

    // MARK: - 同步补剂记录
    func syncSupplements(_ records: [SupplementRecord]) async throws {
        syncStatus = .syncing
        defer { syncStatus = .completed }

        for record in records {
            let ckRecord = CKRecord(recordType: "SupplementRecord", recordID: recordID(forSupplement: record))
            ckRecord["supplementName"] = record.supplementName
            ckRecord["dosage"] = record.dosage
            ckRecord["timeOfDay"] = record.timeOfDay.rawValue
            ckRecord["date"] = record.date

            do {
                try await privateDatabase.save(ckRecord)
            } catch {
                logger.error("补剂「\(record.supplementName, privacy: .public)」同步失败：\(error.localizedDescription, privacy: .public)")
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
