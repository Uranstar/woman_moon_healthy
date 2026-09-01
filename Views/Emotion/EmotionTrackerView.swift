import SwiftUI
import SwiftData

struct EmotionTrackerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmotionRecord.date, order: .reverse) private var emotionRecords: [EmotionRecord]

    @State private var selectedMood: Mood = .neutral
    @State private var selectedEmotions: Set<EmotionTag> = []
    @State private var trigger: String = ""
    @State private var notes: String = ""
    @State private var showingAnalysis = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 今日心情打卡
                moodCheckIn

                // 情绪趋势
                moodTrend

                // 周期-情绪关联
                cycleEmotionCorrelation

                // AI 情绪分析
                aiAnalysisCard

                // 正念引导
                mindfulnessCard

                // 历史记录
                recentEmotions
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("情绪管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: MindfulnessView()) {
                    Image(systemName: "leaf.circle")
                }
            }
        }
    }

    // MARK: - 心情打卡
    private var moodCheckIn: some View {
        VStack(spacing: 20) {
            Text("今天感觉如何？")
                .font(.headline)

            HStack(spacing: 16) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button(action: { selectedMood = mood }) {
                        VStack(spacing: 6) {
                            Text(mood.emoji)
                                .font(.system(size: 36))
                            Text(mood.label)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMood == mood ? Color(hex: "#FCE4EC") : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMood == mood ? Color(hex: "#E91E63") : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }

            // 情绪标签
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                ForEach(EmotionTag.allCases, id: \.self) { tag in
                    Button(action: {
                        if selectedEmotions.contains(tag) {
                            selectedEmotions.remove(tag)
                        } else {
                            selectedEmotions.insert(tag)
                        }
                    }) {
                        Text(tag.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedEmotions.contains(tag) ?
                                          Color(hex: "#E91E63").opacity(0.2) :
                                          Color(.systemGray6))
                            )
                            .foregroundColor(
                                selectedEmotions.contains(tag) ?
                                Color(hex: "#E91E63") : .secondary
                            )
                    }
                }
            }

            // 保存按钮
            Button(action: saveMood) {
                Text("记录心情")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#E91E63"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 情绪趋势
    private var moodTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("7天情绪趋势", systemImage: "chart.xyaxis.line")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(recentWeekEmotions, id: \.day) { item in
                    VStack(spacing: 4) {
                        Text(item.moodEmoji)
                            .font(.title3)
                        Rectangle()
                            .fill(moodBarColor(item.moodValue))
                            .frame(width: 24, height: max(CGFloat(item.moodValue) * 16, 8))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(item.dayLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 周期-情绪关联
    private var cycleEmotionCorrelation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("周期与情绪", systemImage: "link")
                .font(.headline)

            Text("你当前处于\(appState.currentCyclePhase.description)，这个阶段常见的情绪特点：")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(phaseEmotionInfo)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: appState.currentCyclePhase.color).opacity(0.08))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - AI 分析
    private var aiAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI 情绪分析", systemImage: "brain")
                .font(.headline)

            Text("基于你近期的情绪记录，AI 可以帮你分析情绪模式，提供科学的调节建议。")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: { showingAnalysis = true }) {
                Text("开始分析")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#9C27B0"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .stroke(Color(hex: "#9C27B0"), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 正念引导
    private var mindfulnessCard: some View {
        NavigationLink(destination: MindfulnessView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("正念 & 冥想", systemImage: "leaf.circle.fill")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    MindfulnessItem(icon: "wind", title: "呼吸练习", duration: "3分钟")
                    MindfulnessItem(icon: "ear", title: "身体扫描", duration: "5分钟")
                    MindfulnessItem(icon: "heart", title: "自我关怀", duration: "5分钟")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
            )
        }
    }

    // MARK: - 历史
    private var recentEmotions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最近记录", systemImage: "list.bullet.clipboard")
                .font(.headline)

            ForEach(emotionRecords.prefix(5)) { record in
                HStack {
                    Text(record.mood.emoji)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.mood.label)
                            .font(.subheadline)
                        if !record.emotions.isEmpty {
                            Text(record.emotions.map(\.rawValue).joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(record.date.shortChineseFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 辅助
    private func saveMood() {
        let record = EmotionRecord(
            mood: selectedMood,
            emotions: Array(selectedEmotions),
            trigger: trigger.isEmpty ? nil : trigger,
            notes: notes,
            cyclePhase: appState.currentCyclePhase,
            dayOfCycle: appState.lastCycleStartDate.map {
                CycleCalculator.dayOfCycle(from: $0)
            }
        )
        modelContext.insert(record)
        try? modelContext.save()

        // 重置
        selectedMood = .neutral
        selectedEmotions = []
        trigger = ""
        notes = ""
    }

    private var recentWeekEmotions: [(day: String, dayLabel: String, moodValue: Int, moodEmoji: String)] {
        let calendar = Calendar.current
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -(6 - offset), to: Date())!
            let dayIndex = calendar.component(.weekday, from: date)
            let dayLabel = weekdays[(dayIndex + 5) % 7]

            let record = emotionRecords.first {
                calendar.isDate($0.date, inSameDayAs: date)
            }

            let moodValue = record?.mood.rawValue ?? 3
            let emoji = record?.mood.emoji ?? "➖"

            return (day: dayLabel, dayLabel: dayLabel, moodValue: moodValue, moodEmoji: emoji)
        }
    }

    private func moodBarColor(_ value: Int) -> Color {
        switch value {
        case 5: return Color(hex: "#4CAF50")
        case 4: return Color(hex: "#8BC34A")
        case 3: return Color(hex: "#FFC107")
        case 2: return Color(hex: "#FF9800")
        default: return Color(hex: "#F44336")
        }
    }

    private var phaseEmotionInfo: String {
        switch appState.currentCyclePhase {
        case .menstrual:
            return "经期雌激素和孕激素都处于低水平，可能感到疲劳、情绪低落。这是正常的生理反应，多休息，做温和运动有助于缓解。"
        case .follicular:
            return "雌激素逐渐上升，精力充沛，心情通常较好。这是社交、创造和开始新项目的好时期。"
        case .ovulatory:
            return "雌激素达到峰值，自信心强，沟通能力提升。魅力四射的时期！享受社交和活动。"
        case .luteal:
            return "孕激素上升可能导致情绪波动、焦虑或易怒。注意自我关怀，减少压力，补充镁和B族维生素。"
        }
    }
}

// MARK: - 辅助组件
struct MindfulnessItem: View {
    let icon: String
    let title: String
    let duration: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: "#4CAF50"))
                .frame(height: 24)

            Text(title)
                .font(.caption2)

            Text(duration)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - 正念练习页面
struct MindfulnessView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 呼吸练习
                BreathingExerciseCard()

                // 身体扫描
                BodyScanCard()

                // 感恩日记
                GratitudeCard()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("正念练习")
    }
}

