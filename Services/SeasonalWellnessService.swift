import Foundation

/// 24 节气养生服务
struct SeasonalWellnessService {
    // MARK: - 获取当前节气
    static func currentSolarTerm(for date: Date = Date()) -> SolarTerm? {
        guard let name = SeasonalTerms.currentTermName(for: date) else { return nil }
        return SeasonalTerms.detail(for: name)
    }

    // MARK: - 获取节气养生建议
    static func wellnessAdvice(for term: SolarTerm) -> WellnessAdvice {
        WellnessAdvice(
            termName: term.name,
            termDescription: term.description,
            dietAdvice: term.dietRecommendations,
            lifestyleAdvice: term.lifestyleRecommendations,
            exerciseAdvice: term.exerciseRecommendations,
            seasonalFoods: term.seasonalFoods,
            healthTips: term.healthTips
        )
    }

    // MARK: - 获取当前季节
    static func currentSeason(for date: Date = Date()) -> Season {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    // MARK: - 获取当季推荐食材
    static func seasonalFoods(for date: Date = Date()) -> [String] {
        currentSolarTerm(for: date)?.seasonalFoods ?? []
    }
}

// MARK: - 节气模型
struct SolarTerm: Codable {
    let name: String
    let date: Date
    let description: String
    let dietRecommendations: [String]
    let lifestyleRecommendations: [String]
    let exerciseRecommendations: [String]
    let seasonalFoods: [String]
    let healthTips: [String]
}

struct WellnessAdvice {
    let termName: String
    let termDescription: String
    let dietAdvice: [String]
    let lifestyleAdvice: [String]
    let exerciseAdvice: [String]
    let seasonalFoods: [String]
    let healthTips: [String]
}

enum Season: String {
    case spring = "春"
    case summer = "夏"
    case autumn = "秋"
    case winter = "冬"

    var element: String {
        switch self {
        case .spring: return "木"
        case .summer: return "火"
        case .autumn: return "金"
        case .winter: return "水"
        }
    }

    var organs: [String] {
        switch self {
        case .spring: return ["肝", "胆"]
        case .summer: return ["心", "小肠"]
        case .autumn: return ["肺", "大肠"]
        case .winter: return ["肾", "膀胱"]
        }
    }
}
