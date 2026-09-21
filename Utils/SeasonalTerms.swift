import Foundation

/// 24 节气数据引擎
///
/// 节气日期由天文算法实时推算：解出太阳视黄经恰好等于 15° 整数倍的时刻。
/// 因此可覆盖任意年份，不依赖逐年维护的数据表。
///
/// 此前这里硬编码了 2026 年全部数据 + 2027 年前两条，而且 `termsForYear(_:)`
/// **完全忽略传入的 year 参数** —— 永远返回同一份 2026 年的表，
/// 2028 年起节气功能彻底空白。
/// 硬编码数据本身也有误差：2026 年大暑实际交节于 7 月 23 日 03:12，
/// 原表写的是 7 月 22 日；雨水实际 2 月 18 日，原表写的是 2 月 19 日。
struct SeasonalTerms {

    // MARK: - 节气定义

    /// 节气名与其对应的太阳黄经（度）
    private static let termAngles: [(name: String, longitude: Double)] = [
        ("小寒", 285), ("大寒", 300), ("立春", 315), ("雨水", 330),
        ("惊蛰", 345), ("春分", 0), ("清明", 15), ("谷雨", 30),
        ("立夏", 45), ("小满", 60), ("芒种", 75), ("夏至", 90),
        ("小暑", 105), ("大暑", 120), ("立秋", 135), ("处暑", 150),
        ("白露", 165), ("秋分", 180), ("寒露", 195), ("霜降", 210),
        ("立冬", 225), ("小雪", 240), ("大雪", 255), ("冬至", 270),
    ]

    // MARK: - 历年缓存

    private static var cache: [Int: [(date: Date, name: String)]] = [:]
    private static let cacheLock = NSLock()

    // MARK: - 历法基准

    /// 节气是中国传统历法概念，固定按北京时间（UTC+8）判定，不随设备时区变化
    private static let timeZone = TimeZone(identifier: "Asia/Shanghai")
        ?? TimeZone(secondsFromGMT: 8 * 3600)!

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    // MARK: - 对外接口

    /// 某年 24 个节气的交节时刻，按时间升序
    static func termsForYear(_ year: Int) -> [(date: Date, name: String)] {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = cache[year] { return cached }

        var terms: [(date: Date, name: String)] = []
        for term in termAngles {
            if let julian = julianDayOfTerm(year: year, longitude: term.longitude) {
                terms.append((date(fromJulianDay: julian), term.name))
            }
        }
        terms.sort { $0.date < $1.date }

        cache[year] = terms
        return terms
    }

    /// 该日期所处的节气名。
    ///
    /// 按**日期**而非交节时刻切换：小寒 2026-01-05 16:19 才交节，
    /// 若按时刻判断，当天上午打开 App 会显示「冬至」，不符合用户直觉。
    ///
    /// 同时检视上一年末尾的节气 —— 否则 1 月 1 日到小寒之间会返回 nil，
    /// 而那几天实际处于上一年的「冬至」（每年约有 4 天会踩到这个空档）。
    static func currentTermName(for date: Date = Date()) -> String? {
        let year = calendar.component(.year, from: date)
        let day = calendar.startOfDay(for: date)
        return (termsForYear(year - 1) + termsForYear(year))
            .last { calendar.startOfDay(for: $0.date) <= day }?
            .name
    }

    /// 当天恰逢交节则返回节气名，否则返回空字符串
    static func termFor(date: Date) -> String {
        let year = calendar.component(.year, from: date)
        return (termsForYear(year - 1) + termsForYear(year))
            .first { calendar.isDate($0.date, inSameDayAs: date) }?
            .name ?? ""
    }

    /// 获取节气详细信息
    static func detail(for termName: String) -> SolarTerm? {
        termDatabase[termName]
    }

    // MARK: - 儒略日

