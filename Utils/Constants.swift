import Foundation

enum Constants {
    // MARK: - API (DeepSeek)
    static let aiAPIBaseURL = "https://api.deepseek.com/v1"
    static let aiModel = "deepseek-v4-flash"  // deepseek-chat / deepseek-reasoner
    // 优先读环境变量 DEEPSEEK_API_KEY，其次读 Keychain
    static var aiAPIKey: String {
        if let envKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return KeychainHelper.read(key: "deepseek_api_key") ?? ""
    }

    // MARK: - Default Values
    // HealthKit 的类型声明集中在 HealthKitService.readTypes / writeTypes，
    // 那里直接使用 HKObjectType 构造，不经过中间枚举。
    static let defaultCycleLength = 28
    static let defaultPeriodLength = 5
    static let defaultLutealLength = 14

    // MARK: - Nutrition Goals (per day)
    static let defaultCalorieGoal = 2000.0
    static let defaultProteinGoal = 60.0  // g
    static let defaultFatGoal = 65.0      // g
    static let defaultCarbsGoal = 250.0   // g
}

// MARK: - Cycle Phase
enum CyclePhase: String, Codable, CaseIterable {
    case menstrual = "经期"       // Day 1-5
    case follicular = "卵泡期"    // Day 6-13
    case ovulatory = "排卵期"     // Day 14-16
    case luteal = "黄体期"        // Day 17-28

    var description: String { rawValue }

    var icon: String {
        switch self {
        case .menstrual: return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulatory: return "star.fill"
        case .luteal: return "moon.fill"
        }
    }

    var color: String {
        switch self {
        case .menstrual: return "#E74C3C"
        case .follicular: return "#2ECC71"
        case .ovulatory: return "#F39C12"
        case .luteal: return "#9B59B6"
        }
    }
}

// MARK: - Goal
enum Goal: String, Codable, CaseIterable {
    case loseWeight = "减重"
    case loseFat = "减脂"
    case gainMuscle = "增肌"
    case maintain = "保持"
}

// MARK: - Activity Level
enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "久坐不动"
    case lightlyActive = "轻度活动"
    case moderatelyActive = "中度活动"
    case veryActive = "高度活跃"
    case extraActive = "极高活跃"
}

// MARK: - Metric Type
enum MetricType: String, Codable, CaseIterable {
    case weight = "体重"
    case bodyFat = "体脂率"
    case waist = "腰围"
    case hip = "臀围"
    case thigh = "大腿围"
    case arm = "手臂围"
    case chest = "胸围"
}

// MARK: - Data Source
enum DataSource: String, Codable {
    case manual = "手动录入"
    case healthKit = "Apple Health"
}

// MARK: - Meal Type
enum MealType: String, Codable, CaseIterable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"
    case snack = "加餐"
}

// MARK: - Mood
enum Mood: Int, Codable, CaseIterable {
    case veryBad = 1
    case bad = 2
    case neutral = 3
    case good = 4
    case veryGood = 5

    var emoji: String {
        switch self {
        case .veryBad: return "😫"
        case .bad: return "😔"
        case .neutral: return "😐"
        case .good: return "😊"
        case .veryGood: return "🥰"
        }
    }

    var label: String {
        switch self {
        case .veryBad: return "很差"
        case .bad: return "不太好"
        case .neutral: return "一般"
        case .good: return "不错"
        case .veryGood: return "很好"
        }
    }
}

// MARK: - Emotion Tag
enum EmotionTag: String, Codable, CaseIterable {
    case happy = "开心"
    case anxious = "焦虑"
    case irritable = "易怒"
    case sad = "悲伤"
    case tired = "疲惫"
    case energized = "精力充沛"
    case calm = "平静"
    case stressed = "压力大"
    case bloated = "胀气"
    case crampy = "腹痛"
    case headache = "头痛"
    case insomnia = "失眠"
}

