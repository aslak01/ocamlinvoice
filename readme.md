# Invoice Splitter

## 🚀 Quick Start

### Desktop Application

```bash
npm install
npm run tauri dev
```

### OCaml Backend (Command Line)

```bash
cd ocaml-backend
dune build
dune exec src/main.exe -- -dry
```

## 📁 Project Structure

This repository contains two main components:

### 🖥️ **Desktop Application** (Root + Tauri Components)

A modern cross-platform desktop application built with Tauri.

- **📁 Frontend**: `./src/` (HTML/CSS/JavaScript)
- **📁 Rust Backend**: `./src-tauri/` (Tauri integration)
- **🚀 Technologies**: Tauri, Rust, HTML/CSS/JavaScript
- **📱 Platforms**: macOS, Linux, Windows
- **✨ Features**: Configuration editor, invoice history browser, PDF preview, settings management

### ⚙️ **OCaml Backend** (`./ocaml-backend/`)

The core invoice generation engine written in OCaml.

- **📁 Location**: `./ocaml-backend/`
- **🚀 Technologies**: OCaml, Dune, CamlPDF, SQLite
- **✨ Features**: PDF generation, database storage, batch processing
- **📖 Documentation**: See `./ocaml-backend/README.md` for detailed usage

## Installation

### For End Users

Download the latest desktop application from the [Releases page](https://github.com/username/ocaml-invoice/releases).

See [installation guide](./INSTALLATION.md) for info on how to make the binary run on your system.

### For Developers

1. **Prerequisites**: OCaml, Dune, Node.js, Rust
2. **Clone**: `git clone <repository-url>`
3. **Setup Desktop App**: `npm install && npm run tauri dev`
4. **Setup OCaml Backend**: `cd ocaml-backend && opam install . --deps-only && dune build`

## 🌟 Features

### Desktop Application

- **📝 Configuration Management**: Edit sender, bank details, and recipients via GUI
- **⚙️ Settings Management**: Configure output and config directories
- **📊 History Browser**: View and download previously generated invoices
- **👁️ PDF Preview**: Live preview of invoice PDFs in the application
- **🗂️ File System Integration**: Cross-platform directory management

### OCaml Backend

- **🧾 Invoice Generation**: Create professional PDF invoices
- **🗄️ Database Storage**: SQLite-based invoice tracking with full audit trail
- **📦 Batch Processing**: Generate multiple invoices simultaneously
- **🔍 Preview Mode**: Test invoice generation without database changes
- **🌍 Multi-locale Support**: Norwegian default with extensible internationalization
- **🖥️ Cross-Platform**: Works on macOS, Linux, and Windows

## 📚 Documentation

- **OCaml Backend**: See `./ocaml-backend/README.md` for standalone CLI usage
- **Installation Guide**: See `./INSTALLATION.md` for platform-specific instructions
- **Technical Details**: See `./ocaml-backend/docs/` for in-depth documentation
- **Development Guide**: See `./CLAUDE.md` for development workflow
