(* Invoice-specific layout logic *)
open Types
open Pdf_text
open Formatting_utils

(* Invoice layout state *)
type layout_state = {
  content : pdf_content;
  current_y : float;
  config : page_config;
}

let create_layout_state config start_y = {
  content = empty_content;
  current_y = start_y;
  config;
}

let add_content_to_state state new_content =
  { state with content = add_to_content state.content new_content }

let move_y state dy =
  { state with current_y = state.current_y -. dy }

(* Helper function for adding space - currently unused but kept for potential future use *)
let _add_space state height = move_y state height

(* Invoice header *)
let add_invoice_title state invoice_data =
  let title = lookup_simple_string invoice_data.meta.title invoice_data.locale in
  let title_ops = text_at_position title state.config.margin state.current_y state.config.font_size_title in
  let new_state = add_content_to_state state title_ops in
  move_y new_state (state.config.font_size_title +. 23.0)

(* Company information blocks *)
let add_company_info state invoice_data =
  let your_company_block = create_address_block state.config invoice_data.your_company state.config.margin state.current_y in
  let customer_x = 350.0 in
  let customer_block = create_address_block state.config invoice_data.customer customer_x state.current_y in
  let state1 = add_content_to_state state your_company_block.content in
  let state2 = add_content_to_state state1 customer_block.content in
  move_y state2 (max your_company_block.height customer_block.height +. 25.0)

(* Invoice metadata (dates, invoice number) *)
let add_invoice_metadata state invoice_data =
  let pay_info = List.assoc invoice_data.locale invoice_data.meta.pay_info in
  let invoice_date_label = List.assoc "invoiceDate" pay_info in
  let due_date_label = List.assoc "dueDate" pay_info in
  let invoice_number_label = List.assoc "invoiceNumber" pay_info in
  
  let formatted_invoice_date = format_date invoice_data.invoice_meta.invoice_date.value in
  let formatted_due_date = format_date invoice_data.invoice_meta.due_date.value in
  
  let metadata_lines = [
    Printf.sprintf "%s %s" invoice_date_label formatted_invoice_date;
    Printf.sprintf "%s %s" due_date_label formatted_due_date;
    Printf.sprintf "%s %s" invoice_number_label invoice_data.invoice_meta.invoice_number.value;
  ] in
  
  let metadata_block = create_text_block state.config metadata_lines state.config.margin state.current_y state.config.font_size_normal in
  let new_state = add_content_to_state state metadata_block.content in
  move_y new_state (metadata_block.height +. 30.0)

(* Line items table *)
let add_line_items_header state invoice_data =
  let line_headings = List.assoc invoice_data.locale invoice_data.meta.line_headings in
  let date_header = List.assoc "date" line_headings in
  let desc_header = List.assoc "description" line_headings in
  let price_header = List.assoc "price" line_headings in
  
  let columns = [
    { x = state.config.margin; alignment = `Left };
    { x = 150.0; alignment = `Left };
    { x = state.config.width -. state.config.margin; alignment = `Right };
  ] in
  
  let headers = [date_header; desc_header; price_header] in
  let header_ops = create_table_header state.config headers columns state.current_y in
  let line_y = state.current_y -. 8.0 in
  let line_ops = horizontal_line state.config.margin (state.config.width -. state.config.margin) (line_y +. 4.0) in
  
  let state1 = add_content_to_state state header_ops in
  let state2 = add_content_to_state state1 line_ops in
  move_y state2 16.0

let add_line_items state invoice_data =
  let columns = [
    { x = state.config.margin; alignment = `Left };
    { x = 150.0; alignment = `Left };
    { x = state.config.width -. state.config.margin; alignment = `Right };
  ] in
  
  let process_line_item state line =
    let formatted_date = format_date line.date in
    let formatted_price = format_currency (float_of_string line.price) invoice_data.currency in
    let values = [formatted_date; line.description; formatted_price] in
    let row_ops = create_table_row state.config values columns state.current_y in
    let new_state = add_content_to_state state row_ops in
    move_y new_state state.config.line_height
  in
  
  List.fold_left process_line_item state invoice_data.lines

(* Totals section *)
let add_totals state invoice_data =
  let subtotal = List.fold_left (fun acc line -> acc +. (float_of_string line.price)) 0.0 invoice_data.lines in
  let (base_total, vat_amount, final_total) = calculate_vat (string_of_float subtotal) invoice_data.vat.rate invoice_data.vat.enabled in
  let price_column_right = state.config.width -. state.config.margin in
  
  (* Add separator line *)
  let line_ops = horizontal_line state.config.margin (state.config.width -. state.config.margin) (state.current_y +. 3.0) in
  let state1 = add_content_to_state state line_ops in
  let state = move_y state1 15.0 in
  
  (* Add VAT breakdown if enabled *)
  let state = 
    if invoice_data.vat.enabled then
      let subtotal_text = Printf.sprintf "Subtotal: %s" (format_currency base_total invoice_data.currency) in
      let vat_text = Printf.sprintf "Moms (%d%%): %s" invoice_data.vat.rate (format_currency vat_amount invoice_data.currency) in
      let subtotal_ops = right_aligned_text subtotal_text price_column_right state.current_y state.config.font_size_normal in
      let vat_ops = right_aligned_text vat_text price_column_right (state.current_y -. state.config.font_size_normal -. 3.0) state.config.font_size_normal in
      let state1 = add_content_to_state state subtotal_ops in
      let state2 = add_content_to_state state1 vat_ops in
      move_y state2 (2.0 *. (state.config.font_size_normal +. 3.0) +. 5.0)
    else
      state
  in
  
  (* Add total *)
  let total_text = format_currency final_total invoice_data.currency in
  let total_ops = right_aligned_text total_text price_column_right state.current_y state.config.font_size_heading in
  let new_state = add_content_to_state state total_ops in
  move_y new_state (state.config.font_size_heading +. 43.0)

(* Payment information *)
let add_payment_info state invoice_data =
  let payable_to_label = lookup_simple_string invoice_data.meta.payable_to invoice_data.locale in
  let payment_lines = [
    payable_to_label;
    Printf.sprintf "Account: %s" invoice_data.your_bank.accno;
    Printf.sprintf "IBAN: %s" invoice_data.your_bank.iban;
    Printf.sprintf "BIC: %s" invoice_data.your_bank.bic;
    invoice_data.your_bank.bank;
  ] in
  
  let title_ops = text_at_position payable_to_label state.config.margin state.current_y state.config.font_size_heading in
  let details_start_y = state.current_y -. state.config.font_size_heading -. 8.0 in
  let details_block = create_text_block state.config (List.tl payment_lines) state.config.margin details_start_y state.config.font_size_small in
  
  let state1 = add_content_to_state state title_ops in
  let state2 = add_content_to_state state1 details_block.content in
  move_y state2 (state.config.font_size_heading +. details_block.height +. 8.0)

(* Main layout function *)
let generate_invoice_layout config invoice_data =
  let initial_state = create_layout_state config 750.0 in
  let state1 = add_invoice_title initial_state invoice_data in
  let state2 = add_company_info state1 invoice_data in
  let state3 = add_invoice_metadata state2 invoice_data in
  let state4 = add_line_items_header state3 invoice_data in
  let state5 = add_line_items state4 invoice_data in
  let state6 = add_totals state5 invoice_data in
  add_payment_info state6 invoice_data