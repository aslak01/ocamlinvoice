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