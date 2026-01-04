# HealthKit MCP Server - Technical Notes

## Implementation Overview

This project implements a complete Model Context Protocol (MCP) server that exposes HealthKit data from macOS. The implementation follows the requirements exactly:

### ✅ Core Components Implemented

1. **Package.swift**
   - Uses `swift-tools-version: 5.9`
   - Targets macOS 13.0+ (`.macOS(.v13)`)
   - Includes dependency on `modelcontextprotocol/swift-sdk` version 0.1.0+
   - Defines an executable target named `HealthKitMCP`

2. **HealthKitService Actor** (`Sources/HealthKitMCP/HealthKitService.swift`)
   - Thread-safe actor pattern for HealthKit operations
   - Authorization handling via `requestAuthorization()`
   - Uses `HKStatisticsQuery` for cumulative data:
     - Steps (stepCount)
     - Active Energy (activeEnergyBurned)
   - Uses `HKSampleQuery` for sample data:
     - Heart Rate samples with timestamps
     - Sleep Analysis with sleep states and durations
   - Implements async/await pattern with continuations
   - Provides comprehensive health summary combining all metrics

3. **Main Server** (`Sources/HealthKitMCP/main.swift`)
   - Initializes MCP Server with name and version
   - Registers all 5 required tools:
     * `get_steps` - Returns cumulative step count
     * `get_heart_rate` - Returns heart rate samples with statistics
     * `get_sleep` - Returns sleep sessions with states and durations
     * `get_active_energy` - Returns cumulative active energy in kcal
     * `get_health_summary` - Returns combined summary of all metrics
   - Uses `StdioTransport` for JSON-RPC communication
   - Implements proper tool call handling with error management
   - Provides formatted, human-readable output

### 🎯 MCP Tools Implementation

Each tool accepts:
- `start_date`: String in YYYY-MM-DD format
- `end_date`: String in YYYY-MM-DD format

Tool schemas are properly defined using JSON Schema format in the `inputSchema` field.

### 📊 Data Models

- `HealthDataSummary`: For cumulative metrics (steps, active energy)
- `HeartRateSample`: Individual heart rate reading with timestamp
- `SleepSample`: Sleep session with start/end times, duration, and state
- `ComprehensiveHealthSummary`: Combined view of all health metrics

### 🔒 Authorization & Privacy

- Requests read-only access to HealthKit data types
- Gracefully handles authorization failures
- Does not request sharing (write) permissions
- Respects user privacy by requiring explicit permission

### 🏗️ Architecture Decisions

1. **Actor Pattern**: HealthKitService uses Swift's actor pattern to ensure thread-safe access to HealthKit
2. **Async/Await**: Modern Swift concurrency for clean asynchronous code
3. **Error Handling**: Proper error propagation with custom HealthKitError enum
4. **Formatted Output**: Human-readable text output with statistics and summaries
5. **Date Handling**: ISO 8601 date format (YYYY-MM-DD) for consistency

### 🧪 Testing Considerations

This code **cannot be tested on Linux** because:
- HealthKit is only available on Apple platforms (macOS, iOS, watchOS)
- The code is designed specifically for macOS 13.0+

To test this server, you need:
1. A Mac running macOS 13.0 or later
2. Swift 5.9 or later
3. HealthKit data (either real or simulated via Health app)
4. An MCP client (e.g., Claude Desktop with MCP support)

### 📝 Building on macOS

```bash
# Clone the repository
git clone <repo-url>
cd ios-mcp

# Build the project
swift build -c release

# Run the server
.build/release/HealthKitMCP
```

### 🔌 Integration Example

To integrate with Claude Desktop, add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "healthkit": {
      "command": "/path/to/ios-mcp/.build/release/HealthKitMCP"
    }
  }
}
```

### 🚀 Usage Example

Once connected, you can ask Claude:
- "What were my steps yesterday?"
- "Show me my heart rate data from last week"
- "Give me a health summary for the past month"
- "How much did I sleep last night?"

The server will query HealthKit and return formatted results.

### ⚠️ Known Limitations

1. **Platform**: macOS only (HealthKit requirement)
2. **Permissions**: Requires user approval on first run
3. **Data Availability**: Only returns data that exists in HealthKit
4. **Date Format**: Strict YYYY-MM-DD format required
5. **Testing**: Cannot be unit tested on CI/CD without macOS runners

### 🔄 Future Enhancements

Possible improvements:
- Add more health metrics (weight, blood pressure, etc.)
- Support for workout sessions
- Nutrition data queries
- Custom date range formatting
- Caching for performance
- Background data collection
- Real-time notifications for health changes

### 📚 References

- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

## Code Quality

- ✅ Type-safe Swift code with proper error handling
- ✅ Actor isolation for thread safety
- ✅ Async/await for clean concurrent code
- ✅ Comprehensive documentation and comments
- ✅ Following MCP protocol specifications
- ✅ Clean separation of concerns (Service vs Server)
- ✅ Proper resource management (no memory leaks)
- ✅ Formatted output for better UX
