import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \MealRecord.date, order: .reverse) private var mealRecords: [MealRecord]

    @State private var todaySteps: Double = 0
    @State private var todayActiveCals: Double = 0
    @State private var waterGlasses: Int = 0
    @State private var currentTermName: String = ""
    @State private var navigatingToStress = false
    @State private var navigatingToWellness = false
    @State private var navigatingToAI = false

    // 一杯水的默认容量
    @AppStorage("waterGlassSize") private var waterGlassSize: Double = 200

    var body: some View {
        let profile = userProfiles.first

        ScrollView {
            VStack(spacing: 14) {
                // 顶部留白
                Color.clear.frame(height: 8)

                // 问候语 + AI入口
                greetingHeader

                // 快速操作卡片（上移到顶）
                quickActions

                // 月亮周期卡片
                moonPhaseCard(profile)

                // 压力指数
                stressCard

                // 今日概览（含喝水计数）
                todayOverview(profile)

                // 节气养生
                seasonalCard
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadData()
            currentTermName = SeasonalWellnessService.currentSolarTerm()?.name ?? ""
        }
        .sheet(isPresented: $navigatingToAI) {
            NavigationStack { AIAssistantView() }
        }
    }

    // MARK: - 问候语
    private var greetingHeader: some View {
        let profile = userProfiles.first
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting = hour < 12 ? "早上好" : hour < 18 ? "中午好" : "晚上好"
        let daysSinceBirth = profile.flatMap { p in
            Calendar.current.dateComponents([.day], from: p.birthDate, to: Date()).day
        } ?? 0

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting)，\(profile?.name ?? "朋友")")
                    .font(.title2).fontWeight(.bold)
                Text("感恩成为女性的第 \(daysSinceBirth) 天 🌸")
                    .font(.caption).foregroundColor(Color(hex: "#E91E63"))
            }
            Spacer()
            // AI 助手入口
            Button(action: { navigatingToAI = true }) {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(LinearGradient(
                        colors: [Color(hex: "#E91E63"), Color(hex: "#9C27B0")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )))
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 快速操作卡片
    private var quickActions: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: NutritionView()) {
                ActionCard(icon: "pencil.and.list.clipboard", label: "记饮食", color: Color(hex: "#FF9800"))
            }
            NavigationLink(destination: EmotionTrackerView()) {
                ActionCard(icon: "heart.text.square", label: "记心情", color: Color(hex: "#E91E63"))
            }
            NavigationLink(destination: HealthMetricsView()) {
                ActionCard(icon: "scalemass", label: "记体重", color: Color(hex: "#2196F3"))
            }
            NavigationLink(destination: NutritionView()) {
                ActionCard(icon: "pill", label: "记补剂", color: Color(hex: "#9C27B0"))
            }
        }
    }

    // MARK: - 月亮周期卡片
    private func moonPhaseCard(_ profile: UserProfile?) -> some View {
        let day = profile?.lastCycleStartDate.map { CycleCalculator.dayOfCycle(from: $0) } ?? 1
        let startStr = profile?.lastCycleStartDate?.shortChineseFormatted ?? "--"
        let endStr: String = {
            guard let p = profile, let start = p.lastCycleStartDate,
                  let end = Calendar.current.date(byAdding: .day, value: p.cycleLength - 1, to: start)
            else { return "--" }
            return end.shortChineseFormatted
        }()

        return VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(phaseColor.opacity(0.15)).frame(width: 72, height: 72)
                    Image(systemName: appState.currentCyclePhase.icon)
                        .font(.system(size: 36)).foregroundColor(phaseColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.currentCyclePhase.description)
                        .font(.title2).fontWeight(.bold).foregroundColor(phaseColor)
                    HStack(spacing: 0) {
                        Text("月经第 \(day) 天")
                            .font(.headline).foregroundColor(.secondary)
                        Text("（\(startStr) - \(endStr)）")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if let startDate = profile?.lastCycleStartDate {
                        let nextDate = CycleCalculator.predictNextCycleStart(
                            from: startDate, cycleLength: profile?.cycleLength ?? 28)
                        Text("预计下次: \(nextDate.shortChineseFormatted)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            Text(phaseDescription).font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8).background(phaseColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 压力指数卡片
    private var stressCard: some View {
        NavigationLink(destination: StressDetailView()) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("压力指数").font(.headline)
                    Text(appState.stressDetail).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 6).frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: appState.stressValue / 100)
                        .stroke(stressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 52, height: 52).rotationEffect(.degrees(-90))
                    Text(appState.stressLevel).font(.caption).fontWeight(.bold).foregroundColor(stressColor)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        }
    }

    // MARK: - 今日概览（含喝水计数+HealthKit数据）
    private func todayOverview(_ profile: UserProfile?) -> some View {
        let todayMeals = mealRecords.filter { $0.date.isSameDay(as: Date()) }
        let dietCals = todayMeals.reduce(0) { $0 + $1.totalCalories }

        return VStack(alignment: .leading, spacing: 12) {
            Label("今日概览", systemImage: "chart.bar.fill").font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                // 步数 → 打开运动页
                NavigationLink(destination: ExerciseView()) {
                    MetricGridItem(icon: "shoeprints.fill", value: "\(Int(todaySteps))", unit: "步", color: Color(hex: "#2196F3"))
                }
                // 活动热量 → 打开运动页
                NavigationLink(destination: ExerciseView()) {
                    MetricGridItem(icon: "flame.fill", value: "\(Int(todayActiveCals))", unit: "kcal", color: Color(hex: "#FF5722"))
                }
                // 饮食热量 → 打开饮食页
                NavigationLink(destination: NutritionView()) {
                    MetricGridItem(icon: "fork.knife", value: "\(Int(dietCals))", unit: "kcal", color: Color(hex: "#FF9800"))
                }
                // 喝水 → 点击加一杯
                Button(action: { waterGlasses += 1 }) {
                    MetricGridItem(icon: "drop.fill", value: "\(waterGlasses)", unit: "杯", color: Color(hex: "#00BCD4"))
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 节气养生卡片
    private var seasonalCard: some View {
        // 方案：用 button + sheet 避免 NavigationLink 在 ScrollView 中的卡死问题
        Button(action: { navigatingToWellness = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("节气养生", systemImage: "leaf.fill")
                        .font(.headline).foregroundColor(.primary)
                    Spacer()
                    Text(currentTermName).font(.subheadline).foregroundColor(Color(hex: "#4CAF50"))
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
                if let term = SeasonalWellnessService.currentSolarTerm(),
                   let detail = SeasonalTerms.detail(for: term.name) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(detail.seasonalFoods.prefix(6), id: \.self) { food in
                                Text(food).font(.caption).padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(Color(hex: "#E8F5E9")))
                                    .foregroundColor(Color(hex: "#2E7D32"))
                            }
                        }
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $navigatingToWellness) {
            NavigationStack { SeasonalWellnessDietView() }
        }
    }

    // MARK: - Helpers
    private func loadData() {
        Task {
            let now = Date()
            let start = Calendar.current.startOfDay(for: now)
            todaySteps = (try? await HealthKitService.shared.fetchStepCount(from: start, to: now)) ?? 0
            todayActiveCals = (try? await HealthKitService.shared.fetchActiveEnergy(from: start, to: now)) ?? 0
            appState.refreshStressLevel()
        }
    }

    private var phaseColor: Color {
        switch appState.currentCyclePhase {
        case .menstrual: return Color(hex: "#E74C3C")
        case .follicular: return Color(hex: "#2ECC71")
        case .ovulatory: return Color(hex: "#F39C12")
        case .luteal: return Color(hex: "#9B59B6")
        }
    }

    private var phaseDescription: String {
        switch appState.currentCyclePhase {
        case .menstrual: return "身体能量较低，注意保暖，适合温和运动。补充铁质和维生素C。"
        case .follicular: return "雌激素上升期，精力旺盛，是运动减脂的最佳时机！💪"
        case .ovulatory: return "代谢率最高，可以挑战高强度训练。注意补充蛋白质。"
        case .luteal: return "可能有经前症状，适度运动有助缓解。补充镁和B6。"
        }
    }

    private var stressColor: Color {
        switch appState.stressValue {
        case 0..<25: return Color(hex: "#4CAF50")
        case 25..<50: return Color(hex: "#FFC107")
        case 50..<75: return Color(hex: "#FF9800")
        default: return Color(hex: "#F44336")
        }
    }
}

// MARK: - 快速操作卡片（和卡片一样的视觉）
struct ActionCard: View {
    let icon: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.subheadline).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white))
    }
}

