open Printf

let usage_msg = "invoice-generator <json-file>"
let input_file = ref ""

let set_input_file filename = input_file := filename

let spec_list = []

let () =
  Arg.parse spec_list set_input_file usage_msg;
  
  if !input_file = "" then (
    eprintf "Error: Please provide a JSON file as input\n";
    eprintf "Usage: %s <json-file>\n" Sys.argv.(0);
    eprintf "Example: %s invoice-data.json\n" Sys.argv.(0);
    exit 1
  );
  
  try
    printf "Reading invoice data from %s...\n" !input_file;
    let invoice_data = Json_parser.load_from_file !input_file in
    
    printf "Generating PDF...\n";
    let output_file = "invoice.pdf" in
    Pdf_generator.generate_invoice_pdf invoice_data output_file;
    
    printf "PDF generated successfully: %s\n" output_file;
  with
  | Sys_error msg ->
      eprintf "File error: %s\n" msg;
      exit 1
  | Yojson.Json_error msg ->
      eprintf "JSON parsing error: %s\n" msg;
      exit 1
  | exn ->
      eprintf "Error: %s\n" (Printexc.to_string exn);
      exit 1