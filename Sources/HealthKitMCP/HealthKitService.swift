import Foundation
import HealthKit

/// Actor responsible for managing HealthKit queries and authorization
actor HealthKitService {
    private let healthStore = HKHealthStore()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Authorization
    
    /// Request authorization for HealthKit data types
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataNotAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis)
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
    
    // MARK: - Steps
    
    /// Get step count for a date range
    func getSteps(startDate: Date, endDate: Date) async throws -> HealthDataSummary {
        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                let summary = HealthDataSummary(
                    type: "steps",
                    startDate: startDate,
                    endDate: endDate,
                    value: steps,
                    unit: "steps"
                )
                continuation.resume(returning: summary)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Heart Rate
    
    /// Get heart rate samples for a date range
    func getHeartRate(startDate: Date, endDate: Date) async throws -> [HeartRateSample] {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let heartRateSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HeartRateSample(
                        date: sample.startDate,
                        value: sample.quantity.doubleValue(for: HKUnit(from: "count/min")),
                        unit: "bpm"
                    )
                } ?? []
                
                continuation.resume(returning: heartRateSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep
    
    /// Get sleep analysis for a date range
    func getSleep(startDate: Date, endDate: Date) async throws -> [SleepSample] {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let sleepSamples = (samples as? [HKCategorySample])?.map { sample in
                    let value = sample.value
                    let sleepState: String
                    
                    if #available(macOS 14.0, *) {
                        switch HKCategoryValueSleepAnalysis(rawValue: value) {
                        case .asleepCore:
                            sleepState = "Core Sleep"
                        case .asleepDeep:
                            sleepState = "Deep Sleep"
                        case .asleepREM:
                            sleepState = "REM Sleep"
                        case .awake:
                            sleepState = "Awake"
                        case .asleepUnspecified:
                            sleepState = "Asleep"
                        case .inBed:
                            sleepState = "In Bed"
                        default:
                            sleepState = "Unknown"
                        }
                    } else {
                        switch HKCategoryValueSleepAnalysis(rawValue: value) {
                        case .asleepUnspecified:
                            sleepState = "Asleep"
                        case .awake:
                            sleepState = "Awake"
                        case .inBed:
                            sleepState = "In Bed"
                        default:
                            sleepState = "Unknown"
                        }
                    }
                    
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0 // hours
                    
                    return SleepSample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        duration: duration,
                        state: sleepState
                    )
                } ?? []
                
                continuation.resume(returning: sleepSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Active Energy
    
    /// Get active energy burned for a date range
    func getActiveEnergy(startDate: Date, endDate: Date) async throws -> HealthDataSummary {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let energy = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                let summary = HealthDataSummary(
                    type: "active_energy",
                    startDate: startDate,
                    endDate: endDate,
                    value: energy,
                    unit: "kcal"
                )
                continuation.resume(returning: summary)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Health Summary
    
    /// Get a comprehensive health summary for a date range
    func getHealthSummary(startDate: Date, endDate: Date) async throws -> ComprehensiveHealthSummary {
        async let steps = getSteps(startDate: startDate, endDate: endDate)
        async let heartRate = getHeartRate(startDate: startDate, endDate: endDate)
        async let sleep = getSleep(startDate: startDate, endDate: endDate)
        async let activeEnergy = getActiveEnergy(startDate: startDate, endDate: endDate)
        
        let (stepsData, heartRateData, sleepData, activeEnergyData) = try await (steps, heartRate, sleep, activeEnergy)
        
        return ComprehensiveHealthSummary(
            startDate: startDate,
            endDate: endDate,
            steps: stepsData,
            heartRate: heartRateData,
            sleep: sleepData,
            activeEnergy: activeEnergyData
        )
    }
}

// MARK: - Data Models

struct HealthDataSummary: Codable {
    let type: String
    let startDate: Date
    let endDate: Date
    let value: Double
    let unit: String
}

struct HeartRateSample: Codable {
    let date: Date
    let value: Double
    let unit: String
}

struct SleepSample: Codable {
    let startDate: Date
    let endDate: Date
    let duration: Double // in hours
    let state: String
}

struct ComprehensiveHealthSummary: Codable {
    let startDate: Date
    let endDate: Date
    let steps: HealthDataSummary
    let heartRate: [HeartRateSample]
    let sleep: [SleepSample]
    let activeEnergy: HealthDataSummary
}

// MARK: - Errors

enum HealthKitError: Error {
    case healthDataNotAvailable
    case invalidDateFormat
    case authorizationDenied
}

extension HealthKitError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit data is not available on this device"
        case .invalidDateFormat:
            return "Invalid date format. Expected YYYY-MM-DD"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        }
    }
}