// MARK: - Exercise Intensity
enum Intensity: String, Codable, CaseIterable {
    case low = "低强度"
    case medium = "中等强度"
    case high = "高强度"
}

// MARK: - Time of Day
enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "早晨"
    case noon = "中午"
    case evening = "晚上"
    case beforeBed = "睡前"
}

// MARK: - Symptom
enum Symptom: String, Codable, CaseIterable {
    case cramp = "痛经"
    case bloating = "腹胀"
    case fatigue = "疲劳"
    case headache = "头痛"
    case acne = "长痘"
    case breastTenderness = "乳房胀痛"
    case backPain = "腰酸"
    case nausea = "恶心"
    case diarrhea = "腹泻"
    case insomnia = "失眠"
    case increasedAppetite = "食欲增加"
}

// MARK: - Food Category
enum FoodCategory: String, Codable, CaseIterable {
    case staple = "主食"
    case meat = "肉类"
    case seafood = "海鲜"
    case egg = "蛋类"
    case dairy = "奶制品"
    case vegetable = "蔬菜"
    case fruit = "水果"
    case nut = "坚果"
    case beverage = "饮品"
    case snack = "零食"
    case supplement = "补剂"
    case seasoning = "调料"
}

extension FoodCategory {
    /// 内置数据文件 [Resources/FoodDatabase.json](Resources/FoodDatabase.json) 用英文 case 名
    /// 作为 `category` 字段取值，而 `rawValue` 是中文展示名，
    /// 因此**不能**用 `FoodCategory(rawValue:)` 反序列化 —— 那样每一条都会解析失败。
    init?(seedKey: String) {
        guard let match = FoodCategory.allCases.first(where: { $0.seedKey == seedKey }) else {
            return nil
        }
        self = match
    }

    /// 与内置数据文件中的 `category` 字段一一对应。
    /// 这里用穷举 switch 而非字符串拼接，新增分类时编译器会强制补全。
    var seedKey: String {
        switch self {
        case .staple: return "staple"
        case .meat: return "meat"
        case .seafood: return "seafood"
        case .egg: return "egg"
        case .dairy: return "dairy"
        case .vegetable: return "vegetable"
        case .fruit: return "fruit"
        case .nut: return "nut"
        case .beverage: return "beverage"
        case .snack: return "snack"
        case .supplement: return "supplement"
        case .seasoning: return "seasoning"
        }
    }
}

// MARK: - Cycle Event Type
enum CycleEventType: String, Codable, CaseIterable {
    case cervicalMucus = "宫颈粘液"
    case ovulationTest = "排卵测试"
    case bbt = "基础体温"
    case otherNote = "其他标记"

    var icon: String {
        switch self {
        case .cervicalMucus: return "drop.fill"
        case .ovulationTest: return "testtube.2"
        case .bbt: return "thermometer"
        case .otherNote: return "tag.fill"
        }
    }
}

// MARK: - Cervical Mucus Type
enum CervicalMucusType: String, Codable, CaseIterable {
    case dry = "干燥"
    case sticky = "粘稠"
    case creamy = "乳白"
    case eggWhite = "蛋清状"
    case watery = "水样"
}

// MARK: - Ovulation Test Result
enum OvulationTestResult: String, Codable, CaseIterable {
    case negative = "阴性"
    case faint = "弱阳"
    case positive = "阳性"
    case peak = "强阳"

    var color: String {
        switch self {
        case .negative: return "#9E9E9E"
        case .faint: return "#FFC107"
        case .positive: return "#FF9800"
        case .peak: return "#E91E63"
        }
    }
}

// MARK: - Medical Category
enum MedicalCategory: String, Codable, CaseIterable {
    case gynecology = "妇科"
    case dermatology = "皮肤科"
    case endocrinology = "内分泌科"
    case gastroenterology = "消化科"
    case cardiology = "心内科"
    case orthopedics = "骨科"
    case neurology = "神经科"
    case general = "全科"
    case other = "其他"
}
