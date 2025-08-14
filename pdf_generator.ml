open Pdf_text
open Invoice_layout
open Pdf_document

let generate_invoice_pdf invoice_data output_filename =
  let config = default_config in
  let layout_state = generate_invoice_layout config invoice_data in
  create_pdf_from_content layout_state.content output_filename
