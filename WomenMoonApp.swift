import SwiftUI
import SwiftData
import os

@main
struct WomenMoonApp: App {
    @StateObject private var appState = AppState()

    private static let schema = Schema([
        UserProfile.self,
        CycleRecord.self,
        CycleEvent.self,
        HealthMetric.self,
        FoodItem.self,
        MealRecord.self,
        EmotionRecord.self,
        ExercisePlan.self,
        MedicalRecord.self,
        SupplementRecord.self,
    ])

    /// 只创建一次，避免多次访问计算属性导致多个 ModelContainer 死锁
    private let storage = StorageBootstrap.make(schema: Self.schema)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(storage.container)
                .task {
                    // 磁盘存储不可用时把原因交给 UI，让用户知道此刻记的数据不会被保存
                    appState.storageWarning = storage.warning

                    // 首次启动时把内置食材库写入 SwiftData，否则「食材库」始终为空
                    FoodSeeder.seedIfNeeded(modelContext: storage.container.mainContext)
                }
        }
    }
}

/// SwiftData 容器的启动结果。
///
/// 旧实现用 `try?` 静默吞掉磁盘初始化失败，无声切换到内存存储：用户以为数据已保存，
/// 退出后才发现全部丢失；而兜底容器只注册了 `UserProfile` 一个模型，其余 `@Query`
/// 一执行就会崩溃。这里改为显式表达两种状态，降级时保留完整 schema 并带上失败原因。
enum StorageBootstrap {
    case persistent(ModelContainer)
    case volatile(ModelContainer, reason: String)

    var container: ModelContainer {
        switch self {
        case .persistent(let container), .volatile(let container, _):
            return container
        }
    }

    /// 仅降级时有值，用于在界面上提示用户
    var warning: String? {
        if case .volatile(_, let reason) = self { return reason }
        return nil
    }

    private static let logger = Logger(subsystem: "com.womenmoon.app", category: "persistence")

    static func make(schema: Schema) -> StorageBootstrap {
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema)]
            )
            logger.info("SwiftData 磁盘存储就绪")
            return .persistent(container)
        } catch {
            let nsError = error as NSError
            logger.error("SwiftData 磁盘存储初始化失败（\(nsError.domain, privacy: .public) code=\(nsError.code)）：\(nsError.localizedDescription, privacy: .public)")

            // 降级容器注册完整 schema，保证所有 @Query 依然可用
            guard let container = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            ) else {
                // 磁盘与内存双双失败意味着 schema 本身存在致命冲突，
                // 此时崩溃并留下原因，好过带着不可用容器继续运行
                fatalError("SwiftData 容器无法初始化（磁盘与内存均失败）：\(error)")
            }
            logger.error("已降级为内存存储，本次记录的数据将在退出后丢失")
            return .volatile(container, reason: error.localizedDescription)
        }
    }
}
