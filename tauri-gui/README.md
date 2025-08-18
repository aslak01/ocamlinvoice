# Invoice Generator - Desktop GUI

A modern cross-platform desktop application for the OCaml Invoice Generator, built with Tauri.

## Features

- 📝 **Configuration Editor**: Edit sender, bank details, invoice details, and recipients
- 🚀 **Invoice Generation**: Generate invoices with integrated OCaml backend
- 👁️ **Preview Mode**: Dry-run preview without database storage
- 📊 **Invoice History**: Browse and preview previously generated invoices
- 💾 **PDF Management**: View and download invoice PDFs
- 🖥️ **Cross-Platform**: Works on macOS, Linux, and Windows

## Development

### Prerequisites

- [Node.js](https://nodejs.org/) (LTS version)
- [Rust](https://rustup.rs/)
- [OCaml](https://ocaml.org/) with dune (for invoice generation backend)

### Setup

1. Clone the repository
2. Navigate to the tauri-gui directory:
   ```bash
   cd tauri-gui
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Run in development mode:
   ```bash
   npm run tauri dev
   ```

### Building

To build for production:

```bash
npm run tauri build
```

This will create platform-specific bundles in `src-tauri/target/release/bundle/`

## Releases

Releases are automatically built for all platforms when a tag is pushed:

- **macOS**: `.dmg` installer (Apple Silicon on GitHub Actions, Intel via Rosetta)
- **Linux**: `.deb` package and `.AppImage`
- **Windows**: `.msi` installer and `.exe` (NSIS)

### Creating a Release

1. Update version in `package.json` and `src-tauri/tauri.conf.json`
2. Commit changes
3. Create and push a tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. GitHub Actions will automatically build and create a release with binaries

## Architecture

The application consists of:

- **Frontend**: HTML/CSS/JavaScript with modern web technologies
- **Backend**: Rust with Tauri framework for system integration
- **OCaml Integration**: Invokes OCaml CLI for invoice processing
- **Database**: SQLite for invoice storage and history

## File Structure

```
tauri-gui/
├── src/                    # Frontend (HTML/CSS/JS)
├── src-tauri/             # Rust backend
│   ├── src/               # Rust source code
│   ├── icons/             # Application icons
│   ├── Cargo.toml         # Rust dependencies
│   └── tauri.conf.json    # Tauri configuration
├── ocaml-backend/         # OCaml invoice generation backend
│   ├── src/               # OCaml source code
│   ├── config/            # Configuration files
│   ├── examples/          # Example data
│   ├── tests/             # Test suite
│   └── dune-project       # OCaml build configuration
├── package.json           # Node.js dependencies
└── README.md              # This file
```

## Installation

Download the latest release for your platform from the [Releases page](https://github.com/username/ocaml-invoice/releases).

### macOS Users
If you see a security warning, right-click the app and select "Open", then click "Open" again. This only needs to be done once.

### Windows Users  
If Windows SmartScreen blocks the installer, click "More info" then "Run anyway".

See [INSTALLATION.md](../INSTALLATION.md) for detailed instructions.

## Configuration

The app includes a bundled OCaml invoice generator backend in the `ocaml-backend/` directory. It reads and writes configuration files in the `ocaml-backend/config/` directory.

## Recommended IDE Setup

- [VS Code](https://code.visualstudio.com/) + [Tauri](https://marketplace.visualstudio.com/items?itemName=tauri-apps.tauri-vscode) + [rust-analyzer](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer)

## License

MIT License - see LICENSE file for details.
