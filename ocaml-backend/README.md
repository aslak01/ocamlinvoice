# OCaml Invoice Generator Backend

## 🎯 Core Features

- **Automatic Invoice Numbering**: Year-based sequential numbering (`2025-1`, `2025-2`, etc.)
- **Normalized Database Storage**: SQLite with relational schema for data integrity
- **Batch Processing**: Generate multiple invoices from `recipients.txt` file automatically
- **Custom Invoice Amount**: Override line items with `invoice.txt` for description and total amount
- **Preview Mode**: Dry-run capability to review invoices before committing to database
- **Multi-locale Support**: Norwegian (`nb-NO`) default with extensible localization
- **Professional PDF Output**: High-quality invoices with precise typography
- **Functional Architecture**: Pure functional design with immutable data structures

## 🚀 Quick Start

### Prerequisites

- OCaml (>= 5.2.x)
- Dune build system
- opam package manager

### Installation

```bash
# Install dependencies
opam install . --deps-only

# Or manually install required packages
opam install camlpdf yojson sqlite3 dune alcotest
```

### Basic Usage

```bash
# Compile the project
dune build

# Generate invoice with database storage (production mode)
dune exec ./src/main.exe examples/example-invoice.json

# Preview mode - no database changes
dune exec ./src/main.exe -- -dry examples/example-invoice.json

# Run tests
dune runtest

# Clean build artifacts
dune clean
```

## 📁 Project Structure

```
ocaml-backend/
├── src/                          # Source code
│   ├── main.ml                   # Entry point and CLI
│   ├── types.ml                  # Core data type definitions
│   ├── json_parser.ml            # JSON parsing and serialization
│   ├── database.ml + .mli        # SQLite operations and schema
│   ├── pdf_generator.ml          # Main PDF orchestrator
│   ├── formatting_utils.ml + .mli # Number/currency formatting utilities
│   ├── pdf_text.ml + .mli        # Low-level PDF text operations
│   ├── invoice_layout.ml + .mli  # Invoice-specific layout engine
│   ├── pdf_document.ml + .mli    # PDF document structure generation
│   ├── recipients_parser.ml + .mli # Batch processing utilities
│   ├── file_parsers.ml + .mli    # Config file parsing
│   └── dune                      # Build configuration
├── tests/                        # Test suite
│   ├── test_basic.ml             # Core functionality tests
│   └── dune                      # Test configuration
├── config/                       # Configuration files
│   ├── sender.txt                # Company information
│   ├── bankdetails.txt           # Payment details
│   ├── recipients.txt            # Batch processing recipients
│   ├── invoice.txt               # Custom amount override
│   ├── description.txt           # Invoice description
│   └── amount.txt                # Invoice amount
├── examples/                     # Sample data
├── out/                          # Generated PDF files
├── docs/                         # Documentation
├── dune-project                  # Project configuration
└── invoices.db                   # SQLite database (auto-created)
```

## 📄 Invoice Generation Modes

### 🏭 Production Mode (Default)

```bash
dune exec ./src/main.exe examples/example-invoice.json
```

- Generates unique invoice number (e.g., `2025-3`)
- Creates PDF file: `out/invoice-2025-3.pdf`
- Stores complete invoice data in normalized database
- Increments year-based counter atomically
- Full audit trail and data persistence

### 🔍 Preview Mode

```bash
dune exec ./src/main.exe -- -dry examples/example-invoice.json
```

- Generates PDF file: `out/invoice-PREVIEW.pdf`
- No database operations performed
- No counter increments
- Perfect for layout review and testing
- Safe for experimentation

## 📦 Batch Processing

### Automatic Detection

When a `recipients.txt` file exists in the working directory, the system automatically switches to batch processing mode.

### Recipients File Format

Create a `recipients.txt` file with recipient information separated by blank lines:

```
John Smith
john.smith@email.com
123 Main Street
Anytown, State 12345

Jane Johnson
jane.johnson@company.com
456 Oak Avenue
Business District
City, State 67890
```

### Batch Commands

```bash
# Batch preview mode
dune exec ./src/main.exe -- -dry examples/example-invoice.json
# → Creates: out/invoice-PREVIEW-1.pdf, out/invoice-PREVIEW-2.pdf, etc.

# Batch production mode
dune exec ./src/main.exe examples/example-invoice.json
# → Creates: out/invoice-2025-6.pdf, out/invoice-2025-7.pdf, etc.
```

## 💰 Custom Invoice Amount

### Invoice.txt Format

Create an `invoice.txt` file with description lines followed by a blank line and the total amount:

```
Software development consulting services
Web application development and maintenance

4500,00
```

### Amount Processing

- **Decimal Separators**: Supports both comma (`,`) and decimal point (`.`)
- **Single Invoice**: Uses the full amount from `invoice.txt`
- **Batch Processing**: Divides the total amount equally among all recipients
- **Line Item Replacement**: Replaces all JSON line items with single line from `invoice.txt`

