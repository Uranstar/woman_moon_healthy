import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query(filter: #Predicate<CycleRecord> { $0.isPredicted == true })
    private var predictionRecords: [CycleRecord]

    var body: some View {
        VStack(spacing: 0) {
            if let warning = appState.storageWarning {
                StorageWarningBanner(message: warning)
            }

            Group {
                if appState.isOnboarded, let profile = userProfiles.first {
                    MainTabView()
                        .onAppear {
                            syncAppState(profile: profile)
                            ensurePredictionsExist(profile: profile)
                        }
                        .onChange(of: profile.lastCycleStartDate) { _, _ in
                            syncAppState(profile: profile)
                        }
                } else {
                    OnboardingView()
                }
            }
        }
    }

    private func syncAppState(profile: UserProfile) {
        appState.userName = profile.name
        appState.userGoals = profile.goals
        appState.lastCycleStartDate = profile.lastCycleStartDate
        if let startDate = profile.lastCycleStartDate {
            appState.currentCyclePhase = Date().cyclePhase(
                cycleStartDate: startDate,
                cycleLength: profile.cycleLength,
                periodLength: profile.periodLength
            )
        }
    }

    /// 首次启动或没有预测记录时，生成预测
    private func ensurePredictionsExist(profile: UserProfile) {
        guard predictionRecords.isEmpty else { return }
        let service = CycleService()
        service.refreshPredictions(modelContext: modelContext, profile: profile)
    }
}

// MARK: - 主 TabView
struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }

            NavigationStack {
                CycleTrackerView()
            }
            .tabItem {
                Label("周期", systemImage: "drop.fill")
            }

            NavigationStack {
                NutritionView()
            }
            .tabItem {
                Label("饮食", systemImage: "fork.knife")
            }

            NavigationStack {
                ExerciseView()
            }
            .tabItem {
                Label("运动", systemImage: "figure.run")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("我", systemImage: "person.circle.fill")
            }
        }
        .tint(Color(hex: "#E91E63"))
    }
}

// MARK: - 存储降级提示
/// 磁盘存储初始化失败时置顶显示。此时数据只存在于内存，退出即丢失，
/// 必须让用户看见，而不是像旧实现那样静默降级。
private struct StorageWarningBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text("数据暂时无法保存")
                    .font(.subheadline).fontWeight(.semibold)
                Text("本地存储初始化失败，本次记录的内容会在退出后丢失。原因：\(message)")
                    .font(.caption)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#D32F2F"))
    }
}

// MARK: - Color Hex 扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
