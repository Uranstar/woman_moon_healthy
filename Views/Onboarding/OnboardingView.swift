import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0

    // Page 1
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var height: Double = 160
    @State private var weight: Double = 50

    // Page 2
    @State private var selectedGoals: Set<Goal> = []

    // Page 3 - HealthKit
    @State private var isAuthorizing = false
    @State private var healthKitGranted = false

    // Page 4 - Cycle
    @State private var cycleLength: Double = 28
    @State private var periodLength: Double = 5
    @State private var isCycleRegular = true
    @State private var lastPeriodDate: Date?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $currentPage) {
                BasicInfoPage(name: $name, birthDate: $birthDate, height: $height, weight: $weight, currentPage: $currentPage)
                    .tag(0)
                GoalSetupPage(selectedGoals: $selectedGoals, currentPage: $currentPage)
                    .tag(1)
                HealthKitAuthPage(isAuthorizing: $isAuthorizing, healthKitGranted: $healthKitGranted, currentPage: $currentPage)
                    .tag(2)
                CycleSetupPage(cycleLength: $cycleLength, periodLength: $periodLength, isCycleRegular: $isCycleRegular,
                               lastPeriodDate: $lastPeriodDate, healthKitGranted: healthKitGranted, currentPage: $currentPage,
                               onComplete: { completeOnboarding() })
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // 跳过按钮
            if currentPage < 3 {
                Button("跳过") {
                    skipAndFinish()
                }
                .font(.subheadline)
                .foregroundColor(Color(hex: "#9C27B0"))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.top, 60)
            }
        }
        .background(
            LinearGradient(colors: [Color(hex: "#FCE4EC"), Color(hex: "#F3E5F5")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }

    // MARK: - 随机名字
    private func randomName() -> String {
        let adjectives = ["小月", "月光", "花语", "清风", "温暖", "元气", "晨曦", "悠然", "星语", "云朵"]
        let suffix = String(format: "%04d", Int.random(in: 0...9999))
        return adjectives.randomElement()! + suffix
    }

    // MARK: - 跳过
    private func skipAndFinish() {
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? randomName() : name
        saveProfile(isCycleRegular: false, name: finalName)
        appState.skipOnboarding()
    }

    // MARK: - 完成引导
    func completeOnboarding() {
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? randomName() : name
        saveProfile(isCycleRegular: isCycleRegular, name: finalName)
        appState.completeOnboarding()
    }

    private func saveProfile(isCycleRegular: Bool, name: String) {
        let profile = UserProfile(
            name: name,
            birthDate: birthDate,
            cycleLength: Int(cycleLength),
            periodLength: Int(periodLength),
            isCycleRegular: isCycleRegular,
            goals: Array(selectedGoals),
            weight: weight,
            height: height,
            lastCycleStartDate: lastPeriodDate ?? Calendar.current.date(byAdding: .day, value: -14, to: Date())
        )
        modelContext.insert(profile)
        try? modelContext.save()
        appState.userName = name
        appState.userGoals = Array(selectedGoals)
    }
}

// MARK: - Page 1: 基本信息
struct BasicInfoPage: View {
    @Binding var name: String
    @Binding var birthDate: Date
    @Binding var height: Double
    @Binding var weight: Double
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("基本信息")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#4A148C"))

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("你的名字（选填）")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("不填将随机生成", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("出生日期")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("身高")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(height)) cm")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#E91E63"))
                    }
                    Slider(value: $height, in: 130...200, step: 0.5)
                        .tint(Color(hex: "#E91E63"))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("体重")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", weight)) kg")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#E91E63"))
                    }
                    Slider(value: $weight, in: 30...150, step: 0.1)
                        .tint(Color(hex: "#E91E63"))
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: { withAnimation { currentPage = 1 } }) {
                Text("下一步")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#E91E63"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Page 2: 目标选择
struct GoalSetupPage: View {
    @Binding var selectedGoals: Set<Goal>
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("你的目标")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#4A148C"))

            Text("可多选，系统会综合你的目标制定计划")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                GoalOptionCard(goal: .loseWeight, isSelected: selectedGoals.contains(.loseWeight),
                    description: "不管肌肉还是脂肪，目标是减少体重") {
                    toggle(.loseWeight)
                }
                GoalOptionCard(goal: .loseFat, isSelected: selectedGoals.contains(.loseFat),
                    description: "在不减少体重的情况下降低体脂率") {
                    toggle(.loseFat)
                }
                GoalOptionCard(goal: .gainMuscle, isSelected: selectedGoals.contains(.gainMuscle),
                    description: "在不减少体重的情况下增加肌肉量") {
                    toggle(.gainMuscle)
                }
                GoalOptionCard(goal: .maintain, isSelected: selectedGoals.contains(.maintain),
                    description: "不运动或仅维持现状") {
                    toggle(.maintain)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            HStack {
                Button(action: { withAnimation { currentPage = 0 } }) {
                    Text("上一步").foregroundColor(Color(hex: "#9C27B0"))
                }
                Spacer()
                Button(action: { withAnimation { currentPage = 2 } }) {
                    Text("下一步")
                        .font(.headline).foregroundColor(.white)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(selectedGoals.isEmpty ? Color.gray : Color(hex: "#E91E63"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedGoals.isEmpty)
            }
            .padding(.horizontal, 32).padding(.bottom, 50)
        }
    }

    private func toggle(_ goal: Goal) {
        if selectedGoals.contains(goal) { selectedGoals.remove(goal) }
        else { selectedGoals.insert(goal) }
    }
}

struct GoalOptionCard: View {
    let goal: Goal
    let isSelected: Bool
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#E91E63")).font(.title3)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color(hex: "#FCE4EC") : Color(.systemGray6)))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: "#E91E63") : Color.clear, lineWidth: 2))
        }
    }
}

