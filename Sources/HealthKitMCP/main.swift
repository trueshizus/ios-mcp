import Foundation
import MCP

@main
struct HealthKitMCPServer {
    static func main() async throws {
        let healthKitService = HealthKitService()
        
        // Request authorization on startup
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            print("Warning: Failed to authorize HealthKit: \(error)", to: &stdErr)
        }
        
        // Create the MCP server
        let server = Server(
            name: "healthkit-mcp-server",
            version: "1.0.0",
            capabilities: Server.Capabilities(
                tools: .init(listChanged: false)
            )
        )
        
        // Register tools
        _ = server
            .withMethodHandler(ListTools.self) { _ in
                ListTools.Result(tools: [
                    Tool(
                        name: "get_steps",
                        description: "Retrieve step count data for a specified date range",
                        inputSchema: [
                            "type": "object",
                            "properties": [
                                "start_date": [
                                    "type": "string",
                                    "description": "Start date in YYYY-MM-DD format"
                                ],
                                "end_date": [
                                    "type": "string",
                                    "description": "End date in YYYY-MM-DD format"
                                ]
                            ],
                            "required": ["start_date", "end_date"]
                        ]
                    ),
                    Tool(
                        name: "get_heart_rate",
                        description: "Retrieve heart rate samples for a specified date range",
                        inputSchema: [
                            "type": "object",
                            "properties": [
                                "start_date": [
                                    "type": "string",
                                    "description": "Start date in YYYY-MM-DD format"
                                ],
                                "end_date": [
                                    "type": "string",
                                    "description": "End date in YYYY-MM-DD format"
                                ]
                            ],
                            "required": ["start_date", "end_date"]
                        ]
                    ),
                    Tool(
                        name: "get_sleep",
                        description: "Retrieve sleep analysis data for a specified date range",
                        inputSchema: [
                            "type": "object",
                            "properties": [
                                "start_date": [
                                    "type": "string",
                                    "description": "Start date in YYYY-MM-DD format"
                                ],
                                "end_date": [
                                    "type": "string",
                                    "description": "End date in YYYY-MM-DD format"
                                ]
                            ],
                            "required": ["start_date", "end_date"]
                        ]
                    ),
                    Tool(
                        name: "get_active_energy",
                        description: "Retrieve active energy burned data for a specified date range",
                        inputSchema: [
                            "type": "object",
                            "properties": [
                                "start_date": [
                                    "type": "string",
                                    "description": "Start date in YYYY-MM-DD format"
                                ],
                                "end_date": [
                                    "type": "string",
                                    "description": "End date in YYYY-MM-DD format"
                                ]
                            ],
                            "required": ["start_date", "end_date"]
                        ]
                    ),
                    Tool(
                        name: "get_health_summary",
                        description: "Retrieve a comprehensive health summary including steps, heart rate, sleep, and active energy for a specified date range",
                        inputSchema: [
                            "type": "object",
                            "properties": [
                                "start_date": [
                                    "type": "string",
                                    "description": "Start date in YYYY-MM-DD format"
                                ],
                                "end_date": [
                                    "type": "string",
                                    "description": "End date in YYYY-MM-DD format"
                                ]
                            ],
                            "required": ["start_date", "end_date"]
                        ]
                    )
                ])
            }
            .withMethodHandler(CallTool.self) { params in
                try await handleToolCall(params, healthKitService: healthKitService)
            }
        
        // Set up stdio transport
        let transport = StdioTransport()
        
        // Run the server
        try await server.start(transport: transport)
    }
}

// MARK: - Tool Call Handler

func handleToolCall(_ params: CallTool.Parameters, healthKitService: HealthKitService) async throws -> CallTool.Result {
    do {
        let arguments = params.arguments ?? [:]
        
        guard let startDateString = arguments["start_date"]?.stringValue,
              let endDateString = arguments["end_date"]?.stringValue else {
            throw HealthKitError.invalidDateFormat
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            throw HealthKitError.invalidDateFormat
        }
        
        let result: String
        
        switch params.name {
        case "get_steps":
            let summary = try await healthKitService.getSteps(startDate: startDate, endDate: endDate)
            result = formatHealthDataSummary(summary)
            
        case "get_heart_rate":
            let samples = try await healthKitService.getHeartRate(startDate: startDate, endDate: endDate)
            result = formatHeartRateSamples(samples)
            
        case "get_sleep":
            let samples = try await healthKitService.getSleep(startDate: startDate, endDate: endDate)
            result = formatSleepSamples(samples)
            
        case "get_active_energy":
            let summary = try await healthKitService.getActiveEnergy(startDate: startDate, endDate: endDate)
            result = formatHealthDataSummary(summary)
            
        case "get_health_summary":
            let summary = try await healthKitService.getHealthSummary(startDate: startDate, endDate: endDate)
            result = formatComprehensiveSummary(summary)
            
        default:
            throw MCPError.invalidRequest("Unknown tool: \(params.name)")
        }
        
        return CallTool.Result(
            content: [.text(result)],
            isError: false
        )
    } catch {
        return CallTool.Result(
            content: [.text("Error: \(error.localizedDescription)")],
            isError: true
        )
    }
}

