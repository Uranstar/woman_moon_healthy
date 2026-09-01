import SwiftUI
import SwiftData

/// 全局应用状态管理
@MainActor
class AppState: ObservableObject {
    @Published var isOnboarded: Bool = UserDefaults.standard.bool(forKey: "isOnboarded")
    @Published var currentCyclePhase: CyclePhase = .follicular
    @Published var lastCycleStartDate: Date?
    @Published var userName: String = ""
    @Published var userGoals: [Goal] = []
    @Published var stressLevel: String = "放松"
    @Published var stressDetail: String = ""
    @Published var stressValue: Double = 15
    @Published var registrationDate: Date?

    /// 非 nil 表示 SwiftData 磁盘存储不可用、已降级为内存存储。
    /// 此时用户记录的数据不会被保存，必须由界面明确告知。
    @Published var storageWarning: String?

    func completeOnboarding() {
        isOnboarded = true
        registrationDate = Date()
        UserDefaults.standard.set(true, forKey: "isOnboarded")
        if let regDate = registrationDate {
            UserDefaults.standard.set(regDate.timeIntervalSince1970, forKey: "registrationDate")
        }
    }

    func skipOnboarding() {
        isOnboarded = true
        UserDefaults.standard.set(true, forKey: "isOnboarded")
    }

    func updateCyclePhase(_ phase: CyclePhase) {
        currentCyclePhase = phase
    }

    func resetOnboarding() {
        isOnboarded = false
        registrationDate = nil
        UserDefaults.standard.set(false, forKey: "isOnboarded")
        UserDefaults.standard.removeObject(forKey: "registrationDate")
    }

    func refreshStressLevel() {
        Task {
            let result = await HealthKitService.shared.estimateStressLevel()
            stressLevel = result.level
            stressDetail = result.detail
            stressValue = result.value
        }
    }
}