// MARK: - Page 3: HealthKit 授权
struct HealthKitAuthPage: View {
    @Binding var isAuthorizing: Bool
    @Binding var healthKitGranted: Bool
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [Color(hex: "#E91E63"), Color(hex: "#FF5722")],
                                                startPoint: .top, endPoint: .bottom))

            Text("连接 Apple Health")
                .font(.largeTitle).fontWeight(.bold)
                .foregroundColor(Color(hex: "#4A148C"))

            Text("月舒可以同步 Apple Health 中的\n经期、体重、步数等数据\n帮助你更全面地管理健康")
                .font(.body) // 更大的字号
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary).lineSpacing(8)

            VStack(alignment: .leading, spacing: 16) {
                PrivacyRow(text: "所有敏感健康数据默认存储在本地")
                PrivacyRow(text: "你随时可以在设置中管理权限")
                PrivacyRow(text: "数据不会在未经授权下上传云端")
            }
            .padding(.vertical, 24)

            Spacer()

            VStack(spacing: 12) {
                Button(action: requestAndNext) {
                    HStack {
                        if isAuthorizing { ProgressView().tint(.white) }
                        Text("授权并继续")
                    }
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [Color(hex: "#E91E63"), Color(hex: "#9C27B0")],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }.disabled(isAuthorizing)

                Button(action: skipToNext) {
                    Text("稍后设置").foregroundColor(Color(hex: "#9C27B0"))
                }
            }
            .padding(.horizontal, 32).padding(.bottom, 50)
        }
    }

    private func requestAndNext() {
        isAuthorizing = true
        Task {
            do { try await HealthKitService.shared.requestAuthorization(); healthKitGranted = true }
            catch { healthKitGranted = false }
            isAuthorizing = false
            withAnimation { currentPage = 3 }
        }
    }

    private func skipToNext() {
        healthKitGranted = false
        withAnimation { currentPage = 3 }
    }
}

struct PrivacyRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(Color(hex: "#4CAF50")).font(.body)
            Text(text).font(.body).foregroundColor(.secondary)
        }.padding(.horizontal, 32)
    }
}

// MARK: - Page 4: 周期设置
struct CycleSetupPage: View {
    @Binding var cycleLength: Double
    @Binding var periodLength: Double
    @Binding var isCycleRegular: Bool
    @Binding var lastPeriodDate: Date?
    let healthKitGranted: Bool
    @Binding var currentPage: Int
    let onComplete: () -> Void

    @State private var hkSynced = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text(healthKitGranted ? "周期数据已同步" : "月经周期设置")
                .font(.largeTitle).fontWeight(.bold)
                .foregroundColor(Color(hex: "#4A148C"))

            if healthKitGranted {
                Text("已从 Apple Health 读取你的经期数据")
                    .font(.subheadline).foregroundColor(Color(hex: "#4CAF50"))
            }

            VStack(spacing: 24) {
                Toggle(isOn: $isCycleRegular) {
                    Text("周期规律").font(.subheadline)
                }.tint(Color(hex: "#E91E63"))

                if isCycleRegular || !healthKitGranted {
                    VStack(spacing: 8) {
                        HStack {
                            Text("周期长度").font(.subheadline)
                            Spacer()
                            Text("\(Int(cycleLength)) 天").font(.title3).fontWeight(.bold)
                                .foregroundColor(Color(hex: "#E91E63"))
                        }
                        Slider(value: $cycleLength, in: 21...35, step: 1)
                            .tint(Color(hex: "#E91E63"))
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("经期长度").font(.subheadline)
                            Spacer()
                            Text("\(Int(periodLength)) 天").font(.title3).fontWeight(.bold)
                                .foregroundColor(Color(hex: "#E91E63"))
                        }
                        Slider(value: $periodLength, in: 2...10, step: 1)
                            .tint(Color(hex: "#E91E63"))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("上一次经期开始日").font(.subheadline)
                        DatePicker("", selection: Binding(
                            get: { lastPeriodDate ?? Date() },
                            set: { lastPeriodDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: { onComplete() }) {
                Text("开始使用月舒")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [Color(hex: "#E91E63"), Color(hex: "#9C27B0")],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32).padding(.bottom, 50)
        }
        .onAppear {
            if healthKitGranted && !hkSynced {
                Task { await syncFromHealthKit() }
                hkSynced = true
            }
        }
    }

    private func syncFromHealthKit() async {
        do {
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            let records = try await HealthKitService.shared.fetchMenstrualCycles(from: oneYearAgo, to: Date())
            if let lastRecord = records.last {
                lastPeriodDate = lastRecord.startDate
                // 计算平均周期长度
                if records.count >= 2 {
                    var totalDays = 0
                    for i in 1..<records.count {
                        let days = Calendar.current.dateComponents([.day], from: records[i-1].startDate, to: records[i].startDate).day ?? 28
                        totalDays += days
                    }
                    cycleLength = Double(totalDays / (records.count - 1))
                    if let endDate = records.last?.endDate {
                        let pDays = Calendar.current.dateComponents([.day], from: records.last!.startDate, to: endDate).day ?? 5
                        periodLength = Double(pDays + 1)
                    }
                }
            }
        } catch {
            // 无法同步时保持默认值
        }
    }

    private func complete() {
        // 由 OnboardingView 的 completeOnboarding 处理
    }
}