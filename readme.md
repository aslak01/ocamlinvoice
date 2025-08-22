# Invoice Splitter

A professional OCaml-based invoice generation system with a modern cross-platform desktop GUI.

**Quick Start:**

```bash
cd tauri-gui
npm install
npm run tauri dev
```

### Backend

The core invoice generation engine written in OCaml.

- ** Location**: `./tauri-gui/ocaml-backend/`
- ** Technologies**: OCaml, Dune, CamlPDF, SQLite
- ** Features**: PDF generation, database storage, batch processing

**Quick Start:**

```bash
cd tauri-gui/ocaml-backend
dune build
dune exec src/main.exe -- -dry
```

## Installation

### For End Users

Download the latest desktop application from the [Releases page](https://github.com/username/ocaml-invoice/releases).

See [installation guide](./INSTALLATION.md) for info on how to make the binary run on your system.

### For Developers

1. **Prerequisites**: OCaml, Dune, Node.js, Rust
2. **Clone**: `git clone <repository-url>`
3. **Setup**: Follow instructions in `tauri-gui/README.md`

## Features

- **Configuration Management**: Edit sender, bank details, and recipients
- **Invoice Generation**: Create professional PDF invoices
- **History Browser**: View and download previously generated invoices
- **PDF Preview**: Live preview of invoice PDFs
- **Database Storage**: SQLite-based invoice tracking
- **Cross-Platform**: Works on macOS, Linux, and Windows
- **Batch Processing**: Generate multiple invoices simultaneously

## Documentation

- **Main Documentation**: See `tauri-gui/README.md` for detailed setup
- **Installation Guide**: See `INSTALLATION.md` for platform-specific instructions
- **OCaml Backend**: See `tauri-gui/ocaml-backend/docs/` for technical details
