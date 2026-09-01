import Foundation

/// AI 服务 — DeepSeek API 驱动，健康分析、营养解读、智能助手
final class AIService {
    static let shared = AIService()

    private let baseURL = Constants.aiAPIBaseURL
    private let session = URLSession.shared

    private init() {}

    // MARK: - 通用 DeepSeek API 请求 (OpenAI 兼容格式)
    private func sendMessage(
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 2000
    ) async throws -> String {
        guard !Constants.aiAPIKey.isEmpty else {
            throw AIError.noAPIKey
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(Constants.aiAPIKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": Constants.aiModel,
            "max_tokens": maxTokens,
            "temperature": 0.7,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.requestFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("DeepSeek API Error: \(message)")
            }
            throw AIError.requestFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AIError.invalidResponse
        }

        return text
    }

    // MARK: - 维生素/营养分析
    func analyzeNutrition(foodName: String, amount: Double) async throws -> NutritionAnalysis {
        let systemPrompt = """
        你是一位专业的营养师。根据用户提供的食物名称和份量，分析其营养成分。
        返回 JSON 格式，包含: foodName(食物名), calories(热量kcal), protein(蛋白质g), fat(脂肪g), carbs(碳水g), fiber(纤维素g), vitamins(维生素列表，每项含name/amount/unit/dailyPercentage), notes(备注)。
        """

        let userMessage = "分析 \(amount)g \(foodName) 的营养成分，返回 JSON。"

        let result = try await sendMessage(systemPrompt: systemPrompt, userMessage: userMessage)

        if let data = extractJSON(from: result).data(using: .utf8) {
            return try JSONDecoder().decode(NutritionAnalysis.self, from: data)
        }
        throw AIError.parsingFailed
    }

    // MARK: - 身体信号解读
    func interpretBodySignal(signal: String, cyclePhase: String, recentSymptoms: [String]) async throws -> String {
        let systemPrompt = """
        你是一位资深妇科医生和健康顾问。用户描述身体信号，请结合她的月经周期阶段和近期症状，
        给出科学、温和、有同理心的解读和建议。不要给出医学诊断，而是提供健康建议和是否需要就医的提示。
        """

        let userMessage = """
        我目前处于\(cyclePhase)，最近有这些症状：\(recentSymptoms.joined(separator: "、"))。
        我注意到：\(signal)。请帮我解读这个身体信号，给出建议。
        """

        return try await sendMessage(systemPrompt: systemPrompt, userMessage: userMessage)
    }

    // MARK: - 情绪分析
    func analyzeEmotion(mood: String, emotions: [String], cyclePhase: String, notes: String) async throws -> EmotionAnalysis {
        let systemPrompt = """
        你是一位专业的心理咨询师，擅长女性心理健康。分析用户的情绪状态，结合月经周期，
        给出科学的解释和实用的调节建议。返回 JSON 格式: summary(总结), possibleCauses(可能原因数组), suggestions(建议数组), cycleRelated(是否与周期相关bool)。
        """

        let userMessage = """
        我在\(cyclePhase)，心情\(mood)，感受到\(emotions.joined(separator: "、"))。
        备注：\(notes)。请分析我的情绪状态并给出建议。
        """

        let result = try await sendMessage(systemPrompt: systemPrompt, userMessage: userMessage)

        if let data = extractJSON(from: result).data(using: .utf8) {
            return try JSONDecoder().decode(EmotionAnalysis.self, from: data)
        }
        throw AIError.parsingFailed
    }

    // MARK: - AI 助手对话
    func chat(userMessage: String, context: AIChatContext) async throws -> String {
        let systemPrompt = """
        你是「月舒」App 的 AI 健康助手，名叫"小月"。你是一位温柔、专业、知识丰富的女性健康顾问。
        你的回答应该：
        1. 结合用户的周期、健康数据给出个性化建议
        2. 用温和亲切的语气
        3. 基于科学证据，不虚构信息
        4. 必要时建议用户咨询专业医生

        用户当前信息：
        - 周期阶段：\(context.cyclePhase.rawValue)
        - 年龄：\(context.age)岁
        - 运动目标：\(context.goals.map(\.rawValue).joined(separator: "、"))
        - BMI：\(String(format: "%.1f", context.bmi ?? 0))
        """

        return try await sendMessage(systemPrompt: systemPrompt, userMessage: userMessage, maxTokens: 1500)
    }

    // MARK: - 医疗记录分析
    func analyzeMedicalRecord(title: String, diagnosis: String?) async throws -> String {
        let systemPrompt = """
        你是一位医学信息整理专家。将用户提供的病例信息，用通俗易懂的语言进行总结分析，
        帮助用户理解自己的健康状况。不要过度解读，提醒用户以医生意见为准。
        """

        let userMessage = """
        病例标题：\(title)
        诊断：\(diagnosis ?? "未提供")
        请帮我用通俗的语言总结这个病例的关键信息。
        """

        return try await sendMessage(systemPrompt: systemPrompt, userMessage: userMessage)
    }

    // MARK: - 每日饮食建议
    func getDailyDietAdvice(cyclePhase: String, goals: [String]) async throws -> String {
        let systemPrompt = """
        你是一位营养师，专门为女性设计周期化饮食方案。根据用户的周期阶段和健身目标，
        给出今日饮食建议，包括推荐食材、营养素配比、注意事项。
        """

        let userMessage = """
        我现在处于\(cyclePhase)，我的目标是\(goals.joined(separator: "、"))。
        请给我今天的饮食建议。
        """

        return try await sendMessage(systemPrompt: systemPrompt, userMessage: userMessage)
    }

    // MARK: - 从回复中提取 JSON
    private func extractJSON(from text: String) -> String {
        // DeepSeek 返回的 JSON 可能在 markdown 代码块中
        if let jsonStart = text.range(of: "```json"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let jsonStart = text.range(of: "```"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 尝试直接找 { 到 }
        if let braceStart = text.range(of: "{"),
           let braceEnd = text.range(of: "}", options: .backwards) {
            return String(text[braceStart.lowerBound...braceEnd.lowerBound])
        }
        return text
    }
}

// MARK: - 数据模型
struct NutritionAnalysis: Codable {
    let foodName: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let fiber: Double?
    let vitamins: [VitaminInfo]
    let notes: String?
}

struct VitaminInfo: Codable {
    let name: String
    let amount: Double
    let unit: String
    let dailyPercentage: Double?
}

struct EmotionAnalysis: Codable {
    let summary: String
    let possibleCauses: [String]
    let suggestions: [String]
    let cycleRelated: Bool
}

struct AIChatContext {
    let cyclePhase: CyclePhase
    let age: Int
    let goals: [Goal]
    let bmi: Double?
}

// MARK: - 错误
enum AIError: LocalizedError {
    case noAPIKey
    case requestFailed
    case invalidResponse
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "未配置 DeepSeek API Key"
        case .requestFailed:
            return "API 请求失败，请检查网络"
        case .invalidResponse:
            return "API 返回格式异常"
        case .parsingFailed:
            return "分析结果解析失败"
        }
    }
}
