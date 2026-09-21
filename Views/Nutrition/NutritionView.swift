import SwiftUI
import SwiftData
import PhotosUI

struct NutritionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealRecord.date, order: .reverse) private var mealRecords: [MealRecord]
    @Query private var allFoodItems: [FoodItem]
    @Query private var userProfiles: [UserProfile]

    @State private var showingAddMeal = false
    @State private var showingFoodLibrary = false
    @State private var showingSupplementDetail = false

    // 目标值：先用 Constants 的通用推荐值占位，onAppear 起按用户档案重算
    @State private var calorieGoal: Double = Constants.defaultCalorieGoal
    @State private var proteinGoal: Double = Constants.defaultProteinGoal
    @State private var fatGoal: Double = Constants.defaultFatGoal
    @State private var carbsGoal: Double = Constants.defaultCarbsGoal

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 热量概览
                calorieOverview

                // 今日餐食
                todaysMeals

                // 周期饮食建议（左对齐）
                cycleDietAdvice

                // 今日补剂简览
                supplementPreview
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("饮食管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddMeal = true }) {
                        Label("记录餐食", systemImage: "fork.knife")
                    }
                    Button(action: { showingFoodLibrary = true }) {
                        Label("食材库", systemImage: "books.vertical")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMeal) { AddMealView(foodItems: allFoodItems) }
        .sheet(isPresented: $showingFoodLibrary) { FoodLibraryView() }
        .sheet(isPresented: $showingSupplementDetail) { SupplementDetailView() }
        .onAppear { calculateGoals() }
    }

    // MARK: - 热量概览
    private var calorieOverview: some View {
        let todayMeals = mealRecords.filter { $0.date.isSameDay(as: Date()) }
        let consumedCalories = todayMeals.reduce(0) { $0 + $1.totalCalories }
        let breakfastCals = todayMeals.filter({ $0.mealType == .breakfast }).reduce(0) { $0 + $1.totalCalories }
        let lunchCals = todayMeals.filter({ $0.mealType == .lunch }).reduce(0) { $0 + $1.totalCalories }
        let dinnerCals = todayMeals.filter({ $0.mealType == .dinner }).reduce(0) { $0 + $1.totalCalories }
        let snackCals = todayMeals.filter({ $0.mealType == .snack }).reduce(0) { $0 + $1.totalCalories }

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("今日热量").font(.headline)
                    Text("\(Int(consumedCalories))/\(Int(calorieGoal)) kcal")
                        .font(.title2).fontWeight(.bold).foregroundColor(Color(hex: "#FF5722"))
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 8).frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: min(consumedCalories / max(calorieGoal, 1), 1.0))
                        .stroke(Color(hex: "#FF5722"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70).rotationEffect(.degrees(-90))
                    Text("\(Int(min(consumedCalories / max(calorieGoal, 1), 1.0) * 100))%")
                        .font(.caption2).fontWeight(.bold)
                }
            }

            // 一日三餐
            HStack(spacing: 8) {
                MealMini(label: "早餐", cals: Int(breakfastCals), color: Color(hex: "#FF9800"))
                MealMini(label: "午餐", cals: Int(lunchCals), color: Color(hex: "#F44336"))
                MealMini(label: "晚餐", cals: Int(dinnerCals), color: Color(hex: "#9C27B0"))
                MealMini(label: "加餐", cals: Int(snackCals), color: Color(hex: "#4CAF50"))
            }

            HStack(spacing: 12) {
                MacroBar(label: "蛋白质", value: todayMeals.reduce(0){$0+$1.totalProtein}, target: proteinGoal, color: Color(hex: "#4CAF50"))
                MacroBar(label: "脂肪", value: todayMeals.reduce(0){$0+$1.totalFat}, target: fatGoal, color: Color(hex: "#FF9800"))
                MacroBar(label: "碳水", value: todayMeals.reduce(0){$0+$1.totalCarbs}, target: carbsGoal, color: Color(hex: "#2196F3"))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 今日餐食
    private var todaysMeals: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("今日餐食", systemImage: "clock").font(.headline)

            let todayRecord = mealRecords.filter { $0.date.isSameDay(as: Date()) }
            if todayRecord.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle").font(.system(size: 36)).foregroundColor(.secondary)
                        Text("还没有记录今天饮食").font(.subheadline).foregroundColor(.secondary)
                        Button(action: { showingAddMeal = true }) {
                            Text("记录第一餐").font(.subheadline).foregroundColor(.white)
                                .padding(.horizontal, 20).padding(.vertical, 8)
                                .background(Color(hex: "#FF9800")).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Spacer()
                }.padding(.vertical, 16)
            } else {
                ForEach(MealType.allCases, id: \.self) { type in
                    let meals = todayRecord.filter { $0.mealType == type }
                    if !meals.isEmpty {
                        ForEach(meals) { meal in
                            ForEach(meal.foods, id: \.self) { food in
                                HStack {
                                    Text(food.foodName).font(.caption)
                                    Spacer()
                                    Text("\(Int(food.amountInGrams))g · \(Int(food.calories))kcal")
                                        .font(.caption2).foregroundColor(.secondary)
                                }.padding(.leading, 12).padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 周期饮食建议（左对齐）
    private var cycleDietAdvice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(appState.currentCyclePhase.description)饮食建议", systemImage: "leaf.fill").font(.headline)
            HStack(alignment: .top, spacing: 6) {
                Text("✅").font(.caption)
                Text(phaseDietAdvice).font(.caption).foregroundColor(.secondary).lineSpacing(3)
            }
            HStack(alignment: .top, spacing: 6) {
                Text("⚠️").font(.caption)
                Text(phaseDietWarning).font(.caption).foregroundColor(.secondary).lineSpacing(3)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 补剂预览
    private var supplementPreview: some View {
        Button(action: { showingSupplementDetail = true }) {
            HStack {
                Label("今日补剂", systemImage: "pills.fill").font(.headline).foregroundColor(.primary)
                Spacer()
                Text("查看详情")
                    .font(.caption).foregroundColor(.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        }
    }

    /// 按用户档案重算热量与三大宏量目标。
    ///
    /// 此前只算了热量，宏量目标在视图里写死为 60/50/200，
    /// 既不随目标（减脂/增肌）变化，也与 NutritionCalculator 的配比结果对不上。
    private func calculateGoals() {
        let profile = userProfiles.first
        let bmrVal = NutritionCalculator.bmr(
            weightKg: profile?.weight ?? 50,
            heightCm: profile?.height ?? 160,
            age: profile?.age ?? 25
        )
        let tdeeVal = NutritionCalculator.tdee(
            bmr: bmrVal,
            activityLevel: profile?.activityLevel ?? .moderatelyActive
        )
        let goal = profile?.goals.first ?? .maintain

        calorieGoal = NutritionCalculator.dailyCalorieTarget(tdee: tdeeVal, goal: goal)
        proteinGoal = NutritionCalculator.dailyProtein(targetCalories: calorieGoal, goal: goal)
        fatGoal = NutritionCalculator.dailyFat(targetCalories: calorieGoal, goal: goal)
        carbsGoal = NutritionCalculator.dailyCarbs(targetCalories: calorieGoal, goal: goal)
    }

    private var phaseDietAdvice: String {
        switch appState.currentCyclePhase {
        case .menstrual: return "补充铁质：多吃红肉、菠菜、红枣。维生素C帮助铁吸收。"
        case .follicular: return "增加蛋白质摄入，多吃新鲜蔬果，为排卵期做准备。"
        case .ovulatory: return "多摄入抗氧化食物：蓝莓、坚果、深色蔬菜。"
        case .luteal: return "补充镁和B6：坚果、香蕉、深绿蔬菜。适当增加碳水。"
        }
    }

    private var phaseDietWarning: String {
        switch appState.currentCyclePhase {
        case .menstrual: return "避免生冷食物和冰饮，减少咖啡因摄入。"
        case .follicular: return "减少精制糖和加工食品。"
        case .ovulatory: return "控制盐分摄入，防水肿。"
        case .luteal: return "控制甜食欲望，避免暴饮暴食。减少盐分。"
        }
    }
}

// MARK: - 小部件
struct MealMini: View {
    let label: String; let cals: Int; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text("\(cals)").font(.caption).fontWeight(.bold).foregroundColor(color)
        }.frame(maxWidth: .infinity).padding(6).background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
    }
}

// MARK: - 添加餐食
struct AddMealView: View {
    let foodItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var mealType: MealType = .breakfast
    @State private var date = Date()
    @State private var selectedFoods: [(FoodItem, Double)] = [] // (food, grams)
    @State private var showingManualInput = false
    @State private var showingPhotoInput = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?

    var body: some View {
        NavigationView {
            Form {
                Section("餐食类型") {
                    Picker("类型", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
                    }
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }

                Section("食材") {
                    if selectedFoods.isEmpty {
                        Text("还未选择食材").foregroundColor(.secondary)
                    } else {
                        ForEach(selectedFoods.indices, id: \.self) { i in
                            HStack {
                                Text(selectedFoods[i].0.name)
                                Spacer()
                                Text("\(Int(selectedFoods[i].1))g")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    NavigationLink("从食材库选择") {
                        FoodPickerView(foodItems: foodItems) { food, grams in
                            selectedFoods.append((food, grams))
                        }
                    }

                    Button("手动输入") { showingManualInput = true }
                    Button("拍照识别") { showingPhotoInput = true }
                }

                if !selectedFoods.isEmpty {
                    let totalCals = selectedFoods.reduce(0) { $0 + $1.0.caloriesPer100g * $1.1 / 100 }
                    Section("预估热量") {
                        Text("约 \(Int(totalCals)) kcal").font(.headline).foregroundColor(Color(hex: "#FF5722"))
                    }
                }
            }
            .navigationTitle("记录餐食")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveMeal() }.disabled(selectedFoods.isEmpty)
                }
            }
            .sheet(isPresented: $showingManualInput) {
                ManualFoodInputView { food in addManualFood(food) }
            }
        }
    }

    /// 手动录入的食物必须落库，否则下次记录还要重新输入。
    /// 同名时复用已有条目，避免食材库里出现一堆重名项。
    private func addManualFood(_ food: FoodItem) {
        if let existing = foodItems.first(where: { $0.name == food.name }) {
            selectedFoods.append((existing, 100))
            return
        }
        modelContext.insert(food)
        try? modelContext.save()
        selectedFoods.append((food, 100))
    }

    private func saveMeal() {
        let entries: [FoodEntry] = selectedFoods.map { food, grams in
            let ratio = grams / 100
            return FoodEntry(foodItemID: food.id, foodName: food.name, amountInGrams: grams,
                             calories: food.caloriesPer100g * ratio, protein: food.protein * ratio,
                             fat: food.fat * ratio, carbs: food.carbs * ratio)
        }
        let meal = MealRecord(date: date, mealType: mealType, foods: entries)
        modelContext.insert(meal)
        try? modelContext.save()
        dismiss()
    }
}

struct FoodPickerView: View {
    let foodItems: [FoodItem]
    let onSelect: (FoodItem, Double) -> Void
    @State private var searchText = ""
    @State private var grams: Double = 100

    var body: some View {
        List {
            HStack { Text("份量: \(Int(grams))g"); Slider(value: $grams, in: 10...500, step: 10) }
            ForEach(filteredFoods) { food in
                Button(action: { onSelect(food, grams) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(food.name).font(.subheadline)
                            Text("\(Int(food.caloriesPer100g))kcal/100g")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(Int(food.caloriesPer100g * grams / 100))kcal")
                            .font(.caption).foregroundColor(Color(hex: "#FF5722"))
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("选择食材")
    }

    private var filteredFoods: [FoodItem] {
        if searchText.isEmpty { return foodItems }
        return foodItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

struct ManualFoodInputView: View {
    let onAdd: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var fat: Double = 0
    @State private var carbs: Double = 0

    var body: some View {
        NavigationView {
            Form {
                TextField("食物名称", text: $name)
                HStack { Text("热量(kcal/100g)"); TextField("", value: $calories, format: .number).keyboardType(.decimalPad) }
                HStack { Text("蛋白质(g/100g)"); TextField("", value: $protein, format: .number).keyboardType(.decimalPad) }
                HStack { Text("脂肪(g/100g)"); TextField("", value: $fat, format: .number).keyboardType(.decimalPad) }
                HStack { Text("碳水(g/100g)"); TextField("", value: $carbs, format: .number).keyboardType(.decimalPad) }
            }
            .navigationTitle("手动输入")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let food = FoodItem(name: name, caloriesPer100g: calories, protein: protein, fat: fat, carbs: carbs, isCustom: true)
                        onAdd(food)
                        dismiss()
                    }.disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - 食材库
struct FoodLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allFoods: [FoodItem]
    @State private var showingAddFood = false

    var body: some View {
        List {
            ForEach(allFoods) { food in
                HStack {
                    VStack(alignment: .leading) {
                        Text(food.name).font(.subheadline)
                        Text("\(Int(food.caloriesPer100g))kcal | P:\(String(format: "%.1f", food.protein)) F:\(String(format: "%.1f", food.fat)) C:\(String(format: "%.1f", food.carbs))")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    if food.isCustom {
                        Button(action: { modelContext.delete(food); try? modelContext.save() }) {
                            Image(systemName: "trash").foregroundColor(.red).font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("食材库")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddFood = true }) { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddFood) {
            ManualFoodInputView { food in
                modelContext.insert(food)
                try? modelContext.save()
            }
        }
    }
}

// MARK: - 组件
struct MacroBar: View {
    let label: String; let value: Double; let target: Double; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))/\(Int(target))g").font(.caption2).foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(.systemGray5)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: geo.size.width * min(value / max(target, 1), 1), height: 4)
                }
            }.frame(height: 4)
        }
    }
}

// MARK: - 补剂详情
struct SupplementDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \SupplementRecord.date, order: .reverse) private var supplementRecords: [SupplementRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var hkMeds: [String] = []

    var body: some View {
        List {
            Section("HealthKit 用药数据") {
                if hkMeds.isEmpty { Text("无同步数据").foregroundColor(.secondary).font(.caption) }
                else { ForEach(hkMeds, id: \.self) { med in Text(med).font(.subheadline) } }
            }

            Section("手动记录") {
                ForEach(supplementRecords.prefix(10)) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.supplementName).font(.subheadline)
                            Text("\(record.dosage) · \(record.timeOfDay.rawValue)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: record.isTaken ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(record.isTaken ? Color(hex: "#4CAF50") : .gray)
                    }
                }
            }
        }
        .navigationTitle("补剂管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAdd = true }) { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddSupplementView()
        }
        .onAppear {
            Task {
                let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                hkMeds = (try? await HealthKitService.shared.fetchMedications(from: oneMonthAgo, to: Date())) ?? []
            }
        }
    }
}

struct AddSupplementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var quantity: Double = 1
    @State private var timeOfDay: TimeOfDay = .morning

    var body: some View {
        NavigationView {
            Form {
                TextField("补剂名称", text: $name)
                TextField("剂量(如500mg)", text: $dosage)
                HStack { Text("数量"); Stepper("\(Int(quantity))", value: $quantity, in: 1...10) }
                Picker("时间", selection: $timeOfDay) {
                    ForEach(TimeOfDay.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
                }
            }
            .navigationTitle("添加补剂")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let record = SupplementRecord(supplementName: name, dosage: dosage, quantity: quantity, timeOfDay: timeOfDay, isTaken: false)
                        modelContext.insert(record); try? modelContext.save(); dismiss()
                    }.disabled(name.isEmpty)
                }
            }
        }
    }
}
