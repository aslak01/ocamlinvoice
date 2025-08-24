open Printf

let usage_msg = "invoice-splitter [-dry]"
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
    (* Get database connection *)
    let db = match Invoice_src.Database.get_or_create_connection () with
      | Ok db -> db
      | Error msg -> failwith ("Database error: " ^ msg)
    in
    
    (* Read configuration from database *)
    let sender_info = Invoice_src.Database.get_setting_or_default db "sender" "" in
    let bank_info = Invoice_src.Database.get_setting_or_default db "bankdetails" "" in
    let description = Invoice_src.Database.get_setting_or_default db "description" "" in
    let amount_str = Invoice_src.Database.get_setting_or_default db "amount" "" in
    
    (* Check required settings *)
    if String.trim sender_info = "" then (
      eprintf "Error: Required setting 'sender' not found in database\n";
      eprintf "Please configure sender information in the application\n";
      exit 1
    );
    
    if String.trim bank_info = "" then (
      eprintf "Error: Required setting 'bankdetails' not found in database\n";
      eprintf "Please configure bank details in the application\n";
      exit 1
    );
    
    if String.trim description = "" then (
      eprintf "Error: Required setting 'description' not found in database\n";
      eprintf "Please configure service description in the application\n";
      exit 1
    );
    
    if String.trim amount_str = "" then (
      eprintf "Error: Required setting 'amount' not found in database\n";
      eprintf "Please configure invoice amount in the application\n";
      exit 1
    );
    
    (* Parse configuration from database *)
    printf "Reading sender details from database...\n";
    let sender_lines = String.split_on_char '\n' (String.trim sender_info) |> List.filter (fun s -> String.trim s <> "") in
    
    printf "Reading bank details from database...\n";
    let bank_lines = String.split_on_char '\n' (String.trim bank_info) |> List.filter (fun s -> String.trim s <> "") in
    
    (* Parse invoice details from database *)
    printf "Reading invoice details from database (description and amount)...\n";
    let amount_value = try Float.of_string (String.trim amount_str) with _ -> 0.0 in
    let invoice_info = {
      Invoice_src.Invoice_parser.description = description;
      Invoice_src.Invoice_parser.total_amount = amount_value;
    } in
    
    printf "Invoice description: %s\n" (if invoice_info.Invoice_src.Invoice_parser.description = "" then "(empty)" else invoice_info.Invoice_src.Invoice_parser.description);
    printf "Total amount: %.2f NOK\n" invoice_info.Invoice_src.Invoice_parser.total_amount;
    
    (* Check for recipients in database *)
    let recipients_info = Invoice_src.Database.get_setting_or_default db "recipients" "" in
    
    if String.trim recipients_info <> "" then (
      printf "Found recipients in database - generating invoices for multiple recipients\n";
      let recipients = Invoice_src.Recipients_parser.parse_recipients_from_string recipients_info in
      
      if List.length recipients = 0 then (
        eprintf "Error: No valid recipients found in database\n";
        eprintf "Please configure recipient information in the application\n";
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
      eprintf "Error: No recipients found in database\n";
      eprintf "Please configure recipient information in the application\n";
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
