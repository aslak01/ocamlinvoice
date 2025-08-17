type invoice_info = {
  description : string;
  total_amount : float;
}

val parse_invoice_files : string -> string -> invoice_info option

val parse_invoice_file : string -> invoice_info option

val invoice_file_exists : string -> bool

val calculate_amount_per_recipient : float -> int -> float