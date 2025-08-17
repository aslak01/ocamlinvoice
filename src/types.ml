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