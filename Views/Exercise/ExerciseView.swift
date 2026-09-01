import SwiftUI
import SwiftData

struct ExerciseView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExercisePlan.date, order: .reverse) private var exercisePlans: [ExercisePlan]

    @State private var showingPlanGenerator = false
    @State private var hkActiveCalories: Double = 0
    @State private var hkExerciseMinutes: Double = 0
    @State private var hkSteps: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 周期运动指南
                cycleExerciseGuide

                // Apple Health 运动数据
                healthKitExerciseData

                // 本周计划
                weeklyPlan

                // 运动打卡
                exerciseStreak

                // 各阶段推荐
                phaseRecommendations
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("运动规划")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingPlanGenerator = true }) {
                    Image(systemName: "wand.and.stars")
                }
            }
        }
        .sheet(isPresented: $showingPlanGenerator) {
            PlanGeneratorView { plans in
                for plan in plans {
                    modelContext.insert(plan)
                }
                try? modelContext.save()
            }
        }
        .onAppear(perform: loadHealthKitData)
    }

    // MARK: - 周期运动指南
    private var cycleExerciseGuide: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "figure.run.circle.fill").font(.title).foregroundColor(Color(hex: "#4CAF50"))
                VStack(alignment: .leading) {
                    Text("\(appState.currentCyclePhase.description)运动指南").font(.headline)
                    Text("运动耐受力：\(exerciseTolerance)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            Divider()
            ForEach(ExercisePlan.recommended(for: appState.currentCyclePhase), id: \.name) { ex in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name).font(.subheadline).fontWeight(.medium)
                        if let notes = ex.notes { Text(notes).font(.caption).foregroundColor(.secondary) }
                    }
                    Spacer()
                    if let dur = ex.durationMinutes { Text("\(dur)分钟").font(.caption).foregroundColor(Color(hex: "#4CAF50")) }
                }
                .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - HealthKit 运动数据
    private var healthKitExerciseData: some View {
        HStack(spacing: 12) {
            ExerciseDataItem(label: "今日步数", value: "\(Int(hkSteps))", unit: "步", icon: "shoeprints.fill", color: Color(hex: "#2196F3"))
            ExerciseDataItem(label: "运动分钟", value: "\(Int(hkExerciseMinutes))", unit: "分钟", icon: "timer", color: Color(hex: "#4CAF50"))
            ExerciseDataItem(label: "活动热量", value: "\(Int(hkActiveCalories))", unit: "kcal", icon: "flame.fill", color: Color(hex: "#FF5722"))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 本周计划
    private var weeklyPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("本周计划", systemImage: "calendar.badge.clock").font(.headline)
            let weekPlans = exercisePlans.filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
            }
            if weekPlans.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run.square.stack").font(.system(size: 36)).foregroundColor(.secondary)
                    Text("还没有本周运动计划").font(.subheadline).foregroundColor(.secondary)
                    Button(action: { showingPlanGenerator = true }) {
                        Text("AI 生成计划").font(.subheadline).foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(Color(hex: "#4CAF50")).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                ForEach(weekPlans) { plan in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.date.weekdayChinese).font(.subheadline).fontWeight(.medium)
                            Text(plan.exercises.map(\.name).joined(separator: " · ")).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text("\(plan.durationMinutes)分钟").font(.caption).foregroundColor(Color(hex: "#4CAF50"))
                    }.padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 运动打卡
    private var exerciseStreak: some View {
        let weekPlans = exercisePlans.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        let monthPlans = exercisePlans.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }

        return HStack {
            StatItemView(label: "连续运动", value: "\(consecutiveDays)", unit: "天", color: Color(hex: "#4CAF50"))
            StatItemView(label: "本周完成", value: "\(weekPlans.filter(\.isCompleted).count)/\(weekPlans.count)", unit: "次", color: .primary)
            StatItemView(label: "本月总计", value: "\(monthPlans.count)", unit: "次", color: .primary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 各阶段推荐
    private var phaseRecommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("各阶段推荐运动", systemImage: "list.bullet.rectangle").font(.headline)
            ForEach(CyclePhase.allCases, id: \.self) { phase in
                DisclosureGroup {
                    ForEach(ExercisePlan.recommended(for: phase), id: \.name) { ex in
                        HStack {
                            Text("• \(ex.name)").font(.caption)
                            Spacer()
                            Text("\(ex.durationMinutes ?? 0)分钟").font(.caption2).foregroundColor(.secondary)
                            Text(ex.type.rawValue).font(.caption2).foregroundColor(Color(hex: phase.color))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: phase.color).opacity(0.15)))
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: phase.icon).foregroundColor(Color(hex: phase.color))
                        Text(phase.description).font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Text(phaseLabel(phase)).font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    private func phaseLabel(_ phase: CyclePhase) -> String {
        switch phase {
        case .menstrual: return "温和"
        case .follicular: return "高强度"
        case .ovulatory: return "最佳期"
        case .luteal: return "中等"
        }
    }

    private var exerciseTolerance: String {
        switch appState.currentCyclePhase {
        case .menstrual: return "低 - 以温和运动为主"
        case .follicular: return "高 - 适合力量训练"
        case .ovulatory: return "最高 - 挑战极限"
        case .luteal: return "中 - 适度有氧"
        }
    }

    private var consecutiveDays: Int {
        var days = 0
        let cal = Calendar.current
        var date = Date()
        while true {
            if exercisePlans.contains(where: { cal.isDate($0.date, inSameDayAs: date) && $0.isCompleted }) {
                days += 1; date = cal.date(byAdding: .day, value: -1, to: date)!
            } else { break }
        }
        return days
    }

    private func loadHealthKitData() {
        Task {
            let now = Date()
            let start = Calendar.current.startOfDay(for: now)
            hkSteps = (try? await HealthKitService.shared.fetchStepCount(from: start, to: now)) ?? 0
            hkActiveCalories = (try? await HealthKitService.shared.fetchActiveEnergy(from: start, to: now)) ?? 0
            hkExerciseMinutes = (try? await HealthKitService.shared.fetchExerciseMinutes(from: start, to: now)) ?? 0
        }
    }
}

// MARK: - 小部件
struct ExerciseDataItem: View {
    let label: String; let value: String; let unit: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.subheadline).fontWeight(.bold)
                Text(unit).font(.caption2).foregroundColor(.secondary)
            }
            Text(label).font(.caption2).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct StatItemView: View {
    let label: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3).fontWeight(.bold).foregroundColor(color)
            Text(unit).font(.caption2).foregroundColor(.secondary)
            Text(label).font(.caption).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - AI 计划生成器 (修复版)
struct PlanGeneratorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Query private var userProfiles: [UserProfile]
    let onSave: ([ExercisePlan]) -> Void
    @State private var selectedFocus = "综合"
    @State private var generating = false
    @State private var generatedPlans: [ExercisePlan] = []

    let focusAreas = ["综合", "减脂", "增肌", "塑形", "柔韧", "减压"]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if generatedPlans.isEmpty {
                    VStack(spacing: 24) {
                        Text("AI 生成运动计划").font(.title2).fontWeight(.bold)
                        Text("根据你的周期阶段和目标\n生成个性化的运动方案")
                            .multilineTextAlignment(.center).foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("训练侧重").font(.headline)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                                ForEach(focusAreas, id: \.self) { area in
                                    Button(action: { selectedFocus = area }) {
                                        Text(area).font(.subheadline).padding(.horizontal, 12).padding(.vertical, 8).frame(maxWidth: .infinity)
                                            .background(RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedFocus == area ? Color(hex: "#4CAF50") : Color(.systemGray6)))
                                            .foregroundColor(selectedFocus == area ? .white : .primary)
                                    }
                                }
                            }
                        }.padding(.horizontal)

                        Button(action: generatePlan) {
                            HStack {
                                if generating { ProgressView().tint(.white) }
                                Text(generating ? "生成中..." : "生成我的计划")
                            }
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(hex: "#4CAF50")).clipShape(RoundedRectangle(cornerRadius: 16))
                        }.padding(.horizontal).disabled(generating)
                    }.padding(.top)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(generatedPlans) { plan in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(plan.date.weekdayChinese).font(.headline)
                                        Spacer()
                                        Text(plan.intensity.rawValue).font(.caption)
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(Capsule().fill(Color(hex: "#4CAF50").opacity(0.15)))
                                            .foregroundColor(Color(hex: "#4CAF50"))
                                    }
                                    ForEach(plan.exercises, id: \.name) { ex in
                                        HStack {
                                            Text(ex.name).font(.subheadline)
                                            Spacer()
                                            if let dur = ex.durationMinutes { Text("\(dur)分钟").font(.caption).foregroundColor(.secondary) }
                                            if let sets = ex.sets, let reps = ex.reps { Text("\(sets)×\(reps)").font(.caption).foregroundColor(.secondary) }
                                        }
                                    }
                                    Text("\(plan.durationMinutes)分钟").font(.caption).foregroundColor(.secondary)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            }
                        }.padding()
                    }
                }
            }
            .navigationTitle("AI 计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                if !generatedPlans.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存计划") { onSave(generatedPlans); dismiss() }
                    }
                }
            }
        }
    }

    private func generatePlan() {
        generating = true
        Task {
            do {
                let context = AIChatContext(profile: userProfiles.first,
                                            cyclePhase: appState.currentCyclePhase)
                let prompt = """
                请为一位处于\(context.cyclePhase.rawValue)的女性生成一周运动计划，侧重\(selectedFocus)。
                周期长度28天，经期5天。返回JSON格式：
                [{"dayOffset": 0, "exercises": [{"name": "运动名", "type": "运动类型", "durationMinutes": 30}], "intensity": "中等强度"}]
                每天3个运动。
                """
                let result = try await AIService.shared.chat(userMessage: prompt, context: context)

                // 尝试解析JSON
                if let data = result.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    var plans: [ExercisePlan] = []
                    let cal = Calendar.current
                    for (i, item) in json.enumerated() {
                        let dayOffset = item["dayOffset"] as? Int ?? i
                        let intensityStr = item["intensity"] as? String ?? "中等强度"
                        let intensity = Intensity.allCases.first(where: { $0.rawValue == intensityStr }) ?? .medium

                        var exercises: [Exercise] = []
                        if let exList = item["exercises"] as? [[String: Any]] {
                            for ex in exList {
                                exercises.append(Exercise(
                                    name: ex["name"] as? String ?? "运动",
                                    type: ExerciseType.allCases.first(where: { $0.rawValue == (ex["type"] as? String ?? "") }) ?? .cardio,
                                    durationMinutes: ex["durationMinutes"] as? Int ?? 30
                                ))
                            }
                        }

                        let date = cal.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
                        let plan = ExercisePlan(date: date, cyclePhase: appState.currentCyclePhase,
                                                 dayOfCycle: dayOffset + 1, exercises: exercises,
                                                 intensity: intensity, durationMinutes: exercises.reduce(0) { $0 + ($1.durationMinutes ?? 30) })
                        plans.append(plan)
                    }
                    generatedPlans = plans
                } else {
                    // Fallback: 使用推荐
                    let cal = Calendar.current
                    let phase = appState.currentCyclePhase
                    generatedPlans = (0..<7).map { i in
                        let date = cal.date(byAdding: .day, value: i, to: Date()) ?? Date()
                        return ExercisePlan(date: date, cyclePhase: phase, dayOfCycle: i+1,
                                             exercises: ExercisePlan.recommended(for: phase),
                                             intensity: .medium, durationMinutes: 30)
                    }
                }
            } catch {
                // Fallback on error
                let cal = Calendar.current
                let phase = appState.currentCyclePhase
                generatedPlans = (0..<7).map { i in
                    let date = cal.date(byAdding: .day, value: i, to: Date()) ?? Date()
                    return ExercisePlan(date: date, cyclePhase: phase, dayOfCycle: i+1,
                                         exercises: ExercisePlan.recommended(for: phase),
                                         intensity: .medium, durationMinutes: 30)
                }
            }
            generating = false
        }
    }
}