// MARK: - 今日数据格子
struct MetricGridItem: View {
    let icon: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value).font(.subheadline).fontWeight(.bold)
                Text(unit).font(.caption2).foregroundColor(.secondary)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }
}

// MARK: - 压力详情页
struct StressDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hrv: Double = 0
    @State private var rhr: Double = 0
    @State private var wristTemp: Double?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 压力指数
                VStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Color(.systemGray5), lineWidth: 12).frame(width: 140, height: 140)
                        Circle()
                            .trim(from: 0, to: appState.stressValue / 100)
                            .stroke(stressGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 140, height: 140).rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            Text("\(Int(appState.stressValue))").font(.largeTitle).fontWeight(.bold)
                            Text(appState.stressLevel).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    Text("基于 HRV 和静息心率的综合评估").font(.caption).foregroundColor(.secondary)
                }.padding().frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white))

                // 详细数据
                VStack(spacing: 12) {
                    DetailRow(icon: "waveform.path.ecg", label: "心率变异性 (HRV)", value: "\(Int(hrv)) ms",
                              detail: hrv < 30 ? "偏低，可能压力较大" : hrv > 60 ? "良好" : "正常")
                    Divider()
                    DetailRow(icon: "heart.fill", label: "静息心率", value: "\(Int(rhr)) bpm",
                              detail: rhr > 80 ? "偏高" : rhr > 60 ? "正常" : "良好")
                    if let temp = wristTemp {
                        Divider()
                        DetailRow(icon: "thermometer", label: "手腕温度", value: String(format: "%.1f°C", temp),
                                  detail: "夜间基础体温")
                    }
                }.padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white))

                // 解读
                VStack(alignment: .leading, spacing: 8) {
                    Label("解读", systemImage: "info.circle").font(.headline)
                    Text(stressInterpretation).font(.subheadline).foregroundColor(.secondary).lineSpacing(4)
                }.padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white))
            }.padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("压力详情")
        .onAppear { loadHRVData() }
    }

    private var stressGradient: LinearGradient {
        switch appState.stressValue {
        case 0..<25: return LinearGradient(colors: [Color(hex: "#4CAF50"), Color(hex: "#8BC34A")], startPoint: .top, endPoint: .bottom)
        case 25..<50: return LinearGradient(colors: [Color(hex: "#FFC107"), Color(hex: "#FF9800")], startPoint: .top, endPoint: .bottom)
        default: return LinearGradient(colors: [Color(hex: "#FF5722"), Color(hex: "#F44336")], startPoint: .top, endPoint: .bottom)
        }
    }

    private var stressInterpretation: String {
        if appState.stressValue < 25 { return "你的身体处于放松状态，HRV较高表明自主神经系统平衡良好。继续保持规律作息和适度运动。" }
        else if appState.stressValue < 50 { return "轻度压力状态。建议增加休息时间，尝试深呼吸或冥想练习。\(appState.currentCyclePhase.description)期间身体对压力的反应可能更敏感。" }
        else if appState.stressValue < 75 { return "中等压力水平。HRV下降表明身体正在承受一定压力。建议减少高强度运动，保证充足睡眠。黄体期尤其需要注意减压。" }
        else { return "压力水平较高。建议优先休息，避免过度运动。可以尝试温和瑜伽和冥想。如果持续处于高压力状态，建议咨询医生。" }
    }

    private func loadHRVData() {
        Task {
            let now = Date(); let ago = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            hrv = (try? await HealthKitService.shared.fetchHRV(from: ago, to: now)) ?? 0
            rhr = (try? await HealthKitService.shared.fetchRestingHeartRate(from: ago, to: now)) ?? 0
            wristTemp = try? await HealthKitService.shared.fetchWristTemperature(from: ago, to: now)
        }
    }
}

