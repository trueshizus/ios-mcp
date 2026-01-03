# Testing Guide for HealthKit MCP Server

## Prerequisites for Testing

### Hardware & Software Requirements
- **Mac Computer** running macOS 13.0 (Ventura) or later
- **Xcode** 14.0 or later (includes Swift 5.9+)
- **HealthKit Data** - Either:
  - Real health data from Apple Watch/iPhone
  - Simulated data via Health app

### Setting Up Test Environment

1. **Clone the repository**
   ```bash
   git clone https://github.com/trueshizus/ios-mcp.git
   cd ios-mcp
   ```

2. **Verify Swift version**
   ```bash
   swift --version
   # Should show Swift 5.9 or later
   ```

3. **Resolve dependencies**
   ```bash
   swift package resolve
   ```

4. **Build the project**
   ```bash
   swift build
   # Or for release build:
   swift build -c release
   ```

## Unit Testing Approach

Since this project uses HealthKit which requires actual Apple hardware and authorization, traditional unit tests are challenging. Here's the recommended testing approach:

### 1. Manual Testing with Real Data

**Test Steps:**

1. Run the server:
   ```bash
   .build/debug/HealthKitMCP
   ```

2. The server will output to stderr if authorization fails, and will wait for JSON-RPC requests on stdin.

3. Send a test request via stdin:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | .build/debug/HealthKitMCP
   ```

4. Expected response should list all 5 tools.

5. Test each tool with valid date ranges:
   ```bash
   # Test get_steps
   echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_steps","arguments":{"start_date":"2024-01-01","end_date":"2024-01-07"}}}' | .build/debug/HealthKitMCP
   
   # Test get_heart_rate
   echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_heart_rate","arguments":{"start_date":"2024-01-01","end_date":"2024-01-07"}}}' | .build/debug/HealthKitMCP
   ```

### 2. Integration Testing with MCP Client

**Using Claude Desktop:**

1. Build release version:
   ```bash
   swift build -c release
   ```

2. Add to Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):
   ```json
   {
     "mcpServers": {
       "healthkit": {
         "command": "/absolute/path/to/ios-mcp/.build/release/HealthKitMCP"
       }
     }
   }
   ```

3. Restart Claude Desktop

4. Try queries like:
   - "What were my steps yesterday?"
   - "Show me my heart rate from last week"
   - "Give me a health summary for the past month"

### 3. Error Handling Tests

Test various error conditions:

**Invalid Date Format:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_steps",
    "arguments": {
      "start_date": "2024-13-45",
      "end_date": "2024-01-01"
    }
  }
}
```
Expected: Error message about invalid date format

**Missing Parameters:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "get_steps",
    "arguments": {
      "start_date": "2024-01-01"
    }
  }
}
```
Expected: Error about missing end_date parameter

**Unknown Tool:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "get_unknown_metric",
    "arguments": {}
  }
}
```
Expected: Error about unknown tool

### 4. Authorization Testing

1. First run should prompt for HealthKit authorization
2. Check System Preferences → Security & Privacy → Privacy → Health
3. Verify the app has requested permissions
4. Test with:
   - All permissions granted
   - Some permissions denied
   - All permissions denied

### 5. Data Validation Tests

For each tool, verify:

**get_steps:**
- Returns cumulative step count
- Matches Health app data
- Correct date range
- Proper unit (steps)

**get_heart_rate:**
- Returns individual samples
- Shows statistics (min, max, average)
- Correct timestamps
- Proper unit (bpm)

**get_sleep:**
- Returns sleep sessions
- Shows sleep states (Asleep, In Bed, REM, Deep, Core)
- Correct durations
- Proper time ranges

**get_active_energy:**
- Returns cumulative energy burned
- Matches Health app data
- Correct date range
- Proper unit (kcal)

**get_health_summary:**
- Combines all metrics
- Shows all data types
- Proper formatting
- Comprehensive overview

## Expected Test Results

### Success Cases

All tools should return:
- Well-formatted text output
- Correct date ranges
- Appropriate units
- Human-readable summaries

### Edge Cases

Test with:
- Date ranges with no data
- Very large date ranges (years)
- Single day ranges
- Future dates (should return no data)
- Date range where start > end (should handle gracefully)

## Debugging Tips

1. **Check Authorization:**
   - Look for stderr messages about authorization
   - Check macOS System Preferences

2. **Verify HealthKit Data:**
   - Open Health app
   - Verify data exists for test date ranges
   - Check data sources

3. **Enable Verbose Logging:**
   - Monitor stderr for warnings
   - Check for JSON-RPC protocol errors

4. **Test JSON Parsing:**
   - Ensure valid JSON in requests
   - Check response format

## Automated Testing (Future)

Potential improvements for automated testing:

1. **Mock HealthKit Data:**
   - Create a MockHealthKitService for unit tests
   - Test tool logic without real HealthKit

2. **Integration Test Suite:**
   - Use XCTest framework
   - Create test fixtures with known data
   - Verify JSON-RPC protocol compliance

3. **CI/CD:**
   - Use GitHub Actions with macOS runners
   - Run builds on each commit
   - Validate API compatibility

## Known Limitations

1. **macOS Only:** Cannot test on other platforms
2. **Real Data Required:** Difficult to create consistent test scenarios
3. **Authorization Required:** Each test run may need user interaction
4. **Date-Dependent:** Test results vary based on actual health data

## Troubleshooting

**Build Errors:**
- Ensure macOS 13.0+
- Verify Xcode Command Line Tools installed
- Check Swift version matches requirements

**Authorization Issues:**
- Reset Health permissions in System Preferences
- Check app's entitlements
- Verify Info.plist has required keys

**No Data Returned:**
- Verify Health app has data for date range
- Check data source permissions
- Try different date ranges

**JSON-RPC Errors:**
- Validate JSON format
- Check method names match exactly
- Verify parameter types

## Success Criteria

The implementation is successful if:
- ✅ Builds without errors on macOS 13.0+
- ✅ All 5 tools are registered
- ✅ Authorization prompt appears on first run
- ✅ Each tool returns formatted data when health data exists
- ✅ Error handling works for invalid inputs
- ✅ Integration with MCP client (Claude Desktop) works
- ✅ Matches data shown in Health app
- ✅ Handles edge cases gracefully

## Conclusion

This implementation is complete and ready for testing on macOS. The code follows best practices for Swift concurrency, MCP protocol compliance, and HealthKit integration. Testing must be performed on a Mac with actual HealthKit data to validate functionality.
