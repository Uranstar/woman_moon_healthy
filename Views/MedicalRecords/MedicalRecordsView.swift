import SwiftUI
import SwiftData

struct MedicalRecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MedicalRecord.date, order: .reverse) private var medicalRecords: [MedicalRecord]

    @State private var showingAddRecord = false
    @State private var selectedCategory: MedicalCategory?
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 快速操作
                quickActions

                // 按类别筛选
                categoryFilter

                // 病例列表
                recordsList
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("病例管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddRecord = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            AddMedicalRecordView()
        }
    }

    // MARK: - 快速操作
    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionCard(
                icon: "camera.fill",
                title: "拍照导入",
                color: Color(hex: "#2196F3"),
                action: { showingAddRecord = true }
            )
            QuickActionCard(
                icon: "doc.text.fill",
                title: "手动录入",
                color: Color(hex: "#4CAF50"),
                action: { showingAddRecord = true }
            )
            QuickActionCard(
                icon: "brain.head.profile",
                title: "AI 分析",
                color: Color(hex: "#9C27B0"),
                action: {}
            )
        }
    }

    // MARK: - 类别筛选
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(name: "全部", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(MedicalCategory.allCases, id: \.self) { category in
                    CategoryChip(name: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    // MARK: - 病例列表
    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("病例记录", systemImage: "list.clipboard")
                .font(.headline)

            let filtered = medicalRecords.filter { record in
                let categoryMatch = selectedCategory == nil || record.category == selectedCategory
                let searchMatch = searchText.isEmpty ||
                    record.title.localizedCaseInsensitiveContains(searchText)
                return categoryMatch && searchMatch
            }

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.full")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("还没有病例记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(filtered) { record in
                    MedicalRecordCard(record: record)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
        )
    }
}

// MARK: - 辅助组件
struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(height: 28)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.03), radius: 4)
            )
        }
    }
}

struct CategoryChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "#E91E63") : Color(.systemGray6))
                )
                .foregroundColor(isSelected ? .white : .secondary)
        }
    }
}

struct MedicalRecordCard: View {
    let record: MedicalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(record.category.rawValue)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#E91E63"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#FCE4EC"))
                    )

                Spacer()

                Text(record.date.shortChineseFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(record.title)
                .font(.subheadline)
                .fontWeight(.medium)

            if let diagnosis = record.diagnosis {
                Text("诊断: \(diagnosis)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let analysis = record.aiAnalysis {
                Text(analysis)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if !record.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(record.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#9C27B0"))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - 添加病例
struct AddMedicalRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()
    @State private var category: MedicalCategory = .general
    @State private var hospital = ""
    @State private var doctor = ""
    @State private var diagnosis = ""
    @State private var prescription = ""
    @State private var tags: [String] = []
    @State private var tagInput = ""

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    Picker("类别", selection: $category) {
                        ForEach(MedicalCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section("医疗信息") {
                    TextField("医院", text: $hospital)
                    TextField("医生", text: $doctor)
                    TextField("诊断", text: $diagnosis, axis: .vertical)
                    TextField("处方", text: $prescription, axis: .vertical)
                }

                Section("标签") {
                    HStack {
                        TextField("添加标签", text: $tagInput)
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hex: "#E91E63"))
                        }
                        .disabled(tagInput.isEmpty)
                    }
                    if !tags.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.caption)
                                        Button(action: { tags.removeAll { $0 == tag } }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6))
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加病例")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    private func saveRecord() {
        let record = MedicalRecord(
            date: date,
            title: title,
            category: category,
            hospital: hospital.isEmpty ? nil : hospital,
            doctor: doctor.isEmpty ? nil : doctor,
            diagnosis: diagnosis.isEmpty ? nil : diagnosis,
            prescription: prescription.isEmpty ? nil : prescription,
            tags: tags
        )
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}