// MARK: - Formatting Helpers

func formatHealthDataSummary(_ summary: HealthDataSummary) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    
    return """
    \(summary.type.uppercased()) SUMMARY
    Period: \(dateFormatter.string(from: summary.startDate)) to \(dateFormatter.string(from: summary.endDate))
    Total: \(String(format: "%.2f", summary.value)) \(summary.unit)
    """
}

func formatHeartRateSamples(_ samples: [HeartRateSample]) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    
    var result = "HEART RATE SAMPLES\n"
    result += "Total samples: \(samples.count)\n\n"
    
    if !samples.isEmpty {
        let average = samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
        let min = samples.map { $0.value }.min() ?? 0
        let max = samples.map { $0.value }.max() ?? 0
        
        result += "Statistics:\n"
        result += "- Average: \(String(format: "%.1f", average)) bpm\n"
        result += "- Min: \(String(format: "%.1f", min)) bpm\n"
        result += "- Max: \(String(format: "%.1f", max)) bpm\n\n"
        
        result += "Recent samples:\n"
        for sample in samples.prefix(10) {
            result += "- \(dateFormatter.string(from: sample.date)): \(String(format: "%.1f", sample.value)) \(sample.unit)\n"
        }
        
        if samples.count > 10 {
            result += "... and \(samples.count - 10) more samples\n"
        }
    } else {
        result += "No heart rate data available for this period.\n"
    }
    
    return result
}

func formatSleepSamples(_ samples: [SleepSample]) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    
    var result = "SLEEP ANALYSIS\n"
    result += "Total samples: \(samples.count)\n\n"
    
    if !samples.isEmpty {
        let totalSleepHours = samples.filter { 
            $0.state.contains("Sleep") || $0.state.contains("Asleep")
        }.reduce(0.0) { $0 + $1.duration }
        
        result += "Total sleep time: \(String(format: "%.2f", totalSleepHours)) hours\n\n"
        
        result += "Sleep sessions:\n"
        for sample in samples {
            result += "- \(sample.state): \(dateFormatter.string(from: sample.startDate)) to \(dateFormatter.string(from: sample.endDate))\n"
            result += "  Duration: \(String(format: "%.2f", sample.duration)) hours\n"
        }
    } else {
        result += "No sleep data available for this period.\n"
    }
    
    return result
}

func formatComprehensiveSummary(_ summary: ComprehensiveHealthSummary) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    
    var result = "COMPREHENSIVE HEALTH SUMMARY\n"
    result += "Period: \(dateFormatter.string(from: summary.startDate)) to \(dateFormatter.string(from: summary.endDate))\n\n"
    
    result += "STEPS\n"
    result += "Total: \(String(format: "%.0f", summary.steps.value)) steps\n\n"
    
    result += "ACTIVE ENERGY\n"
    result += "Total: \(String(format: "%.2f", summary.activeEnergy.value)) kcal\n\n"
    
    result += "HEART RATE\n"
    if !summary.heartRate.isEmpty {
        let average = summary.heartRate.reduce(0.0) { $0 + $1.value } / Double(summary.heartRate.count)
        result += "Average: \(String(format: "%.1f", average)) bpm\n"
        result += "Samples: \(summary.heartRate.count)\n\n"
    } else {
        result += "No data available\n\n"
    }
    
    result += "SLEEP\n"
    if !summary.sleep.isEmpty {
        let totalSleepHours = summary.sleep.filter { 
            $0.state.contains("Sleep") || $0.state.contains("Asleep")
        }.reduce(0.0) { $0 + $1.duration }
        result += "Total sleep: \(String(format: "%.2f", totalSleepHours)) hours\n"
        result += "Sessions: \(summary.sleep.count)\n"
    } else {
        result += "No data available\n"
    }
    
    return result
}

// MARK: - Stderr Helper

var stdErr = StandardErrorOutputStream()

struct StandardErrorOutputStream: TextOutputStream {
    func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}
