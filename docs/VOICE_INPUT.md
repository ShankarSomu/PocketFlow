# Voice Input Feature

## Overview
PocketFlow now supports voice-to-text input in the Chat screen, making it easy to add transactions hands-free using your device's built-in speech recognition.

## How It Works

### Android
- Uses Android's native speech recognition service (Google Speech API)
- No internet required if you have offline speech recognition enabled on your device
- Supports multiple languages based on your device settings

### Features
- **Tap to speak**: Tap the microphone button to start voice input
- **Real-time transcription**: See your words appear as you speak
- **Auto-submit**: Automatically submits when you finish speaking
- **Visual feedback**: Pulsing red microphone icon while listening
- **Partial results**: Shows transcription in real-time as you speak

## Usage

1. Open the Chat screen
2. Tap the microphone icon (🎤) next to the input field
3. Grant microphone permission if prompted
4. Speak your transaction naturally:
   - "Bought groceries for $50"
   - "Got paid $3000 salary"
   - "Spent $25 on lunch at McDonald's"
5. The app will automatically transcribe and submit your command

## Examples

### Adding Expenses
- "Expense 45 food lunch"
- "Bought coffee for 5 dollars"
- "Spent 200 on groceries from Walmart"

### Adding Income
- "Income 3000 salary"
- "Got paid 500 freelance"

### With Accounts
- "Expense 100 shopping at Chase"
- "Income 2000 salary to checking"

## Tips
- Speak clearly and at a normal pace
- Include amounts, categories, and optional notes
- Mention account names if you want to specify which account
- The AI will understand natural language and convert it to proper commands

## Permissions Required
- **RECORD_AUDIO**: Required to capture voice input
- **BLUETOOTH** (optional): For Bluetooth headset support

## Troubleshooting

### "Speech recognition not available"
- Ensure Google app is installed and updated
- Check that speech recognition is enabled in device settings
- Try downloading offline speech recognition for your language

### Poor recognition accuracy
- Speak clearly in a quiet environment
- Check your device's language settings
- Ensure microphone is not blocked or damaged

### Permission denied
- Go to Settings → Apps → PocketFlow → Permissions
- Enable Microphone permission

## Privacy
- Voice data is processed by your device's native speech recognition
- No audio is sent to PocketFlow servers
- Speech recognition may use Google's services depending on your device settings
