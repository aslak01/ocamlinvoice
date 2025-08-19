# Invoice Generator

A professional OCaml-based invoice generation system with a modern cross-platform desktop GUI.

## Project Structure

This repository contains two main components:

### 🖥️ **Desktop Application** (`tauri-gui/`)
A modern cross-platform desktop application built with Tauri (Rust + Web technologies).

- **📁 Location**: `./tauri-gui/`
- **🚀 Technologies**: Tauri, Rust, HTML/CSS/JavaScript
- **📱 Platforms**: macOS, Linux, Windows
- **✨ Features**: Configuration editor, invoice history browser, PDF preview

**Quick Start:**
```bash
cd tauri-gui
npm install
npm run tauri dev
```

### ⚙️ **OCaml Backend** (`tauri-gui/ocaml-backend/`)
The core invoice generation engine written in OCaml.

- **📁 Location**: `./tauri-gui/ocaml-backend/`
- **🚀 Technologies**: OCaml, Dune, CamlPDF, SQLite
- **✨ Features**: PDF generation, database storage, batch processing

**Quick Start:**
```bash
cd tauri-gui/ocaml-backend
dune build
dune exec src/main.exe -- -dry  # Preview mode
```

## Installation

### For End Users
Download the latest desktop application from the [Releases page](https://github.com/username/ocaml-invoice/releases).

### For Developers
1. **Prerequisites**: OCaml, Dune, Node.js, Rust
2. **Clone**: `git clone <repository-url>`
3. **Setup**: Follow instructions in `tauri-gui/README.md`

## Features

- 📝 **Configuration Management**: Edit sender, bank details, and recipients
- 🚀 **Invoice Generation**: Create professional PDF invoices
- 📊 **History Browser**: View and download previously generated invoices
- 👁️ **PDF Preview**: Live preview of invoice PDFs
- 💾 **Database Storage**: SQLite-based invoice tracking
- 🌍 **Cross-Platform**: Works on macOS, Linux, and Windows
- 🔄 **Batch Processing**: Generate multiple invoices simultaneously

## Documentation

- **Main Documentation**: See `tauri-gui/README.md` for detailed setup
- **Installation Guide**: See `INSTALLATION.md` for platform-specific instructions
- **OCaml Backend**: See `tauri-gui/ocaml-backend/docs/` for technical details

## Development Workflow

The recommended development workflow is:

1. **Work in the Desktop App**: `cd tauri-gui && npm run tauri dev`
2. **Test OCaml Changes**: `cd tauri-gui/ocaml-backend && dune exec src/main.exe`
3. **Run Tests**: `cd tauri-gui/ocaml-backend && dune runtest`

## Clean Architecture

This project now has a clean, focused structure:
- All active development happens in `tauri-gui/`
- OCaml backend is self-contained within `tauri-gui/ocaml-backend/`
- No legacy files remain in the root directory

## License

MIT License - see LICENSE file for details.
