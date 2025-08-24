open Types

let parse_recipient_block lines =
  match lines with
  | [] -> None
  | name :: rest ->
    let (email_line, address_lines) = 
      match rest with
      | [] -> ("", [])
      | first :: remaining ->
        if String.contains first '@' then
          (first, remaining)
        else
          ("", first :: remaining)
    in
    let orgno = "" in (* Default empty orgno for recipients *)
    Some {
      name = String.trim name;
      orgno = orgno;
      adr = List.map String.trim (email_line :: address_lines) |> List.filter (fun s -> s <> "")
    }

let parse_recipients_from_string content =
  let lines = String.split_on_char '\n' content 
              |> List.map String.trim in
  
  let rec split_into_blocks acc current_block = function
    | [] -> 
        if current_block = [] then acc
        else (List.rev current_block) :: acc
    | "" :: rest -> 
        let acc' = if current_block = [] then acc else (List.rev current_block) :: acc in
        split_into_blocks acc' [] rest
    | line :: rest -> 
        split_into_blocks acc (line :: current_block) rest
  in
  
  let blocks = split_into_blocks [] [] lines |> List.rev in
  List.filter_map parse_recipient_block blocks

let parse_recipients_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    
    parse_recipients_from_string content
  with
  | Sys_error _ -> []
  | exn -> 
    Printf.eprintf "Error parsing recipients file: %s\n" (Printexc.to_string exn);
    []

let recipients_file_exists filename =
  try
    let _ = Unix.stat filename in
    true
  with
  | Unix.Unix_error (Unix.ENOENT, _, _) -> false
  | _ -> false