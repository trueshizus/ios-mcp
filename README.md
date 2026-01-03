# ios-mcp

# HealthKit MCP Server

A Model Context Protocol (MCP) server that exposes HealthKit data from macOS. This allows Large Language Models to query health data including steps, heart rate, sleep analysis, and active energy burned.

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- HealthKit access permissions

## Features

The server provides the following MCP tools:

### Tools

1. **get_steps** - Retrieve step count data for a date range
   - Parameters: `start_date`, `end_date` (YYYY-MM-DD format)
   - Returns: Total step count for the period

2. **get_heart_rate** - Retrieve heart rate samples for a date range
   - Parameters: `start_date`, `end_date` (YYYY-MM-DD format)
   - Returns: Heart rate statistics and recent samples

3. **get_sleep** - Retrieve sleep analysis data for a date range
   - Parameters: `start_date`, `end_date` (YYYY-MM-DD format)
   - Returns: Sleep sessions with durations and states

4. **get_active_energy** - Retrieve active energy burned data for a date range
   - Parameters: `start_date`, `end_date` (YYYY-MM-DD format)
   - Returns: Total active energy in kilocalories

5. **get_health_summary** - Get a comprehensive health summary
   - Parameters: `start_date`, `end_date` (YYYY-MM-DD format)
   - Returns: Combined summary of steps, heart rate, sleep, and active energy

## Building

```bash
swift build -c release
```

## Running

```bash
.build/release/HealthKitMCP
```

The server communicates via standard input/output using the MCP protocol over JSON-RPC.

## Architecture

- **HealthKitService** - Actor responsible for querying HealthKit data
  - Uses `HKStatisticsQuery` for cumulative data (steps, active energy)
  - Uses `HKSampleQuery` for sample data (heart rate, sleep)
  - Handles authorization requests
  
- **main.swift** - MCP server setup with StdioTransport
  - Registers MCP tools
  - Handles tool execution
  - Formats results for display

## HealthKit Permissions

On first run, the server will request permission to access HealthKit data. You must grant the following permissions:
- Step Count
- Heart Rate
- Active Energy Burned
- Sleep Analysis

## Integration with MCP Clients

This server can be integrated with any MCP-compatible client by configuring it to launch the executable. The server uses stdio transport for communication.

Example configuration for Claude Desktop:

```json
{
  "mcpServers": {
    "healthkit": {
      "command": "/path/to/HealthKitMCP"
    }
  }
}
```

## Development

The project structure:

```
HealthKitMCP/
├── Package.swift                    # Swift package manifest
└── Sources/
    └── HealthKitMCP/
        ├── main.swift               # MCP server setup
        └── HealthKitService.swift   # HealthKit interaction layer
```

## Notes

- All dates must be in YYYY-MM-DD format (ISO 8601)
- The server requires macOS as HealthKit is only available on Apple platforms
- HealthKit data is private and requires user authorization
- The server runs as a foreground process and communicates via stdio

## License

This project uses the [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) for MCP protocol implementation.

