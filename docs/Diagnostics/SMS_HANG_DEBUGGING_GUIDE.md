# SMS Hang Debugging Guide

## Problem
The app hangs and becomes unresponsive after SMS scanning completes.

## Enhanced Debugging (Just Added)

I've added comprehensive debugging to help identify where the hang occurs:

### 1. Performance Tracking
- Every phase of SMS scanning now logs timing information
- Slow operations (>500ms) are flagged with WARNING level
- Progress is logged every 10 messages

### 2. Log Tags for Filtering

Use these `adb logcat` filters to see SMS-specific logs:

```bash
# See all SMS pipeline logs
adb logcat -s SMS_PIPELINE:V

# See performance metrics
adb logcat | grep SMS_PERF

# See slow operations
adb logcat | grep SLOW

# See all PocketFlow logs
adb logcat -s POCKETFLOW:V SMS_PIPELINE:V SMS_DB:V SMS_ERROR:V
```

## How to Capture the Hang

### Method 1: Using Android Studio Debugger

1. **Set Breakpoints** in these key locations:
   - `lib/services/sms_service.dart` line ~225 (start of `scanAndImport`)
   - `lib/services/sms_service.dart` line ~400 (end of `scanAndImport`, before return)
   - `lib/services/sms_pipeline_executor.dart` line ~20 (start of `processSms`)
   - `lib/screens/settings/components/preferences_tab.dart` line ~190 (SMS scan call)

2. **Run in Debug Mode**:
   ```bash
   flutter run --debug
   ```

3. **Trigger SMS Scan** from Settings > Preferences

4. **Watch the Call Stack**:
   - When the app hangs, click "Pause" in Android Studio debugger
   - Check the "Frames" panel to see where execution is stuck
   - Look for any infinite loops or blocking operations

### Method 2: Using adb logcat (Recommended for Performance Issues)

1. **Clear existing logs**:
   ```bash
   adb logcat -c
   ```

2. **Start logging** (in a separate terminal):
   ```bash
   adb logcat -s SMS_PIPELINE:V SMS_PERF:V POCKETFLOW:V > sms_debug.log
   ```

3. **Run the app** and trigger SMS scan

4. **Watch the log file** in real-time:
   ```bash
   tail -f sms_debug.log
   ```

5. **Look for**:
   - Last logged message before hang (shows where it stopped)
   - Any "SLOW" warnings (operations taking >500ms)
   - Phase numbers (0-5) to see which phase hangs
   - Performance metrics showing time per operation

### Method 3: Using Flutter DevTools

1. **Run app with DevTools**:
   ```bash
   flutter run --debug
   ```

2. **Open DevTools** (URL shown in terminal)

3. **Go to Performance tab**

4. **Start recording**

5. **Trigger SMS scan**

6. **Stop recording** when hang occurs

7. **Analyze timeline** to see:
   - Which operations are taking longest
   - Any UI thread blocking
   - Memory spikes

### Method 4: Thread Dump (When App is Frozen)

1. **Get process ID**:
   ```bash
   adb shell ps | grep pocket_flow
   ```

2. **Send SIGQUIT to get thread dump**:
   ```bash
   adb shell kill -3 <PID>
   ```

3. **View thread dump**:
   ```bash
   adb logcat -d | grep "SIGQUIT"
   ```

## What to Look For

### Common Hang Causes

1. **Infinite Loop**:
   - Look for repeated log messages
   - Check if progress counter stops incrementing

2. **Blocking Database Operation**:
   - Look for "Phase 3: Saving processed IDs" without completion
   - Check for database lock messages

3. **ML Model Loading**:
   - Look for "Phase 2: Initializing ML classifier" taking too long
   - Check if TFLite model is stuck loading

4. **Transfer Detection**:
   - Look for "Phase 4: Running transfer detection" without completion
   - This scans all transactions and could be slow with many records

5. **Pattern Detection**:
   - Look for "Phase 5: Running recurring pattern detection" without completion
   - This analyzes transaction patterns

