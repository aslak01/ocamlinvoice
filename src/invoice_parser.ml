type invoice_info = {
  description : string;
  total_amount : float;
}

let normalize_decimal_separator amount_str =
  String.map (function ',' -> '.' | c -> c) amount_str

let parse_amount amount_str =
  try
    let normalized = normalize_decimal_separator (String.trim amount_str) in
    Some (Float.of_string normalized)
  with
  | Failure _ -> None

let parse_invoice_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    
    (* Split content by double newline to separate description from amount *)
    let parts = String.split_on_char '\n' content in
    let non_empty_lines = List.filter (fun s -> String.trim s <> "") parts in
    
    match non_empty_lines with
    | [] -> None
    | [single_line] ->
        (* If only one line, treat it as amount with empty description *)
        (match parse_amount single_line with
         | Some amount -> Some { description = ""; total_amount = amount }
         | None -> None)
    | lines ->
        (* Last line is amount, everything else is description *)
        let amount_line = List.nth lines (List.length lines - 1) in
        let description_lines = List.rev (List.tl (List.rev lines)) in
        let description = String.concat "\n" description_lines in
        
        (match parse_amount amount_line with
         | Some amount -> Some { description = String.trim description; total_amount = amount }
         | None -> None)
  with
  | Sys_error _ -> None
  | exn -> 
    Printf.eprintf "Error parsing invoice file: %s\n" (Printexc.to_string exn);
    None

let invoice_file_exists filename =
  try
    let _ = Unix.stat filename in
    true
  with
  | Unix.Unix_error (Unix.ENOENT, _, _) -> false
  | _ -> false

let calculate_amount_per_recipient total_amount recipient_count =
  if recipient_count <= 0 then 0.0
  else total_amount /. (Float.of_int recipient_count)