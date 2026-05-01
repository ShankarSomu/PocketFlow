# SMS Debugging Enhancements - Summary

## Changes Made

### 1. Enhanced Logging in `app_logger.dart`

**Added:**
- Timestamps to all SMS log messages for precise timing analysis
- New `smsPerf()` method for performance tracking
- Separate performance log tag `SMS_PERF` for easy filtering

**Benefits:**
- Can track exactly when each operation starts/completes
- Can identify slow operations (>500ms)
- Can measure time per message and total scan time

### 2. Comprehensive Debugging in `sms_service.dart`

**Added:**
- Phase-by-phase logging (Phases 0-5)
- Performance timing for each phase:
  - Phase 0: SMS query
  - Phase 1: Loading processed IDs
  - Phase 2: ML classifier initialization
  - Phase 3: Saving processed IDs
  - Phase 4: Transfer detection
  - Phase 5: Pattern detection
- Progress logging every 10 messages
- Average time per message calculation
- Slow operation warnings (>500ms for pipeline, >1000ms for message)
- Reduced log spam by only logging first 5 skipped messages

**Benefits:**
- Can identify which phase hangs
- Can see processing speed in real-time
- Can identify slow messages
- Reduces log clutter while maintaining visibility

### 3. Detailed Pipeline Debugging in `sms_pipeline_executor.dart`

**Added:**
- Step-by-step logging for each pipeline stage:
  - Privacy check
  - ML classification
  - Rule-based classification
  - Entity extraction
  - Account resolution
  - Type-specific processing
- Performance timing for each step
- Slow operation warnings (>200ms for ML, >100ms for other steps)
- Total pipeline time tracking

**Benefits:**
- Can identify which pipeline step is slow
- Can see if ML model is causing delays
- Can track cumulative slowdowns

### 4. Timeout Protection in `preferences_tab.dart`

**Added:**
- 5-minute timeout on SMS scan operation
- Graceful timeout handling with error message
- Progress tracking at timeout

**Benefits:**
- Prevents indefinite hangs
- User gets feedback instead of frozen app
- Can see how far scan progressed before timeout

## How to Use

### View Logs in Real-Time

```bash
# All SMS logs
adb logcat -s SMS_PIPELINE:V

# Performance metrics only
adb logcat | grep SMS_PERF

# Slow operations only
adb logcat | grep SLOW

# Everything
adb logcat -s POCKETFLOW:V SMS_PIPELINE:V SMS_PERF:V
```

### Save Logs to File

```bash
adb logcat -c  # Clear old logs
adb logcat -s SMS_PIPELINE:V SMS_PERF:V > sms_debug.log
# Run SMS scan in app
# Ctrl+C to stop logging
```

### Analyze Logs

Look for:
1. **Last logged phase** - Shows where hang occurred
2. **SLOW warnings** - Shows performance bottlenecks
3. **Progress messages** - Shows if processing is stuck
4. **Performance metrics** - Shows time per operation

## Expected Output

### Normal Scan (No Issues)

```
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] === SMS SCAN STARTED ===
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Phase 0: Querying SMS inbox
SMS_PERF [2026-04-26T10:30:00] SMS query took 234ms | Found 1500 messages
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Phase 1: Loading processed IDs
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Loaded 1200 processed IDs
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Phase 2: Initializing ML classifier
SMS_PERF [2026-04-26T10:30:01] ML classifier init took 156ms
SMS_PIPELINE [INFO] [2026-04-26T10:30:01] Progress: 10/1500 | Avg 45.2ms/msg
SMS_PIPELINE [INFO] [2026-04-26T10:30:02] Progress: 20/1500 | Avg 43.8ms/msg
...
SMS_PIPELINE [INFO] [2026-04-26T10:31:15] Phase 3: Saving processed IDs
SMS_PERF [2026-04-26T10:31:15] Save processed IDs took 23ms
SMS_PIPELINE [INFO] [2026-04-26T10:31:15] Phase 4: Running transfer detection
SMS_PERF [2026-04-26T10:31:16] Transfer detection took 456ms | Found 3 transfers
SMS_PIPELINE [INFO] [2026-04-26T10:31:16] Phase 5: Running recurring pattern detection
SMS_PERF [2026-04-26T10:31:16] Pattern detection took 234ms | Created 2 patterns
SMS_PIPELINE [INFO] [2026-04-26T10:31:16] === SMS SCAN COMPLETE ===
SMS_PERF [2026-04-26T10:31:16] TOTAL SMS SCAN took 76234ms | Processed 1500 messages
```