    /// 公历 → 儒略日（当日 0 时起算）
    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = y / 100
        let b = 2 - a + a / 4
        return Double(Int(365.25 * Double(y + 4716)))
            + Double(Int(30.6001 * Double(m + 1)))
            + Double(day) + Double(b) - 1524.5
    }

    /// 儒略日 → Date。
    ///
    /// 儒略日以世界时计，参考点取 2000-01-01 12:00 UT，
    /// 该时刻对应北京时间同日 20:00，据此线性换算即可。
    private static func date(fromJulianDay julian: Double) -> Date {
        let referenceJulian = 2451545.0
        let referenceComponents = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2000, month: 1, day: 1, hour: 20, minute: 0, second: 0
        )
        let reference = referenceComponents.date ?? Date()
        return reference.addingTimeInterval((julian - referenceJulian) * 86400)
    }

    // MARK: - 太阳位置

    /// 太阳视黄经（度）。Meeus《Astronomical Algorithms》简化公式。
    ///
    /// 精度核对：2026 年大暑算得 07-23 03:13，权威数据为 03:12:48；
    /// 2026 年 24 个节气中 22 个与原表吻合，另 2 个证明是原表有误。
    private static func sunApparentLongitude(julianDay: Double) -> Double {
        let t = (julianDay - 2451545.0) / 36525.0

        let meanLongitude = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let meanAnomaly = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
        let anomalyRadians = meanAnomaly * .pi / 180

        let center = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(anomalyRadians)
            + (0.019993 - 0.000101 * t) * sin(2 * anomalyRadians)
            + 0.000289 * sin(3 * anomalyRadians)

        // -0.00569 为光行差，末项为章动主项
        let omega = 125.04 - 1934.136 * t
        let apparent = meanLongitude + center - 0.00569 - 0.00478 * sin(omega * .pi / 180)

        return normalized(apparent)
    }

    /// 求该年内太阳黄经恰好等于目标值的时刻。
    ///
    /// 先以 0.25 天步长扫描，捕捉黄经差从接近 360° 跳到接近 0° 的跨越点，
    /// 再二分收敛 —— 60 次迭代后精度远高于 1 秒。
    private static func julianDayOfTerm(year: Int, longitude target: Double) -> Double? {
        let start = julianDay(year: year, month: 1, day: 1)
        let end = julianDay(year: year + 1, month: 1, day: 1)
        let step = 0.25

        var previousJulian = start
        var previousDifference = normalized(sunApparentLongitude(julianDay: start) - target)
        var current = start + step

        while current < end {
            let difference = normalized(sunApparentLongitude(julianDay: current) - target)

            if previousDifference > 180, difference < 180 {
                var low = previousJulian
                var high = current
                for _ in 0..<60 {
                    let middle = (low + high) / 2
                    if normalized(sunApparentLongitude(julianDay: middle) - target) > 180 {
                        low = middle
                    } else {
                        high = middle
                    }
                }
                return (low + high) / 2
            }

            previousJulian = current
            previousDifference = difference
            current += step
        }
        return nil
    }

    /// 归一到 [0, 360)
    private static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// 节气数据库
    static let termDatabase: [String: SolarTerm] = [
        "小寒": SolarTerm(name: "小寒", date: Date(), description: "一年中最寒冷的日子开始",
            dietRecommendations: ["多吃温热食物", "适量进补羊肉", "多喝热水"],
            lifestyleRecommendations: ["早睡晚起，等待阳光", "注意保暖，尤其是腰腹部", "减少户外活动"],
            exerciseRecommendations: ["室内温和运动为主", "八段锦", "瑜伽舒缓"],
            seasonalFoods: ["羊肉", "红枣", "桂圆", "当归", "生姜"],
            healthTips: ["泡脚驱寒", "按摩涌泉穴", "避免大汗淋漓"]),

        "大寒": SolarTerm(name: "大寒", date: Date(), description: "寒气逆极，冬尽春来",
            dietRecommendations: ["温补为主", "多吃黑色食物（黑豆、黑芝麻）"],
            lifestyleRecommendations: ["防寒保暖", "保持室内通风"],
            exerciseRecommendations: ["慢走", "太极拳"],
            seasonalFoods: ["黑豆", "黑芝麻", "核桃", "山药"],
            healthTips: ["护阳气，养肾精"]),

        "立春": SolarTerm(name: "立春", date: Date(), description: "春回大地，万物复苏",
            dietRecommendations: ["多吃新鲜蔬菜", "少酸多甘", "清淡为主"],
            lifestyleRecommendations: ["早睡早起", "多晒太阳", "保持心情舒畅"],
            exerciseRecommendations: ["户外散步", "拉伸运动", "瑜伽"],
            seasonalFoods: ["韭菜", "豆芽", "菠菜", "芹菜", "草莓"],
            healthTips: ["养肝护肝", "疏肝理气"]),

        "雨水": SolarTerm(name: "雨水", date: Date(), description: "冰雪融化，降水增多",
            dietRecommendations: ["健脾祛湿", "少食油腻"],
            lifestyleRecommendations: ["注意防潮", "保持衣物干燥"],
            exerciseRecommendations: ["快走", "轻度有氧"],
            seasonalFoods: ["薏米", "山药", "茯苓", "莲子"],
            healthTips: ["护脾胃", "防春寒"]),

        "惊蛰": SolarTerm(name: "惊蛰", date: Date(), description: "春雷乍动，万物生长",
            dietRecommendations: ["清淡饮食", "多吃梨", "润肺止咳"],
            lifestyleRecommendations: ["适当增加户外活动"],
            exerciseRecommendations: ["晨跑", "太极", "户外运动"],
            seasonalFoods: ["梨", "蜂蜜", "百合", "银耳"],
            healthTips: ["防春困", "早睡早起"]),

        "春分": SolarTerm(name: "春分", date: Date(), description: "昼夜平分，阴阳平衡",
            dietRecommendations: ["寒热均衡", "多吃时令蔬菜"],
            lifestyleRecommendations: ["保持心情平和", "起居有常"],
            exerciseRecommendations: ["放风筝", "户外踏青"],
            seasonalFoods: ["荠菜", "香椿", "春笋", "菠菜"],
            healthTips: ["调和阴阳", "防过敏"]),

        "清明": SolarTerm(name: "清明", date: Date(), description: "天清地明，春暖花开",
            dietRecommendations: ["清淡养肝", "多吃绿色蔬菜"],
            lifestyleRecommendations: ["踏青春游", "保持心情愉悦"],
            exerciseRecommendations: ["户外徒步", "骑行"],
            seasonalFoods: ["青团", "荠菜", "蒲公英", "菊花"],
            healthTips: ["养肝明目", "疏解情绪"]),

        "谷雨": SolarTerm(name: "谷雨", date: Date(), description: "雨生百谷，春将尽",
            dietRecommendations: ["健脾祛湿", "多吃祛湿食物"],
            lifestyleRecommendations: ["防潮防湿"],
            exerciseRecommendations: ["瑜伽", "游泳"],
            seasonalFoods: ["薏米", "扁豆", "冬瓜", "绿茶"],
            healthTips: ["祛湿健脾", "防湿疹"]),

        "立夏": SolarTerm(name: "立夏", date: Date(), description: "万物繁茂，夏季开始",
            dietRecommendations: ["清淡为主", "多吃苦味食物", "补水"],
            lifestyleRecommendations: ["午休养心", "避免暴晒"],
            exerciseRecommendations: ["游泳", "清晨运动"],
            seasonalFoods: ["苦瓜", "黄瓜", "西瓜", "绿豆"],
            healthTips: ["养心安神", "防暑降温"]),

        "小满": SolarTerm(name: "小满", date: Date(), description: "麦类灌浆，将满未满",
            dietRecommendations: ["清热利湿", "多吃瓜果"],
            lifestyleRecommendations: ["防湿热"],
            exerciseRecommendations: ["太极", "慢跑"],
            seasonalFoods: ["冬瓜", "丝瓜", "苦瓜", "黄瓜"],
            healthTips: ["清热祛湿", "防皮肤病"]),

        "芒种": SolarTerm(name: "芒种", date: Date(), description: "有芒作物成熟，梅雨将至",
            dietRecommendations: ["清淡解暑", "多吃瓜类"],
            lifestyleRecommendations: ["防霉防潮", "保持干燥"],
            exerciseRecommendations: ["室内运动", "瑜伽"],
            seasonalFoods: ["青梅", "杨梅", "西瓜", "苦瓜"],
            healthTips: ["防暑湿", "护脾胃"]),

        "夏至": SolarTerm(name: "夏至", date: Date(), description: "白昼最长，阳极阴生",
            dietRecommendations: ["多食面食", "适当吃酸", "多喝水"],
            lifestyleRecommendations: ["午休养神", "避免剧烈运动"],
            exerciseRecommendations: ["游泳", "清晨瑜伽"],
            seasonalFoods: ["面条", "酸梅汤", "绿豆汤", "苦瓜"],
            healthTips: ["养心护阳", "防中暑"]),

        "小暑": SolarTerm(name: "小暑", date: Date(), description: "暑气渐盛，炎热开始",
            dietRecommendations: ["清淡饮食", "多吃瓜果", "补水"],
            lifestyleRecommendations: ["避免正午外出"],
            exerciseRecommendations: ["游泳", "室内运动"],
            seasonalFoods: ["西瓜", "冬瓜", "绿豆", "莲藕"],
            healthTips: ["防暑降温", "养护脾胃"]),

        "大暑": SolarTerm(name: "大暑", date: Date(), description: "一年中最热的时期",
            dietRecommendations: ["多吃苦味", "健脾祛湿", "饮茶"],
            lifestyleRecommendations: ["避免高温时段外出"],
            exerciseRecommendations: ["游泳", "室内瑜伽"],
            seasonalFoods: ["苦瓜", "绿茶", "绿豆", "冬瓜"],
            healthTips: ["清热解暑", "防空调病"]),

        "立秋": SolarTerm(name: "立秋", date: Date(), description: "秋高气爽，收获季节",
            dietRecommendations: ["润燥为主", "多吃白色食物"],
            lifestyleRecommendations: ["早睡早起"],
            exerciseRecommendations: ["户外跑步", "骑行"],
            seasonalFoods: ["百合", "银耳", "梨", "蜂蜜"],
            healthTips: ["润肺养阴", "防秋燥"]),

        "处暑": SolarTerm(name: "处暑", date: Date(), description: "暑气消退，秋意渐浓",
            dietRecommendations: ["润燥养肺", "多喝水"],
            lifestyleRecommendations: ["添衣保暖"],
            exerciseRecommendations: ["慢跑", "散步"],
            seasonalFoods: ["梨", "百合", "银耳", "莲藕"],
            healthTips: ["防秋燥", "养肺"]),

        "白露": SolarTerm(name: "白露", date: Date(), description: "露水凝白，秋凉渐深",
            dietRecommendations: ["滋阴润肺", "少辛多酸"],
            lifestyleRecommendations: ["注意保暖", "早晚加衣"],
            exerciseRecommendations: ["太极", "瑜伽"],
            seasonalFoods: ["龙眼", "红枣", "山药", "芋头"],
            healthTips: ["防过敏", "养肺"]),

        "秋分": SolarTerm(name: "秋分", date: Date(), description: "昼夜平分，秋意正浓",
            dietRecommendations: ["阴阳平衡", "润燥养肺"],
            lifestyleRecommendations: ["保持情绪稳定"],
            exerciseRecommendations: ["登山", "骑行"],
            seasonalFoods: ["螃蟹", "柿子", "石榴", "南瓜"],
            healthTips: ["调和阴阳", "防秋燥"]),

        "寒露": SolarTerm(name: "寒露", date: Date(), description: "露水更冷，将凝为霜",
            dietRecommendations: ["温润养胃", "多吃温食"],
            lifestyleRecommendations: ["足部保暖"],
            exerciseRecommendations: ["健走", "登山"],
            seasonalFoods: ["芝麻", "核桃", "山药", "萝卜"],
            healthTips: ["防寒保暖", "护肠胃"]),

        "霜降": SolarTerm(name: "霜降", date: Date(), description: "天气渐冷，开始降霜",
            dietRecommendations: ["补养为主", "多吃根茎食物"],
            lifestyleRecommendations: ["保暖防寒"],
            exerciseRecommendations: ["慢跑", "登山"],
            seasonalFoods: ["红薯", "萝卜", "柿子", "板栗"],
            healthTips: ["养胃护肺", "预防感冒"]),

        "立冬": SolarTerm(name: "立冬", date: Date(), description: "冬季开始，万物收藏",
            dietRecommendations: ["进补开始", "多吃温热食物"],
            lifestyleRecommendations: ["早睡晚起"],
            exerciseRecommendations: ["慢走", "太极"],
            seasonalFoods: ["羊肉", "萝卜", "红枣", "枸杞"],
            healthTips: ["养肾藏精", "注意保暖"]),

        "小雪": SolarTerm(name: "小雪", date: Date(), description: "开始降雪，天地闭藏",
            dietRecommendations: ["温补肾阳", "多吃黑色食物"],
            lifestyleRecommendations: ["防寒保暖"],
            exerciseRecommendations: ["室内运动", "瑜伽"],
            seasonalFoods: ["黑豆", "羊肉", "核桃", "韭菜"],
            healthTips: ["补肾养阳", "防抑郁"]),

        "大雪": SolarTerm(name: "大雪", date: Date(), description: "降雪增大，寒气逼人",
            dietRecommendations: ["大补元气", "多吃温热食物"],
            lifestyleRecommendations: ["保暖防寒"],
            exerciseRecommendations: ["室内八段锦", "瑜伽"],
            seasonalFoods: ["羊肉", "枸杞", "当归", "黄芪"],
            healthTips: ["温补肾阳", "增强免疫"]),

        "冬至": SolarTerm(name: "冬至", date: Date(), description: "白昼最短，一阳来复",
            dietRecommendations: ["温补为主", "多吃饺子"],
            lifestyleRecommendations: ["静养为主"],
            exerciseRecommendations: ["太极", "八段锦"],
            seasonalFoods: ["饺子", "羊肉", "桂圆", "红枣"],
            healthTips: ["养阳护阴", "节欲保精"]),
    ]
}
