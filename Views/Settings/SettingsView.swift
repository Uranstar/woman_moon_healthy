import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]

    @State private var showingExportSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPrivacyPolicy = false

    var body: some View {
        Form {
            // MARK: - 个人信息
            Section("个人信息") {
                if let profile = userProfiles.first {
                    NavigationLink {
                        ProfileEditView(profile: profile)
                    } label: {
                        HStack {
                            Text("姓名")
                            Spacer()
                            Text(profile.name).foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("年龄")
                        Spacer()
                        Text("\(profile.age) 岁").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("身高")
                        Spacer()
                        Text("\(Int(profile.height)) cm").foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - 周期设置
            Section("周期设置") {
                if let profile = userProfiles.first {
                    HStack {
                        Text("周期长度")
                        Spacer()
                        Text("\(profile.cycleLength) 天").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("经期长度")
                        Spacer()
                        Text("\(profile.periodLength) 天").foregroundColor(.secondary)
                    }
                }

                NavigationLink("目标设置") {
                    GoalSettingsView()
                }

                NavigationLink("运动水平") {
                    ActivityLevelSettingsView()
                }
            }

            // MARK: - 通用
            Section("通用设置") {
                NavigationLink("喝水杯容量") {
                    WaterGlassSizeSettingView()
                }
            }

            // MARK: - Apple Health
            Section("Apple Health") {
                HStack {
                    Label("健康数据同步", systemImage: "apple.logo")
                    Spacer()
                    Text("已连接")
                        .foregroundColor(Color(hex: "#4CAF50"))
                }
            }

            // MARK: - AI 设置
            Section("AI 助手") {
                HStack {
                    Text("AI 模型")
                    Spacer()
                    Text("DeepSeek Chat")
                        .foregroundColor(.secondary)
                }

                NavigationLink("API Key 设置") {
                    APIKeySettingsView()
                }
            }

            // MARK: - 数据管理
            Section("数据管理") {
                Button(action: { showingExportSheet = true }) {
                    Label("导出数据", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    Label("清除所有数据", systemImage: "trash")
                }
            }

            // MARK: - 通知
            Section("通知") {
                NavigationLink("提醒设置") {
                    NotificationSettingsView()
                }
            }

            // MARK: - 关于
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondary)
                }

                Button(action: { showingPrivacyPolicy = true }) {
                    Label("隐私政策", systemImage: "hand.raised.fill")
                }

                Link(destination: URL(string: "https://github.com/women-moon")!) {
                    Label("开源仓库", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            // MARK: - 开发者
            Section("开发者工具") {
                Button(role: .destructive, action: {
                    appState.resetOnboarding()
                }) {
                    Label("重置引导流程", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("设置")
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                // 清除所有数据
                try? modelContext.delete(model: UserProfile.self)
                try? modelContext.delete(model: CycleRecord.self)
                try? modelContext.delete(model: HealthMetric.self)
                try? modelContext.delete(model: FoodItem.self)
                try? modelContext.delete(model: MealRecord.self)
                try? modelContext.delete(model: EmotionRecord.self)
                try? modelContext.delete(model: ExercisePlan.self)
                try? modelContext.delete(model: MedicalRecord.self)
                try? modelContext.delete(model: SupplementRecord.self)
                appState.resetOnboarding()
            }
        } message: {
            Text("此操作不可撤销，所有本地数据将被永久删除。")
        }
    }
}

// MARK: - 子页面
struct ProfileEditView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Form {
            Section {
                TextField("姓名", text: $profile.name)
                DatePicker("出生日期", selection: $profile.birthDate, displayedComponents: .date)
                HStack {
                    Text("身高")
                    Slider(value: $profile.height, in: 130...200, step: 0.5)
                    Text("\(Int(profile.height))cm")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("编辑资料")
    }
}

struct GoalSettingsView: View {
    @Query private var userProfiles: [UserProfile]

    var body: some View {
        Form {
            if let profile = userProfiles.first {
                Section("选择目标") {
                    ForEach(Goal.allCases, id: \.self) { goal in
                        Button(action: {
                            if profile.goals.contains(goal) {
                                profile.goals.removeAll { $0 == goal }
                            } else {
                                profile.goals.append(goal)
                            }
                        }) {
                            HStack {
                                Text(goal.rawValue)
                                Spacer()
                                if profile.goals.contains(goal) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "#E91E63"))
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle("目标设置")
    }
}

struct ActivityLevelSettingsView: View {
    @Query private var userProfiles: [UserProfile]

    var body: some View {
        Form {
            if let profile = userProfiles.first {
                Section("活动水平") {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Button(action: { profile.activityLevel = level }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(level.rawValue)
                                    Text(levelDescription(level))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if profile.activityLevel == level {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "#E91E63"))
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle("运动水平")
    }

    private func levelDescription(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "几乎不运动"
        case .lightlyActive: return "每周运动 1-2 次"
        case .moderatelyActive: return "每周运动 3-5 次"
        case .veryActive: return "每周运动 6-7 次"
        case .extraActive: return "每天高强度训练"
        }
    }
}

struct APIKeySettingsView: View {
    @State private var apiKey = ""

    var body: some View {
        Form {
            Section {
                SecureField("输入 DeepSeek API Key", text: $apiKey)
                Text("API Key 仅存储在本地 Keychain 中，不会上传到任何服务器。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Button("保存") {
                    // 保存到 Keychain
                    KeychainHelper.save(key: "deepseek_api_key", value: apiKey)
                }
                .disabled(apiKey.isEmpty)
            }

            Section {
                Link("获取 API Key", destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                    .font(.subheadline)
            }
        }
        .navigationTitle("API Key")
        .onAppear {
            apiKey = KeychainHelper.read(key: "deepseek_api_key") ?? ""
        }
    }
}

struct NotificationSettingsView: View {
    @State private var periodReminder = true
    @State private var supplementReminder = true
    @State private var exerciseReminder = false
    @State private var mealReminder = false
    @State private var emotionReminder = true

    var body: some View {
        Form {
            Section("提醒") {
                Toggle("经期预测提醒", isOn: $periodReminder)
                Toggle("补剂提醒", isOn: $supplementReminder)
                Toggle("运动提醒", isOn: $exerciseReminder)
                Toggle("饮食记录提醒", isOn: $mealReminder)
                Toggle("心情打卡提醒", isOn: $emotionReminder)
            }

            Section("提醒时间") {
                HStack {
                    Text("早晨提醒")
                    Spacer()
                    Text("8:00").foregroundColor(.secondary)
                }
                HStack {
                    Text("晚间提醒")
                    Spacer()
                    Text("21:00").foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("通知设置")
    }
}

// MARK: - Keychain 工具
struct KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - 喝水杯容量设置
struct WaterGlassSizeSettingView: View {
    @AppStorage("waterGlassSize") private var glassSize: Double = 200
    @State private var sliderValue: Double = 200

    let presets: [(String, Double)] = [
        ("小杯 150ml", 150), ("标准杯 200ml", 200),
        ("大杯 300ml", 300), ("马克杯 350ml", 350),
        ("水瓶 500ml", 500)
    ]

    var body: some View {
        Form {
            Section("选择一杯水的容量") {
                ForEach(presets, id: \.0) { label, value in
                    Button(action: { glassSize = value; sliderValue = value }) {
                        HStack {
                            Text(label)
                            Spacer()
                            if abs(glassSize - value) < 1 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(hex: "#E91E63"))
                            }
                        }
                    }.foregroundColor(.primary)
                }
            }

            Section("自定义容量") {
                HStack {
                    Text("\(Int(sliderValue)) ml")
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(Color(hex: "#2196F3"))
                    Spacer()
                }
                Slider(value: $sliderValue, in: 50...1000, step: 10) { _ in
                    glassSize = sliderValue
                }
                .tint(Color(hex: "#2196F3"))
            }
        }
        .navigationTitle("喝水杯容量")
        .onAppear { sliderValue = glassSize }
    }
}