### Scan with Performance Issues

```
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] === SMS SCAN STARTED ===
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Phase 0: Querying SMS inbox
SMS_PERF [2026-04-26T10:30:02] SMS query took 2345ms | Found 5000 messages
SMS_PIPELINE [WARNING] [2026-04-26T10:30:02] SLOW: SMS query took too long
SMS_PIPELINE [INFO] [2026-04-26T10:30:02] Phase 2: Initializing ML classifier
SMS_PERF [2026-04-26T10:30:03] ML classifier init took 856ms
SMS_PIPELINE [WARNING] [2026-04-26T10:30:03] SLOW: ML init took too long
SMS_PIPELINE [INFO] [2026-04-26T10:30:05] Progress: 10/5000 | Avg 234.5ms/msg
SMS_PIPELINE [WARNING] [2026-04-26T10:30:05] SLOW: Pipeline took 1234ms | smsId=12345
...
```

### Hang Detection

If logs stop at a specific phase, that's where the hang is:

```
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] === SMS SCAN STARTED ===
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Phase 0: Querying SMS inbox
SMS_PERF [2026-04-26T10:30:00] SMS query took 234ms | Found 1500 messages
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Phase 1: Loading processed IDs
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Loaded 1200 processed IDs
SMS_PIPELINE [INFO] [2026-04-26T10:30:00] Phase 2: Initializing ML classifier
# <-- HANGS HERE, no more logs
```

This tells you the ML classifier initialization is hanging.

## Troubleshooting

### If No Logs Appear

1. Check if app is running: `adb shell ps | grep pocket_flow`
2. Check logcat is working: `adb logcat -d | tail`
3. Try broader filter: `adb logcat | grep SMS`

### If Logs Stop Suddenly

1. App might have crashed - check for crash logs:
   ```bash
   adb logcat -d | grep -i "fatal\|exception\|crash"
   ```

2. Check if process is still running:
   ```bash
   adb shell ps | grep pocket_flow
   ```

### If Timeout Occurs

1. Check which phase was running when timeout occurred
2. Reduce scan range (Settings > Preferences > SMS Scan Range)
3. Check for SLOW warnings before timeout
4. Consider moving slow operations to background

## Performance Benchmarks

### Expected Performance
- SMS query: <500ms for 1000 messages
- ML classifier init: <200ms
- Message processing: <100ms per message
- Transfer detection: <1s for 100 transactions
- Pattern detection: <500ms for 50 transactions

### Warning Thresholds
- Pipeline: >500ms per message
- ML classification: >200ms per message
- Entity extraction: >100ms per message
- Account resolution: >100ms per message
- Message processing: >1000ms total

## Next Steps

1. **Run the app** with enhanced logging
2. **Trigger SMS scan** from Settings > Preferences
3. **Capture logs** using the commands above
4. **Analyze logs** to find:
   - Which phase hangs
   - Which operations are slow
   - Any error messages
5. **Share findings** to get targeted fixes

## Files Modified

1. `lib/services/app_logger.dart` - Added performance tracking
2. `lib/services/sms_service.dart` - Added phase-by-phase logging
3. `lib/services/sms_pipeline_executor.dart` - Added step-by-step logging
4. `lib/screens/settings/components/preferences_tab.dart` - Added timeout protection

## Additional Resources

- See `docs/Diagnostics/SMS_HANG_DEBUGGING_GUIDE.md` for detailed debugging instructions
- See `docs/SMS_PARSING_FLOW.md` for SMS processing architecture
- See `docs/SMS_SCAN_FLOW_COMPLETE.md` for complete scan flow documentation
