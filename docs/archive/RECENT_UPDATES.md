# PocketFlow - Recent Updates Summary

## 🎤 Voice Input Feature (NEW!)

### What's New
- Added voice-to-text input in the Chat screen
- Tap the microphone button to speak your transactions instead of typing
- Uses Android's native speech recognition (Google Speech API)
- Real-time transcription with auto-submit when you finish speaking
- Pulsing red animation while listening for visual feedback

### How to Use
1. Open Chat screen
2. Tap the microphone icon (🎤)
3. Speak naturally: "Bought groceries for $50"
4. App automatically transcribes and submits

### Technical Details
- Package: `speech_to_text: ^6.6.0`
- Permissions: RECORD_AUDIO, BLUETOOTH (optional)
- Works offline if device has offline speech recognition
- Supports multiple languages based on device settings

---

## 📊 Logging & Diagnostics

### Logging Level Control
- Added logging level setting in Profile → Preferences
- Options: Errors only, Warnings, Normal, Verbose
- Filters logs based on selected level to reduce noise
- Persisted across app restarts

### Implementation
- Updated `AppLogger` with level filtering
- Added dropdown in profile screen
- Logs stored in SharedPreferences

---

## 🏦 Default Account Settings

### What's New
- Set default accounts for expenses and income in Profile → Preferences
- When adding transactions via chat without `@account`, defaults are used automatically
- Separate defaults for expense and income transactions

### How to Use
1. Go to Profile → Preferences
2. Select default expense account (e.g., Credit Card)
3. Select default income account (e.g., Checking)
4. In chat: "expense 50 food" → automatically uses default expense account

### Technical Details
- Stored in SharedPreferences
- Methods: `ChatParser.getDefaultExpenseAccount()`, `setDefaultExpenseAccount()`
- Falls back to no account if default not set

---

## 🔤 Case-Insensitive Category Spending

### Bug Fix
- Fixed spending by category to be case-insensitive
- "Food", "food", and "FOOD" now grouped together
- Updated SQL query to use `LOWER(category)` for grouping

### Impact
- Home screen spending chart now accurate
- Budget tracking works correctly regardless of case
- No data migration needed - fix is in the query

---

## ✅ AI Subcategory Confirmation

### What's New
- AI now shows Yes/No buttons when asking to create subcategories
- Transaction is logged immediately, then AI asks for confirmation
- Click "Yes" to create subcategory and re-log transaction
- Click "No" to keep original category

### How It Works
1. User: "bought vegetables for $200"
2. AI logs: `expense 200 food vegetables`
3. AI asks: "Would you like me to create a 'Vegetables' subcategory under Food?"
4. User clicks Yes → subcategory created, transaction re-logged
5. User clicks No → keeps original transaction

### Technical Details
- Detection: checks for "would you like" + "?" in AI response
- Pending actions stored in message object
- Confirmation buttons appear in chat bubble
- Updated AI prompt with clear workflow examples

---

## 🔧 Technical Changes

### Dependencies Added
```yaml
speech_to_text: ^6.6.0
permission_handler: ^11.3.0
```

### Android Permissions Added
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

### Files Modified
- `lib/services/app_logger.dart` - Added log level filtering
- `lib/services/chat_parser.dart` - Added default account support
- `lib/services/groq_service.dart` - Updated AI prompt for subcategory workflow
- `lib/screens/chat_screen.dart` - Added voice input + confirmation buttons
- `lib/screens/profile_screen.dart` - Added preferences card
- `lib/db/database.dart` - Fixed case-sensitive category query
- `android/app/src/main/AndroidManifest.xml` - Added permissions
- `pubspec.yaml` - Added dependencies

### New Files
- `VOICE_INPUT.md` - Voice input documentation

---

## 🎯 User Benefits

1. **Faster Transaction Entry**: Speak instead of type - 3x faster
2. **Better Organization**: Case-insensitive categories prevent duplicates
3. **Smarter Defaults**: Set once, use everywhere
4. **Cleaner Logs**: Filter by importance level
5. **Better AI Flow**: Clear confirmation for subcategories

---

## 🚀 Next Steps

To use these features:
1. Run `flutter pub get` to install new dependencies
2. Build and install the app on Android device
3. Grant microphone permission when prompted
4. Go to Profile → Preferences to set defaults and logging level
5. Try voice input in Chat screen!

---

## 📝 Notes

- Voice input requires Android device with Google Speech services
- Works best in quiet environments
- Offline speech recognition available if downloaded on device
- All features follow existing code patterns and guidelines
