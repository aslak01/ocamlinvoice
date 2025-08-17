open Printf

let usage_msg = "invoice-generator [-dry] <json-file>"
let input_file = ref ""
let dry_run = ref false

let set_input_file filename = input_file := filename

let spec_list = [
  ("-dry", Arg.Set dry_run, " Generate PDF without saving to database (preview mode)");
]

let ensure_output_directory () =
  let out_dir = "out" in
  try
    let _ = Unix.stat out_dir in
    ()
  with
  | Unix.Unix_error (Unix.ENOENT, _, _) ->
      Unix.mkdir out_dir 0o755
  | _ -> ()

let generate_single_invoice invoice_data customer_info invoice_number_or_preview is_preview invoice_info_opt =
  let updated_with_customer = 
    Invoice_src.Types.update_invoice_customer_and_number invoice_data customer_info invoice_number_or_preview in
  
  let final_invoice_data = 
    match invoice_info_opt with
    | Some info ->
        Invoice_src.Types.update_invoice_with_single_line updated_with_customer info.Invoice_src.Invoice_parser.description info.Invoice_src.Invoice_parser.total_amount
    | None ->
        updated_with_customer in
  
  ensure_output_directory ();
  let output_file = Printf.sprintf "out/invoice-%s.pdf" invoice_number_or_preview in
  printf "Generating PDF: %s...\n" output_file;
  Invoice_src.Pdf_generator.generate_invoice_pdf final_invoice_data output_file;
  printf "PDF generated successfully: %s\n" output_file;
  
  if not is_preview then (
    printf "Reading PDF content for storage...\n";
    let pdf_content = 
      let ic = open_in_bin output_file in
      let length = in_channel_length ic in
      let content = really_input_string ic length in
      close_in ic;
      content in
    (final_invoice_data, pdf_content)
  ) else (
    (final_invoice_data, "")
  )

let process_single_invoice db invoice_data customer_info invoice_info_opt =
  match Invoice_src.Database.generate_invoice_number db with
  | Error msg ->
      eprintf "Failed to generate invoice number: %s\n" msg;
      Error msg
  | Ok invoice_number -> (
      printf "Generated invoice number: %s\n" invoice_number;
      
      let (updated_invoice_data, pdf_content) = 
        generate_single_invoice invoice_data customer_info invoice_number false invoice_info_opt in
      
      printf "Storing invoice in database...\n";
      match Invoice_src.Database.store_invoice db invoice_number updated_invoice_data pdf_content with
      | Error msg ->
          eprintf "Failed to store invoice: %s\n" msg;
          Error msg
      | Ok () ->
          printf "Invoice stored in database with number: %s\n" invoice_number;
          Ok invoice_number
  )

let process_recipients invoice_data recipients invoice_info_opt =
  printf "Connecting to database...\n";
  match Invoice_src.Database.get_or_create_connection () with
  | Error msg ->
      eprintf "Database error: %s\n" msg;
      exit 1
  | Ok db -> (
      printf "Processing %d recipients...\n" (List.length recipients);
      
      (* Calculate per-recipient invoice info if invoice.txt is present *)
      let per_recipient_invoice_info = 
        match invoice_info_opt with
        | Some info ->
            let amount_per_recipient = Invoice_src.Invoice_parser.calculate_amount_per_recipient info.Invoice_src.Invoice_parser.total_amount (List.length recipients) in
            printf "Dividing total amount %.2f NOK equally among %d recipients: %.2f NOK each\n" 
              info.Invoice_src.Invoice_parser.total_amount (List.length recipients) amount_per_recipient;
            Some { Invoice_src.Invoice_parser.description = info.Invoice_src.Invoice_parser.description; total_amount = amount_per_recipient }
        | None -> 
            None in
      
      let rec process_all successful_count = function
        | [] -> 
            printf "Batch processing complete: %d invoices generated successfully\n" successful_count;
            let _ = Invoice_src.Database.close_connection db in
            ()
        | recipient :: remaining_recipients ->
            printf "\n--- Processing recipient: %s ---\n" recipient.Invoice_src.Types.name;
            match process_single_invoice db invoice_data recipient per_recipient_invoice_info with
            | Ok invoice_number ->
                printf "✓ Successfully generated invoice %s for %s\n" invoice_number recipient.Invoice_src.Types.name;
                process_all (successful_count + 1) remaining_recipients
            | Error _ ->
                eprintf "✗ Failed to generate invoice for %s\n" recipient.Invoice_src.Types.name;
                process_all successful_count remaining_recipients
      in
      process_all 0 recipients
  )

