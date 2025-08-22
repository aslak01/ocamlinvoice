# CamlPDF Text Placement and Formatting Guide

This guide covers text placement and formatting capabilities in CamlPDF based on the official documentation at http://www.coherentpdf.com/camlpdf.

## Core Modules for Text Operations

### Pdfops - PDF Operations and Commands

The `Pdfops` module provides the fundamental PDF graphics operators for text manipulation:

#### Text Positioning Commands
- `Op_Td (x, y)` - Move text position by relative coordinates
- `Op_TD (x, y)` - Move text position and set leading
- `Op_Tm (a, b, c, d, e, f)` - Set text transformation matrix

#### Font and Text State
- `Op_Tf (font_name, size)` - Select font and size
- `Op_Tr mode` - Set text rendering mode
- `Op_Tc spacing` - Set character spacing
- `Op_Tw spacing` - Set word spacing

#### Text Output
- `Op_Tj text` - Show text string
- `Op_TJ array` - Show text with individual glyph positioning

### Pdftext - Text Processing and Font Handling

The `Pdftext` module handles complex text processing:

#### Font Types and Encoding
- Supports Type1, TrueType, and CID-keyed fonts
- Handles multiple encodings (UTF-8, UTF-16BE, PDFDocEncoding)
- Unicode codepoint manipulation

#### Key Functions
```ocaml
read_font : Pdf.t -> Pdf.pdfobject -> font
write_font : Pdf.t -> font -> Pdf.pdfobject * Pdf.t
text_extractor_of_font : Pdf.t -> font -> text_extractor
codepoints_of_text : encoding -> string -> int list
```

### Pdfstandard14 - Standard PDF Fonts

The `Pdfstandard14` module provides utilities for the 14 standard PDF fonts:

#### Text Width Calculation
```ocaml
textwidth : bool -> font -> string -> int
```
- Calculates string width in millipoints
- Optional kerning support
- Essential for precise text positioning

#### Font Metrics
```ocaml
baseline_adjustment : font -> int
afm_data : font -> afm_data option
stemv_of_standard_font : font -> int
flags_of_standard_font : font -> int
```

## Text Placement Workflow

### 1. Font Selection and Setup

```ocaml
(* Select font and size *)
let font_ops = [Op_Tf ("Helvetica", 12.0)]

(* Set text rendering mode if needed *)
let render_ops = [Op_Tr 0] (* 0 = fill text *)
```

### 2. Text Positioning

#### Absolute Positioning
```ocaml
(* Set absolute position using transformation matrix *)
let position_ops = [Op_Tm (1.0, 0.0, 0.0, 1.0, x, y)]
```

#### Relative Positioning
```ocaml
(* Move by relative offset *)
let move_ops = [Op_Td (dx, dy)]

(* Move and set leading for next line *)
let move_with_leading = [Op_TD (dx, dy)]
```

### 3. Text Output

#### Simple Text
```ocaml
let text_ops = [Op_Tj "Hello World"]
```

#### Text with Custom Spacing
```ocaml
(* Array format: [text; spacing; text; spacing; ...] *)
let spaced_text = [Op_TJ [String "Hello"; Number (-100); String "World"]]
```

### 4. Text Spacing Control

```ocaml
(* Character spacing (in text units) *)
let char_spacing = [Op_Tc 2.0]

(* Word spacing (applies to space character) *)
let word_spacing = [Op_Tw 5.0]
```

## Advanced Text Formatting

### Text Width Calculation

```ocaml
open Pdfstandard14

(* Calculate text width for positioning *)
let text = "Sample Text"
let font = TimesRoman
let width_in_millipoints = textwidth false font text
let width_in_points = float_of_int width_in_millipoints /. 1000.0
```

### Coordinate Transformations

Using `Pdftransform` for complex text positioning:

```ocaml
open Pdftransform

(* Create transformation matrix *)
let translation = [Translate (x, y)]
let rotation = [Rotate (angle_in_radians)]
let scale = [Scale (sx, sy)]

(* Combine transformations *)
let combined = translation @ rotation @ scale
let matrix = transform_matrix combined
```

### Multi-line Text Layout

```ocaml
let rec place_lines lines x y line_height =
  match lines with
  | [] -> []
  | line :: rest ->
      let line_ops = [
        Op_Tm (1.0, 0.0, 0.0, 1.0, x, y);
        Op_Tj line
      ] in
      line_ops @ place_lines rest x (y -. line_height) line_height
```

## Page Integration

### Adding Text to Pages

Using `Pdfpage` module:

```ocaml
(* Create text operations *)
let text_ops = [
  Op_Tf ("Helvetica", 12.0);
  Op_Tm (1.0, 0.0, 0.0, 1.0, 100.0, 700.0);
  Op_Tj "Hello World"
]

(* Add to page content *)
let updated_page = Pdfpage.prepend_operators pdf text_ops page
```

## Text Encoding and Special Characters

### Unicode Support
```ocaml
(* Convert text to codepoints *)
let codepoints = Pdftext.codepoints_of_text encoding text

(* Handle special characters with proper encoding *)
let escaped_text = escape_special_chars text
```

### Character Escaping
For PDF text strings, escape these characters:
- `(` → `\(`
- `)` → `\)`
- `\` → `\\`
- Characters > 127: Use octal notation `\nnn`

## Best Practices

### 1. Text Measurement
Always calculate text width before positioning:
```ocaml
let text_width = Pdfstandard14.textwidth false font text
let centered_x = (page_width -. text_width) /. 2.0
```

### 2. Coordinate System
- PDF origin (0,0) is bottom-left
- Y-axis increases upward
- Text baseline positioning

### 3. Font Resource Management
```ocaml
(* Ensure font is available in page resources *)
let font_dict = [("/F1", font_object)]
let resources = add_fonts_to_resources page.resources font_dict
```

### 4. Text State Management
Group related text operations:
```ocaml
let text_block = [
  (* Begin text object *)
  "BT";
  (* Set font and position *)
  Op_Tf ("Helvetica", 12.0);
  Op_Tm (1.0, 0.0, 0.0, 1.0, x, y);
  (* Output text *)
  Op_Tj text;
  (* End text object *)
  "ET"
]
```

## Common Patterns

### Right-aligned Text
```ocaml
let right_align_text text font size right_edge y =
  let width = Pdfstandard14.textwidth false font text in
  let x = right_edge -. (float_of_int width /. 1000.0 *. size) in
  [Op_Tm (1.0, 0.0, 0.0, 1.0, x, y); Op_Tj text]
```

### Justified Text
```ocaml
let justify_text words target_width font size =
  let total_word_width = List.fold_left (+) 0 
    (List.map (Pdfstandard14.textwidth false font) words) in
  let space_width = Pdfstandard14.textwidth false font " " in
  let extra_space = target_width - total_word_width - 
    (List.length words - 1) * space_width in
  let space_adjustment = extra_space / (List.length words - 1) in
  (* Use Op_TJ with calculated spacing *)
```

This guide provides the foundation for sophisticated text layout and formatting using CamlPDF's comprehensive text handling capabilities.