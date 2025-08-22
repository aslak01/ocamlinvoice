(* Formatting utilities for invoice generation *)
open Types

(* Number formatting with Norwegian conventions *)
let format_number amount =
  let amount_str = Printf.sprintf "%.2f" amount in
  let parts = String.split_on_char '.' amount_str in
  match parts with
  | [integer_part; decimal_part] ->
      let format_integer_part part =
        let len = String.length part in
        let buf = Buffer.create (len + len / 3) in
        for i = 0 to len - 1 do
          if i > 0 && (len - i) mod 3 = 0 then
            Buffer.add_char buf ' ';
          Buffer.add_char buf part.[i]
        done;
        Buffer.contents buf
      in
      let formatted_integer = format_integer_part integer_part in
      Printf.sprintf "%s,%s" formatted_integer decimal_part
  | [integer_part] ->
      let len = String.length integer_part in
      let buf = Buffer.create (len + len / 3) in
      for i = 0 to len - 1 do
        if i > 0 && (len - i) mod 3 = 0 then
          Buffer.add_char buf ' ';
        Buffer.add_char buf integer_part.[i]
      done;
      Buffer.contents buf
  | _ -> amount_str

(* Currency formatting *)
let format_currency amount currency =
  let formatted_amount = format_number amount in
  match currency.symbol with
  | Some symbol -> Printf.sprintf "%s %s" formatted_amount symbol
  | None -> Printf.sprintf "%s %s" formatted_amount currency.short

(* Date formatting from ISO format to dd/mm/yyyy *)
let format_date date_str =
  try
    let date_part = 
      if String.contains date_str 'T' then
        let parts = String.split_on_char 'T' date_str in
        List.hd parts
      else
        date_str
    in
    let parts = String.split_on_char '-' date_part in
    match parts with
    | [year; month; day] -> Printf.sprintf "%s/%s/%s" day month year
    | _ -> date_str
  with _ -> date_str

(* VAT calculation *)
let calculate_vat amount rate enabled =
  if enabled then
    let base_amount = float_of_string amount in
    let vat_amount = base_amount *. (float_of_int rate) /. 100.0 in
    (base_amount, vat_amount, base_amount +. vat_amount)
  else
    let amount_f = float_of_string amount in
    (amount_f, 0.0, amount_f)

(* Localization helpers *)
let lookup_simple_string dict locale =
  try List.assoc locale dict
  with Not_found -> "Missing translation"

let lookup_nested_string dict locale key =
  try
    let locale_dict = List.assoc locale dict in
    List.assoc key locale_dict
  with Not_found -> key

(* UTF-8 to Latin-1 character conversion for Norwegian characters *)
let utf8_to_latin1_char s pos =
  let len = String.length s in
  if pos < len - 1 then
    let b1 = Char.code s.[pos] in
    let b2 = Char.code s.[pos + 1] in
    match (b1, b2) with
    | (0xC3, 0xB8) -> Some (0xF8, 2) (* ø *)
    | (0xC3, 0x98) -> Some (0xD8, 2) (* Ø *)
    | (0xC3, 0xA6) -> Some (0xE6, 2) (* æ *)
    | (0xC3, 0x86) -> Some (0xC6, 2) (* Æ *)
    | (0xC3, 0xA5) -> Some (0xE5, 2) (* å *)
    | (0xC3, 0x85) -> Some (0xC5, 2) (* Å *)
    | _ -> None
  else None

(* PDF string escaping with Norwegian character support *)
let escape_pdf_string s =
  let buf = Buffer.create (String.length s * 2) in
  let rec process_string pos =
    if pos >= String.length s then ()
    else
      let c = s.[pos] in
      match c with
      | '(' -> Buffer.add_string buf "\\("; process_string (pos + 1)
      | ')' -> Buffer.add_string buf "\\)"; process_string (pos + 1)
      | '\\' -> Buffer.add_string buf "\\\\"; process_string (pos + 1)
      | _ when Char.code c > 127 ->
          (match utf8_to_latin1_char s pos with
           | Some (latin1_code, consumed) ->
               Buffer.add_char buf (Char.chr latin1_code);
               process_string (pos + consumed)
           | None ->
               Buffer.add_string buf (Printf.sprintf "\\%03o" (Char.code c));
               process_string (pos + 1))
      | _ -> Buffer.add_char buf c; process_string (pos + 1)
  in
  process_string 0;
  Buffer.contents buf