6. **UI Thread Blocking**:
   - SMS scan runs on main thread (await in UI code)
   - Long operations block UI updates

## Expected Log Output

When working correctly, you should see:

```
SMS_PIPELINE [INFO] [2026-04-26T...] === SMS SCAN STARTED ===
SMS_PIPELINE [INFO] [2026-04-26T...] Phase 0: Querying SMS inbox
SMS_PERF [2026-04-26T...] SMS query took 234ms | Found 1500 messages
SMS_PIPELINE [INFO] [2026-04-26T...] Phase 1: Loading processed IDs
SMS_PIPELINE [INFO] [2026-04-26T...] Loaded 1200 processed IDs
SMS_PIPELINE [INFO] [2026-04-26T...] Phase 2: Initializing ML classifier
SMS_PERF [2026-04-26T...] ML classifier init took 156ms
SMS_PIPELINE [INFO] [2026-04-26T...] Progress: 10/1500 | Avg 45.2ms/msg, Imported=2, Skipped=8
SMS_PIPELINE [INFO] [2026-04-26T...] Progress: 20/1500 | Avg 43.8ms/msg, Imported=5, Skipped=15
...
SMS_PIPELINE [INFO] [2026-04-26T...] Phase 3: Saving processed IDs
SMS_PERF [2026-04-26T...] Save processed IDs took 23ms
SMS_PIPELINE [INFO] [2026-04-26T...] Phase 4: Running transfer detection
SMS_PERF [2026-04-26T...] Transfer detection took 456ms | Found 3 transfers
SMS_PIPELINE [INFO] [2026-04-26T...] Phase 5: Running recurring pattern detection
SMS_PERF [2026-04-26T...] Pattern detection took 234ms | Created 2 patterns
SMS_PIPELINE [INFO] [2026-04-26T...] === SMS SCAN COMPLETE ===
SMS_PERF [2026-04-26T...] TOTAL SMS SCAN took 12345ms | Processed 1500 messages, Imported 45
```

## Likely Culprits Based on Symptoms

### If hang happens immediately:
- Check Phase 0 (SMS query) or Phase 1 (loading processed IDs)
- Possible permission issue or database corruption

### If hang happens during processing:
- Check for SLOW warnings in pipeline
- ML classifier might be stuck
- Database writes might be blocking

### If hang happens at the end:
- Check Phase 3, 4, or 5
- Transfer detection or pattern detection might be slow
- Database operations might be blocking

### If app becomes unresponsive but logs continue:
- UI thread is blocked
- Need to move SMS scan to background isolate

## Quick Fixes to Try

### 1. Reduce Scan Range
In Settings > Preferences, change SMS scan range from "All messages" to "Last 1 week"

### 2. Disable Transfer Detection
Comment out the transfer detection block in `sms_service.dart` (lines ~380-395)

### 3. Disable Pattern Detection
Comment out the pattern detection block in `sms_service.dart` (lines ~397-430)

### 4. Add Timeout
Wrap the scan call with a timeout:

```dart
final result = await SmsService.scanAndImport(
  force: forceRescan,
  onProgress: (current) { ... },
).timeout(
  const Duration(seconds: 30),
  onTimeout: () {
    AppLogger.sms('SMS scan timed out after 30s', level: LogLevel.error);
    return SmsImportResult(error: 'Scan timed out');
  },
);
```

## Next Steps

1. Run the app with enhanced logging
2. Capture the logs using Method 2 above
3. Share the `sms_debug.log` file to identify the exact hang point
4. Based on the logs, we can:
   - Move slow operations to background
   - Add proper cancellation support
   - Optimize database queries
   - Add progress indicators for long operations

## Additional Information

### Log Levels
- `INFO`: Normal operation milestones
- `WARNING`: Slow operations (>500ms)
- `ERROR`: Failures and exceptions
- `DEBUG`: Detailed step-by-step execution

### Performance Thresholds
- Message processing: Should be <100ms per message
- ML classification: Should be <200ms per message
- Database operations: Should be <50ms
- Total scan: Depends on message count, ~50ms per message average
