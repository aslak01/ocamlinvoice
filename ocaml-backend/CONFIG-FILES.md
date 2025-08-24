# Configuration Files Reference

The OCaml invoice backend is now fully configuration-file driven, eliminating the need for JSON input files. All invoice data is managed through simple text files in the `config/` directory.

## 📁 Complete Configuration Files

### Required Files

#### `sender.txt` - Your Company Information
```
Your Company AS
123456789
Your Address 123
1234 Your City

Mark the transfer "reference123"
```

#### `customer.txt` - Customer Information (Single Invoice Mode)
```
Customer Company AS
987654321
Customer Address 456
5678 Customer City
```

#### `bankdetails.txt` - Payment Information
```
Account: 1234 56 78901
IBAN: NO93 1234 5678 901
BIC/SWIFT: BANKNO22
Bank Name: Your Bank
```

#### `currency.txt` - Currency Settings
```
Norwegian Krone
NOK
kr
```
Format: Full name, Short code, Symbol (one per line)

#### `dates.txt` - Invoice and Due Dates
```
2025-01-22
2025-02-21
```
Format: Invoice date, Due date (YYYY-MM-DD)

#### `vat.txt` - VAT Configuration
```
true
25
```
Format: VAT enabled (true/false), VAT rate percentage

#### `locale.txt` - Localization
```
nb-NO
```

#### `metadata.txt` - Invoice Metadata
```
Your Name
Your Service Description
Invoice Title
```
Format: Author, Service description, PDF title

### Optional Files (Override Behavior)

#### `recipients.txt` - Batch Processing Mode
When this file exists, the system generates separate invoices for each recipient:

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

#### `invoice.txt` - Custom Amount Override
When this file exists, it overrides line items with custom description and amount:

```
Software development consulting services
Web application development and maintenance

3750.50
```
Format: Description lines, blank line, total amount

#### `description.txt` + `amount.txt` - Separate Override
Alternative to `invoice.txt` for separate description and amount:

**description.txt:**
```
Custom invoice description
Multiple lines supported
```

**amount.txt:**
```
2500.00
```

## 🚀 Usage Examples

### Single Invoice Generation
```bash
# Configure customer.txt with single customer
dune exec src/main.exe          # Production mode
dune exec src/main.exe -- -dry  # Preview mode
```

### Batch Invoice Generation  
```bash
# Configure recipients.txt with multiple recipients
dune exec src/main.exe          # Generates invoice-2025-1.pdf, invoice-2025-2.pdf, etc.
dune exec src/main.exe -- -dry  # Generates invoice-PREVIEW-1.pdf, invoice-PREVIEW-2.pdf, etc.
```

### Custom Amount Processing
- **Single customer**: Uses full amount from `invoice.txt`
- **Multiple recipients**: Divides amount equally among recipients
- **Format support**: Both comma (3750,50) and decimal (3750.50) formats

## ⚙️ File Processing Priority

1. **Batch vs Single**: If `recipients.txt` exists → batch mode, else single customer mode
2. **Amount override**: `invoice.txt` → `description.txt` + `amount.txt` → default line items
3. **Customer source**: Batch mode uses `recipients.txt`, single mode uses `customer.txt`

## 🔄 Migration from JSON

The system previously required JSON input files. All JSON functionality has been replaced with simple text configuration files:

| JSON Field | Config File | Format |
|------------|-------------|---------|
| `locale` | `locale.txt` | `nb-NO` |
| `currency` | `currency.txt` | 3 lines: name, code, symbol |
| `yourCompany` | `sender.txt` | Multi-line company info |
| `customer` | `customer.txt` | Multi-line customer info |
| `invoiceDate`, `dueDate` | `dates.txt` | 2 lines: YYYY-MM-DD format |
| `vatEnabled`, `vatRate` | `vat.txt` | 2 lines: boolean, percentage |
| `author`, `service`, `pdfTitle` | `metadata.txt` | 3 lines |
| `lineItems` | `invoice.txt` or `description.txt`+`amount.txt` | Custom format |

## ✅ Benefits

- **Simplicity**: No JSON syntax requirements
- **Human-readable**: Plain text files easy to edit
- **Version control friendly**: Text files diff well
- **Scriptable**: Easy to automate with shell scripts  
- **Error-resistant**: No JSON parsing errors
- **Modular**: Each concern separated into dedicated files

This configuration system makes the OCaml backend truly standalone and eliminates any dependency on JSON input files.