# macOS Installation Guide

## Installation Methods (In Order of Success Rate)

### Method 1: Terminal Installation (Most Reliable)
This bypasses Gatekeeper completely:

```bash
# 1. Download the DMG file from GitHub releases
# 2. Open Terminal and run:
cd ~/Downloads
hdiutil attach "Invoice Generator_*.dmg"
cp -R "/Volumes/Invoice Generator/Invoice Generator.app" /Applications/
hdiutil detach "/Volumes/Invoice Generator"

# 3. Remove quarantine attribute
xattr -d com.apple.quarantine "/Applications/Invoice Generator.app"

# 4. Launch the app
open "/Applications/Invoice Generator.app"
```

### Method 2: System Preferences Override
1. Try to open the app normally (it will be blocked)
2. Go to **System Preferences** → **Security & Privacy** → **General**
3. Look for a message about "Invoice Generator" being blocked
4. Click **"Open Anyway"** next to the message
5. Enter your password when prompted

### Method 3: Alternative Download Location
Sometimes downloading to a different location helps:

```bash
# Download to Desktop instead of Downloads folder
cd ~/Desktop
# Download the DMG here, then install normally
```

### Method 4: Temporary Disable Gatekeeper (Advanced)
**Warning**: Only do this temporarily and re-enable afterwards

```bash
# Disable Gatekeeper temporarily
sudo spctl --master-disable

# Install the app normally, then re-enable Gatekeeper
sudo spctl --master-enable
```

## Why These Issues Happen

- **No Developer Certificate**: The app isn't signed with Apple's paid developer certificate
- **Quarantine Attribute**: macOS marks downloaded files as potentially unsafe
- **Gatekeeper Policy**: macOS blocks unsigned applications by default

## Verification Steps

After installation, verify the app works:
```bash
# Check if app is properly installed
ls -la "/Applications/Invoice Generator.app"

# Check quarantine status (should show nothing after removal)
xattr -l "/Applications/Invoice Generator.app"

# Launch from terminal to see any error messages
open "/Applications/Invoice Generator.app"
```

## Troubleshooting

### "App is Damaged" Error
```bash
# Remove all extended attributes
sudo xattr -cr "/Applications/Invoice Generator.app"
```

### App Won't Launch
```bash
# Check for permission issues
chmod +x "/Applications/Invoice Generator.app/Contents/MacOS/"*
```

### Still Having Issues?
1. Try restarting your Mac after installation
2. Make sure you're running macOS 10.13 or later
3. Check Console.app for detailed error messages

## Security Note

This application is built from open source code and only accesses local files. The installation warnings are normal for unsigned applications. You can always:

- Review the source code on GitHub
- Build the application yourself using the provided instructions
- Use the command-line tools directly if you prefer not to install the GUI