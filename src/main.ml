open Printf

let usage_msg = "invoice-generator [-dry]"
let dry_run = ref false

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

let generate_single_invoice invoice_data bank_lines customer_info invoice_number_or_preview is_preview invoice_info_opt =
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
  Invoice_src.Pdf_generator.generate_invoice_pdf final_invoice_data bank_lines output_file;
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

let process_single_invoice db invoice_data bank_lines customer_info invoice_info_opt =
  match Invoice_src.Database.generate_invoice_number db with
  | Error msg ->
      eprintf "Failed to generate invoice number: %s\n" msg;
      Error msg
  | Ok invoice_number -> (
      printf "Generated invoice number: %s\n" invoice_number;
      
      let (updated_invoice_data, pdf_content) = 
        generate_single_invoice invoice_data bank_lines customer_info invoice_number false invoice_info_opt in
      
      printf "Storing invoice in database...\n";
      match Invoice_src.Database.store_invoice db invoice_number updated_invoice_data pdf_content with
      | Error msg ->
          eprintf "Failed to store invoice: %s\n" msg;
          Error msg
      | Ok () ->
          printf "Invoice stored in database with number: %s\n" invoice_number;
          Ok invoice_number
  )

let process_recipients invoice_data bank_lines recipients invoice_info_opt =
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
            match process_single_invoice db invoice_data bank_lines recipient per_recipient_invoice_info with
            | Ok invoice_number ->
                printf "✓ Successfully generated invoice %s for %s\n" invoice_number recipient.Invoice_src.Types.name;
                process_all (successful_count + 1) remaining_recipients
            | Error _ ->
                eprintf "✗ Failed to generate invoice for %s\n" recipient.Invoice_src.Types.name;
                process_all successful_count remaining_recipients
      in
      process_all 0 recipients
  )

let run_cli_mode dry_run =
  try
    (* Required files *)
    let sender_file = "config/sender.txt" in
    let bank_file = "config/bankdetails.txt" in
    let description_file = "config/description.txt" in
    let amount_file = "config/amount.txt" in
    let invoice_file = "config/invoice.txt" in
    
    (* Check required files exist *)
    if not (Invoice_src.File_parsers.file_exists sender_file) then (
      eprintf "Error: Required file %s not found\n" sender_file;
      exit 1
    );
    
    if not (Invoice_src.File_parsers.file_exists bank_file) then (
      eprintf "Error: Required file %s not found\n" bank_file;
      exit 1
    );
    
    (* Check for new separate files first, fallback to old format *)
    let has_separate_files = 
      Invoice_src.File_parsers.file_exists description_file && 
      Invoice_src.File_parsers.file_exists amount_file in
    
    let has_old_invoice_file = Invoice_src.File_parsers.file_exists invoice_file in
    
    if not has_separate_files && not has_old_invoice_file then (
      eprintf "Error: Neither separate files (%s, %s) nor old format file (%s) found\n" 
        description_file amount_file invoice_file;
      exit 1
    );
    
    (* Parse required files *)
    printf "Reading sender details from %s...\n" sender_file;
    let sender_lines = Invoice_src.File_parsers.parse_text_file sender_file in
    
    printf "Reading bank details from %s...\n" bank_file;
    let bank_lines = Invoice_src.File_parsers.parse_text_file bank_file in
    
    (* Parse invoice details using appropriate method *)
    let invoice_info = 
      if has_separate_files then (
        printf "Reading invoice details from %s and %s...\n" description_file amount_file;
        match Invoice_src.Invoice_parser.parse_invoice_files description_file amount_file with
        | Some info -> info
        | None -> 
            eprintf "Error: Failed to parse %s or %s\n" description_file amount_file;
            exit 1
      ) else (
        printf "Reading invoice details from %s...\n" invoice_file;
        match Invoice_src.Invoice_parser.parse_invoice_file invoice_file with
        | Some info -> info
        | None -> 
            eprintf "Error: Failed to parse %s\n" invoice_file;
            exit 1
      ) in
    
    printf "Invoice description: %s\n" (if invoice_info.Invoice_src.Invoice_parser.description = "" then "(empty)" else invoice_info.Invoice_src.Invoice_parser.description);
    printf "Total amount: %.2f NOK\n" invoice_info.Invoice_src.Invoice_parser.total_amount;
    
    (* Check for recipients.txt file *)
    let recipients_file = "config/recipients.txt" in
    
    if Invoice_src.Recipients_parser.recipients_file_exists recipients_file then (
      printf "Found %s - generating invoices for multiple recipients\n" recipients_file;
      let recipients = Invoice_src.Recipients_parser.parse_recipients_file recipients_file in
      
      if List.length recipients = 0 then (
        eprintf "Error: No valid recipients found in %s\n" recipients_file;
        exit 1
      );
      
      (* Create basic invoice data for first recipient to get structure *)
      let dummy_customer = List.hd recipients in
      let base_invoice_data = Invoice_src.Types.create_basic_invoice_data 
        sender_lines bank_lines dummy_customer "TEMP" 
        invoice_info.Invoice_src.Invoice_parser.description 
        invoice_info.Invoice_src.Invoice_parser.total_amount in
      
      if dry_run then (
        printf "DRY RUN MODE - Preview mode for batch processing\n";
        printf "Would generate %d invoices for:\n" (List.length recipients);
        
        let amount_per_recipient = Invoice_src.Invoice_parser.calculate_amount_per_recipient invoice_info.Invoice_src.Invoice_parser.total_amount (List.length recipients) in
        printf "Would divide total amount %.2f NOK equally among %d recipients: %.2f NOK each\n" 
          invoice_info.Invoice_src.Invoice_parser.total_amount (List.length recipients) amount_per_recipient;
        
        let per_recipient_info = { Invoice_src.Invoice_parser.description = invoice_info.Invoice_src.Invoice_parser.description; total_amount = amount_per_recipient } in
        
        List.iteri (fun i recipient ->
          printf "  %d. %s\n" (i + 1) recipient.Invoice_src.Types.name;
          let preview_name = Printf.sprintf "PREVIEW-%d" (i + 1) in
          let (_, _) = generate_single_invoice base_invoice_data bank_lines recipient preview_name true (Some per_recipient_info) in
          ()
        ) recipients;
        printf "\nUse without -dry flag to generate actual invoices with database storage\n"
      ) else (
        process_recipients base_invoice_data bank_lines recipients (Some invoice_info)
      )
    ) else (
      eprintf "Error: No recipients.txt file found\n";
      eprintf "Please create a recipients.txt file with recipient information\n";
      exit 1
    )
  with
  | Sys_error msg ->
      eprintf "File error: %s\n" msg;
      exit 1
  | exn ->
      eprintf "Error: %s\n" (Printexc.to_string exn);
      exit 1

let () =
  (* Always run in CLI mode - parse arguments and run *)
  Arg.parse spec_list (fun _ -> ()) usage_msg;
  run_cli_mode !dry_run