type currency = {
  name : string;
  short : string;
  symbol : string option;
}

type company = {
  name : string;
  orgno : string;
  adr : string list;
}

type bank = {
  accno : string;
  iban : string;
  bic : string;
  bank : string;
}

type invoice_date_field = {
  value : string;
}

type invoice_meta = {
  invoice_date : invoice_date_field;
  due_date : invoice_date_field;
  invoice_number : invoice_date_field;
}

type vat = {
  enabled : bool;
  rate : int;
}

type line_item = {
  date : string;
  description : string;
  price : string;
}

type meta_strings = {
  title : (string * string) list;
  pay_info : (string * (string * string) list) list;
  line_headings : (string * (string * string) list) list;
  payable_to : (string * string) list;
}

type invoice_data = {
  locale : string;
  currency : currency;
  your_company : company;
  your_bank : bank;
  invoice_meta : invoice_meta;
  customer : company;
  author : string;
  service : string;
  lines : line_item list;
  pdf_title : string;
  vat : vat;
  meta : meta_strings;
}

(* Helper functions for invoice data manipulation *)
let update_invoice_customer_and_number invoice_data new_customer new_invoice_number =
  let updated_meta = {
    invoice_data.invoice_meta with
    invoice_number = { value = new_invoice_number }
  } in
  { invoice_data with
    customer = new_customer;
    invoice_meta = updated_meta;
  }

let get_customer invoice_data = invoice_data.customer

let update_invoice_with_single_line invoice_data description amount =
  let line_item = {
    date = "";
    description = description;
    price = Printf.sprintf "%.2f" amount;
  } in
  { invoice_data with lines = [line_item] }

(* Simplified invoice data creation from file-based inputs *)
let create_basic_invoice_data sender_lines _bank_lines customer invoice_number description amount =
  let today = 
    let tm = Unix.localtime (Unix.time ()) in
    Printf.sprintf "%04d-%02d-%02d" (1900 + tm.tm_year) (tm.tm_mon + 1) tm.tm_mday in
  let due_date = 
    let tm = Unix.localtime (Unix.time () +. (30.0 *. 24.0 *. 60.0 *. 60.0)) in
    Printf.sprintf "%04d-%02d-%02d" (1900 + tm.tm_year) (tm.tm_mon + 1) tm.tm_mday in
  
  let sender_company = {
    name = (match sender_lines with [] -> "Sender" | h :: _ -> h);
    orgno = "";
    adr = sender_lines;
  } in
  
  let line_item = {
    date = "";
    description = description;
    price = Printf.sprintf "%.2f" amount;
  } in
  
  {
    locale = "nb-NO";
    currency = { name = "Norwegian Krone"; short = "NOK"; symbol = Some "kr" };
    your_company = sender_company;
    your_bank = { accno = ""; iban = ""; bic = ""; bank = "" };
    invoice_meta = {
      invoice_date = { value = today };
      due_date = { value = due_date };
      invoice_number = { value = invoice_number };
    };
    customer = customer;
    author = "";
    service = "";
    lines = [line_item];
    pdf_title = "Invoice";
    vat = { enabled = false; rate = 0 };
    meta = {
      title = [("nb-NO", "FAKTURA")];
      pay_info = [("nb-NO", [
        ("invoiceDate", "Fakturadato:");
        ("dueDate", "Forfallsdato:");
        ("invoiceNumber", "Fakturanummer:");
      ])];
      line_headings = [("nb-NO", [
        ("description", "Beskrivelse");
        ("price", "Beløp");
      ])];
      payable_to = [("nb-NO", "Betalingsdetaljer")];
    };
  }