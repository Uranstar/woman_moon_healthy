import SwiftUI
import SwiftData

struct CycleTrackerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CycleRecord.startDate, order: .reverse) private var cycleRecords: [CycleRecord]
    @Query private var userProfiles: [UserProfile]

    @State private var showingRecordSheet = false
    @State private var selectedDate: Date?
    @State private var showingDayDetail = false
    @State private var currentMonth = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 经期日历
                cycleCalendarView

                // 周期概览
                cycleSummaryCard

                // 最近记录
                recentRecordsSection
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingRecordSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingRecordSheet) {
            RecordCycleView()
        }
        .sheet(isPresented: $showingDayDetail) {
            if let date = selectedDate {
                DayDetailView(date: date)
            }
        }
    }

    // MARK: - 经期日历
    private var cycleCalendarView: some View {
        let profile = userProfiles.first

        return VStack(alignment: .leading, spacing: 12) {
            // 月份导航
            HStack {
                Button(action: { changeMonth(-1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(currentMonth, format: .dateTime.year().month(.wide))
                    .font(.headline)
                Spacer()
                Button(action: { changeMonth(1) }) {
                    Image(systemName: "chevron.right")
                }
            }

            // 星期标题
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(["一","二","三","四","五","六","日"], id: \.self) { d in
                    Text(d).font(.caption2).foregroundColor(.secondary)
                }

                ForEach(monthDays, id: \.self) { date in
                    if let date = date {
                        let phase = phaseForDay(date, profile: profile)
                        let isPeriod = isPeriodDay(date)
                        let isPredicted = isPredictedDay(date)
                        let isToday = date.isSameDay(as: Date())

                        Button(action: {
                            selectedDate = date
                            showingDayDetail = true
                        }) {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption)
                                .fontWeight(isToday ? .bold : .regular)
                                .frame(height: 32)
                                .background(
                                    Circle()
                                        .fill(phaseColor(phase, isPeriod: isPeriod, isPredicted: isPredicted))
                                        .frame(width: 30, height: 30)
                                )
                                .foregroundColor(isPeriod || phase != nil ? .white :
                                                  isToday ? Color(hex: "#E91E63") : .primary)
                        }
                    } else {
                        Text("").frame(height: 32)
                    }
                }
            }

            // 图例
            HStack(spacing: 12) {
                LegendDot(color: Color(hex: "#E74C3C"), text: "经期")
                LegendDot(color: Color(hex: "#E74C3C").opacity(0.3), text: "预测")
                LegendDot(color: Color(hex: "#2ECC71"), text: "卵泡期")
                LegendDot(color: Color(hex: "#F39C12"), text: "排卵期")
                LegendDot(color: Color(hex: "#9B59B6"), text: "黄体期")
            }
            .font(.caption2)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 周期概览卡片
    private var cycleSummaryCard: some View {
        let service = CycleService()
        let profile = userProfiles.first
        let realRecords = cycleRecords.filter { !$0.isPredicted }
        let avgCycle = service.averageCycleLength(from: realRecords)
        let avgPeriod = service.averagePeriodLength(from: realRecords)
        let effectiveStart = service.effectiveCycleStartDate(records: realRecords, profile: profile ?? UserProfile())
        let dayOfCycle = effectiveStart.map { CycleCalculator.dayOfCycle(from: $0) }
        let cycleLen = avgCycle ?? profile?.cycleLength ?? 28
        let currentPhase: CyclePhase? = effectiveStart.map {
            CycleCalculator.currentPhase(from: $0, cycleLength: cycleLen, periodLength: avgPeriod ?? profile?.periodLength ?? 5)
        }

        // 下次预测：优先取预测记录，否则计算
        let nextPredictedDate: Date? = {
            if let nextPred = cycleRecords.filter({ $0.isPredicted }).min(by: { $0.startDate < $1.startDate }),
               nextPred.startDate > Date() {
                return nextPred.startDate
            }
            guard let start = effectiveStart else { return nil }
            return CycleCalculator.predictNextCycleStart(from: start, cycleLength: cycleLen)
        }()

        // 受孕窗口
        let fertility: (start: Date, end: Date)? = {
            guard let start = effectiveStart else { return nil }
            return CycleCalculator.fertilityWindow(from: start, cycleLength: cycleLen)
        }()

        return VStack(alignment: .leading, spacing: 12) {
            Label("周期概览", systemImage: "chart.bar.fill").font(.headline)

            // 关键指标行
            HStack(spacing: 0) {
                SummaryMetric(
                    title: "平均周期",
                    value: avgCycle.map { "\($0)天" } ?? "--",
                    icon: "arrow.triangle.2.circlepath",
                    color: Color(hex: "#9C27B0")
                )
                Divider().frame(height: 40)
                SummaryMetric(
                    title: "平均经期",
                    value: avgPeriod.map { "\($0)天" } ?? "--",
                    icon: "drop.fill",
                    color: Color(hex: "#E74C3C")
                )
                Divider().frame(height: 40)
                SummaryMetric(
                    title: "当前天数",
                    value: dayOfCycle.map { "第\($0)天" } ?? "--",
                    icon: "calendar",
                    color: Color(hex: "#E91E63")
                )
            }

            Divider()

            // 详情行
            VStack(alignment: .leading, spacing: 6) {
                if let phase = currentPhase {
                    HStack {
                        Text("当前阶段：")
                            .font(.subheadline).foregroundColor(.secondary)
                        Text(phase.description)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(Color(hex: phase.color))
                    }
                }
                if let nextDate = nextPredictedDate {
                    HStack {
                        Text("下次预计：")
                            .font(.subheadline).foregroundColor(.secondary)
                        Text(nextDate.shortChineseFormatted)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(Color(hex: "#E74C3C"))
                    }
                }
                if let f = fertility {
                    HStack {
                        Text("受孕窗口：")
                            .font(.subheadline).foregroundColor(.secondary)
                        Text("\(f.start.shortChineseFormatted) - \(f.end.shortChineseFormatted)")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(Color(hex: "#F39C12"))
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - 最近记录
    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最近记录", systemImage: "list.bullet.clipboard").font(.headline)

            let realRecords = cycleRecords.filter { !$0.isPredicted }
            if realRecords.isEmpty {
                Text("还没有记录，点击右上角 + 添加")
                    .font(.subheadline).foregroundColor(.secondary).padding()
            } else {
                ForEach(realRecords.prefix(5)) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.startDate.shortChineseFormatted)
                                .font(.subheadline).fontWeight(.medium)
                            if let end = record.endDate {
                                Text("至 \(end.shortChineseFormatted)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            if !record.symptoms.isEmpty {
                                Text(record.symptoms.map(\.rawValue).joined(separator: " · "))
                                    .font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                        Spacer()
                        Text(["","极少","少","中","多","极多"][record.flowIntensity])
                            .font(.caption).foregroundColor(Color(hex: "#E91E63"))
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
    }

    // MARK: - Helpers

    /// 计算该日期的周期阶段
    private func phaseForDay(_ date: Date, profile: UserProfile?) -> CyclePhase? {
        guard let startDate = profile?.lastCycleStartDate,
              let cycleLen = profile?.cycleLength,
              let periodLen = profile?.periodLength else { return nil }

        let day = CycleCalculator.dayOfCycle(from: startDate, to: date)
        let normalizedDay = ((day - 1) % cycleLen) + 1

        switch normalizedDay {
        case 1...periodLen: return .menstrual
        case (periodLen + 1)...(cycleLen - (profile?.lutealLength ?? 14) - 1): return .follicular
        case (cycleLen - (profile?.lutealLength ?? 14))...(cycleLen - (profile?.lutealLength ?? 14) + 2): return .ovulatory
        default: return .luteal
        }
    }

    private func phaseColor(_ phase: CyclePhase?, isPeriod: Bool, isPredicted: Bool = false) -> Color {
        if isPredicted { return Color(hex: "#E74C3C").opacity(0.3) }
        if isPeriod { return Color(hex: "#E74C3C").opacity(0.8) }
        guard let phase = phase else { return .clear }
        switch phase {
        case .menstrual: return Color(hex: "#E74C3C").opacity(0.6)
        case .follicular: return Color(hex: "#2ECC71").opacity(0.6)
        case .ovulatory: return Color(hex: "#F39C12").opacity(0.7)
        case .luteal: return Color(hex: "#9B59B6").opacity(0.6)
        }
    }

    private func isPeriodDay(_ date: Date) -> Bool {
        cycleRecords.contains { record in
            guard !record.isPredicted, let end = record.endDate else { return false }
            return date >= record.startDate && date <= end
        }
    }

    private func isPredictedDay(_ date: Date) -> Bool {
        cycleRecords.contains { record in
            guard record.isPredicted, let end = record.endDate else { return false }
            return date >= record.startDate && date <= end
        }
    }

    private var monthDays: [Date?] {
        let cal = Calendar.current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth))!
        let weekday = cal.component(.weekday, from: startOfMonth)
        let offset = (weekday + 5) % 7

        let range = cal.range(of: .day, in: .month, for: currentMonth)!
        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            days.append(cal.date(byAdding: .day, value: day - 1, to: startOfMonth)!)
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func changeMonth(_ by: Int) {
        if let new = Calendar.current.date(byAdding: .month, value: by, to: currentMonth) {
            currentMonth = new
        }
    }
}

// MARK: - 概览指标组件
struct SummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(value).font(.subheadline).fontWeight(.bold)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 日期详情弹窗
struct DayDetailView: View {
    let date: Date
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \CycleRecord.startDate, order: .reverse) private var cycleRecords: [CycleRecord]
    @Query(sort: \CycleEvent.date, order: .reverse) private var cycleEvents: [CycleEvent]

    @State private var selectedSymptoms: Set<Symptom> = []
    @State private var flowLevel: Int = 0  // 0=无, 1=少, 2=中, 3=多
    @State private var notes: String = ""

    // 排卵迹象
    @State private var mucusType: String = ""
    @State private var ovulationTestResult: String = ""
    @State private var bbtReading: String = ""

    private let flowLabels = ["无", "少", "中等", "量多"]

    var body: some View {
        let profile = userProfiles.first
        let dayOfCycle = profile?.lastCycleStartDate.map { CycleCalculator.dayOfCycle(from: $0, to: date) }
        let phase = cyclePhaseForDate(profile: profile)

        return NavigationView {
            Form {
                Section("\(date.chineseFormatted)") {
                    HStack {
                        Text("阶段")
                        Spacer()
                        Text(phase?.description ?? "未知")
                            .foregroundColor(phaseColor(phase))
                            .fontWeight(.bold)
                    }
                    if let day = dayOfCycle {
                        HStack {
                            Text("周期天数")
                            Spacer()
                            Text("第 \(day) 天").foregroundColor(.secondary)
                        }
                    }
                }

                Section("流血量") {
                    Picker("流血量", selection: $flowLevel) {
                        ForEach(0..<flowLabels.count, id: \.self) { i in
                            Text(flowLabels[i]).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("症状") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Symptom.allCases, id: \.self) { symptom in
                            Button(action: {
                                if selectedSymptoms.contains(symptom) {
                                    selectedSymptoms.remove(symptom)
                                } else {
                                    selectedSymptoms.insert(symptom)
                                }
                            }) {
                                Text(symptom.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedSymptoms.contains(symptom) ?
                                                  Color(hex: "#E91E63").opacity(0.2) : Color(.systemGray6))
                                    )
                                    .foregroundColor(selectedSymptoms.contains(symptom) ?
                                                    Color(hex: "#E91E63") : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // MARK: 排卵迹象
                Section("排卵迹象") {
                    Picker("宫颈粘液", selection: $mucusType) {
                        Text("未记录").tag("")
                        ForEach(CervicalMucusType.allCases, id: \.rawValue) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }

                    Picker("排卵测试", selection: $ovulationTestResult) {
                        Text("未记录").tag("")
                        ForEach(OvulationTestResult.allCases, id: \.rawValue) { result in
                            HStack {
                                Circle().fill(Color(hex: result.color)).frame(width: 8, height: 8)
                                Text(result.rawValue)
                            }.tag(result.rawValue)
                        }
                    }

                    HStack {
                        Text("基础体温")
                        Spacer()
                        TextField("36.5", text: $bbtReading)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("°C")
                            .foregroundColor(.secondary)
                    }
                }

                Section("备注") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
            }
            .navigationTitle("当日详情")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { saveDayDetail() } }
            }
            .onAppear(perform: loadExistingData)
        }
    }

    private func cyclePhaseForDate(profile: UserProfile?) -> CyclePhase? {
        guard let startDate = profile?.lastCycleStartDate else { return nil }
        let cycleLen = profile?.cycleLength ?? 28
        let periodLen = profile?.periodLength ?? 5
        let lutealLen = profile?.lutealLength ?? 14
        let day = CycleCalculator.dayOfCycle(from: startDate, to: date)
        let normalized = ((day - 1) % cycleLen) + 1
        switch normalized {
        case 1...periodLen: return .menstrual
        case (periodLen + 1)...(cycleLen - lutealLen - 1): return .follicular
        case (cycleLen - lutealLen)...(cycleLen - lutealLen + 2): return .ovulatory
        default: return .luteal
        }
    }

    private func phaseColor(_ phase: CyclePhase?) -> Color {
        guard let p = phase else { return .secondary }
        switch p {
        case .menstrual: return Color(hex: "#E74C3C")
        case .follicular: return Color(hex: "#2ECC71")
        case .ovulatory: return Color(hex: "#F39C12")
        case .luteal: return Color(hex: "#9B59B6")
        }
    }

    private func loadExistingData() {
        // 加载经期数据
        if let existing = cycleRecords.first(where: { $0.startDate.isSameDay(as: date) && !$0.isPredicted }) {
            selectedSymptoms = Set(existing.symptoms)
            flowLevel = existing.flowIntensity
            notes = existing.notes
        } else {
            selectedSymptoms = []
            flowLevel = 0
            notes = ""
        }

        // 加载排卵迹象
        let service = CycleService()
        let todayEvents = service.eventsForDate(date, in: cycleEvents)
        mucusType = todayEvents.first(where: { $0.type == .cervicalMucus })?.value ?? ""
        ovulationTestResult = todayEvents.first(where: { $0.type == .ovulationTest })?.value ?? ""
        bbtReading = todayEvents.first(where: { $0.type == .bbt })?.value ?? ""
    }

    private func saveDayDetail() {
        guard let profile = userProfiles.first else { return }
        let service = CycleService()

        // 保存经期数据
        service.saveDayDetail(
            date: date,
            symptoms: Array(selectedSymptoms),
            flowIntensity: flowLevel,
            notes: notes,
            modelContext: modelContext,
            profile: profile
        )

        // 保存排卵迹象
        if !mucusType.isEmpty {
            service.saveCycleEvent(date: date, type: .cervicalMucus, value: mucusType, notes: "", modelContext: modelContext)
        }
        if !ovulationTestResult.isEmpty {
            service.saveCycleEvent(date: date, type: .ovulationTest, value: ovulationTestResult, notes: "", modelContext: modelContext)
        }
        if !bbtReading.isEmpty {
            service.saveCycleEvent(date: date, type: .bbt, value: bbtReading, notes: "", modelContext: modelContext)
        }

        dismiss()
    }
}

// MARK: - 组件
struct LegendDot: View {
    let color: Color; let text: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

// MARK: - 记录经期
struct RecordCycleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var userProfiles: [UserProfile]

    @State private var startDate = Date()
    @State private var isRange = false
    @State private var endDate = Date()
    @State private var flowIntensity: Double = 3
    @State private var selectedSymptoms: Set<Symptom> = []
    @State private var notes = ""

    var body: some View {
        NavigationView {
            Form {
                Section("日期") {
                    Toggle("记录时间段", isOn: $isRange)
                    DatePicker("日期", selection: $startDate, displayedComponents: .date)
                    if isRange {
                        DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section("经量") {
                    Picker("", selection: $flowIntensity) {
                        Text("极少").tag(1.0); Text("少").tag(2.0); Text("中").tag(3.0)
                        Text("多").tag(4.0); Text("极多").tag(5.0)
                    }.pickerStyle(.segmented)
                }

                Section("症状") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Symptom.allCases, id: \.self) { symptom in
                            Button(action: {
                                if selectedSymptoms.contains(symptom) {
                                    selectedSymptoms.remove(symptom)
                                } else {
                                    selectedSymptoms.insert(symptom)
                                }
                            }) {
                                Text(symptom.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 6).padding(.vertical, 5)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedSymptoms.contains(symptom) ?
                                                  Color(hex: "#E91E63").opacity(0.2) : Color(.systemGray6))
                                    )
                                    .foregroundColor(selectedSymptoms.contains(symptom) ?
                                                    Color(hex: "#E91E63") : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("备注") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
            }
            .navigationTitle("记录经期")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { saveRecord() } }
            }
        }
    }

    private func saveRecord() {
        guard let profile = userProfiles.first else { return }
        let service = CycleService()
        service.recordPeriod(
            startDate: startDate,
            endDate: isRange ? endDate : nil,
            symptoms: Array(selectedSymptoms),
            flowIntensity: Int(flowIntensity),
            notes: notes,
            modelContext: modelContext,
            profile: profile
        )
        dismiss()
    }
}