struct BreathingExerciseCard: View {
    @State private var isBreathing = false
    @State private var breathPhase = "准备开始"
    @State private var breathCount = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("4-7-8 呼吸法")
                .font(.headline)

            ZStack {
                Circle()
                    .stroke(Color(hex: "#4CAF50").opacity(0.2), lineWidth: 2)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: isBreathing ? 1 : 0.3)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "#4CAF50"), Color(hex: "#81C784")],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 4).repeatForever(), value: isBreathing)

                VStack(spacing: 8) {
                    Text(breathPhase)
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("\(breathCount) 轮")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: toggleBreathing) {
                Text(isBreathing ? "停止" : "开始练习")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#4CAF50"))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    private func toggleBreathing() {
        isBreathing.toggle()
        if isBreathing {
            breathPhase = "吸气..."
            breathCount = 0
        } else {
            breathPhase = "准备开始"
        }
    }
}

struct BodyScanCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("身体扫描冥想", systemImage: "figure.mind.and.body")
                .font(.headline)

            Text("闭上眼睛，将注意力依次带到身体的每个部位，从脚趾到头顶，觉察身体的感受，不加评判。")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineSpacing(4)

            Button(action: {}) {
                Label("开始 5 分钟练习", systemImage: "play.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#2196F3"))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }
}

struct GratitudeCard: View {
    @State private var gratitudeText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("感恩日记", systemImage: "heart.text.square.fill")
                .font(.headline)

            Text("今天让你感到感恩的三件事：")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $gratitudeText)
                .frame(minHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )

            Button(action: {}) {
                Text("保存")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#E91E63"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }
}
