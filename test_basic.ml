open Alcotest
open Types

let _test_currency = { name = "Norwegian Krone"; short = "NOK"; symbol = Some "kr" }

let test_format_number () =
  let result = Formatting_utils.format_number 1234.56 in
  check string "format number" "1 234,56" result

let test_calculate_vat () =
  let (_, _, total) = Formatting_utils.calculate_vat "1000.00" 25 true in
  check (float 0.01) "vat calculation" 1250.0 total

let test_escape_string () =
  let result = Formatting_utils.escape_pdf_string "test" in
  check string "escape string" "test" result

let test_text_width () =
  let width = Pdf_text.calculate_text_width "Hello" 12.0 in
  check bool "text width positive" true (width > 0.0)

let () =
  run "Basic Tests" [
    ("Formatting", [
      test_case "format_number" `Quick test_format_number;
      test_case "calculate_vat" `Quick test_calculate_vat;
      test_case "escape_string" `Quick test_escape_string;
    ]);
    ("PDF Text", [
      test_case "text_width" `Quick test_text_width;
    ]);
  ]