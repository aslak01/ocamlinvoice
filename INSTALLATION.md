# Installation Guide

## macOS Installation

### Option 1: Standard Installation

1. Download `InvoiceSplitter_X.X.X_aarch64.dmg` from [Releases](https://github.com/username/ocaml-invoice/releases)
2. Open the DMG file
3. Drag "InvoiceSplitter" to Applications folder

### If Gatekeeper Blocks the App

If you see "InvoiceSplitter cannot be opened because it is from an unidentified developer":

**Recommended Method - System Preferences:**

1. Try to open the app (it will be blocked)
2. Go to **System Preferences** → **Security & Privacy** → **General**
3. You'll see a message about "InvoiceSplitter" being blocked
4. Click **"Open Anyway"** next to that message
5. Enter your password when prompted
6. The app will now run normally

**Alternative Method - Command Line:**
Open Terminal and run:

```bash
xattr -d com.apple.quarantine "/Applications/InvoiceSplitter.app"
```

**Note**: Right-click → Open often doesn't work for unsigned apps and may only offer "Move to Trash".

## Linux Installation

### Ubuntu/Debian (.deb package)

```bash
# Download the .deb file, then:
sudo dpkg -i invoice-generator_X.X.X_amd64.deb

# If there are dependency issues:
sudo apt-get install -f
```

### Universal Linux (AppImage)

```bash
# Download the .AppImage file, then:
chmod +x Invoice_Generator_X.X.X_amd64.AppImage
./Invoice_Generator_X.X.X_amd64.AppImage
```

## Windows Installation

### Standard Installation

1. Download `InvoiceSplitter_X.X.X_x64.msi` from Releases
2. Double-click to run the installer
3. Follow the installation wizard

### If Windows SmartScreen Blocks the App

If you see "Windows protected your PC":

1. Click "More info"
2. Click "Run anyway"
3. The installer will proceed normally

### Alternative: NSIS Installer

If the MSI doesn't work, try the `.exe` installer:

1. Download `InvoiceSplitter_X.X.X_x64_en-US.exe`
2. Right-click → "Run as administrator" if needed
3. Follow the installation steps

## Troubleshooting

### macOS: "App is damaged and can't be opened"

```bash
# Remove extended attributes and quarantine
xattr -cr "/Applications/InvoiceSplitter.app"
```

### Linux: Missing dependencies

```bash
# Install WebKit dependencies
sudo apt-get install libwebkit2gtk-4.0-37
```

### Windows: "VCRUNTIME140.dll not found"

Install Microsoft Visual C++ Redistributable:

- Download from Microsoft's official website
- Install the x64 version

## Security Note

These applications are not code-signed with paid developer certificates. The security warnings are normal for unsigned applications. You can verify the integrity by:

1. Checking the SHA256 checksums provided with each release
2. Building from source code using the instructions in the repository
3. Reviewing the open-source code before installation

The applications do not require internet access and only access local files in the project directory.

