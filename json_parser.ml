open Types
open Yojson.Basic.Util

let parse_currency json =
  {
    name = json |> member "name" |> to_string;
    short = json |> member "short" |> to_string;
    symbol = json |> member "symbol" |> to_option to_string;
  }

let parse_company json =
  {
    name = json |> member "name" |> to_string;
    orgno = json |> member "orgno" |> to_string;
    adr = json |> member "adr" |> to_list |> List.map to_string;
  }

let parse_bank json =
  {
    accno = json |> member "accno" |> to_string;
    iban = json |> member "iban" |> to_string;
    bic = json |> member "bic" |> to_string;
    bank = json |> member "bank" |> to_string;
  }

let parse_invoice_date_field json =
  {
    value = json |> member "value" |> to_string;
  }

let parse_invoice_meta json =
  {
    invoice_date = json |> member "invoiceDate" |> parse_invoice_date_field;
    due_date = json |> member "dueDate" |> parse_invoice_date_field;
    invoice_number = json |> member "invoiceNumber" |> parse_invoice_date_field;
  }

let parse_vat json =
  {
    enabled = json |> member "enabled" |> to_bool;
    rate = json |> member "rate" |> to_int;
  }

let parse_line_item json =
  {
    date = json |> member "date" |> to_string;
    description = json |> member "description" |> to_string;
    price = json |> member "price" |> to_string;
  }

let parse_string_dict json =
  json |> to_assoc |> List.map (fun (k, v) -> (k, to_string v))

let parse_nested_string_dict json =
  json |> to_assoc |> List.map (fun (k, v) -> (k, parse_string_dict v))

let parse_meta json =
  {
    title = json |> member "title" |> parse_string_dict;
    pay_info = json |> member "payInfo" |> parse_nested_string_dict;
    line_headings = json |> member "lineHeadings" |> parse_nested_string_dict;
    payable_to = json |> member "payableTo" |> parse_string_dict;
  }

let safe_string json field default =
  try json |> member field |> to_string
  with _ -> default

let parse_invoice_data json =
  {
    locale = safe_string json "locale" "nb-NO";
    currency = json |> member "currency" |> parse_currency;
    your_company = json |> member "yourCompany" |> parse_company;
    your_bank = json |> member "yourBank" |> parse_bank;
    invoice_meta = json |> member "invoiceMeta" |> parse_invoice_meta;
    customer = json |> member "customer" |> parse_company;
    author = safe_string json "author" "Invoice Generator";
    service = safe_string json "service" "Professional Services";
    lines = json |> member "lines" |> to_list |> List.map parse_line_item;
    pdf_title = json |> member "pdfTitle" |> to_string;
    vat = json |> member "vat" |> parse_vat;
    meta = json |> member "meta" |> parse_meta;
  }

let load_from_file filename =
  let json = Yojson.Basic.from_file filename in
  parse_invoice_data json