## 🗄️ Database Schema

The application uses a sophisticated SQLite database with normalized relational design:

### Core Tables

- **`invoices`**: Main invoice records with auto-generated numbers
- **`companies`**: Normalized company information (sender/customer)
- **`banks`**: Bank account details with foreign key relationships
- **`currencies`**: Multi-currency support
- **`line_items`**: Invoice line items with foreign keys
- **`meta_strings`**: Localization and metadata storage
- **`invoice_counters`**: Year-based numbering system

### Database Operations

```bash
# View stored invoices
sqlite3 invoices.db "SELECT invoice_number, created_at FROM invoices;"

# Check current counters
sqlite3 invoices.db "SELECT year, counter FROM invoice_counters;"

# Export database backup
sqlite3 invoices.db .dump > backup.sql
```

## 🏗️ Architecture

### Functional Design

The application follows functional programming principles:

- **Immutability**: All data structures are immutable by default
- **Pure Functions**: No side effects in core business logic
- **Composability**: Functions compose naturally using pipelines
- **Type Safety**: Comprehensive `.mli` interfaces ensure contracts
- **Error Handling**: Result types for explicit error management

### Module Organization

```
main.ml ← Entry point
  ↓
pdf_generator.ml ← Orchestration
  ↓
┌─────────┬─────────┬─────────┐
│json_    │format   │database │
│parser   │utils    │         │
└────┬────┴────┬────┴────┬────┘
     ↓         ↓         ↓
  types.ml (Core Data Types)
     ↓
┌──────────┬──────────────┐
│pdf_text  │invoice_layout│
│(Low-level│(High-level   │
│PDF ops)  │layout engine)│
└──────────┴──────────────┘
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
dune runtest

# Run tests with verbose output
dune runtest --display verbose

# Run specific test modules
dune exec ./tests/test_basic.exe
```

### Test Coverage

- **Formatting Functions**: Number, currency, and date formatting
- **PDF Text Operations**: Text width calculations and positioning
- **VAT Calculations**: Tax computation accuracy
- **String Escaping**: UTF-8 to Latin-1 conversion

## 🔧 Dependencies

- **`camlpdf`**: PDF manipulation library with precise text metrics
- **`yojson`**: JSON parsing and manipulation
- **`sqlite3`**: SQLite database interface for OCaml
- **`unix`**: System interface for date/time operations
- **`dune`**: Build system with modular compilation
- **`alcotest`**: Testing framework (dev dependency)

## 📄 Configuration Files

### sender.txt

Your company information:

```
Your Company Name
Organization Number: 123456789
Address Line 1
Address Line 2
City, Postal Code
```

### bankdetails.txt

Payment information:

```
Bank Account: 1234.56.78901
IBAN: NO93 1234 5678 901
BIC/SWIFT: BANKNO22
Bank Name: Your Bank
```

### Example JSON Input

```json
{
  "locale": "nb-NO",
  "currency": { "name": "Norwegian Krone", "short": "NOK", "symbol": "kr" },
  "yourCompany": {
    "name": "Your Company AS",
    "orgno": "123456789",
    "address": "Your Address\nCity, Country"
  },
  "customer": {
    "name": "Customer Name",
    "orgno": "987654321",
    "address": "Customer Address\nCity, Country"
  },
  "invoiceDate": "2025-01-15",
  "dueDate": "2025-02-14",
  "lineItems": [
    {
      "date": "2025-01-15",
      "description": "Consulting services",
      "price": "2500,00"
    }
  ],
  "vatEnabled": true,
  "vatRate": 25
}
```

## 🔧 Troubleshooting

### Common Issues

```bash
# Issue: Missing dependencies
Error: Unbound module Sqlite3
# Solution: Install dependencies
opam install sqlite3 yojson camlpdf

# Issue: Database permission error
Error: Failed to open database
# Solution: Check file permissions or recreate
rm invoices.db  # Let it recreate with proper permissions

# Issue: UTF-8 encoding problems
Error: Invalid character in PDF text
# Solution: Check JSON input encoding
file -I examples/example-invoice.json  # Should be utf-8
```

### Debug Mode

```bash
# Check database integrity
sqlite3 invoices.db "PRAGMA integrity_check;"

# View recent invoices
sqlite3 invoices.db "SELECT * FROM invoices ORDER BY created_at DESC LIMIT 5;"
```

## 🌍 Internationalization

The system supports multiple locales through JSON metadata:

- **Primary**: Norwegian (`nb-NO`) - Default locale with complete translations
- **Framework**: Extensible for additional locales via JSON metadata
- **Elements**: Invoice headers, payment info, VAT descriptions, date/number formatting

## 📝 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Ensure all tests pass: `dune runtest`
6. Submit a pull request

This OCaml backend can be used independently of the GUI frontend and provides a complete command-line invoice generation solution with professional PDF output and robust database storage.

