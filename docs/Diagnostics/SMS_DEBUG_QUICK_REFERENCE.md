# SMS Debugging - Quick Reference

## 🚀 Quick Start

### 1. Clear Logs & Start Capture
```bash
adb logcat -c
adb logcat -s SMS_PIPELINE:V SMS_PERF:V > sms_debug.log
```

### 2. Run SMS Scan in App
Settings > Preferences > SMS Scanning > Scan Now

### 3. Watch Logs in Real-Time
```bash
tail -f sms_debug.log
```

### 4. Stop Capture
Press `Ctrl+C` in the terminal

---

## 📊 Log Filters

| What to See | Command |
|-------------|---------|
| All SMS logs | `adb logcat -s SMS_PIPELINE:V` |
| Performance only | `adb logcat \| grep SMS_PERF` |
| Slow operations | `adb logcat \| grep SLOW` |
| Errors only | `adb logcat \| grep ERROR` |
| Everything | `adb logcat -s POCKETFLOW:V SMS_PIPELINE:V SMS_PERF:V` |

---

## 🔍 What to Look For

### Hang Detection
Look for the **last logged phase** before logs stop:

| Last Phase Seen | Hang Location |
|----------------|---------------|
| Phase 0 | SMS inbox query |
| Phase 1 | Loading processed IDs |
| Phase 2 | ML classifier initialization |
| Progress: X/Y | Message processing loop |
| Phase 3 | Saving processed IDs |
| Phase 4 | Transfer detection |
| Phase 5 | Pattern detection |

### Performance Issues
Look for **SLOW warnings**:

```
SMS_PIPELINE [WARNING] SLOW: Pipeline took 1234ms | smsId=12345
SMS_PIPELINE [WARNING] SLOW: ML classify took 567ms
```

### Progress Tracking
Look for **progress messages** every 10 messages:

```
SMS_PIPELINE [INFO] Progress: 10/1500 | Avg 45.2ms/msg, Imported=2, Skipped=8
SMS_PIPELINE [INFO] Progress: 20/1500 | Avg 43.8ms/msg, Imported=5, Skipped=15
```

If progress stops incrementing → **infinite loop or hang**

---

## ⚡ Performance Benchmarks

| Operation | Expected | Warning |
|-----------|----------|---------|
| SMS query | <500ms | >1000ms |
| ML init | <200ms | >500ms |
| Per message | <100ms | >500ms |
| ML classify | <200ms | >500ms |
| Entity extract | <100ms | >200ms |
| Account resolve | <100ms | >200ms |
| Transfer detect | <1s | >5s |
| Pattern detect | <500ms | >2s |

---

## 🛠️ Quick Fixes

### If Hang at Phase 0 (SMS Query)
- Check SMS permission granted
- Try restarting app
- Check device storage space

### If Hang at Phase 2 (ML Init)
- ML model might be corrupted
- Check `assets/ml/sms_classifier.tflite` exists
- Try reinstalling app

### If Slow Message Processing
- Reduce scan range: Settings > SMS Scan Range > Last 1 week
- Check for SLOW warnings to identify bottleneck

### If Hang at Phase 4 (Transfer Detection)
- Too many transactions to analyze
- Temporary fix: Comment out transfer detection code

### If Hang at Phase 5 (Pattern Detection)
- Too many transactions to analyze
- Temporary fix: Comment out pattern detection code

### If Timeout Occurs
- Current timeout: 5 minutes
- Reduce scan range
- Check logs for last phase before timeout

---

## 🐛 Common Issues

### No Logs Appearing
```bash
# Check if app is running
adb shell ps | grep pocket_flow

# Check logcat is working
adb logcat -d | tail

# Try broader filter
adb logcat | grep SMS
```

### App Crashes
```bash
# Check for crash logs
adb logcat -d | grep -i "fatal\|exception\|crash"
```

### Logs Stop Suddenly
```bash
# Check if process still running
adb shell ps | grep pocket_flow

# Check for out of memory
adb logcat -d | grep -i "out of memory\|oom"
```

---

## 📱 In-App Debugging

### Enable Debug Mode
Settings > Preferences > Log Level > Debug

### View Logs in App
Settings > Diagnostics > View Logs

### Export Logs
Settings > Diagnostics > Export Logs > Technical Logs

---

## 🎯 Expected Log Flow

```
=== SMS SCAN STARTED ===
Phase 0: Querying SMS inbox
  ↓ SMS query took Xms | Found Y messages
Phase 1: Loading processed IDs
  ↓ Loaded X processed IDs
Phase 2: Initializing ML classifier
  ↓ ML classifier init took Xms
Progress: 10/Y | Avg Xms/msg, Imported=X, Skipped=X
Progress: 20/Y | Avg Xms/msg, Imported=X, Skipped=X
  ... (continues every 10 messages)
Progress: Y/Y | Avg Xms/msg, Imported=X, Skipped=X
Phase 3: Saving processed IDs
  ↓ Save processed IDs took Xms
Phase 4: Running transfer detection
  ↓ Transfer detection took Xms | Found X transfers
Phase 5: Running recurring pattern detection
  ↓ Pattern detection took Xms | Created X patterns
=== SMS SCAN COMPLETE ===
TOTAL SMS SCAN took Xms | Processed Y messages, Imported X
```

---

## 📞 Getting Help

When reporting issues, include:

1. **Last phase logged** before hang
2. **Any SLOW warnings** in logs
3. **Progress when stopped** (e.g., "Progress: 45/1500")
4. **Device info**: Android version, RAM, storage
5. **Scan settings**: Range, force rescan, etc.
6. **Full log file**: `sms_debug.log`

---

## 🔗 Related Documentation

- `SMS_HANG_DEBUGGING_GUIDE.md` - Detailed debugging guide
- `SMS_DEBUGGING_CHANGES.md` - Summary of changes made
- `SMS_PARSING_FLOW.md` - SMS processing architecture
- `SMS_SCAN_FLOW_COMPLETE.md` - Complete scan flow

---

## ⚙️ Advanced Debugging

### Thread Dump (When Frozen)
```bash
# Get process ID
adb shell ps | grep pocket_flow

# Send SIGQUIT
adb shell kill -3 <PID>

# View thread dump
adb logcat -d | grep "SIGQUIT"
```

### Memory Profiling
```bash
# Check memory usage
adb shell dumpsys meminfo com.example.pocket_flow

# Monitor memory in real-time
watch -n 1 'adb shell dumpsys meminfo com.example.pocket_flow | grep TOTAL'
```

### CPU Profiling
```bash
# Check CPU usage
adb shell top -n 1 | grep pocket_flow
```

---

**Last Updated**: 2026-04-26
**Version**: 1.0