let () =
  Arg.parse spec_list set_input_file usage_msg;
  
  if !input_file = "" then (
    eprintf "Error: Please provide a JSON file as input\n";
    eprintf "Usage: %s [-dry] <json-file>\n" Sys.argv.(0);
    eprintf "Example: %s invoice-data.json\n" Sys.argv.(0);
    eprintf "         %s -dry invoice-data.json  (preview mode)\n" Sys.argv.(0);
    eprintf "\nRecipients: If recipients.txt exists, generates invoices for each recipient\n";
    exit 1
  );
  
  try
    printf "Reading invoice data from %s...\n" !input_file;
    let invoice_data = Invoice_src.Json_parser.load_from_file !input_file in
    
    (* Check for invoice.txt file and update invoice data if present *)
    let invoice_file = "invoice.txt" in
    let (final_invoice_data, invoice_info_opt) = 
      if Invoice_src.Invoice_parser.invoice_file_exists invoice_file then (
        printf "Found %s - using custom invoice description and amount\n" invoice_file;
        match Invoice_src.Invoice_parser.parse_invoice_file invoice_file with
        | Some info ->
            printf "Invoice description: %s\n" (if info.Invoice_src.Invoice_parser.description = "" then "(empty)" else info.Invoice_src.Invoice_parser.description);
            printf "Total amount: %.2f NOK\n" info.Invoice_src.Invoice_parser.total_amount;
            (invoice_data, Some info)
        | None ->
            eprintf "Warning: Failed to parse %s, using original invoice data\n" invoice_file;
            (invoice_data, None)
      ) else (
        (invoice_data, None)
      ) in
    
    (* Check for recipients.txt file *)
    let recipients_file = "recipients.txt" in
    
    if Invoice_src.Recipients_parser.recipients_file_exists recipients_file then (
      printf "Found %s - generating invoices for multiple recipients\n" recipients_file;
      let recipients = Invoice_src.Recipients_parser.parse_recipients_file recipients_file in
      
      if List.length recipients = 0 then (
        eprintf "Error: No valid recipients found in %s\n" recipients_file;
        exit 1
      );
      
      if !dry_run then (
        printf "DRY RUN MODE - Preview mode for batch processing\n";
        printf "Would generate %d invoices for:\n" (List.length recipients);
        
        (* Calculate per-recipient preview info if invoice.txt is present *)
        let per_recipient_preview_info = 
          match invoice_info_opt with
          | Some info ->
              let amount_per_recipient = Invoice_src.Invoice_parser.calculate_amount_per_recipient info.Invoice_src.Invoice_parser.total_amount (List.length recipients) in
              printf "Would divide total amount %.2f NOK equally among %d recipients: %.2f NOK each\n" 
                info.Invoice_src.Invoice_parser.total_amount (List.length recipients) amount_per_recipient;
              Some { Invoice_src.Invoice_parser.description = info.Invoice_src.Invoice_parser.description; total_amount = amount_per_recipient }
          | None -> 
              None in
        
        List.iteri (fun i recipient ->
          printf "  %d. %s\n" (i + 1) recipient.Invoice_src.Types.name;
          let preview_name = Printf.sprintf "PREVIEW-%d" (i + 1) in
          let (_, _) = generate_single_invoice final_invoice_data recipient preview_name true per_recipient_preview_info in
          ()
        ) recipients;
        printf "\nUse without -dry flag to generate actual invoices with database storage\n"
      ) else (
        process_recipients final_invoice_data recipients invoice_info_opt
      )
    ) else (
      (* Single invoice mode (original behavior) *)
      if !dry_run then (
        printf "DRY RUN MODE - Preview only, not saving to database\n";
        let original_customer = Invoice_src.Types.get_customer final_invoice_data in
        let (_, _) = generate_single_invoice final_invoice_data original_customer "PREVIEW" true invoice_info_opt in
        printf "Use without -dry flag to generate with real invoice number and save to database\n"
      ) else (
        printf "Connecting to database...\n";
        match Invoice_src.Database.get_or_create_connection () with
        | Error msg ->
            eprintf "Database error: %s\n" msg;
            exit 1
        | Ok db -> (
            let original_customer = Invoice_src.Types.get_customer final_invoice_data in
            match process_single_invoice db final_invoice_data original_customer invoice_info_opt with
            | Ok _ -> 
                let _ = Invoice_src.Database.close_connection db in
                ()
            | Error _ ->
                let _ = Invoice_src.Database.close_connection db in
                exit 1
        )
      )
    )
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