import SwiftUI
import SwiftData

struct HealthMetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthMetric.date, order: .reverse) private var healthMetrics: [HealthMetric]

    @State private var selectedMetricType: MetricType = .weight
    @State private var showingAddMetric = false
    @State private var timeRange: TimeRange = .month

    enum TimeRange: String, CaseIterable {
        case week = "7天"
        case month = "30天"
        case quarter = "90天"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 数据来源
                dataSourceCard

                // 指标选择
                metricTypePicker

                // 趋势图
                trendChart

                // 最近数据
                recentData

                // 手动录入
                manualEntryButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("健康数据")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddMetric = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMetric) {
            AddMetricView()
        }
        .onAppear(perform: syncHealthKitMetrics)
    }

    // MARK: - HealthKit 同步（仅读取，不弹授权弹窗）
    private func syncHealthKitMetrics() {
        guard HealthKitService.shared.isAuthorized else { return }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        Task {
            guard let metrics = try? await HealthKitService.shared.fetchBodyMass(
                from: thirtyDaysAgo, to: Date()
            ) else { return }

            var saved = false
            for metric in metrics {
                let exists = healthMetrics.contains {
                    $0.type == .weight &&
                    Calendar.current.isDate($0.date, inSameDayAs: metric.date) &&
                    $0.source == .healthKit
                }
                if !exists {
                    modelContext.insert(metric)
                    saved = true
                }
            }
            if saved { try? modelContext.save() }
        }
    }

    // MARK: - 数据来源
    private var dataSourceCard: some View {
        HStack {
            Image(systemName: "apple.logo")
                .font(.title)
                .foregroundColor(.primary)
            VStack(alignment: .leading) {
                Text("Apple Health 同步")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("步数 · 心率 · 睡眠 · 体重")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "#4CAF50"))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 指标选择
    private var metricTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MetricType.allCases, id: \.self) { type in
                    Button(action: { selectedMetricType = type }) {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.title3)
                            Text(type.rawValue)
                                .font(.caption2)
                        }
                        .frame(width: 64)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMetricType == type ?
                                      Color(hex: "#E3F2FD") : Color(.systemGray6))
                        )
                        .foregroundColor(selectedMetricType == type ?
                                        Color(hex: "#2196F3") : .secondary)
                    }
                }
            }
        }
    }

    // MARK: - 趋势图
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(selectedMetricType.rawValue + "趋势", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
                Picker("", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            let metrics = filteredMetrics

            if metrics.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无\(selectedMetricType.rawValue)数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("点击右上角 + 手动录入\n或连接 Apple Health 自动同步")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                // 简化的条形图
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(metrics.prefix(7).enumerated()), id: \.offset) { index, metric in
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", metric.value))
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Rectangle()
                                .fill(Color(hex: "#2196F3"))
                                .frame(width: 24, height: max(CGFloat(metric.value) * 2, 8))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            Text(metric.date, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 160)

                // 统计信息
                HStack {
                    StatBadge(label: "最低", value: String(format: "%.1f", minValue ?? 0), unit: selectedMetricType.defaultUnit)
                    StatBadge(label: "最高", value: String(format: "%.1f", maxValue ?? 0), unit: selectedMetricType.defaultUnit)
                    StatBadge(label: "平均", value: String(format: "%.1f", avgValue ?? 0), unit: selectedMetricType.defaultUnit)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }

    // MARK: - 最近数据
    private var recentData: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最近记录", systemImage: "list.bullet")
                .font(.headline)

            ForEach(healthMetrics.filter { $0.type == selectedMetricType }.prefix(10)) { metric in
                HStack {
                    Text(metric.date.shortChineseFormatted)
                        .font(.subheadline)
                    Spacer()
                    Text("\(String(format: "%.1f", metric.value)) \(metric.unit)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(metric.source.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                        )
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

    // MARK: - 手动录入
    private var manualEntryButton: some View {
        Button(action: { showingAddMetric = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("手动录入数据")
            }
            .font(.subheadline)
            .foregroundColor(Color(hex: "#2196F3"))
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#2196F3"), lineWidth: 1)
            )
        }
    }

    // MARK: - 辅助
    private var filteredMetrics: [HealthMetric] {
        let calendar = Calendar.current
        let cutoffDate: Date
        switch timeRange {
        case .week:
            cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .quarter:
            cutoffDate = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        }

        return healthMetrics
            .filter { $0.type == selectedMetricType && $0.date >= cutoffDate }
            .sorted { $0.date > $1.date }
    }

    private var minValue: Double? {
        filteredMetrics.map(\.value).min()
    }

    private var maxValue: Double? {
        filteredMetrics.map(\.value).max()
    }

    private var avgValue: Double? {
        let values = filteredMetrics.map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - 辅助组件
struct StatBadge: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value) \(unit)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - 添加数据页
struct AddMetricView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var metricType: MetricType = .weight
    @State private var value: Double = 0
    @State private var date = Date()

    var body: some View {
        NavigationView {
            Form {
                Section("指标类型") {
                    Picker("类型", selection: $metricType) {
                        ForEach(MetricType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("数值") {
                    HStack {
                        TextField("请输入", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                        Text(metricType.defaultUnit)
                            .foregroundColor(.secondary)
                    }
                }

                Section("日期") {
                    DatePicker("记录日期", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("录入数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let metric = HealthMetric(
                            date: date,
                            type: metricType,
                            value: value,
                            source: .manual
                        )
                        modelContext.insert(metric)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
