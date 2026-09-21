import Foundation
import HealthKit

/// Apple HealthKit 数据读写服务
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    // MARK: - 需要读取的数据类型
    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        ]
    }

    // MARK: - 需要写入的数据类型
    private var writeTypes: Set<HKSampleType> {
        [
            HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
        ]
    }

    private init() {}

    // MARK: - 请求权限
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        do {
            try await healthStore.requestAuthorization(
                toShare: writeTypes,
                read: readTypes
            )
            isAuthorized = true
        } catch {
            // 保留底层错误，否则无法区分「用户拒绝」与「配置缺失／系统异常」
            throw HealthKitError.authorizationFailed(error)
        }
    }

    // MARK: - 读取经期数据
    func fetchMenstrualCycles(from startDate: Date, to endDate: Date) async throws -> [CycleRecord] {
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                // 将 HKCategorySample 转换为 CycleRecord
                var records: [CycleRecord] = []
                for sample in samples {
                    let record = CycleRecord(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        flowIntensity: sample.value == HKCategoryValueMenstrualFlow.medium.rawValue ? 3 :
                                      sample.value == HKCategoryValueMenstrualFlow.heavy.rawValue ? 4 : 2
                    )
                    records.append(record)
                }
                continuation.resume(returning: records)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - 写入经期数据
    func saveMenstrualFlow(startDate: Date, endDate: Date, flowLevel: HKCategoryValueMenstrualFlow) async throws {
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let sample = HKCategorySample(
            type: type,
            value: flowLevel.rawValue,
            start: startDate,
            end: endDate
        )
        try await healthStore.save(sample)
    }

    // MARK: - 读取体重
    func fetchBodyMass(from startDate: Date, to endDate: Date) async throws -> [HealthMetric] {
        let type = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let metrics = samples.map { sample in
                    let weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    return HealthMetric(
                        date: sample.startDate,
                        type: .weight,
                        value: weightKg,
                        unit: "kg",
                        source: .healthKit
                    )
                }
                continuation.resume(returning: metrics)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - 读取步数
    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Double {
        let type = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - 读取睡眠数据
    func fetchSleepAnalysis(from startDate: Date, to endDate: Date) async throws -> TimeInterval {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var totalSleep: TimeInterval = 0
                for sample in (samples as? [HKCategorySample] ?? []) {
                    if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                        totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }
                continuation.resume(returning: totalSleep)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - 读取 HRV (心率变异性)
    func fetchHRV(from startDate: Date, to endDate: Date) async throws -> Double {
        try await fetchLatestQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            from: startDate, to: endDate
        )
    }

    // MARK: - 读取静息心率
    func fetchRestingHeartRate(from startDate: Date, to endDate: Date) async throws -> Double {
        try await fetchLatestQuantity(
            identifier: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: startDate, to: endDate
        )
    }

    // MARK: - 读取手腕温度
    func fetchWristTemperature(from startDate: Date, to endDate: Date) async throws -> Double? {
        let type = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if error != nil { continuation.resume(returning: nil); return }
                guard let sample = samples?.first as? HKQuantitySample else { continuation.resume(returning: nil); return }
                let temp = sample.quantity.doubleValue(for: .degreeCelsius())
                continuation.resume(returning: temp)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - 读取运动数据
    func fetchActiveEnergy(from startDate: Date, to endDate: Date) async throws -> Double {
        try await fetchCumulativeQuantity(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            from: startDate, to: endDate
        )
    }

    func fetchExerciseMinutes(from startDate: Date, to endDate: Date) async throws -> Double {
        try await fetchCumulativeQuantity(
            identifier: .appleExerciseTime,
            unit: .minute(),
            from: startDate, to: endDate
        )
    }

    // MARK: - 读取用药/补剂数据
    func fetchMedications(from startDate: Date, to endDate: Date) async throws -> [String] {
        var medications: [String] = []
        if #available(iOS 16.0, *) {
            let type = HKObjectType.clinicalType(forIdentifier: .medicationRecord)!
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 50, sortDescriptors: nil) { _, samples, error in
                    if error != nil { continuation.resume(returning: []); return }
                    guard let samples = samples as? [HKClinicalRecord] else { continuation.resume(returning: []); return }
                    for sample in samples {
                        let name = sample.displayName; medications.append(name)
                    }
                    continuation.resume(returning: medications)
                }
                healthStore.execute(query)
            }
        }
        return medications
    }

    // MARK: - 压力估算 (基于HRV和静息心率)
    func estimateStressLevel() async -> (level: String, detail: String, value: Double) {
        let now = Date()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        let hrv = (try? await fetchHRV(from: oneDayAgo, to: now)) ?? 50
        let rhr = (try? await fetchRestingHeartRate(from: oneDayAgo, to: now)) ?? 65

        // HRV 越低 + RHR 越高 = 压力越大
        let stressValue: Double
        if hrv < 30 || rhr > 80 {
            stressValue = 80  // 高压力
        } else if hrv < 45 || rhr > 70 {
            stressValue = 55  // 中等压力
        } else if hrv < 60 || rhr > 60 {
            stressValue = 30  // 轻度压力
        } else {
            stressValue = 15  // 放松
        }

        let level: String
        let detail: String
        switch stressValue {
        case 0..<25: level = "放松"; detail = "HRV \(Int(hrv))ms, 心率 \(Int(rhr))bpm"
        case 25..<45: level = "轻度"; detail = "HRV \(Int(hrv))ms, 心率 \(Int(rhr))bpm"
        case 45..<70: level = "中等"; detail = "HRV \(Int(hrv))ms, 心率 \(Int(rhr))bpm"
        default: level = "较高"; detail = "HRV \(Int(hrv))ms, 心率 \(Int(rhr))bpm"
        }

        return (level, detail, stressValue)
    }

    // MARK: - 通用读取方法
    private func fetchLatestQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double {
        let type = HKObjectType.quantityType(forIdentifier: identifier)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(throwing: HealthKitError.dataNotFound); return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func fetchCumulativeQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double {
        let type = HKObjectType.quantityType(forIdentifier: identifier)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - 错误类型
enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case authorizationFailed(Error)
    case dataNotFound

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "此设备不支持健康数据"
        case .authorizationDenied:
            return "未授权访问健康数据"
        case .authorizationFailed(let underlying):
            return "健康数据授权失败：\(underlying.localizedDescription)"
        case .dataNotFound:
            return "未找到健康数据"
        }
    }
}
