import Foundation

/// 24 节气数据引擎
struct SeasonalTerms {
    /// 获取指定日期的节气（如果是节气日）
    static func termFor(date: Date) -> String {
        let year = Calendar.current.component(.year, from: date)
        let terms = termsForYear(year)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let dateString = formatter.string(from: date)
        return terms.first { termDateString, _ in
            termDateString == dateString
        }?.1 ?? ""
    }

    /// 获取指定年份的所有节气日期和名称
    static func termsForYear(_ year: Int) -> [(String, String)] {
        // 2026 年 24 节气近似日期 (实际每年有1-2天浮动)
        // 格式: (日期, 节气名)
        [
            ("2026-01-05", "小寒"), ("2026-01-20", "大寒"),
            ("2026-02-04", "立春"), ("2026-02-19", "雨水"),
            ("2026-03-05", "惊蛰"), ("2026-03-20", "春分"),
            ("2026-04-05", "清明"), ("2026-04-20", "谷雨"),
            ("2026-05-05", "立夏"), ("2026-05-21", "小满"),
            ("2026-06-05", "芒种"), ("2026-06-21", "夏至"),
            ("2026-07-07", "小暑"), ("2026-07-22", "大暑"),
            ("2026-08-07", "立秋"), ("2026-08-23", "处暑"),
            ("2026-09-07", "白露"), ("2026-09-23", "秋分"),
            ("2026-10-08", "寒露"), ("2026-10-23", "霜降"),
            ("2026-11-07", "立冬"), ("2026-11-22", "小雪"),
            ("2026-12-07", "大雪"), ("2026-12-22", "冬至"),
            // 2027
            ("2027-01-05", "小寒"), ("2027-01-20", "大寒"),
        ]
    }

    /// 获取节气详细信息
    static func detail(for termName: String) -> SolarTerm? {
        termDatabase[termName]
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
