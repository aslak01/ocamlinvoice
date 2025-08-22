# Testing Guide

This document describes the testing strategy and implementation for the OCaml invoice splitter.

## Test Structure

The project uses [Alcotest](https://github.com/mirage/alcotest) as the testing framework, chosen for its simplicity and good OCaml integration.

### Test Organization

**`test_basic.ml`** - Core functionality tests covering:

- Number formatting (Norwegian conventions)
- VAT calculations
- Text escaping for PDF generation
- PDF text width calculations

## Running Tests

### Run All Tests

```bash
dune runtest
```

### Build and Test

```bash
dune build
dune runtest
```

### Test Output

Tests produce colored output showing:

- ✓ `[OK]` - Passing tests
- ✗ `[FAIL]` - Failed tests with detailed diff output

## Test Categories

### Unit Tests

- **Formatting Functions**: Number, currency, and date formatting
- **PDF Text Operations**: Text width calculation and positioning
- **VAT Calculations**: Tax computation with enabled/disabled scenarios
- **Text Escaping**: PDF string safety and Norwegian character handling

### Integration Testing Approach

While not currently implemented due to module dependency complexity, integration tests would cover:

- JSON parsing with real invoice files
- Complete PDF generation pipeline
- Error handling and edge cases
- Multi-locale support

## Test Data

The project includes test invoice files that can be used for manual testing:

- `example-invoice.json` - Standard invoice with VAT
- `test-formatting.json` - Large numbers and formatting edge cases
- `test-unicode.json` - Norwegian characters (æ, ø, å)

## Adding New Tests

1. **Add test functions** to `test_basic.ml`:

```ocaml
let test_new_feature () =
  let result = Module.function_to_test input in
  check expected_type "test description" expected_value result
```

2. **Register tests** in the test suite:

```ocaml
("Test Category", [
  test_case "test_name" `Quick test_new_feature;
]);
```

3. **Run tests**:

```bash
dune runtest
```

## Test Design Principles

### Functional Testing

- Tests focus on pure functions without side effects
- Input/output verification rather than implementation details
- Immutable test data to prevent test interaction

### Modular Testing

- Each module tested independently where possible
- Clear separation between unit and integration concerns
- Minimal test dependencies

### Error Coverage

- Boundary conditions (empty strings, zero values)
- Invalid input handling
- Expected exception scenarios