struct DetailRow: View {
    let icon: String; let label: String; let value: String; let detail: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(Color(hex: "#E91E63")).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline)
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(value).font(.headline)
        }
    }
}

// MARK: - 节气+饮食分析合并页
struct SeasonalWellnessDietView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentTerm: SolarTerm?
    @State private var wellnessAdvice: WellnessAdvice?
    @State private var aiDietAdvice: String?
    @State private var loadingAI = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 节气信息
                if let advice = wellnessAdvice {
                    // 节气标题
                    VStack(spacing: 8) {
                        Text(advice.termName).font(.largeTitle).fontWeight(.bold).foregroundColor(Color(hex: "#2E7D32"))
                        Text(advice.termDescription).font(.subheadline).foregroundColor(.secondary)
                    }.padding().frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [Color(hex: "#E8F5E9"), Color(hex: "#F1F8E9")], startPoint: .topLeading, endPoint: .bottomTrailing)))

                    // 时令食材
                    VStack(alignment: .leading, spacing: 8) {
                        Label("时令食材", systemImage: "carrot.fill").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(advice.seasonalFoods, id: \.self) { food in
                                Text(food).font(.caption).padding(6).frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#E8F5E9")))
                                    .foregroundColor(Color(hex: "#2E7D32"))
                            }
                        }
                    }.padding().background(RoundedRectangle(cornerRadius: 16).fill(.white))

                    // AI 综合饮食建议
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI 饮食分析", systemImage: "brain.head.profile").font(.headline)
                        if loadingAI {
                            HStack { Spacer(); ProgressView("分析中..."); Spacer() }.padding()
                        } else if let advice = aiDietAdvice {
                            Text(advice).font(.subheadline).foregroundColor(.secondary).lineSpacing(4)
                        } else {
                            Button("生成饮食建议") { generateDietAdvice(advice) }
                                .font(.subheadline).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 10)
                                .background(Color(hex: "#4CAF50")).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding().background(RoundedRectangle(cornerRadius: 16).fill(.white))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("节气养生")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadData)
    }

    private func loadData() {
        guard let term = SeasonalWellnessService.currentSolarTerm(),
              let detail = SeasonalTerms.detail(for: term.name) else { return }
        currentTerm = term
        wellnessAdvice = SeasonalWellnessService.wellnessAdvice(for: detail)
    }

    private func generateDietAdvice(_ advice: WellnessAdvice) {
        loadingAI = true
        Task {
            do {
                let context = AIChatContext(cyclePhase: appState.currentCyclePhase, age: 25,
                                            goals: appState.userGoals.isEmpty ? [.maintain] : appState.userGoals, bmi: 22)
                let prompt = "我现在处于\(context.cyclePhase.rawValue)，当前节气是\(advice.termName)，推荐食材有\(advice.seasonalFoods.joined(separator: "、"))。请结合我的周期阶段和节气，给出今日饮食建议，包括推荐菜式和注意事项。"
                aiDietAdvice = try await AIService.shared.chat(userMessage: prompt, context: context)
            } catch { aiDietAdvice = "无法生成建议，请检查网络。" }
            loadingAI = false
        }
    }
}
