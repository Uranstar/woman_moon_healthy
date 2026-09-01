import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \EmotionRecord.date, order: .reverse) private var emotionRecords: [EmotionRecord]
    @Query(sort: \MealRecord.date, order: .reverse) private var mealRecords: [MealRecord]
    @Query(sort: \ExercisePlan.date, order: .reverse) private var exercisePlans: [ExercisePlan]
    @Query(sort: \HealthMetric.date, order: .reverse) private var healthMetrics: [HealthMetric]

    @State private var showingEditProfile = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 头像和名字卡片
                profileCard

                // 成就值
                achievementCard

                // 数据统计
                statsCard

                // 设置入口
                settingsSection
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingEditProfile) {
            if let profile = userProfiles.first {
                ProfileEditSheet(profile: profile)
            }
        }
    }

    // MARK: - 个人信息卡片
    private var profileCard: some View {
        let profile = userProfiles.first
        return VStack(spacing: 12) {
            HStack {
                // 头像
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "#E91E63"), Color(hex: "#9C27B0")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)

                    Text(String((profile?.name ?? "小月").prefix(1)))
                        .font(.title).fontWeight(.bold).foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.name ?? "小月用户")
                        .font(.title3).fontWeight(.bold)

                    if let regDate = appState.registrationDate {
                        Text("注册于 \(regDate.chineseFormatted)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()

                Button(action: { showingEditProfile = true }) {
                    Text("编辑")
                        .font(.caption)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().stroke(Color(hex: "#E91E63"), lineWidth: 1))
                        .foregroundColor(Color(hex: "#E91E63"))
                }
            }

            if let profile = profile {
                HStack(spacing: 20) {
                    ProfileStatItem(label: "身高", value: "\(Int(profile.height))cm")
                    ProfileStatItem(label: "体重", value: "\(String(format: "%.1f", profile.weight))kg")
                    ProfileStatItem(label: "年龄", value: "\(profile.age)岁")
                    ProfileStatItem(label: "目标", value: profile.goals.first?.rawValue ?? "保持")
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 成就值
    private var achievementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("能量成就", systemImage: "star.circle.fill")
                .font(.headline)

            HStack(spacing: 16) {
                AchievementItem(icon: "flame.fill", label: "连续记录", value: "\(consecutiveDays)天",
                                color: Color(hex: "#FF5722"))
                AchievementItem(icon: "checkmark.circle.fill", label: "运动打卡", value: "\(exercisePlans.filter(\.isCompleted).count)次",
                                color: Color(hex: "#4CAF50"))
                AchievementItem(icon: "heart.fill", label: "心情记录", value: "\(emotionRecords.count)次",
                                color: Color(hex: "#E91E63"))
                AchievementItem(icon: "fork.knife", label: "饮食记录", value: "\(mealRecords.count)次",
                                color: Color(hex: "#FF9800"))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 数据统计
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("数据统计", systemImage: "chart.pie.fill")
                .font(.headline)

            HStack(spacing: 12) {
                StatBox(label: "总记录", value: "\(healthMetrics.count)", unit: "条")
                StatBox(label: "本月运动", value: "\(monthlyExercise)", unit: "次")
                StatBox(label: "平均心情", value: avgMood, unit: "分")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 设置入口
    private var settingsSection: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: SettingsView()) {
                SettingsRow(icon: "gearshape.fill", title: "设置", color: Color(hex: "#607D8B"))
            }
            Divider().padding(.leading, 44)
            NavigationLink(destination: HealthMetricsView()) {
                SettingsRow(icon: "apple.logo", title: "健康数据", color: Color(hex: "#4CAF50"))
            }
            Divider().padding(.leading, 44)
            NavigationLink(destination: MedicalRecordsView()) {
                SettingsRow(icon: "cross.case.fill", title: "病例管理", color: Color(hex: "#2196F3"))
            }
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 计算
    private var consecutiveDays: Int {
        var days = 0
        let calendar = Calendar.current
        var date = Date()
        while true {
            let hasRecord = emotionRecords.contains { calendar.isDate($0.date, inSameDayAs: date) } ||
                            mealRecords.contains { calendar.isDate($0.date, inSameDayAs: date) }
            if hasRecord { days += 1; date = calendar.date(byAdding: .day, value: -1, to: date)! }
            else { break }
        }
        return days
    }

    private var monthlyExercise: Int {
        let thisMonth = Calendar.current.dateComponents([.year, .month], from: Date())
        return exercisePlans.filter {
            $0.isCompleted &&
            Calendar.current.date($0.date, matchesComponents: thisMonth)
        }.count
    }

    private var avgMood: String {
        let recent = emotionRecords.prefix(30)
        guard !recent.isEmpty else { return "--" }
        let avg = Double(recent.map(\.mood.rawValue).reduce(0, +)) / Double(recent.count)
        return String(format: "%.1f", avg)
    }
}

// MARK: - 小部件
struct ProfileStatItem: View {
    let label: String; let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.caption).fontWeight(.medium)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

struct AchievementItem: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(value).font(.caption).fontWeight(.bold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct StatBox: View {
    let label: String; let value: String; let unit: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).fontWeight(.bold)
            Text(unit).font(.caption2).foregroundColor(.secondary)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity).padding(8).background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }
}

struct SettingsRow: View {
    let icon: String; let title: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.subheadline).foregroundColor(color).frame(width: 20)
            Text(title).font(.subheadline).foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 10)
    }
}

// MARK: - 编辑资料 Sheet
struct ProfileEditSheet: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double
    @State private var height: Double

    init(profile: UserProfile) {
        self.profile = profile
        _weight = State(initialValue: profile.weight)
        _height = State(initialValue: profile.height)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("名字", text: $profile.name)
                    DatePicker("出生日期", selection: $profile.birthDate, displayedComponents: .date)
                    HStack { Text("身高: \(Int(height))cm"); Slider(value: $height, in: 130...200, step: 0.5) }
                    HStack { Text("体重: \(String(format: "%.1f", weight))kg"); Slider(value: $weight, in: 30...150, step: 0.1) }
                }
                Section("目标") {
                    ForEach(Goal.allCases, id: \.self) { goal in
                        Button(action: {
                            if profile.goals.contains(goal) { profile.goals.removeAll { $0 == goal } }
                            else { profile.goals.append(goal) }
                        }) {
                            HStack {
                                Text(goal.rawValue).foregroundColor(.primary)
                                Spacer()
                                if profile.goals.contains(goal) { Image(systemName: "checkmark").foregroundColor(Color(hex: "#E91E63")) }
                            }
                        }
                    }
                }
                Section("周期") {
                    HStack { Text("周期: \(profile.cycleLength)天"); Slider(value: Binding(get: {Double(profile.cycleLength)}, set: {profile.cycleLength = Int($0)}), in: 21...35, step: 1) }
                    HStack { Text("经期: \(profile.periodLength)天"); Slider(value: Binding(get: {Double(profile.periodLength)}, set: {profile.periodLength = Int($0)}), in: 2...10, step: 1) }
                    Toggle("周期规律", isOn: $profile.isCycleRegular)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        profile.weight = weight
                        profile.height = height
                        try? dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }
}
