 import SwiftUI

struct SeasonalWellnessView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentTerm: SolarTerm?
    @State private var wellnessAdvice: WellnessAdvice?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 当前节气卡片
                if let advice = wellnessAdvice {
                    currentTermCard(advice)
                }

                // 饮食建议
                if let advice = wellnessAdvice {
                    dietSection(advice)
                }

                // 起居建议
                if let advice = wellnessAdvice {
                    lifestyleSection(advice)
                }

                // 运动建议
                if let advice = wellnessAdvice {
                    exerciseSection(advice)
                }

                // 经络养生
                meridianSection

                // 24节气一览
                allTermsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("节气养生")
        .onAppear(perform: loadTermData)
    }

    // MARK: - 当前节气
    private func currentTermCard(_ advice: WellnessAdvice) -> some View {
        VStack(spacing: 16) {
            // 节气标题
            VStack(spacing: 8) {
                Text(advice.termName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#2E7D32"))

                Text(advice.termDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                let season = SeasonalWellnessService.currentSeason()
                HStack(spacing: 8) {
                    SeasonTag(text: "\(season.rawValue)季", color: Color(hex: "#4CAF50"))
                    SeasonTag(text: "属\(season.element)", color: Color(hex: "#FF9800"))
                    SeasonTag(text: "养\(season.organs.first ?? "")", color: Color(hex: "#E91E63"))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#E8F5E9"), Color(hex: "#F1F8E9")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: - 饮食建议
    private func dietSection(_ advice: WellnessAdvice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("饮食调养", systemImage: "fork.knife")
                .font(.headline)

            ForEach(advice.dietAdvice, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("🍽️")
                        .font(.caption)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Text("时令食材推荐")
                .font(.subheadline)
                .fontWeight(.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(advice.seasonalFoods, id: \.self) { food in
                        VStack(spacing: 4) {
                            Text(foodEmoji(food))
                                .font(.title)
                            Text(food)
                                .font(.caption2)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: "#E8F5E9"))
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 起居建议
    private func lifestyleSection(_ advice: WellnessAdvice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("起居调养", systemImage: "bed.double.fill")
                .font(.headline)

            ForEach(advice.lifestyleAdvice, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("🏠")
                        .font(.caption)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 运动建议
    private func exerciseSection(_ advice: WellnessAdvice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("运动导引", systemImage: "figure.walk")
                .font(.headline)

            ForEach(advice.exerciseAdvice, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("🧘")
                        .font(.caption)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 经络穴位
    private var meridianSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("经络穴位", systemImage: "figure.acupuncture")
                .font(.headline)

            let season = SeasonalWellnessService.currentSeason()

            VStack(spacing: 10) {
                MeridianRow(organ: season.organs.first ?? "肝",
                           description: "\(season.rawValue)季重点养护",
                           points: season == .spring ? "太冲 · 行间" :
                                   season == .summer ? "神门 · 少府" :
                                   season == .autumn ? "太渊 · 尺泽" : "太溪 · 涌泉")
            }

            if let tips = wellnessAdvice?.healthTips.first {
                Text("💆 \(tips)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#FFF3E0"))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 24节气一览
    private var allTermsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("24节气一览", systemImage: "calendar.badge.clock")
                .font(.headline)

            let allTerms = SeasonalTerms.termsForYear(Calendar.current.component(.year, from: Date()))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(allTerms, id: \.name) { term in
                    let isCurrent = currentTerm?.name == term.name
                    VStack(spacing: 4) {
                        Text(term.name)
                            .font(.caption)
                            .fontWeight(isCurrent ? .bold : .regular)
                        Text(term.date.shortChineseFormatted)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isCurrent ? Color(hex: "#C8E6C9") : Color(.systemGray6))
                    )
                    .foregroundColor(isCurrent ? Color(hex: "#2E7D32") : .primary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 辅助
    private func loadTermData() {
        guard let term = SeasonalWellnessService.currentSolarTerm(),
              let detail = SeasonalTerms.detail(for: term.name) else { return }
        currentTerm = term
        wellnessAdvice = SeasonalWellnessService.wellnessAdvice(for: detail)
    }

    private func foodEmoji(_ food: String) -> String {
        let map: [String: String] = [
            "羊肉": "🍖", "红枣": "🫐", "桂圆": "🟤", "当归": "🌿", "生姜": "🫚",
            "黑豆": "🫘", "黑芝麻": "🖤", "核桃": "🥜", "山药": "🥔",
            "韭菜": "🥬", "豆芽": "🌱", "菠菜": "🥬", "芹菜": "🥬", "草莓": "🍓",
            "薏米": "🌾", "茯苓": "🪵", "莲子": "🪷",
            "梨": "🍐", "蜂蜜": "🍯", "百合": "🤍", "银耳": "🍄",
            "荠菜": "🌿", "香椿": "🌱", "春笋": "🎋",
            "苦瓜": "🥒", "黄瓜": "🥒", "西瓜": "🍉", "绿豆": "🟢",
            "百合": "🤍", "银耳": "🍄", "莲藕": "🪷",
            "龙眼": "🟤", "芋头": "🥔",
            "螃蟹": "🦀", "柿子": "🟠", "石榴": "🔴", "南瓜": "🎃",
            "芝麻": "🖤", "萝卜": "🥕",
            "红薯": "🍠", "板栗": "🌰",
            "枸杞": "🔴", "绿茶": "🍵", "冬瓜": "🍈",
        ]
        return map[food] ?? "🥗"
    }
}

// MARK: - 辅助组件
struct SeasonTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .foregroundColor(color)
    }
}

struct MeridianRow: View {
    let organ: String
    let description: String
    let points: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(organ + "经")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("穴位")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(points)
                    .font(.caption)
                    .foregroundColor(Color(hex: "#E91E63"))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}
