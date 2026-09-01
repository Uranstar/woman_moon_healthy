import SwiftUI

extension Color {
    /// 从十六进制字符串创建颜色 (已在 ContentView 中定义，此处为补充方法)

    /// 主色调 - 玫瑰粉
    static let womenMoonPink = Color(hex: "#E91E63")

    /// 辅助色 - 紫色
    static let womenMoonPurple = Color(hex: "#9C27B0")

    /// 周期阶段颜色
    static let phaseMenstrual = Color(hex: "#E74C3C")
    static let phaseFollicular = Color(hex: "#2ECC71")
    static let phaseOvulatory = Color(hex: "#F39C12")
    static let phaseLuteal = Color(hex: "#9B59B6")

    /// 周期阶段颜色（按阶段获取）
    static func colorForPhase(_ phase: CyclePhase) -> Color {
        switch phase {
        case .menstrual: return phaseMenstrual
        case .follicular: return phaseFollicular
        case .ovulatory: return phaseOvulatory
        case .luteal: return phaseLuteal
        }
    }
}
