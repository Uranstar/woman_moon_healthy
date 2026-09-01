import SwiftUI
import SwiftData

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
    private let modelContainer: ModelContainer = {
        let diskConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [diskConfig]) {
            print("✅ SwiftData 磁盘存储就绪")
            return container
        }
        // 磁盘失败则用内存存储
        print("⚠️ 磁盘存储失败，使用内存存储")
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return (try? ModelContainer(for: schema, configurations: [memConfig]))
            ?? ModelContainer.fallback
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
        }
    }
}

extension ModelContainer {
    static let fallback: ModelContainer = {
        let schema = Schema([UserProfile.self])
        return try! ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        ])
    }()
}
